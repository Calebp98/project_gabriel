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
endmodule
