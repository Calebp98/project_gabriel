/**
 * Stage 2: FPGA UART Transmitter Test
 *
 * Continuously sends test pattern: 0xAA, 0x55, 0xAA, 0x55, ...
 * This allows testing with Pico Stage 1 receiver or logic analyzer
 */

module top (
    input wire clk,        // 12 MHz iCEBreaker clock
    output wire uart_tx,   // PMOD1A Pin 1 -> Pico GP0
    output wire led_r,     // Red LED: on while transmitting
    output wire led_g      // Green LED: blinks with each byte sent
);

    reg [7:0] tx_data;
    reg tx_start = 0;
    wire tx_busy;
    wire tx_done;
    wire tx_line;

    assign uart_tx = tx_line;
    assign led_r = tx_busy;      // Red on during transmission

    // Instantiate UART transmitter
    uart_tx uart_inst (
        .clk(clk),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(tx_line),
        .busy(tx_busy),
        .done(tx_done)
    );

    // State machine to send alternating pattern
    localparam IDLE = 0, SEND = 1, WAIT = 2;
    reg [1:0] state = IDLE;
    reg [31:0] delay_counter = 0;
    reg pattern_toggle = 0;
    reg green_led = 0;

    assign led_g = green_led;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                // Wait a bit on startup
                if (delay_counter < 12_000_000) begin  // 1 second
                    delay_counter <= delay_counter + 1;
                end else begin
                    delay_counter <= 0;
                    state <= SEND;

                    // Alternate between 0xAA and 0x55
                    tx_data <= pattern_toggle ? 8'hAA : 8'h55;
                    pattern_toggle <= ~pattern_toggle;
                    tx_start <= 1;
                end
            end

            SEND: begin
                tx_start <= 0;
                if (tx_done) begin
                    green_led <= ~green_led;  // Toggle green LED
                    state <= WAIT;
                end
            end

            WAIT: begin
                // Wait ~100ms between bytes
                if (delay_counter < 1_200_000) begin
                    delay_counter <= delay_counter + 1;
                end else begin
                    delay_counter <= 0;
                    state <= SEND;

                    // Alternate pattern
                    tx_data <= pattern_toggle ? 8'hAA : 8'h55;
                    pattern_toggle <= ~pattern_toggle;
                    tx_start <= 1;
                end
            end
        endcase
    end

endmodule
