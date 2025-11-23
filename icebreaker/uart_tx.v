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

    // Property 4: TX line is HIGH when idle
    always @(posedge clk) begin
        if (!rst && past_valid && state == IDLE)
            assert(tx == 1);
    end

    // Property 5: TX line is LOW during start bit (after first cycle in state)
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst) && state == START && $past(state) == START)
            assert(tx == 0);
    end

    // Property 6: TX line is HIGH during stop bit (after first cycle in state)
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst) && state == STOP && $past(state) == STOP)
            assert(tx == 1);
    end

    // Property 7: Busy signal behavior
    always @(posedge clk) begin
        if (!rst && past_valid && state == IDLE)
            assert(busy == 0);
        if (!rst && past_valid && (state == START || state == DATA || state == STOP))
            assert(busy == 1);
    end

    // Property 8: Reset behavior
    always @(posedge clk) begin
        if (past_valid && $past(rst)) begin
            assert(state == IDLE);
            assert(tx == 1);
            assert(busy == 0);
            assert(clk_count == 0);
            assert(bit_index == 0);
        end
    end

    // Property 9: In IDLE state, counters should be reset
    always @(posedge clk) begin
        if (!rst && state == IDLE) begin
            assert(clk_count == 0);
            assert(bit_index == 0);
        end
    end

    // Property 10: Bit index increments correctly in DATA state
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

    // Property 11: TX data matches captured data in DATA state
    always @(posedge clk) begin
        if (!rst && state == DATA)
            assert(tx == tx_data[bit_index]);
    end

    // Cover properties - verify we can transmit data
    always @(posedge clk) begin
        cover(state == IDLE);
        cover(state == START);
        cover(state == DATA);
        cover(state == STOP);
        cover(busy);
    end

    // Cover property - complete byte transmission
    reg seen_transmission = 0;
    always @(posedge clk) begin
        if (state == STOP)
            seen_transmission <= 1;
    end
    always @(posedge clk) begin
        cover(seen_transmission);
    end
`endif

endmodule
