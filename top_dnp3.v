// Top module: UART receiver with DNP3 Link Layer Parser
// Receives and validates DNP3 link layer frames
//
// LED Behavior:
//   LED_RX (pin 26, active-high): Pulses when UART data received
//   LED_GREEN (pin 37, active-low): Lights when valid DNP3 frame with matching address
//   LED_RED (pin 11, active-low): Lights when frame error detected
//
// Device Address: 0x0001 (can be changed via parameter)

module top_dnp3 (
    input wire CLK,      // 12 MHz clock on iCEBreaker
    input wire RX_PIN,   // UART RX from Pico
    output wire LED_RED,
    output wire LED_GREEN,
    output wire LED_RX
);
    // UART signals
    wire [7:0] uart_data;
    wire uart_valid;

    // DNP3 link layer signals
    wire frame_valid;
    wire frame_error;
    wire [7:0] control;
    wire [15:0] src_addr;
    wire [15:0] dest_addr;
    wire addr_match;

    // Status registers for LED persistence
    reg valid_frame_received = 0;
    reg error_detected = 0;

    // UART Receiver instance
    uart_rx #(
        .CLKS_PER_BIT(104) // 12MHz / 115200
    ) uart_inst (
        .clk(CLK),
        .rst(1'b0),
        .rx(RX_PIN),
        .data_out(uart_data),
        .data_valid(uart_valid)
    );

    // DNP3 Link Layer Parser instance
    dnp3_link_layer #(
        .MY_ADDRESS(16'h0001)  // Our device address
    ) dnp3_inst (
        .clk(CLK),
        .rst(1'b0),
        .data_in(uart_data),
        .data_valid(uart_valid),
        .frame_valid(frame_valid),
        .frame_error(frame_error),
        .control(control),
        .src_addr(src_addr),
        .dest_addr(dest_addr),
        .addr_match(addr_match)
    );

    // Latch valid frame and error status for LED display
    always @(posedge CLK) begin
        if (frame_valid && addr_match) begin
            valid_frame_received <= 1;
            error_detected <= 0;
        end else if (frame_error) begin
            valid_frame_received <= 0;
            error_detected <= 1;
        end
    end

    // LED outputs
    assign LED_RX = uart_valid;              // Active high - pulses when data received
    assign LED_GREEN = ~valid_frame_received; // Active low - ON when valid frame with matching address
    assign LED_RED = ~error_detected;        // Active low - ON when frame error detected

endmodule
