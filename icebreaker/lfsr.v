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

`ifdef FORMAL
    // Formal verification properties

    // Track that we're past the first cycle
    reg past_valid = 0;
    always @(posedge clk) begin
        past_valid <= 1;
    end

    // Property 1: LFSR never becomes zero (maximal length property)
    always @(posedge clk) begin
        assert(random != 16'h0000);
    end

    // Property 2: Feedback is correctly computed
    always @(posedge clk) begin
        assert(feedback == (random[15] ^ random[13] ^ random[12] ^ random[10]));
    end

    // Property 3: Reset behavior - LFSR resets to SEED
    always @(posedge clk) begin
        if (past_valid && $past(rst))
            assert(random == SEED);
    end

    // Property 4: When enabled, LFSR shifts correctly
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst) && $past(enable))
            assert(random == {$past(random[14:0]), $past(feedback)});
    end

    // Property 5: When not enabled, LFSR holds its value
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst) && !$past(enable))
            assert(random == $past(random));
    end

    // Property 6: SEED is non-zero (required for LFSR operation)
    always @(posedge clk) begin
        assert(SEED != 16'h0000);
    end

    // Cover properties - verify LFSR can generate different values
    always @(posedge clk) begin
        cover(enable);
        cover(random[15:12] == 4'hA);
        cover(random[15:12] == 4'hF);
        cover(random[15:12] == 4'h0);
    end

    // Cover property - verify we can generate many different values
    reg [2:0] transitions = 0;
    always @(posedge clk) begin
        if (enable && random != $past(random))
            transitions <= transitions + 1;
    end
    always @(posedge clk) begin
        cover(transitions >= 7);
    end
`endif

endmodule
