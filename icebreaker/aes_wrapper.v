//======================================================================
//
// aes_wrapper.v
// -------------
// Simple wrapper around secworks/aes core for challenge-response auth.
//
// This wrapper:
// - Uses AES-128 ECB mode for encryption only
// - Fixed 128-bit key (set at initialization)
// - Simple start/done interface
//
// Based on secworks/aes (BSD-2-Clause license)
// https://github.com/secworks/aes
//
//======================================================================

`default_nettype none

module aes_wrapper(
    input wire clk,
    input wire rst_n,

    // Simple control interface
    input wire start,              // Pulse to start encryption
    output wire ready,             // High when ready for new operation

    // Data interface
    input wire [127:0] plaintext,  // Input block to encrypt
    input wire [127:0] key,        // AES-128 key (set once)
    output wire [127:0] ciphertext, // Encrypted output
    output wire valid              // High when ciphertext is valid
);

    //----------------------------------------------------------------
    // Internal wires and registers
    //----------------------------------------------------------------
    reg init_key;
    reg next_block;
    reg key_initialized;
    reg [127:0] key_reg;

    wire core_ready;
    wire core_valid;
    wire [127:0] core_result;

    // State machine
    localparam STATE_IDLE = 2'd0;
    localparam STATE_INIT_KEY = 2'd1;
    localparam STATE_ENCRYPT = 2'd2;

    reg [1:0] state;
    reg [127:0] plaintext_reg;

    //----------------------------------------------------------------
    // AES core instantiation
    //----------------------------------------------------------------
    aes_core aes(
        .clk(clk),
        .reset_n(rst_n),

        .encdec(1'b1),              // 1 = encrypt
        .init(init_key),
        .next(next_block),
        .ready(core_ready),

        .key({128'h0, key_reg}),    // 256-bit input, use lower 128 bits
        .keylen(1'b0),              // 0 = 128-bit key

        .block(plaintext_reg),
        .result(core_result),
        .result_valid(core_valid)
    );

    //----------------------------------------------------------------
    // Output assignments
    //----------------------------------------------------------------
    assign ready = (state == STATE_IDLE) && key_initialized;
    assign ciphertext = core_result;
    assign valid = core_valid;

    //----------------------------------------------------------------
    // Control FSM
    //----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            init_key <= 0;
            next_block <= 0;
            key_initialized <= 0;
            key_reg <= 128'h0;
            plaintext_reg <= 128'h0;
        end else begin
            // Default: clear control signals
            init_key <= 0;
            next_block <= 0;

            case (state)
                STATE_IDLE: begin
                    if (!key_initialized) begin
                        // First time: initialize key
                        key_reg <= key;
                        init_key <= 1;
                        state <= STATE_INIT_KEY;
                    end else if (start) begin
                        // Key already initialized, start encryption
                        plaintext_reg <= plaintext;
                        next_block <= 1;
                        state <= STATE_ENCRYPT;
                    end
                end

                STATE_INIT_KEY: begin
                    // Wait for key expansion to complete
                    if (core_ready && !init_key) begin
                        key_initialized <= 1;
                        state <= STATE_IDLE;
                    end
                end

                STATE_ENCRYPT: begin
                    // Wait for encryption to complete
                    if (core_ready && !next_block) begin
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
