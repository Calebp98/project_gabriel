//======================================================================
// Challenge-response authentication system using AES-128
// Sends "CHAL:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n" every 5 seconds (128-bit challenge)
// Expects "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" where YYYY = AES-128(XXXX, secret_key)
// If authenticated, accepts 'Y' (pin LOW/0V) or 'N' (pin HIGH/3.3V) commands
// LED blinks fast if authenticated, slow if not
//======================================================================

module top (
    input  wire CLK,         // 12 MHz clock on iCEbreaker
    input  wire RX,          // UART RX from picoprobe
    output wire TX,          // UART TX to picoprobe
    output wire CONTROL_PIN, // Control output pin (0V for 'Y', 3.3V for 'N')
    output wire LED1         // Status LED
);

    // Secret key for AES-128 authentication
    localparam [127:0] SECRET_KEY = 128'hA5C3_DEAD_BEEF_CAFE_1337_FACE_B00B_C0DE;

    // Challenge period: 5 seconds at 12 MHz = 60,000,000 cycles
    localparam [25:0] CHALLENGE_PERIOD = 26'd60_000_000;

    // State machine
    localparam STATE_IDLE = 3'd0;
    localparam STATE_AES_START = 3'd1;
    localparam STATE_AES_WAIT = 3'd2;
    localparam STATE_SEND_CHALLENGE = 3'd3;
    localparam STATE_WAIT_RESPONSE = 3'd4;
    localparam STATE_VERIFY = 3'd5;

    // UART signals
    wire [7:0] rx_data;
    wire rx_data_valid;
    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_busy;

    // State and timers
    reg [2:0] state = STATE_IDLE;
    reg [25:0] timer = 0;
    reg [5:0] send_index = 0;  // Need up to 38 for 128-bit challenge
    reg [5:0] recv_index = 0;

    // Challenge/response (128-bit for AES)
    wire [127:0] challenge;
    reg [127:0] challenge_snapshot = 0;
    reg [7:0] response_buffer [0:37];  // "RESP:" + 32 hex chars + "\n" = 38 bytes

    // AES encryption for response verification
    reg aes_start;
    wire aes_ready;
    wire [127:0] aes_ciphertext;
    wire aes_valid;

    // Authentication status
    reg authenticated = 0;
    reg [25:0] auth_timer = 0;

    // Control pin state
    reg control_state = 1;  // Default HIGH (3.3V)

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
    // LFSR for challenge generation (8x 16-bit LFSRs = 128 bits)
    //----------------------------------------------------------------
    wire [15:0] lfsr_out[0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_lfsr
            lfsr #(.SEED(16'hACE1 + i)) lfsr_inst (
                .clk(CLK),
                .rst(1'b0),
                .enable(1'b1),
                .random(lfsr_out[i])
            );
        end
    endgenerate

    assign challenge = {lfsr_out[7], lfsr_out[6], lfsr_out[5], lfsr_out[4],
                        lfsr_out[3], lfsr_out[2], lfsr_out[1], lfsr_out[0]};

    //----------------------------------------------------------------
    // AES wrapper for challenge-response verification
    //----------------------------------------------------------------
    aes_wrapper aes_inst (
        .clk(CLK),
        .rst_n(1'b1),
        .start(aes_start),
        .ready(aes_ready),
        .plaintext(challenge_snapshot),
        .key(SECRET_KEY),
        .ciphertext(aes_ciphertext),
        .valid(aes_valid)
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
        aes_start <= 0;

        // Update timers
        timer <= timer + 1;
        if (authenticated)
            auth_timer <= auth_timer + 1;

        // Handle Y/N commands when authenticated (but not during response collection)
        if (authenticated && rx_data_valid &&
            !(state == STATE_WAIT_RESPONSE && recv_index < 38)) begin
            case (rx_data)
                8'h59,  // 'Y'
                8'h79:  // 'y'
                begin
                    control_state <= 0;  // Set to LOW (0V)
                end

                8'h4E,  // 'N'
                8'h6E:  // 'n'
                begin
                    control_state <= 1;  // Set to HIGH (3.3V)
                end

                default: begin
                    // Ignore other characters
                end
            endcase
        end

        case (state)
            STATE_IDLE: begin
                // Wait for 5 seconds
                if (timer >= CHALLENGE_PERIOD) begin
                    timer <= 0;
                    challenge_snapshot <= challenge;  // Capture current challenge
                    send_index <= 0;
                    state <= STATE_AES_START;
                end
            end

            STATE_AES_START: begin
                // Start AES encryption of challenge
                aes_start <= 1;
                state <= STATE_AES_WAIT;
            end

            STATE_AES_WAIT: begin
                // Wait for AES encryption to complete
                if (aes_valid) begin
                    // AES done, now send challenge
                    state <= STATE_SEND_CHALLENGE;
                end
            end

            STATE_SEND_CHALLENGE: begin
                // Send "CHAL:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n" (38 characters)
                // Wait for falling edge before incrementing
                if (tx_busy_prev && !tx_busy) begin
                    send_index <= send_index + 1;
                end

                if (!tx_busy && !tx_busy_prev) begin
                    if (send_index < 38) begin
                        if (send_index < 5) begin
                            // Send "CHAL:"
                            case (send_index)
                                0: tx_data <= 8'h43;  // 'C'
                                1: tx_data <= 8'h48;  // 'H'
                                2: tx_data <= 8'h41;  // 'A'
                                3: tx_data <= 8'h4C;  // 'L'
                                4: tx_data <= 8'h3A;  // ':'
                            endcase
                        end else if (send_index < 37) begin
                            // Send 32 hex characters (128 bits / 4 bits per hex = 32 chars)
                            // Index 5-36 are hex chars, map to nibbles 31 down to 0
                            tx_data <= nibble_to_hex(challenge_snapshot[(36-send_index)*4 +: 4]);
                        end else begin
                            // Send newline
                            tx_data <= 8'h0A;  // '\n'
                        end
                        tx_data_valid <= 1;
                    end else begin
                        // Done sending, wait for response
                        recv_index <= 0;
                        timer <= 0;  // Reset timeout
                        state <= STATE_WAIT_RESPONSE;
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
                if (timer >= CHALLENGE_PERIOD) begin
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
                    reg [127:0] received_response;
                    integer j;
                    reg match;

                    match = 1;
                    for (j = 0; j < 32; j = j + 1) begin
                        received_response[(31-j)*4 +: 4] = hex_to_nibble(response_buffer[5+j]);
                    end

                    // Compare with expected AES response
                    if (received_response == aes_ciphertext) begin
                        authenticated <= 1;  // Success!
                        auth_timer <= 0;
                    end else begin
                        authenticated <= 0;  // Wrong response
                    end
                end else begin
                    // Invalid format
                    authenticated <= 0;
                end

                state <= STATE_IDLE;
            end

            default: state <= STATE_IDLE;
        endcase
    end

    //----------------------------------------------------------------
    // LED blinking: fast if authenticated, slow if not
    //----------------------------------------------------------------
    assign LED1 = authenticated ? auth_timer[20] : timer[23];

    //----------------------------------------------------------------
    // Control pin output
    //----------------------------------------------------------------
    assign CONTROL_PIN = control_state;

endmodule
