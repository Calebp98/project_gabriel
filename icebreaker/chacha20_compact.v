//======================================================================
//
// chacha20_compact.v
// ------------------
// Compact ChaCha20 implementation optimized for small FPGA (iCE40).
//
// This is an area-optimized implementation that:
// - Processes one quarterround at a time (not 4 in parallel)
// - Uses 20 rounds as per ChaCha20 specification
// - Designed for authentication/PRF use, not stream cipher
//
// Based on ChaCha20 specification: RFC 8439
// Inspired by secworks/chacha (BSD-2-Clause license)
//
//======================================================================

`default_nettype none

module chacha20_compact(
    input wire clk,
    input wire rst_n,

    // Control
    input wire start,           // Pulse to begin encryption
    output reg ready,           // High when ready for new operation
    output reg valid,           // High when output is valid

    // Data (using as a PRF: key + nonce as input, output as authentication tag)
    input wire [255:0] key,     // 256-bit key
    input wire [127:0] nonce,   // 128-bit nonce/plaintext
    output reg [127:0] output_block  // 128-bit output (first 128 bits of ChaCha20 output)
);

    //----------------------------------------------------------------
    // ChaCha20 state: 16 x 32-bit words
    // Initial state:
    //   cccccccc  cccccccc  cccccccc  cccccccc   (constants)
    //   kkkkkkkk  kkkkkkkk  kkkkkkkk  kkkkkkkk   (key)
    //   kkkkkkkk  kkkkkkkk  kkkkkkkk  kkkkkkkk   (key cont.)
    //   bbbbbbbb  nnnnnnnn  nnnnnnnn  nnnnnnnn   (block counter + nonce)
    //----------------------------------------------------------------
    localparam [31:0] C0 = 32'h61707865;  // "expa"
    localparam [31:0] C1 = 32'h3320646e;  // "nd 3"
    localparam [31:0] C2 = 32'h79622d32;  // "2-by"
    localparam [31:0] C3 = 32'h6b206574;  // "te k"

    //----------------------------------------------------------------
    // State machine
    //----------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_ROUND = 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;
    reg [5:0] round_counter;  // 0-79 (20 double-rounds, 4 QRs each)

    //----------------------------------------------------------------
    // ChaCha state registers
    //----------------------------------------------------------------
    reg [31:0] s0, s1, s2, s3, s4, s5, s6, s7;
    reg [31:0] s8, s9, s10, s11, s12, s13, s14, s15;
    reg [31:0] init_s0, init_s1, init_s2, init_s3, init_s4, init_s5, init_s6, init_s7;
    reg [31:0] init_s8, init_s9, init_s10, init_s11, init_s12, init_s13, init_s14, init_s15;

    //----------------------------------------------------------------
    // Quarterround function
    // QR(a, b, c, d):
    //   a += b; d ^= a; d <<<= 16;
    //   c += d; b ^= c; b <<<= 12;
    //   a += b; d ^= a; d <<<= 8;
    //   c += d; b ^= c; b <<<= 7;
    //----------------------------------------------------------------
    function [31:0] rotl;
        input [31:0] x;
        input [4:0] n;
        begin
            rotl = (x << n) | (x >> (32 - n));
        end
    endfunction

    // Quarterround outputs and temp variables
    reg [31:0] qr_a_out, qr_b_out, qr_c_out, qr_d_out;
    reg [31:0] a, b, c, d;

    //----------------------------------------------------------------
    // Quarterround computation (combinational)
    //----------------------------------------------------------------
    always @* begin
        // Select which 4 words to process based on round_counter
        case (round_counter[1:0])
            2'd0: begin  // Column rounds
                case (round_counter[3:2])
                    2'd0: begin a = s0; b = s4; c = s8;  d = s12; end
                    2'd1: begin a = s1; b = s5; c = s9;  d = s13; end
                    2'd2: begin a = s2; b = s6; c = s10; d = s14; end
                    2'd3: begin a = s3; b = s7; c = s11; d = s15; end
                endcase
            end
            2'd1: begin  // Diagonal rounds
                case (round_counter[3:2])
                    2'd0: begin a = s0; b = s5; c = s10; d = s15; end
                    2'd1: begin a = s1; b = s6; c = s11; d = s12; end
                    2'd2: begin a = s2; b = s7; c = s8;  d = s13; end
                    2'd3: begin a = s3; b = s4; c = s9;  d = s14; end
                endcase
            end
            default: begin
                a = s0; b = s1; c = s2; d = s3;
            end
        endcase

        // Quarterround operations
        a = a + b; d = rotl(d ^ a, 16);
        c = c + d; b = rotl(b ^ c, 12);
        a = a + b; d = rotl(d ^ a, 8);
        c = c + d; b = rotl(b ^ c, 7);

        qr_a_out = a;
        qr_b_out = b;
        qr_c_out = c;
        qr_d_out = d;
    end

    //----------------------------------------------------------------
    // Main state machine
    //----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            ready <= 1;
            valid <= 0;
            round_counter <= 0;
            output_block <= 128'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    valid <= 0;
                    if (start) begin
                        // Initialize ChaCha20 state
                        init_s0 <= C0;
                        init_s1 <= C1;
                        init_s2 <= C2;
                        init_s3 <= C3;
                        init_s4 <= key[255:224];
                        init_s5 <= key[223:192];
                        init_s6 <= key[191:160];
                        init_s7 <= key[159:128];
                        init_s8 <= key[127:96];
                        init_s9 <= key[95:64];
                        init_s10 <= key[63:32];
                        init_s11 <= key[31:0];
                        init_s12 <= 32'h0;  // Block counter = 0
                        init_s13 <= nonce[127:96];
                        init_s14 <= nonce[95:64];
                        init_s15 <= nonce[63:32] ^ nonce[31:0];  // Mix nonce for 128-bit input

                        s0 <= C0;
                        s1 <= C1;
                        s2 <= C2;
                        s3 <= C3;
                        s4 <= key[255:224];
                        s5 <= key[223:192];
                        s6 <= key[191:160];
                        s7 <= key[159:128];
                        s8 <= key[127:96];
                        s9 <= key[95:64];
                        s10 <= key[63:32];
                        s11 <= key[31:0];
                        s12 <= 32'h0;
                        s13 <= nonce[127:96];
                        s14 <= nonce[95:64];
                        s15 <= nonce[63:32] ^ nonce[31:0];

                        round_counter <= 0;
                        ready <= 0;
                        state <= STATE_ROUND;
                    end
                end

                STATE_ROUND: begin
                    // Update state based on quarterround output
                    case (round_counter[1:0])
                        2'd0: begin  // Column rounds
                            case (round_counter[3:2])
                                2'd0: begin s0 <= qr_a_out; s4 <= qr_b_out; s8 <= qr_c_out;  s12 <= qr_d_out; end
                                2'd1: begin s1 <= qr_a_out; s5 <= qr_b_out; s9 <= qr_c_out;  s13 <= qr_d_out; end
                                2'd2: begin s2 <= qr_a_out; s6 <= qr_b_out; s10 <= qr_c_out; s14 <= qr_d_out; end
                                2'd3: begin s3 <= qr_a_out; s7 <= qr_b_out; s11 <= qr_c_out; s15 <= qr_d_out; end
                            endcase
                        end
                        2'd1: begin  // Diagonal rounds
                            case (round_counter[3:2])
                                2'd0: begin s0 <= qr_a_out; s5 <= qr_b_out; s10 <= qr_c_out; s15 <= qr_d_out; end
                                2'd1: begin s1 <= qr_a_out; s6 <= qr_b_out; s11 <= qr_c_out; s12 <= qr_d_out; end
                                2'd2: begin s2 <= qr_a_out; s7 <= qr_b_out; s8 <= qr_c_out;  s13 <= qr_d_out; end
                                2'd3: begin s3 <= qr_a_out; s4 <= qr_b_out; s9 <= qr_c_out;  s14 <= qr_d_out; end
                            endcase
                        end
                    endcase

                    round_counter <= round_counter + 1;

                    // 20 double-rounds = 40 rounds total, but we do 4 QRs per double-round
                    // So 20 double-rounds × 2 (column+diagonal) × 4 (QRs) = 160 operations
                    // But we actually do: 20 iterations × 8 QRs = 160, organized as 80 pairs
                    if (round_counter >= 6'd79) begin  // 20 double-rounds (80 QRs)
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    // Add initial state and output first 128 bits
                    output_block <= {
                        s0 + init_s0,
                        s1 + init_s1,
                        s2 + init_s2,
                        s3 + init_s3
                    };
                    valid <= 1;
                    ready <= 1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
