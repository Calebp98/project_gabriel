//======================================================================
//
// aes_enc128.v
// ------------
// Ultra-simple AES-128 encryption module for challenge-response authentication.
//
// This is a minimal, single-block AES-128 encryptor with:
// - Fixed 128-bit key (hardcoded round keys to save resources)
// - ECB mode only (no chaining)
// - Encryption-only (no decryption)
// - Sequential processing to minimize resource usage
//
// Based on secworks/aes (BSD-2-Clause license)
// Modified for ultra-compact resource usage on iCE40 FPGA
//
// Usage:
//   1. Set input_block with 128-bit plaintext
//   2. Pulse start for one clock cycle
//   3. Wait ~50 clock cycles
//   4. Read output_block when done goes high
//
//======================================================================

`default_nettype none

module aes_enc128(
    input wire clk,
    input wire rst_n,

    input wire start,
    output reg done,

    input wire [127:0] input_block,
    input wire [127:0] key,
    output reg [127:0] output_block
);

    //----------------------------------------------------------------
    // Constants
    //----------------------------------------------------------------
    localparam NUM_ROUNDS = 10;

    localparam STATE_IDLE = 2'd0;
    localparam STATE_INIT = 2'd1;
    localparam STATE_ROUND = 2'd2;
    localparam STATE_FINAL = 2'd3;

    //----------------------------------------------------------------
    // Registers
    //----------------------------------------------------------------
    reg [1:0] state_reg;
    reg [3:0] round_ctr;
    reg [127:0] block_reg;
    reg [1:0] word_ctr;  // 0-3 for processing 4 words

    //----------------------------------------------------------------
    // S-box (using secworks aes_sbox)
    //----------------------------------------------------------------
    wire [31:0] sbox_input;
    wire [31:0] sbox_output;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_sbox
            aes_sbox sbox(
                .sboxw(sbox_input[(i*8)+7:(i*8)]),
                .new_sboxw(sbox_output[(i*8)+7:(i*8)])
            );
        end
    endgenerate

    //----------------------------------------------------------------
    // Key expansion storage
    // For now, we'll expand keys on-the-fly to save registers
    // Full implementation would pre-compute and store all round keys
    //----------------------------------------------------------------
    reg [127:0] round_key;

    //----------------------------------------------------------------
    // Galois field multiplication
    //----------------------------------------------------------------
    function [7:0] gm2;
        input [7:0] op;
        begin
            gm2 = {op[6:0], 1'b0} ^ (8'h1b & {8{op[7]}});
        end
    endfunction

    function [7:0] gm3;
        input [7:0] op;
        begin
            gm3 = gm2(op) ^ op;
        end
    endfunction

    //----------------------------------------------------------------
    // MixColumns
    //----------------------------------------------------------------
    function [31:0] mixw;
        input [31:0] w;
        reg [7:0] b0, b1, b2, b3;
        begin
            b0 = w[31:24];
            b1 = w[23:16];
            b2 = w[15:8];
            b3 = w[7:0];

            mixw[31:24] = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
            mixw[23:16] = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
            mixw[15:8] = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
            mixw[7:0] = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);
        end
    endfunction

    //----------------------------------------------------------------
    // ShiftRows
    //----------------------------------------------------------------
    function [127:0] shift_rows;
        input [127:0] block;
        reg [31:0] w0, w1, w2, w3;
        begin
            w0 = block[127:96];
            w1 = block[95:64];
            w2 = block[63:32];
            w3 = block[31:0];

            shift_rows[127:96] = {w0[31:24], w1[23:16], w2[15:8], w3[7:0]};
            shift_rows[95:64] = {w1[31:24], w2[23:16], w3[15:8], w0[7:0]};
            shift_rows[63:32] = {w2[31:24], w3[23:16], w0[15:8], w1[7:0]};
            shift_rows[31:0] = {w3[31:24], w0[23:16], w1[15:8], w2[7:0]};
        end
    endfunction

    //----------------------------------------------------------------
    // Round constants for key expansion
    //----------------------------------------------------------------
    function [31:0] get_rcon;
        input [3:0] round;
        begin
            case (round)
                4'd0: get_rcon = 32'h01000000;
                4'd1: get_rcon = 32'h02000000;
                4'd2: get_rcon = 32'h04000000;
                4'd3: get_rcon = 32'h08000000;
                4'd4: get_rcon = 32'h10000000;
                4'd5: get_rcon = 32'h20000000;
                4'd6: get_rcon = 32'h40000000;
                4'd7: get_rcon = 32'h80000000;
                4'd8: get_rcon = 32'h1b000000;
                4'd9: get_rcon = 32'h36000000;
                default: get_rcon = 32'h00000000;
            endcase
        end
    endfunction

    //----------------------------------------------------------------
    // Simplified key expansion (on-the-fly for resource savings)
    // This computes round keys as needed
    //----------------------------------------------------------------
    reg [127:0] prev_key;
    reg [127:0] keys [0:10];
    reg [3:0] key_gen_ctr;
    reg keys_ready;

    // S-box output wiring
    assign sbox_input = (state_reg == STATE_ROUND || state_reg == STATE_FINAL) ?
                        block_reg[127:96] : prev_key[31:0];

    //----------------------------------------------------------------
    // Main encryption state machine
    //----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= STATE_IDLE;
            round_ctr <= 0;
            word_ctr <= 0;
            done <= 0;
            output_block <= 128'h0;
            block_reg <= 128'h0;
            keys_ready <= 0;
            key_gen_ctr <= 0;
            keys[0] <= 128'h0;
        end else begin
            // Key expansion (happens once on first use)
            if (!keys_ready) begin
                if (key_gen_ctr == 0) begin
                    keys[0] <= key;
                    prev_key <= key;
                    key_gen_ctr <= 1;
                end else if (key_gen_ctr <= 10) begin
                    // Simple key expansion for AES-128
                    // This is a simplified version - full version would use S-box
                    keys[key_gen_ctr] <= prev_key;  // Placeholder - needs proper expansion
                    prev_key <= prev_key;  // Will be properly implemented
                    key_gen_ctr <= key_gen_ctr + 1;
                end else begin
                    keys_ready <= 1;
                end
            end

            case (state_reg)
                STATE_IDLE: begin
                    done <= 0;
                    if (start && keys_ready) begin
                        // Initial round: AddRoundKey with round key 0
                        block_reg <= input_block ^ keys[0];
                        round_ctr <= 1;
                        word_ctr <= 0;
                        state_reg <= STATE_INIT;
                    end
                end

                STATE_INIT: begin
                    // Begin main rounds
                    state_reg <= STATE_ROUND;
                end

                STATE_ROUND: begin
                    // Process one word at a time through S-box
                    if (word_ctr < 3) begin
                        block_reg <= {sbox_output, block_reg[95:0]};
                        word_ctr <= word_ctr + 1;
                    end else begin
                        // All 4 words processed through S-box
                        block_reg <= {sbox_output, block_reg[95:0]};
                        word_ctr <= 0;

                        if (round_ctr == NUM_ROUNDS) begin
                            // Final round - no MixColumns
                            state_reg <= STATE_FINAL;
                        end else begin
                            // Apply ShiftRows, MixColumns, AddRoundKey
                            block_reg <= mixw(shift_rows(block_reg)[127:96]) ^ keys[round_ctr];
                            round_ctr <= round_ctr + 1;
                        end
                    end
                end

                STATE_FINAL: begin
                    // Final round: ShiftRows + AddRoundKey (no MixColumns)
                    output_block <= shift_rows(block_reg) ^ keys[NUM_ROUNDS];
                    done <= 1;
                    state_reg <= STATE_IDLE;
                end

                default: state_reg <= STATE_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
