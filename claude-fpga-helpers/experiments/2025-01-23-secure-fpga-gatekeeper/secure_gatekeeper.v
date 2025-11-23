// Secure FPGA-Gated Programming System
// Implements challenge-response authentication and SWD clock jamming control

module top(
    input CLK,              // 12 MHz system clock
    input UART_RX,          // Pin 3: Receive from laptop via Pico Probe
    output UART_TX,         // Pin 2: Transmit to laptop via Pico Probe
    output JAM_CTRL,        // Pin 4: SWD clock jamming control (HIGH=jam, LOW=allow)
    input JAM_STATUS,       // Pin 38: Loopback of JAM_CTRL for verification
    input BLINK_IN          // Pin 43: Blink pattern from target Pico
);

// ============================================================================
// Parameters and Constants
// ============================================================================

// UART Configuration (115200 baud @ 12 MHz)
localparam CLKS_PER_BIT = 104;  // 12,000,000 / 115200 ≈ 104

// Authentication
localparam [31:0] SECRET_KEY = 32'hDEADBEEF;

// Commands
localparam CMD_PROG_REQUEST = 8'h01;
localparam CMD_CHALLENGE    = 8'h02;
localparam CMD_RESPONSE     = 8'h03;
localparam CMD_AUTH_OK      = 8'h04;
localparam CMD_AUTH_FAIL    = 8'h05;
localparam CMD_STATUS       = 8'h06;

// State Machine
localparam STATE_IDLE          = 4'd0;
localparam STATE_CHALLENGE     = 4'd1;
localparam STATE_WAIT_RESPONSE = 4'd2;
localparam STATE_VERIFY        = 4'd3;
localparam STATE_DISABLE_JAM   = 4'd4;
localparam STATE_WAIT_BLINK    = 4'd5;
localparam STATE_ENABLE_JAM    = 4'd6;
localparam STATE_SEND_AUTH_OK  = 4'd7;
localparam STATE_SEND_AUTH_FAIL= 4'd8;

// Timeouts
localparam TIMEOUT_5S  = 27'd60_000_000;  // 5 seconds @ 12 MHz
localparam TIMEOUT_10S = 27'd120_000_000; // 10 seconds @ 12 MHz

// Blink detection
localparam BLINK_PERIOD_MIN = 23'd3_600_000; // 300ms @ 12 MHz (tolerance)
localparam BLINK_PERIOD_MAX = 23'd6_000_000; // 500ms @ 12 MHz (tolerance)
localparam BLINK_CHECK_TIME = 27'd24_000_000; // 2 seconds @ 12 MHz

// ============================================================================
// UART Receiver Module
// ============================================================================

reg [7:0] uart_rx_data;
reg uart_rx_valid;
reg uart_rx_active;
reg [7:0] uart_rx_clk_count;
reg [2:0] uart_rx_bit_index;
reg [7:0] uart_rx_shift;

// UART RX synchronizer (prevent metastability)
reg uart_rx_sync1, uart_rx_sync2;
always @(posedge CLK) begin
    uart_rx_sync1 <= UART_RX;
    uart_rx_sync2 <= uart_rx_sync1;
end

// UART RX state machine
always @(posedge CLK) begin
    uart_rx_valid <= 0;

    if (!uart_rx_active) begin
        // Wait for start bit (falling edge)
        if (!uart_rx_sync2) begin
            uart_rx_active <= 1;
            uart_rx_clk_count <= 0;
            uart_rx_bit_index <= 0;
        end
    end else begin
        if (uart_rx_clk_count < CLKS_PER_BIT - 1) begin
            uart_rx_clk_count <= uart_rx_clk_count + 1;
        end else begin
            uart_rx_clk_count <= 0;

            if (uart_rx_bit_index < 8) begin
                // Sample data bits
                uart_rx_shift <= {uart_rx_sync2, uart_rx_shift[7:1]};
                uart_rx_bit_index <= uart_rx_bit_index + 1;
            end else begin
                // Stop bit - complete reception
                uart_rx_data <= uart_rx_shift;
                uart_rx_valid <= 1;
                uart_rx_active <= 0;
            end
        end
    end
end

// ============================================================================
// UART Transmitter Module
// ============================================================================

reg [7:0] uart_tx_data;
reg uart_tx_start;
reg uart_tx_busy;
reg uart_tx_bit;
reg [7:0] uart_tx_clk_count;
reg [3:0] uart_tx_bit_index;

assign UART_TX = uart_tx_bit;

