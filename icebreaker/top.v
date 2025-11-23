// Challenge-response authentication system
// Sends "CHAL:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n" every 5 seconds (128-bit challenge)
// Expects "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" where YYYY... = (XXXX... XOR secret) + secret
// If authenticated, accepts 'Y' (pin LOW/0V) or 'N' (pin HIGH/3.3V) commands
// LED blinks fast if authenticated, slow if not

module top (
    input  wire CLK,         // 12 MHz clock on iCEbreaker
    input  wire RX,          // UART RX from picoprobe
    output wire TX,          // UART TX to picoprobe
    output wire CONTROL_PIN, // Control output pin (0V for 'Y', 3.3V for 'N')
    output wire LED1         // Status LED
);

    // Secret key for authentication (128-bit)
    localparam [127:0] SECRET_KEY = 128'hDEAD_BEEF_CAFE_BABE_1337_C0DE_FACE_FEED;

    // Challenge period: 5 seconds at 12 MHz = 60,000,000 cycles
    localparam [25:0] CHALLENGE_PERIOD = 26'd60_000_000;

    // State machine
    localparam STATE_IDLE = 2'd0;
    localparam STATE_SEND_CHALLENGE = 2'd1;
    localparam STATE_WAIT_RESPONSE = 2'd2;
    localparam STATE_VERIFY = 2'd3;

    // UART signals
    wire [7:0] rx_data;
    wire rx_data_valid;
    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_busy;

    // State and timers
    reg [1:0] state = STATE_IDLE;
    reg [25:0] timer = 0;
    reg [5:0] send_index = 0;  // 0-37 for 38-byte message
    reg [5:0] recv_index = 0;  // 0-37 for 38-byte response

    // Challenge/response (128-bit)
    wire [127:0] challenge;
    reg [127:0] challenge_snapshot = 0;  // Snapshot of challenge when sent
    wire [127:0] expected_response = (challenge_snapshot ^ SECRET_KEY) + SECRET_KEY;
    reg [7:0] response_buffer [0:37];  // "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" (38 bytes)

    // Authentication status
    reg authenticated = 0;
    reg [25:0] auth_timer = 0;

    // Control pin state
    reg control_state = 1;  // Default HIGH (3.3V)

    // UART TX busy edge detection
    reg tx_busy_prev = 0;

    // UART receiver
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

    // UART transmitter
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

    // LFSR for challenge generation (always running for better randomness)
    lfsr challenge_gen (
        .clk(CLK),
        .rst(1'b0),
        .enable(1'b1),  // Always enabled for continuous randomness
        .random(challenge)
    );

    // Helper function: 4-bit value to ASCII hex
    function [7:0] nibble_to_hex;
        input [3:0] nibble;
        begin
            nibble_to_hex = (nibble < 10) ? (8'h30 + nibble) : (8'h41 + nibble - 10);
        end
    endfunction

    // Helper function: ASCII hex to 4-bit value
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

    // Main state machine
    always @(posedge CLK) begin
        tx_data_valid <= 0;
        tx_busy_prev <= tx_busy;

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
                    // Ignore other characters during authentication
                end
            endcase
        end

        case (state)
            STATE_IDLE: begin
                // Wait for 5 seconds
                if (timer >= CHALLENGE_PERIOD) begin
                    timer <= 0;
                    challenge_snapshot <= challenge;  // Capture current LFSR value
                    send_index <= 0;
                    state <= STATE_SEND_CHALLENGE;
                end
            end

            STATE_SEND_CHALLENGE: begin
                // Send "CHAL:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n" character by character (38 bytes)
                // Wait for falling edge before incrementing
                if (tx_busy_prev && !tx_busy) begin
                    send_index <= send_index + 1;
                end

                if (!tx_busy && !tx_busy_prev) begin
                    if (send_index < 38) begin
                        if (send_index == 0)
                            tx_data <= 8'h43;  // 'C'
                        else if (send_index == 1)
                            tx_data <= 8'h48;  // 'H'
                        else if (send_index == 2)
                            tx_data <= 8'h41;  // 'A'
                        else if (send_index == 3)
                            tx_data <= 8'h4C;  // 'L'
                        else if (send_index == 4)
                            tx_data <= 8'h3A;  // ':'
                        else if (send_index >= 5 && send_index <= 36) begin
                            // Send 32 hex characters (indices 5-36)
                            // nibble_index goes from 31 (most significant) to 0 (least significant)
                            tx_data <= nibble_to_hex(challenge_snapshot[(36 - send_index) * 4 +: 4]);
                        end else if (send_index == 37)
                            tx_data <= 8'h0A;  // '\n'
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
                // Collect response characters for verification (38 bytes)
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
                // Parse "RESP:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY\n" and verify (128-bit)
                if (response_buffer[0] == 8'h52 &&  // 'R'
                    response_buffer[1] == 8'h45 &&  // 'E'
                    response_buffer[2] == 8'h53 &&  // 'S'
                    response_buffer[3] == 8'h50 &&  // 'P'
                    response_buffer[4] == 8'h3A) begin  // ':'

                    // Extract 128-bit hex response from 32 hex characters (indices 5-36)
                    if ({hex_to_nibble(response_buffer[5]),  hex_to_nibble(response_buffer[6]),
                         hex_to_nibble(response_buffer[7]),  hex_to_nibble(response_buffer[8]),
                         hex_to_nibble(response_buffer[9]),  hex_to_nibble(response_buffer[10]),
                         hex_to_nibble(response_buffer[11]), hex_to_nibble(response_buffer[12]),
                         hex_to_nibble(response_buffer[13]), hex_to_nibble(response_buffer[14]),
                         hex_to_nibble(response_buffer[15]), hex_to_nibble(response_buffer[16]),
                         hex_to_nibble(response_buffer[17]), hex_to_nibble(response_buffer[18]),
                         hex_to_nibble(response_buffer[19]), hex_to_nibble(response_buffer[20]),
                         hex_to_nibble(response_buffer[21]), hex_to_nibble(response_buffer[22]),
                         hex_to_nibble(response_buffer[23]), hex_to_nibble(response_buffer[24]),
                         hex_to_nibble(response_buffer[25]), hex_to_nibble(response_buffer[26]),
                         hex_to_nibble(response_buffer[27]), hex_to_nibble(response_buffer[28]),
                         hex_to_nibble(response_buffer[29]), hex_to_nibble(response_buffer[30]),
                         hex_to_nibble(response_buffer[31]), hex_to_nibble(response_buffer[32]),
                         hex_to_nibble(response_buffer[33]), hex_to_nibble(response_buffer[34]),
                         hex_to_nibble(response_buffer[35]), hex_to_nibble(response_buffer[36])
                        } == expected_response) begin
                        // Authentication successful!
                        authenticated <= 1;
                        auth_timer <= 0;
                    end else begin
                        // Wrong response
                        authenticated <= 0;
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

    // LED blinking: fast if authenticated, slow if not
    // Fast blink: ~6 Hz (bit 20), Slow blink: ~1.4 Hz (bit 23)
    assign LED1 = authenticated ? auth_timer[20] : timer[23];

    // Control pin output
    assign CONTROL_PIN = control_state;

`ifdef FORMAL
    // Formal verification properties

    // Track that we're past the first cycle
    reg past_valid = 0;
    always @(posedge CLK) begin
        past_valid <= 1;
    end

    // Property 1: State is always valid
    always @(posedge CLK) begin
        assert(state == STATE_IDLE || state == STATE_SEND_CHALLENGE ||
               state == STATE_WAIT_RESPONSE || state == STATE_VERIFY);
    end

    // Property 2: Send index stays within bounds during SEND_CHALLENGE
    always @(posedge CLK) begin
        if (state == STATE_SEND_CHALLENGE)
            assert(send_index <= 38);
    end

    // Property 3: Receive index stays within bounds during WAIT_RESPONSE
    always @(posedge CLK) begin
        if (state == STATE_WAIT_RESPONSE)
            assert(recv_index <= 38);
    end

    // Property 4: Control pin matches control_state
    always @(posedge CLK) begin
        assert(CONTROL_PIN == control_state);
    end

    // Property 5: Expected response calculation is correct
    always @(posedge CLK) begin
        assert(expected_response == ((challenge_snapshot ^ SECRET_KEY) + SECRET_KEY));
    end

    // Property 6: LED blink rate depends on authentication status
    always @(posedge CLK) begin
        if (authenticated)
            assert(LED1 == auth_timer[20]);
        else
            assert(LED1 == timer[23]);
    end

    // Property 7: In IDLE state, send_index should be 0 after initialization
    always @(posedge CLK) begin
        if (past_valid && state == STATE_IDLE && $past(state) == STATE_IDLE)
            assert(send_index == 0);
    end

    // Property 8: In VERIFY state, should transition back to IDLE
    always @(posedge CLK) begin
        if (past_valid && $past(state) == STATE_VERIFY)
            assert(state == STATE_IDLE);
    end

    // Property 9: Timer increments continuously
    always @(posedge CLK) begin
        if (past_valid)
            assert(timer == $past(timer) + 1);
    end

    // Property 10: Auth timer increments only when authenticated
    always @(posedge CLK) begin
        if (past_valid && authenticated)
            assert(auth_timer == $past(auth_timer) + 1);
    end

    // Cover properties - verify we can reach all states
    always @(posedge CLK) begin
        cover(state == STATE_IDLE);
        cover(state == STATE_SEND_CHALLENGE);
        cover(state == STATE_WAIT_RESPONSE);
        cover(state == STATE_VERIFY);
        cover(authenticated);
        cover(control_state == 0);
        cover(control_state == 1);
    end

    // Cover property - verify we can complete authentication
    reg seen_auth = 0;
    always @(posedge CLK) begin
        if (authenticated)
            seen_auth <= 1;
    end
    always @(posedge CLK) begin
        cover(seen_auth);
    end
`endif

endmodule
