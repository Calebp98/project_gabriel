module top(
    input CLK,           // 12 MHz clock
    input PIN_38,        // Pin 38 to read
    output TX            // UART TX (pin 6)
);

    // UART parameters for 115200 baud at 12 MHz
    // Baud divisor = 12,000,000 / 115200 = 104.17 ≈ 104
    localparam BAUD_DIV = 104;
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3, DELAY = 4;

    reg [7:0] state = IDLE;
    reg [7:0] tx_byte = 0;
    reg [7:0] baud_counter = 0;
    reg [2:0] bit_index = 0;
    reg tx_out = 1;

    // Delay counter to send data periodically (not too fast)
    reg [23:0] delay_counter = 0;
    localparam DELAY_MAX = 24'd6_000_000;  // Send every 0.5 seconds

    // State machine to send pin state via UART
    always @(posedge CLK) begin
        case (state)
            IDLE: begin
                tx_out <= 1;  // UART idle is high
                if (delay_counter == DELAY_MAX) begin
                    delay_counter <= 0;
                    // Set byte to send: ASCII '0' (0x30) or '1' (0x31)
                    tx_byte <= PIN_38 ? 8'h31 : 8'h30;
                    state <= START;
                    baud_counter <= 0;
                end else begin
                    delay_counter <= delay_counter + 1;
                end
            end

            START: begin
                tx_out <= 0;  // Start bit
                if (baud_counter == BAUD_DIV - 1) begin
                    baud_counter <= 0;
                    state <= DATA;
                    bit_index <= 0;
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end

            DATA: begin
                tx_out <= tx_byte[bit_index];
                if (baud_counter == BAUD_DIV - 1) begin
                    baud_counter <= 0;
                    if (bit_index == 7) begin
                        state <= STOP;
                    end else begin
                        bit_index <= bit_index + 1;
                    end
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end

            STOP: begin
                tx_out <= 1;  // Stop bit
                if (baud_counter == BAUD_DIV - 1) begin
                    baud_counter <= 0;
                    state <= IDLE;
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end

            default: state <= IDLE;
        endcase
    end

    assign TX = tx_out;

endmodule
