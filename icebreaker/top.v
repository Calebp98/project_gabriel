//======================================================================
// Challenge-response authentication system using ChaCha20
// Client-initiated authentication flow:
// 1. Client sends "AUTH\n" to request challenge
// 2. Device responds with "CHAL:XXXXXXXXXXXXXXXXXXXXXXXX\n" (96-bit challenge)
// 3. Client sends "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" where YYYY = ChaCha20(XXXX, secret_key)
// 4. Device verifies and grants authentication
// Once authenticated, accepts 'Y' (pin LOW/0V) or 'N' (pin HIGH/3.3V) commands
// LED shows different patterns for each state (for debugging)
//======================================================================

module top (
    input  wire CLK,         // 12 MHz clock on iCEbreaker
    input  wire RX,          // UART RX from picoprobe
    output wire TX,          // UART TX to picoprobe
    output wire CONTROL_PIN, // Control output pin (0V for 'Y', 3.3V for 'N')
    output wire LED1         // Status LED
);

    // Secret key for ChaCha20 authentication (256 bits)
    localparam [255:0] SECRET_KEY = 256'hA5C3_DEAD_BEEF_CAFE_1337_FACE_B00B_C0DE_0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;

    // Response timeout: 5 seconds at 12 MHz = 60,000,000 cycles
    localparam [25:0] RESPONSE_TIMEOUT = 26'd60_000_000;

    // State machine
    localparam STATE_IDLE = 3'd0;           // Wait for AUTH request
    localparam STATE_CHACHA_START = 3'd1;   // Start ChaCha20 computation
    localparam STATE_CHACHA_WAIT = 3'd2;    // Wait for ChaCha20 to complete
    localparam STATE_SEND_CHALLENGE = 3'd3; // Send challenge to client
    localparam STATE_WAIT_RESPONSE = 3'd4;  // Wait for client response
    localparam STATE_VERIFY = 3'd5;         // Verify response
    localparam STATE_SEND_ACK = 3'd6;       // Send acknowledgment (OK or FAIL)

    // UART signals
    wire [7:0] rx_data;
    wire rx_data_valid;
    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_busy;

    // State and timers
    reg [2:0] state = STATE_IDLE;
    reg [25:0] timer = 0;
    reg [5:0] send_index = 0;  // Need up to 30 for 96-bit challenge
    reg [5:0] recv_index = 0;

    // Challenge/response (96-bit challenge, 128-bit response)
    wire [95:0] challenge;
    reg [95:0] challenge_snapshot = 0;
    reg [7:0] response_buffer [0:37];  // "RESP:" + 32 hex chars + "\n" = 38 bytes
    reg [7:0] auth_buffer [0:4];       // "AUTH\n" = 5 bytes
    reg [2:0] auth_index = 0;

    // ChaCha20 for response verification
    reg chacha_start;
    wire chacha_ready;
    wire [127:0] chacha_output;
    wire chacha_valid;

    // Authentication status
    reg authenticated = 0;
    reg [25:0] auth_timer = 0;
    reg auth_success = 0;  // Track if last verification succeeded

    // Control pin state
    reg control_state = 1;  // Default HIGH (3.3V)

    // Response parsing variables
    reg [127:0] received_response;
    integer j;
    reg match;

    // UART TX busy edge detection
    reg tx_busy_prev = 0;

    //----------------------------------------------------------------
    // UART receiver
    //----------------------------------------------------------------
    uart_rx #(
        .CLOCK_FREQ(12_000_000),
        .BAUD_RATE(115200)
    ) uart_receiver (
        .clk(CLK),
        .rst(1'b0),
        .rx(RX),
        .data(rx_data),
        .data_valid(rx_data_valid)
    );

    //----------------------------------------------------------------
    // UART transmitter
    //----------------------------------------------------------------
    uart_tx #(
        .CLOCK_FREQ(12_000_000),
        .BAUD_RATE(115200)
    ) uart_transmitter (
        .clk(CLK),
        .rst(1'b0),
        .data(tx_data),
        .data_valid(tx_data_valid),
        .tx(TX),
        .busy(tx_busy)
    );

    //----------------------------------------------------------------
    // LFSR for challenge generation (6x 16-bit LFSRs = 96 bits)
    //----------------------------------------------------------------
    wire [15:0] lfsr_out[0:5];
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : gen_lfsr
            lfsr #(.SEED(16'hACE1 + i)) lfsr_inst (
                .clk(CLK),
                .rst(1'b0),
                .enable(1'b1),
                .random(lfsr_out[i])
            );
        end
    endgenerate

    assign challenge = {lfsr_out[5], lfsr_out[4], lfsr_out[3],
                        lfsr_out[2], lfsr_out[1], lfsr_out[0]};

    //----------------------------------------------------------------
    // ChaCha20 for challenge-response verification
    // Use challenge as nonce, encrypt zeros (cleaner approach for 96-bit)
    //----------------------------------------------------------------
    chacha20_compact chacha_inst (
        .clk(CLK),
        .rst_n(1'b1),
        .start(chacha_start),
        .ready(chacha_ready),
        .key(SECRET_KEY),
        .nonce(challenge_snapshot),  // Challenge IS the nonce
        .plaintext(128'h0),          // Encrypt zeros to get response
        .output_block(chacha_output),
        .valid(chacha_valid)
    );

    //----------------------------------------------------------------
    // Helper function: 4-bit value to ASCII hex
    //----------------------------------------------------------------
    function [7:0] nibble_to_hex;
        input [3:0] nibble;
        begin
            nibble_to_hex = (nibble < 10) ? (8'h30 + nibble) : (8'h41 + nibble - 10);
        end
    endfunction

    //----------------------------------------------------------------
    // Helper function: ASCII hex to 4-bit value
    //----------------------------------------------------------------
    function [3:0] hex_to_nibble;
        input [7:0] hex;
        begin
            if (hex >= 8'h30 && hex <= 8'h39)  // '0'-'9'
                hex_to_nibble = hex - 8'h30;
            else if (hex >= 8'h41 && hex <= 8'h46)  // 'A'-'F'
                hex_to_nibble = hex - 8'h41 + 4'd10;
            else if (hex >= 8'h61 && hex <= 8'h66)  // 'a'-'f'
                hex_to_nibble = hex - 8'h61 + 4'd10;
            else
                hex_to_nibble = 4'd0;
        end
    endfunction

    //----------------------------------------------------------------
    // Main state machine
    //----------------------------------------------------------------
    always @(posedge CLK) begin
        tx_data_valid <= 0;
        tx_busy_prev <= tx_busy;
        chacha_start <= 0;

        // Update timers
        timer <= timer + 1;
        if (authenticated)
            auth_timer <= auth_timer + 1;

        // Handle Y/N commands when authenticated and not collecting response
        // After processing Y/N, immediately clear authentication to require re-auth
        if (authenticated && rx_data_valid && state != STATE_WAIT_RESPONSE) begin
            case (rx_data)
                8'h59,  // 'Y'
                8'h79:  // 'y'
                begin
                    control_state <= 0;  // Set to LOW (0V)
                    authenticated <= 0;  // Clear auth - require re-authentication for next command
                end

                8'h4E,  // 'N'
                8'h6E:  // 'n'
                begin
                    control_state <= 1;  // Set to HIGH (3.3V)
                    authenticated <= 0;  // Clear auth - require re-authentication for next command
                end

                default: begin
                    // Ignore other characters
                end
            endcase
        end

        case (state)
            STATE_IDLE: begin
                // Wait for "AUTH\n" request from client (only if not already authenticated)
                if (!authenticated && rx_data_valid) begin
                    auth_buffer[auth_index] <= rx_data;

                    // Check if we received complete "AUTH\n" sequence
                    if (auth_index == 0 && rx_data == 8'h41) begin  // 'A'
                        auth_index <= 1;
                    end else if (auth_index == 1 && rx_data == 8'h55) begin  // 'U'
                        auth_index <= 2;
                    end else if (auth_index == 2 && rx_data == 8'h54) begin  // 'T'
                        auth_index <= 3;
                    end else if (auth_index == 3 && rx_data == 8'h48) begin  // 'H'
                        auth_index <= 4;
                    end else if (auth_index == 4 && rx_data == 8'h0A) begin  // '\n'
                        // Received valid "AUTH\n" - start challenge process
                        auth_index <= 0;
                        timer <= 0;
                        challenge_snapshot <= challenge;  // Capture current challenge
                        send_index <= 0;
                        state <= STATE_CHACHA_START;
                    end else begin
                        // Invalid sequence, reset
                        auth_index <= 0;
                    end
                end
                // If authenticated, just stay in IDLE and accept Y/N commands
            end

            STATE_CHACHA_START: begin
                // Start ChaCha20 encryption of challenge
                chacha_start <= 1;
                state <= STATE_CHACHA_WAIT;
            end

            STATE_CHACHA_WAIT: begin
                // Wait for ChaCha20 encryption to complete
                if (chacha_valid) begin
                    // ChaCha20 done, now send challenge
                    state <= STATE_SEND_CHALLENGE;
                end
            end

            STATE_SEND_CHALLENGE: begin
                // Send "CHAL:XXXXXXXXXXXXXXXXXXXXXXXX\n" (30 characters: 5 + 24 + 1)
                // Wait for falling edge before incrementing
                if (tx_busy_prev && !tx_busy) begin
                    send_index <= send_index + 1;
                    if (send_index >= 29) begin  // After sending last char
                        recv_index <= 0;
                        timer <= 0;
                        state <= STATE_WAIT_RESPONSE;
                    end
                end

                if (!tx_busy && !tx_busy_prev) begin
                    if (send_index < 30) begin
                        if (send_index < 5) begin
                            // Send "CHAL:"
                            case (send_index)
                                0: tx_data <= 8'h43;  // 'C'
                                1: tx_data <= 8'h48;  // 'H'
                                2: tx_data <= 8'h41;  // 'A'
                                3: tx_data <= 8'h4C;  // 'L'
                                4: tx_data <= 8'h3A;  // ':'
                            endcase
                        end else if (send_index < 29) begin
                            // Send 24 hex characters (96 bits / 4 bits per hex = 24 chars)
                            // Index 5-28 are hex chars, map to nibbles 23 down to 0
                            tx_data <= nibble_to_hex(challenge_snapshot[(28-send_index)*4 +: 4]);
                        end else begin
                            // Send newline
                            tx_data <= 8'h0A;  // '\n'
                        end
                        tx_data_valid <= 1;
                    end
                end
            end

            STATE_WAIT_RESPONSE: begin
                // Collect response characters: "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" (38 bytes)
                if (rx_data_valid && recv_index < 38) begin
                    response_buffer[recv_index] <= rx_data;
                    recv_index <= recv_index + 1;

                    // Check for newline (end of response)
                    if (rx_data == 8'h0A && recv_index >= 37) begin
                        state <= STATE_VERIFY;
                    end
                end

                // Timeout after 5 seconds
                if (timer >= RESPONSE_TIMEOUT) begin
                    authenticated <= 0;
                    state <= STATE_IDLE;
                end
            end

            STATE_VERIFY: begin
                // Parse "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" and verify
                if (response_buffer[0] == 8'h52 &&  // 'R'
                    response_buffer[1] == 8'h45 &&  // 'E'
                    response_buffer[2] == 8'h53 &&  // 'S'
                    response_buffer[3] == 8'h50 &&  // 'P'
                    response_buffer[4] == 8'h3A) begin  // ':'

                    // Extract 128-bit hex response (32 hex chars = indices 5-36)
                    match = 1;
                    for (j = 0; j < 32; j = j + 1) begin
                        received_response[(31-j)*4 +: 4] = hex_to_nibble(response_buffer[5+j]);
                    end

                    // Compare with expected ChaCha20 response
                    if (received_response == chacha_output) begin
                        authenticated <= 1;  // Success!
                        auth_success <= 1;
                        auth_timer <= 0;
                    end else begin
                        authenticated <= 0;  // Wrong response
                        auth_success <= 0;
                    end
                end else begin
                    // Invalid format
                    authenticated <= 0;
                    auth_success <= 0;
                end

                send_index <= 0;
                state <= STATE_SEND_ACK;
            end

            STATE_SEND_ACK: begin
                // Send "OK\n" if authenticated, "FAIL\n" if not
                if (tx_busy_prev && !tx_busy) begin
                    send_index <= send_index + 1;
                    if ((auth_success && send_index >= 2) ||  // "OK\n" = 3 chars
                        (!auth_success && send_index >= 4)) begin  // "FAIL\n" = 5 chars
                        state <= STATE_IDLE;
                    end
                end

                if (!tx_busy && !tx_busy_prev) begin
                    if (auth_success) begin
                        // Send "OK\n"
                        case (send_index)
                            0: tx_data <= 8'h4F;  // 'O'
                            1: tx_data <= 8'h4B;  // 'K'
                            2: tx_data <= 8'h0A;  // '\n'
                        endcase
                        if (send_index < 3)
                            tx_data_valid <= 1;
                    end else begin
                        // Send "FAIL\n"
                        case (send_index)
                            0: tx_data <= 8'h46;  // 'F'
                            1: tx_data <= 8'h41;  // 'A'
                            2: tx_data <= 8'h49;  // 'I'
                            3: tx_data <= 8'h4C;  // 'L'
                            4: tx_data <= 8'h0A;  // '\n'
                        endcase
                        if (send_index < 5)
                            tx_data_valid <= 1;
                    end
                end
            end

            default: state <= STATE_IDLE;
        endcase
    end

    //----------------------------------------------------------------
    // LED debugging: different patterns for each state
    // STATE_IDLE (0):              Solid OFF (not authenticated) or very fast blink (authenticated)
    // STATE_CHACHA_START (1):      1 short blink
    // STATE_CHACHA_WAIT (2):       2 short blinks
    // STATE_SEND_CHALLENGE (3):    3 short blinks
    // STATE_WAIT_RESPONSE (4):     4 short blinks
    // STATE_VERIFY (5):            5 short blinks (rapid)
    // STATE_SEND_ACK (6):          6 short blinks
    //----------------------------------------------------------------
    reg [25:0] led_counter = 0;
    reg led_state = 0;

    always @(posedge CLK) begin
        led_counter <= led_counter + 1;

        // Create blink patterns based on state
        case (state)
            STATE_IDLE: begin
                // Fast blink if authenticated, slow if not
                led_state <= authenticated ? led_counter[20] : led_counter[23];
            end
            STATE_CHACHA_START: begin
                // 1 blink: on for short period
                led_state <= (led_counter[23:20] < 4'd1) ? 1'b1 : 1'b0;
            end
            STATE_CHACHA_WAIT: begin
                // 2 blinks
                led_state <= ((led_counter[23:20] < 4'd1) ||
                             (led_counter[23:20] >= 4'd2 && led_counter[23:20] < 4'd3)) ? 1'b1 : 1'b0;
            end
            STATE_SEND_CHALLENGE: begin
                // 3 blinks
                led_state <= ((led_counter[23:20] < 4'd1) ||
                             (led_counter[23:20] >= 4'd2 && led_counter[23:20] < 4'd3) ||
                             (led_counter[23:20] >= 4'd4 && led_counter[23:20] < 4'd5)) ? 1'b1 : 1'b0;
            end
            STATE_WAIT_RESPONSE: begin
                // 4 blinks
                led_state <= ((led_counter[23:20] < 4'd1) ||
                             (led_counter[23:20] >= 4'd2 && led_counter[23:20] < 4'd3) ||
                             (led_counter[23:20] >= 4'd4 && led_counter[23:20] < 4'd5) ||
                             (led_counter[23:20] >= 4'd6 && led_counter[23:20] < 4'd7)) ? 1'b1 : 1'b0;
            end
            STATE_VERIFY: begin
                // 5 rapid blinks
                led_state <= ((led_counter[23:20] < 4'd1) ||
                             (led_counter[23:20] >= 4'd2 && led_counter[23:20] < 4'd3) ||
                             (led_counter[23:20] >= 4'd4 && led_counter[23:20] < 4'd5) ||
                             (led_counter[23:20] >= 4'd6 && led_counter[23:20] < 4'd7) ||
                             (led_counter[23:20] >= 4'd8 && led_counter[23:20] < 4'd9)) ? 1'b1 : 1'b0;
            end
            STATE_SEND_ACK: begin
                // 6 blinks
                led_state <= ((led_counter[23:20] < 4'd1) ||
                             (led_counter[23:20] >= 4'd2 && led_counter[23:20] < 4'd3) ||
                             (led_counter[23:20] >= 4'd4 && led_counter[23:20] < 4'd5) ||
                             (led_counter[23:20] >= 4'd6 && led_counter[23:20] < 4'd7) ||
                             (led_counter[23:20] >= 4'd8 && led_counter[23:20] < 4'd9) ||
                             (led_counter[23:20] >= 4'd10 && led_counter[23:20] < 4'd11)) ? 1'b1 : 1'b0;
            end
            default: begin
                led_state <= 1'b0;
            end
        endcase
    end

    assign LED1 = led_state;

    //----------------------------------------------------------------
    // Control pin output
    //----------------------------------------------------------------
    assign CONTROL_PIN = control_state;

endmodule
