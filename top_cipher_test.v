// Top module for testing XOR cipher with hardcoded encrypted data
// Hardcoded encrypted "CAT": 0x9D 0xEC 0xEA
// Feeds encrypted bytes → XOR Decrypt → Grammar FSM → LEDs
//
// LED Behavior:
//   LED_GREEN (pin 37, active-low): Lights when "CAT" accepted (after decryption)
//   LED_RED (pin 11, active-low): Lights when pattern rejected
//   LED_RX (pin 26, active-high): Activity indicator (toggles during test)

module top_test (
    input wire CLK,      // 12 MHz clock on iCEBreaker
    output wire LED_RED,
    output wire LED_GREEN,
    output wire LED_RX
);
    // Encrypted "CAT" bytes
    // 'C' (0x43) XOR 0xDE = 0x9D
    // 'A' (0x41) XOR 0xAD = 0xEC
    // 'T' (0x54) XOR 0xBE = 0xEA
    localparam [7:0] ENC_BYTE_0 = 8'h9D;
    localparam [7:0] ENC_BYTE_1 = 8'hEC;
     localparam [7:0] ENC_BYTE_2 = 8'hEA;

    // Slow down clock for visible LED behavior
    reg [23:0] counter = 0;
    reg [1:0] byte_index = 0;
    reg [7:0] current_byte = 0;
    reg byte_valid = 0;

    wire [7:0] decrypted_data;
    wire decrypted_valid;
    wire accept_signal;
    wire reject_signal;

    // Activity LED toggle
    reg activity_led = 0;

    // Clock divider and byte feeder
    always @(posedge CLK) begin
        counter <= counter + 1;

        // Every ~1.4 seconds (12MHz / 2^24), send next byte
        if (counter == 24'd0) begin
            byte_valid <= 1;
            activity_led <= ~activity_led;

            case (byte_index)
                2'd0: current_byte <= ENC_BYTE_0;  // 0x9D
                2'd1: current_byte <= ENC_BYTE_1;  // 0xEC
                2'd2: current_byte <= ENC_BYTE_2;  // 0xEA
                default: current_byte <= 8'h00;
            endcase

            // Cycle through bytes
            if (byte_index == 2'd2)
                byte_index <= 2'd0;  // Reset after last byte
            else
                byte_index <= byte_index + 1;
        end else begin
            byte_valid <= 0;
        end
    end

    // XOR Cipher instance - decrypts the hardcoded encrypted data
    xor_cipher cipher_inst (
        .clk(CLK),
        .rst(1'b0),
        .data_in(current_byte),
        .data_valid(byte_valid),
        .data_out(decrypted_data),
        .data_out_valid(decrypted_valid)
    );

    // Grammar FSM instance - validates "CAT" pattern on decrypted data
    grammar_fsm fsm_inst (
        .clk(CLK),
        .rst(1'b0),
        .data_in(decrypted_data),
        .data_valid(decrypted_valid),
        .accept(accept_signal),
        .reject(reject_signal)
    );

    // LED outputs
    assign LED_GREEN = ~accept_signal;   // Active low - ON when "CAT" accepted
    assign LED_RED = ~reject_signal;     // Active low - ON when pattern rejected
    assign LED_RX = activity_led;        // Active high - toggles to show activity

endmodule
