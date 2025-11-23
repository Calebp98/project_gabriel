/**
 * UART Transmitter Module
 *
 * Transmits 8-bit data at 115200 baud from 12 MHz clock
 * Clock cycles per bit = 12,000,000 / 115,200 ≈ 104
 */

module uart_tx (
    input wire clk,              // 12 MHz clock
    input wire [7:0] tx_data,    // Data byte to transmit
    input wire tx_start,         // Pulse high to start transmission
    output reg tx,               // UART TX line
    output reg busy,             // High while transmitting
    output reg done              // Pulses high for 1 cycle when complete
);

    localparam CLKS_PER_BIT = 104;  // 12 MHz / 115200

    // State machine states
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state = IDLE;
    reg [7:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] data_reg;

    always @(posedge clk) begin
        done <= 0;  // Default: done is only high for 1 cycle

        case (state)
            IDLE: begin
                tx <= 1'b1;      // Idle high
                busy <= 1'b0;
                bit_index <= 0;
                clk_count <= 0;

                if (tx_start) begin
                    data_reg <= tx_data;
                    busy <= 1'b1;
                    state <= START;
                end
            end

            START: begin
                tx <= 1'b0;  // Start bit (low)
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state <= DATA;
                end
            end

            DATA: begin
                tx <= data_reg[bit_index];  // Send LSB first
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1;
                    end else begin
                        bit_index <= 0;
                        state <= STOP;
                    end
                end
            end

            STOP: begin
                tx <= 1'b1;  // Stop bit (high)
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
        endcase
    end

endmodule
