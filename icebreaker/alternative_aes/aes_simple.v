//======================================================================
//
// aes_simple.v
// ------------
// Simplified AES-128 encryption-only wrapper for challenge-response auth.
// This is a compact, easy-to-use interface for AES-128 ECB encryption.
//
// Usage:
//   1. Set plaintext and key inputs
//   2. Pulse start signal high for one cycle
//   3. Wait for done signal to go high (~11 cycles)
//   4. Read ciphertext output
//
// Based on secworks/aes (BSD-2-Clause license)
// https://github.com/secworks/aes
//
//======================================================================

`default_nettype none

module aes_simple(
    input wire clk,
    input wire rst,

    // Control
    input wire start,           // Pulse high to begin encryption
    output reg done,            // High when encryption complete

    // Data
    input wire [127:0] plaintext,  // 128-bit input block
    input wire [127:0] key,        // 128-bit key (fixed for this design)
    output reg [127:0] ciphertext  // 128-bit encrypted output
);

    //----------------------------------------------------------------
    // State machine
    //----------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_ROUND = 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] round_ctr;

    //----------------------------------------------------------------
    // Round constants for key expansion
    //----------------------------------------------------------------
    function [7:0] rcon;
        input [3:0] round;
        begin
            case(round)
                4'h0: rcon = 8'h01;
                4'h1: rcon = 8'h02;
                4'h2: rcon = 8'h04;
                4'h3: rcon = 8'h08;
                4'h4: rcon = 8'h10;
                4'h5: rcon = 8'h20;
                4'h6: rcon = 8'h40;
                4'h7: rcon = 8'h80;
                4'h8: rcon = 8'h1b;
                4'h9: rcon = 8'h36;
                default: rcon = 8'h00;
            endcase
        end
    endfunction

    //----------------------------------------------------------------
    // S-box instances (use 4 for word-level processing)
    //----------------------------------------------------------------
    wire [31:0] sbox_in;
    wire [31:0] sbox_out;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : sbox_array
            aes_sbox sbox_inst(
                .sboxw(sbox_in[i*8 +: 8]),
                .new_sboxw(sbox_out[i*8 +: 8])
            );
        end
    endgenerate

    //----------------------------------------------------------------
    // Galois field multiplication functions
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
    // MixColumns transformation
    //----------------------------------------------------------------
    function [31:0] mixw;
        input [31:0] w;
        reg [7:0] b0, b1, b2, b3;
        begin
            b0 = w[31:24];
            b1 = w[23:16];
            b2 = w[15:8];
            b3 = w[7:0];

            mixw = {
                gm2(b0) ^ gm3(b1) ^ b2 ^ b3,
                b0 ^ gm2(b1) ^ gm3(b2) ^ b3,
                b0 ^ b1 ^ gm2(b2) ^ gm3(b3),
                gm3(b0) ^ b1 ^ b2 ^ gm2(b3)
            };
        end
    endfunction

    function [127:0] mixcolumns;
        input [127:0] data;
        begin
            mixcolumns = {
                mixw(data[127:96]),
                mixw(data[95:64]),
                mixw(data[63:32]),
                mixw(data[31:0])
            };
        end
    endfunction

    //----------------------------------------------------------------
    // ShiftRows transformation
    //----------------------------------------------------------------
    function [127:0] shiftrows;
        input [127:0] data;
        reg [31:0] w0, w1, w2, w3;
        begin
            w0 = data[127:96];
            w1 = data[95:64];
            w2 = data[63:32];
            w3 = data[31:0];

            shiftrows = {
                {w0[31:24], w1[23:16], w2[15:8], w3[7:0]},
                {w1[31:24], w2[23:16], w3[15:8], w0[7:0]},
                {w2[31:24], w3[23:16], w0[15:8], w1[7:0]},
                {w3[31:24], w0[23:16], w1[15:8], w2[7:0]}
            };
        end
    endfunction

    //----------------------------------------------------------------
    // Registers for encryption state
    //----------------------------------------------------------------
    reg [127:0] state_block;
    reg [127:0] round_keys [0:10];  // Store all 11 round keys (0-10)

    //----------------------------------------------------------------
    // Key expansion logic (generate all round keys at start)
    //----------------------------------------------------------------
    reg keys_expanded;
    reg [3:0] key_round;

    // S-box input for key expansion
    reg [31:0] key_sbox_in;
    wire [31:0] key_sbox_out;

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : key_sbox_array
            aes_sbox key_sbox(
                .sboxw(key_sbox_in[j*8 +: 8]),
                .new_sboxw(key_sbox_out[j*8 +: 8])
            );
        end
    endgenerate

    // Key expansion function
    function [127:0] expand_key;
        input [127:0] prev_key;
        input [3:0] round;
        input [31:0] sbox_result;
        reg [31:0] w0, w1, w2, w3;
        reg [31:0] rotated;
        begin
            w0 = prev_key[127:96];
            w1 = prev_key[95:64];
            w2 = prev_key[63:32];
            w3 = prev_key[31:0];

            // RotWord and SubWord applied to w3, then XOR with rcon
            rotated = {sbox_result[23:0], sbox_result[31:24]};
            w0 = w0 ^ rotated ^ {rcon(round), 24'h000000};
            w1 = w1 ^ w0;
            w2 = w2 ^ w1;
            w3 = w3 ^ w2;

            expand_key = {w0, w1, w2, w3};
        end
    endfunction

    //----------------------------------------------------------------
    // S-box multiplexing
    //----------------------------------------------------------------
    assign sbox_in = (state == STATE_ROUND) ? state_block[127:96] : 32'h0;

    //----------------------------------------------------------------
    // Main state machine and encryption logic
    //----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            done <= 0;
            round_ctr <= 0;
            keys_expanded <= 0;
            key_round <= 0;
            ciphertext <= 128'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 0;

                    if (start) begin
                        // Initialize key expansion if not done
                        if (!keys_expanded) begin
                            round_keys[0] <= key;
                            key_round <= 0;
                            // Start key expansion
                            key_sbox_in <= key[31:0];
                        end else begin
                            // Keys already expanded, start encryption
                            state_block <= plaintext ^ round_keys[0];
                            round_ctr <= 1;
                            state <= STATE_ROUND;
                        end
                    end
                end

                STATE_ROUND: begin
                    // Apply SubBytes (S-box) to current word
                    state_block <= {sbox_out, state_block[95:0]};

                    // After processing all 4 words of the round
                    if (round_ctr == 4'd10) begin
                        // Final round: ShiftRows + SubBytes only
                        state_block <= shiftrows(state_block) ^ round_keys[10];
                        state <= STATE_DONE;
                    end else begin
                        // Regular round: ShiftRows + MixColumns + AddRoundKey
                        state_block <= mixcolumns(shiftrows(state_block)) ^ round_keys[round_ctr];
                        round_ctr <= round_ctr + 1;
                    end
                end

                STATE_DONE: begin
                    ciphertext <= state_block;
                    done <= 1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase

            // Handle key expansion in parallel
            if (!keys_expanded && key_round < 10) begin
                round_keys[key_round + 1] <= expand_key(
                    round_keys[key_round],
                    key_round,
                    key_sbox_out
                );
                key_round <= key_round + 1;

                // Prepare next S-box input
                if (key_round < 9) begin
                    key_sbox_in <= round_keys[key_round][31:0];
                end else begin
                    keys_expanded <= 1;
                end
            end
        end
    end

endmodule

`default_nettype wire
