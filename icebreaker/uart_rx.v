// Simple UART Receiver Module
// Receives characters at 115200 baud (12 MHz clock)

module uart_rx #(
    parameter CLOCK_FREQ = 12_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data,
    output reg data_valid
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
    reg [7:0] rx_data = 0;

    // Synchronize RX input to avoid metastability
    reg rx_sync1 = 1;
    reg rx_sync2 = 1;

    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            data_valid <= 0;
            clk_count <= 0;
            bit_index <= 0;
            data <= 0;
        end else begin
            data_valid <= 0;  // Default: no new data

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;

                    if (rx_sync2 == 0) begin  // Start bit detected
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == (CLKS_PER_BIT / 2) - 1) begin
                        if (rx_sync2 == 0) begin  // Verify start bit
                            clk_count <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        rx_data[bit_index] <= rx_sync2;

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
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        data <= rx_data;
                        data_valid <= 1;
                        state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

`ifdef FORMAL
    // Formal verification properties

    // Track that we're past the first cycle
    reg past_valid = 0;
    always @(posedge clk) begin
        past_valid <= 1;
    end

    // Property 1: State is always valid
    always @(posedge clk) begin
        assert(state == IDLE || state == START || state == DATA || state == STOP);
    end

    // Property 2: Bit index never exceeds 7
    always @(posedge clk) begin
        assert(bit_index <= 7);
    end

    // Property 3: Clock count stays within bounds
    always @(posedge clk) begin
        assert(clk_count < CLKS_PER_BIT);
    end

    // Property 4: Data valid is only asserted for one cycle
    always @(posedge clk) begin
        if (!rst && past_valid && $past(data_valid) && !$past(rst))
            assert(!data_valid);
    end

    // Property 5: Data valid only asserted in transition from STOP to IDLE
    always @(posedge clk) begin
        if (!rst && data_valid && past_valid)
            assert($past(state) == STOP);
    end

    // Property 6: Reset behavior
    always @(posedge clk) begin
        if (past_valid && $past(rst)) begin
            assert(state == IDLE);
            assert(data_valid == 0);
            assert(clk_count == 0);
            assert(bit_index == 0);
            assert(data == 0);
        end
    end

    // Property 7: In IDLE state, counters should be reset
    always @(posedge clk) begin
        if (!rst && state == IDLE) begin
            assert(clk_count == 0);
            assert(bit_index == 0);
        end
    end

    // Property 8: Bit index increments correctly in DATA state
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst) && $past(state) == DATA && state == DATA) begin
            if ($past(clk_count) == CLKS_PER_BIT - 1) begin
                if ($past(bit_index) == 7)
                    assert(bit_index == 0);  // Will transition to STOP next
                else
                    assert(bit_index == $past(bit_index) + 1);
            end else begin
                assert(bit_index == $past(bit_index));
            end
        end
    end

    // Property 9: RX synchronization chain
    always @(posedge clk) begin
        if (past_valid && !$past(rst))
            assert(rx_sync2 == $past(rx_sync1));
    end

    // Cover properties - verify we can receive data
    always @(posedge clk) begin
        cover(state == IDLE);
        cover(state == START);
        cover(state == DATA);
        cover(state == STOP);
        cover(data_valid);
    end

    // Cover property - complete byte reception
    reg seen_byte = 0;
    always @(posedge clk) begin
        if (data_valid)
            seen_byte <= 1;
    end
    always @(posedge clk) begin
        cover(seen_byte);
    end
`endif

endmodule
