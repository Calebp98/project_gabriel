// 16-bit Linear Feedback Shift Register (LFSR)
// Generates pseudo-random numbers for challenge generation
// Uses polynomial x^16 + x^14 + x^13 + x^11 + 1 (maximal length)

module lfsr (
    input wire clk,
    input wire rst,
    input wire enable,
    output reg [15:0] random
);

    // Seed value (non-zero required for LFSR)
    localparam SEED = 16'hACE1;  // "ACE1" for iCEbreaker :)

    // Initialize to seed value
    initial random = SEED;

    wire feedback;

    // Feedback polynomial: taps at bits 15, 13, 12, 10
    assign feedback = random[15] ^ random[13] ^ random[12] ^ random[10];

    always @(posedge clk) begin
        if (rst) begin
            random <= SEED;
        end else if (enable) begin
            random <= {random[14:0], feedback};
        end
    end

endmodule
