// Top module: UART receiver with XOR decryption and grammar-based FSM filter
// Receives encrypted serial data, decrypts with XOR cipher, validates "CAT" pattern
//
// Data flow: UART RX → XOR Decrypt → Grammar FSM Validate
//
// LED Behavior:
//   LED_RX (pin 26, active-high): Pulses when UART data received
//   LED_GREEN (pin 37, active-low): Lights when "CAT" accepted (after decryption)
//   LED_RED (pin 11, active-low): Lights when pattern rejected

module top_test (
    input wire CLK,      // 12 MHz clock on iCEBreaker
    input wire RX_PIN,   // UART RX from Pico
    output wire LED_RED,
    output wire LED_GREEN,
    output wire LED_RX
);
    wire [7:0] uart_data;
    wire uart_valid;
    wire [7:0] decrypted_data;
    wire decrypted_valid;
    wire accept_signal;
    wire reject_signal;

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

    // XOR Cipher instance - decrypts incoming data
    xor_cipher cipher_inst (
        .clk(CLK),
        .rst(1'b0),
        .data_in(uart_data),
        .data_valid(uart_valid),
        .data_out(decrypted_data),
        .data_out_valid(decrypted_valid)
    );

    // Grammar FSM instance - validates "CAT" pattern on decrypted data
    grammar_fsm fsm_inst (
        .clk(CLK),
        .rst(1'b0),
        .data_in(decrypted_data),
        .data_valid(decrypted_valid),
        .accept(accept_signal),
        .reject(reject_signal)
    );

    // LED outputs
    assign LED_RX = uart_valid;          // Active high - pulses when data received
    assign LED_GREEN = ~accept_signal;   // Active low - ON when pattern accepted
    assign LED_RED = ~reject_signal;     // Active low - ON when pattern rejected

endmodule
