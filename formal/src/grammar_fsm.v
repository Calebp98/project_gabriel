// Grammar-based Finite State Machine
// Validates incoming serial data against "CAT" pattern
//
// States:
//   IDLE    -> Waiting for 'C'
//   S_C     -> Got 'C', waiting for 'A'
//   S_CA    -> Got "CA", waiting for 'T'
//   S_CAT   -> Got "CAT" - ACCEPT state
//   S_REJECT -> Invalid character received - REJECT state
//
// Behavior: Stays in accept/reject state until new data arrives

module grammar_fsm (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg accept,
    output reg reject
);
    // State encoding for "CAT" grammar
    localparam S_IDLE = 3'd0;
    localparam S_C = 3'd1;
    localparam S_CA = 3'd2;
    localparam S_CAT = 3'd3;
    localparam S_REJECT = 3'd4;

    reg [2:0] state = S_IDLE;

    // ASCII constants for "CAT"
    localparam CHAR_C = 8'd67;  // 'C'
    localparam CHAR_A = 8'd65;  // 'A'
    localparam CHAR_T = 8'd84;  // 'T'

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            accept <= 0;
            reject <= 0;
        end else if (data_valid) begin
            // New data arrived, process it based on current state
            case (state)
                S_IDLE: begin
                    accept <= 0;
                    reject <= 0;
                    if (data_in == CHAR_C)
                        state <= S_C;
                    else begin
                        state <= S_REJECT;
                        reject <= 1;
                    end
                end

                S_C: begin
                    if (data_in == CHAR_A)
                        state <= S_CA;
                    else begin
                        state <= S_REJECT;
                        reject <= 1;
                        accept <= 0;
                    end
                end

                S_CA: begin
                    if (data_in == CHAR_T) begin
                        state <= S_CAT;
                        accept <= 1;
                        reject <= 0;
                    end else begin
                        state <= S_REJECT;
                        reject <= 1;
                        accept <= 0;
                    end
                end

                S_CAT: begin
                    // Already in accept state
                    // New data resets us back to IDLE to start fresh
                    accept <= 0;
                    reject <= 0;
                    state <= S_IDLE;
                    // Re-evaluate this new byte as if starting over
                    if (data_in == CHAR_C)
                        state <= S_C;
                    else begin
                        state <= S_REJECT;
                        reject <= 1;
                    end
                end

                S_REJECT: begin
                    // Already in reject state
                    // New data resets us back to IDLE to start fresh
                    accept <= 0;
                    reject <= 0;
                    state <= S_IDLE;
                    // Re-evaluate this new byte as if starting over
                    if (data_in == CHAR_C)
                        state <= S_C;
                    else begin
                        state <= S_REJECT;
                        reject <= 1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    accept <= 0;
                    reject <= 0;
                end
            endcase
        end
        // If no new data, maintain current accept/reject signals
    end

`ifdef FORMAL
    // Formal verification properties

    // Initial state assumptions
    initial assume(state == S_IDLE);
    initial assume(accept == 0);
    initial assume(reject == 0);

    // Property 1: Mutual exclusion - never accept and reject simultaneously
    always @(posedge clk) begin
        assert(!(accept && reject));
    end

    // Property 2: Valid states only
    always @(posedge clk) begin
        assert(state <= S_REJECT);
    end

    // Property 3: Accept only in S_CAT state
    always @(posedge clk) begin
        if (accept)
            assert(state == S_CAT || state == S_IDLE);
    end

    // Property 4: Reject only in S_REJECT state
    always @(posedge clk) begin
        if (reject)
            assert(state == S_REJECT || state == S_IDLE);
    end

    // Property 5: Correct sequence C->A->T leads to accept
    reg [1:0] seq_step = 0;
    reg seen_accept = 0;

    always @(posedge clk) begin
        if (rst) begin
            seq_step <= 0;
            seen_accept <= 0;
        end else if (data_valid) begin
            if (seq_step == 0 && data_in == CHAR_C && state == S_IDLE)
                seq_step <= 1;
            else if (seq_step == 1 && data_in == CHAR_A && state == S_C)
                seq_step <= 2;
            else if (seq_step == 2 && data_in == CHAR_T && state == S_CA)
                seq_step <= 3;

            if (seq_step == 3 && accept)
                seen_accept <= 1;
        end
    end

    always @(posedge clk) begin
        if (seq_step == 3)
            assert(accept || seen_accept);
    end

    // Property 6: Wrong character in IDLE leads to reject (check next cycle)
    reg bad_char_in_idle = 0;
    always @(posedge clk) begin
        if (rst) begin
            bad_char_in_idle <= 0;
        end else begin
            if (data_valid && state == S_IDLE && data_in != CHAR_C)
                bad_char_in_idle <= 1;
            else if (bad_char_in_idle)
                bad_char_in_idle <= 0;
        end
    end

    always @(posedge clk) begin
        if (bad_char_in_idle && !rst)
            assert(reject);
    end

    // Cover properties - verify all states are reachable
    always @(posedge clk) begin
        cover(state == S_IDLE);
        cover(state == S_C);
        cover(state == S_CA);
        cover(state == S_CAT && accept);
        cover(state == S_REJECT && reject);
    end

    // Cover property - verify we can accept after seeing CAT
    always @(posedge clk) begin
        cover(accept);
    end

    // Cover property - verify we can reject invalid input
    always @(posedge clk) begin
        cover(reject);
    end
`endif

endmodule
