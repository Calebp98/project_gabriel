// Simple UART Transmitter Module
// Sends characters at 115200 baud (12 MHz clock)

module uart_tx #(
    parameter CLOCK_FREQ = 12_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst,
    input wire [7:0] data,
    input wire data_valid,
    output reg tx,
    output reg busy
);

    localparam CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;

    // State machine states
    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam DATA = 2'b10;
    localparam STOP = 2'b11;

    reg [1:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] tx_data = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1;  // UART idle state is HIGH
            busy <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;  // Idle HIGH
                    busy <= 0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (data_valid) begin
                        tx_data <= data;
                        busy <= 1;
                        state <= START;
                    end
                end

                START: begin
                    tx <= 0;  // Start bit is LOW

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state <= DATA;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DATA: begin
                    tx <= tx_data[bit_index];

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;

                        if (bit_index == 7) begin
                            bit_index <= 0;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                STOP: begin
                    tx <= 1;  // Stop bit is HIGH

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
