// Simple test top module for UART receiver
// LED_RX (red) blinks when data is received
// Green LED shows LSB of received data
// Red LED shows MSB of received data

module top_test (
    input wire CLK,      // 12 MHz clock on iCEBreaker
    input wire RX_PIN,   // UART RX from Pico
    output wire LED_RED,
    output wire LED_GREEN,
    output wire LED_RX
);
    wire [7:0] uart_data;
    wire uart_valid;
    reg [7:0] last_byte = 8'h00;

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

    // Store last received byte
    always @(posedge CLK) begin
        if (uart_valid) begin
            last_byte <= uart_data;
        end
    end

    // LED outputs for testing
    assign LED_RX = uart_valid;        // Active high - pulses when data received
    assign LED_GREEN = ~last_byte[0];  // Active low - LSB of last byte (inverted)
    assign LED_RED = ~last_byte[7];    // Active low - MSB of last byte (inverted)

endmodule