always @(posedge CLK) begin
    if (!uart_tx_busy) begin
        uart_tx_bit <= 1; // Idle high
        if (uart_tx_start) begin
            uart_tx_busy <= 1;
            uart_tx_clk_count <= 0;
            uart_tx_bit_index <= 0;
        end
    end else begin
        if (uart_tx_clk_count < CLKS_PER_BIT - 1) begin
            uart_tx_clk_count <= uart_tx_clk_count + 1;
        end else begin
            uart_tx_clk_count <= 0;

            if (uart_tx_bit_index == 0) begin
                // Start bit
                uart_tx_bit <= 0;
                uart_tx_bit_index <= uart_tx_bit_index + 1;
            end else if (uart_tx_bit_index < 9) begin
                // Data bits
                uart_tx_bit <= uart_tx_data[uart_tx_bit_index - 1];
                uart_tx_bit_index <= uart_tx_bit_index + 1;
            end else if (uart_tx_bit_index == 9) begin
                // Stop bit
                uart_tx_bit <= 1;
                uart_tx_bit_index <= uart_tx_bit_index + 1;
            end else begin
                // Complete
                uart_tx_busy <= 0;
            end
        end
    end
end

// ============================================================================
// LFSR for Challenge Generation
// ============================================================================

reg [31:0] lfsr;
wire lfsr_feedback;

assign lfsr_feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

always @(posedge CLK) begin
    lfsr <= {lfsr[30:0], lfsr_feedback};
end

// Initialize LFSR with non-zero seed
initial begin
    lfsr = 32'hACE1BABE;
end

// ============================================================================
// Blink Pattern Detector
// ============================================================================

reg blink_sync1, blink_sync2;
reg blink_prev;
reg [3:0] blink_edge_count;
reg [22:0] blink_period_counter;
reg [26:0] blink_check_counter;
reg blink_detected;
reg blink_detect_active;

always @(posedge CLK) begin
    // Synchronize blink input
    blink_sync1 <= BLINK_IN;
    blink_sync2 <= blink_sync1;
    blink_prev <= blink_sync2;

    if (blink_detect_active) begin
        // Detect rising edge
        if (blink_sync2 && !blink_prev) begin
            // Rising edge detected
            if (blink_period_counter >= BLINK_PERIOD_MIN &&
                blink_period_counter <= BLINK_PERIOD_MAX) begin
                // Valid period - count edge
                blink_edge_count <= blink_edge_count + 1;
            end
            blink_period_counter <= 0;
        end else begin
            blink_period_counter <= blink_period_counter + 1;
        end

        // Check time window
        if (blink_check_counter < BLINK_CHECK_TIME) begin
            blink_check_counter <= blink_check_counter + 1;
        end else begin
            // Time window complete - check if we got enough edges
            blink_detected <= (blink_edge_count >= 4); // At least 4 valid blinks
        end
    end else begin
        blink_period_counter <= 0;
        blink_check_counter <= 0;
        blink_edge_count <= 0;
        blink_detected <= 0;
    end
end

// ============================================================================
// Main State Machine
// ============================================================================

reg [3:0] state;
reg [31:0] challenge;
reg [31:0] expected_response;
reg [31:0] received_response;
reg [26:0] timeout_counter;
reg [2:0] rx_byte_index;  // Track which byte of packet we're receiving
reg [7:0] rx_command;
reg jam_ctrl_reg;

assign JAM_CTRL = jam_ctrl_reg;

// Packet reception tracking
reg packet_in_progress;
reg [31:0] rx_data_buffer;

