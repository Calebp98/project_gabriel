// XOR Stream Cipher Module
// Implements a weak 4-byte repeating key XOR cipher for demonstration
//
// WARNING: This is intentionally weak cryptography for educational purposes
// Key: 0xDE 0xAD 0xBE 0xEF (repeating)
//
// Operation: plaintext = ciphertext XOR key[index]
// Since XOR is symmetric: ciphertext = plaintext XOR key[index]

module xor_cipher (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,      // Encrypted input
    input wire data_valid,          // Data valid strobe
    output reg [7:0] data_out,      // Decrypted output
    output reg data_out_valid       // Output valid strobe
);
    // 4-byte repeating key: DEADBEEF
    localparam [7:0] KEY_0 = 8'hDE;
    localparam [7:0] KEY_1 = 8'hAD;
    localparam [7:0] KEY_2 = 8'hBE;
    localparam [7:0] KEY_3 = 8'hEF;

    // Key index counter (0-3, wraps around)
    reg [1:0] key_index = 2'b00;

    // Current key byte based on index
    reg [7:0] current_key;

    // Combinational key selection
    always @(*) begin
        case (key_index)
            2'd0: current_key = KEY_0;
            2'd1: current_key = KEY_1;
            2'd2: current_key = KEY_2;
            2'd3: current_key = KEY_3;
            default: current_key = KEY_0;
        endcase
    end

    // XOR decryption and key rotation
    always @(posedge clk) begin
        if (rst) begin
            key_index <= 2'b00;
            data_out <= 8'h00;
            data_out_valid <= 1'b0;
        end else if (data_valid) begin
            // Decrypt: plaintext = ciphertext XOR key
            data_out <= data_in ^ current_key;
            data_out_valid <= 1'b1;

            // Rotate to next key byte (wraps automatically with 2-bit counter)
            key_index <= key_index + 2'b01;
        end else begin
            data_out_valid <= 1'b0;
        end
    end

`ifdef FORMAL
    // Formal verification properties

    // Initial state assumptions
    initial assume(key_index < 4);
    initial assume(data_out_valid == 0);

    // Track that we're past the first cycle
    reg past_valid = 0;
    always @(posedge clk) begin
        past_valid <= 1;
    end

    // Property 1: Key index always valid (0-3)
    always @(posedge clk) begin
        assert(key_index < 4);
    end

    // Property 2: Output valid only when input was valid last cycle
    reg prev_data_valid = 0;
    always @(posedge clk) begin
        if (!rst) begin
            prev_data_valid <= data_valid;
            if (data_out_valid && past_valid)
                assert(prev_data_valid);
        end
    end

    // Property 3: XOR decryption correctness
    // If we know plaintext, encrypting and decrypting should return original
    reg [7:0] test_plaintext = 8'hAA;  // Arbitrary test value
    reg [7:0] test_ciphertext;
    reg [7:0] test_decrypted;

    always @(posedge clk) begin
        if (!rst) begin
            // Simulate encryption: ciphertext = plaintext XOR key
            test_ciphertext = test_plaintext ^ current_key;
            // Then decrypt: plaintext = ciphertext XOR key
            test_decrypted = test_ciphertext ^ current_key;
            // Should get back original plaintext
            assert(test_decrypted == test_plaintext);
        end
    end

    // Property 4: Current key matches key_index
    always @(posedge clk) begin
        case (key_index)
            2'd0: assert(current_key == KEY_0);
            2'd1: assert(current_key == KEY_1);
            2'd2: assert(current_key == KEY_2);
            2'd3: assert(current_key == KEY_3);
        endcase
    end

    // Property 5: Key rotation wraps correctly (0->1->2->3->0)
    reg [1:0] prev_key_index = 0;
    always @(posedge clk) begin
        if (!rst && past_valid && !$past(rst)) begin
            if ($past(data_valid)) begin
                // After valid data, key_index should increment (with wrap)
                if ($past(key_index) == 2'd3)
                    assert(key_index == 2'd0);  // Wrap around
                else
                    assert(key_index == $past(key_index) + 1);
            end else begin
                // Without data_valid, key_index should not change
                assert(key_index == $past(key_index));
            end
        end
    end

    // Property 6: Decryption output matches XOR operation
    always @(posedge clk) begin
        if (!rst && past_valid && $past(data_valid) && !$past(rst)) begin
            assert(data_out == ($past(data_in) ^ $past(current_key)));
        end
    end

    // Property 7: Reset behavior
    always @(posedge clk) begin
        if (past_valid && $past(rst)) begin
            assert(key_index == 0);
            assert(data_out_valid == 0);
        end
    end

    // Cover properties - verify key rotation works through all positions
    always @(posedge clk) begin
        cover(key_index == 2'd0 && data_valid);
        cover(key_index == 2'd1 && data_valid);
        cover(key_index == 2'd2 && data_valid);
        cover(key_index == 2'd3 && data_valid);
    end

    // Cover property - verify we can decrypt data
    always @(posedge clk) begin
        cover(data_out_valid);
    end

    // Cover property - verify key wraps around
    reg seen_wrap = 0;
    always @(posedge clk) begin
        if (past_valid && key_index == 2'd0 && $past(key_index) == 2'd3 && $past(data_valid))
            seen_wrap <= 1;
    end
    always @(posedge clk) begin
        cover(seen_wrap);
    end
`endif

endmodule
