// CRC-16 DNP3 Calculator Module
// Polynomial: 0xA6BC (reversed: 0x3D65)
// Initial value: 0x0000
// Final XOR: 0xFFFF (complement result)
//
// DNP3 uses a byte-wise CRC calculation with the polynomial
// x^16 + x^13 + x^12 + x^11 + x^10 + x^8 + x^6 + x^5 + x^2 + 1

module crc16_dnp (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire crc_clear,        // Reset CRC calculation
    output reg [15:0] crc_out
);
    reg [15:0] crc_reg;

    // CRC lookup table for faster computation (optional, but saves cycles)
    // For now, we'll use bit-serial calculation

    integer i;
    reg [15:0] crc_temp;

    always @(posedge clk) begin
        if (rst || crc_clear) begin
            crc_reg <= 16'h0000;
            crc_out <= 16'hFFFF;
        end else if (data_valid) begin
            // Byte-wise CRC calculation
            crc_temp = crc_reg;

            // XOR data byte into LSB of CRC
            crc_temp = crc_temp ^ {8'h00, data_in};

            // Process 8 bits
            for (i = 0; i < 8; i = i + 1) begin
                if (crc_temp[0])
                    crc_temp = (crc_temp >> 1) ^ 16'hA6BC;
                else
                    crc_temp = crc_temp >> 1;
            end

            crc_reg <= crc_temp;
            crc_out <= ~crc_temp;  // DNP3 complements the final CRC
        end
    end
endmodule