always @(posedge CLK) begin
    // Default: don't start new transmissions
    uart_tx_start <= 0;

    case (state)
        STATE_IDLE: begin
            // Jamming enabled in IDLE
            jam_ctrl_reg <= 1;
            timeout_counter <= 0;
            packet_in_progress <= 0;
            rx_byte_index <= 0;

            // Wait for PROG_REQUEST command
            if (uart_rx_valid) begin
                if (!packet_in_progress) begin
                    // First byte - should be command
                    rx_command <= uart_rx_data;
                    packet_in_progress <= 1;
                    rx_byte_index <= 0;

                    if (uart_rx_data == CMD_PROG_REQUEST) begin
                        // Start challenge sequence
                        challenge <= lfsr;
                        expected_response <= lfsr ^ SECRET_KEY;
                        state <= STATE_CHALLENGE;
                    end
                end
            end
        end

        STATE_CHALLENGE: begin
            // Send challenge packet: CMD_CHALLENGE + 32-bit challenge
            if (!uart_tx_busy && !uart_tx_start) begin
                if (rx_byte_index == 0) begin
                    uart_tx_data <= CMD_CHALLENGE;
                    uart_tx_start <= 1;
                    rx_byte_index <= 1;
                end else if (rx_byte_index == 1) begin
                    uart_tx_data <= challenge[31:24];
                    uart_tx_start <= 1;
                    rx_byte_index <= 2;
                end else if (rx_byte_index == 2) begin
                    uart_tx_data <= challenge[23:16];
                    uart_tx_start <= 1;
                    rx_byte_index <= 3;
                end else if (rx_byte_index == 3) begin
                    uart_tx_data <= challenge[15:8];
                    uart_tx_start <= 1;
                    rx_byte_index <= 4;
                end else if (rx_byte_index == 4) begin
                    uart_tx_data <= challenge[7:0];
                    uart_tx_start <= 1;
                    rx_byte_index <= 0;
                    packet_in_progress <= 0;
                    state <= STATE_WAIT_RESPONSE;
                    timeout_counter <= 0;
                end
            end
        end

        STATE_WAIT_RESPONSE: begin
            // Wait for response packet with timeout
            if (timeout_counter < TIMEOUT_5S) begin
                timeout_counter <= timeout_counter + 1;

                if (uart_rx_valid) begin
                    if (!packet_in_progress) begin
                        // First byte - command
                        rx_command <= uart_rx_data;
                        packet_in_progress <= 1;
                        rx_byte_index <= 0;
                    end else begin
                        // Data bytes
                        case (rx_byte_index)
                            0: begin
                                rx_data_buffer[31:24] <= uart_rx_data;
                                rx_byte_index <= 1;
                            end
                            1: begin
                                rx_data_buffer[23:16] <= uart_rx_data;
                                rx_byte_index <= 2;
                            end
                            2: begin
                                rx_data_buffer[15:8] <= uart_rx_data;
                                rx_byte_index <= 3;
                            end
                            3: begin
                                rx_data_buffer[7:0] <= uart_rx_data;
                                received_response <= {rx_data_buffer[31:8], uart_rx_data};
                                packet_in_progress <= 0;
                                rx_byte_index <= 0;

                                if (rx_command == CMD_RESPONSE) begin
                                    state <= STATE_VERIFY;
                                end else begin
                                    state <= STATE_SEND_AUTH_FAIL;
                                end
                            end
                        endcase
                    end
                end
            end else begin
                // Timeout - return to IDLE
                state <= STATE_IDLE;
            end
        end

        STATE_VERIFY: begin
            // Check if response matches expected value
            if (received_response == expected_response) begin
                state <= STATE_SEND_AUTH_OK;
            end else begin
                state <= STATE_SEND_AUTH_FAIL;
            end
        end

        STATE_SEND_AUTH_OK: begin
            // Send AUTH_OK packet
            if (!uart_tx_busy && !uart_tx_start) begin
                if (rx_byte_index == 0) begin
                    uart_tx_data <= CMD_AUTH_OK;
                    uart_tx_start <= 1;
                    rx_byte_index <= 1;
                end else begin
                    rx_byte_index <= 0;
                    state <= STATE_DISABLE_JAM;
                end
            end
        end

        STATE_SEND_AUTH_FAIL: begin
            // Send AUTH_FAIL packet and return to IDLE
            if (!uart_tx_busy && !uart_tx_start) begin
                if (rx_byte_index == 0) begin
                    uart_tx_data <= CMD_AUTH_FAIL;
                    uart_tx_start <= 1;
                    rx_byte_index <= 1;
                end else begin
                    rx_byte_index <= 0;
                    state <= STATE_IDLE;
                end
            end
        end

        STATE_DISABLE_JAM: begin
            // Disable jamming to allow programming
            jam_ctrl_reg <= 0;
            blink_detect_active <= 1;
            timeout_counter <= 0;
            state <= STATE_WAIT_BLINK;
        end

        STATE_WAIT_BLINK: begin
            // Wait for blink pattern detection or timeout
            if (timeout_counter < TIMEOUT_10S) begin
                timeout_counter <= timeout_counter + 1;

                if (blink_detected) begin
                    state <= STATE_ENABLE_JAM;
                end
            end else begin
                // Timeout - re-enable jamming and return to IDLE
                blink_detect_active <= 0;
                state <= STATE_ENABLE_JAM;
            end
        end

        STATE_ENABLE_JAM: begin
            // Re-enable jamming
            jam_ctrl_reg <= 1;
            blink_detect_active <= 0;
            state <= STATE_IDLE;
        end

        default: begin
            state <= STATE_IDLE;
        end
    endcase
end

// Initialize state machine
initial begin
    state = STATE_IDLE;
    jam_ctrl_reg = 1;  // Start with jamming enabled
    uart_tx_start = 0;
    packet_in_progress = 0;
    rx_byte_index = 0;
    blink_detect_active = 0;
end

endmodule
