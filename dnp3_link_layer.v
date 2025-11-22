// DNP3 Link Layer Frame Parser
// Parses and validates DNP3 link layer frames
//
// Frame Format:
//   [0x05] [0x64] [LEN] [CTRL] [DEST_L] [DEST_H] [SRC_L] [SRC_H] [CRC_L] [CRC_H] [DATA...]
//
// Features:
//   - Validates start bytes (0x05 0x64)
//   - Validates header CRC-16
//   - Filters by destination address
//   - Extracts control byte and source address
//
// States track frame reception and validation

module dnp3_link_layer #(
    parameter [15:0] MY_ADDRESS = 16'h0001  // Device address (little-endian)
)(
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,

    // Outputs
    output reg frame_valid,       // Pulse when valid frame received
    output reg frame_error,       // Pulse when frame error detected
    output reg [7:0] control,     // Control byte from frame
    output reg [15:0] src_addr,   // Source address
    output reg [15:0] dest_addr,  // Destination address
    output reg addr_match         // Set if dest address matches MY_ADDRESS
);

    // State machine states
    localparam S_IDLE       = 4'd0;
    localparam S_START1     = 4'd1;  // Got 0x05
    localparam S_START2     = 4'd2;  // Got 0x64
    localparam S_LENGTH     = 4'd3;
    localparam S_CONTROL    = 4'd4;
    localparam S_DEST_L     = 4'd5;
    localparam S_DEST_H     = 4'd6;
    localparam S_SRC_L      = 4'd7;
    localparam S_SRC_H      = 4'd8;
    localparam S_CRC_L      = 4'd9;
    localparam S_CRC_H      = 4'd10;
    localparam S_VALIDATE   = 4'd11;

    reg [3:0] state = S_IDLE;
    reg [7:0] length;
    reg [7:0] control_reg;
    reg [15:0] src_addr_reg;
    reg [15:0] dest_addr_reg;
    reg [7:0] rx_crc_l;
    reg [7:0] rx_crc_h;

    // CRC calculation wires
    wire [15:0] calc_crc;
    reg crc_clear;
    reg crc_data_valid;

    // Instantiate CRC module
    crc16_dnp crc_inst (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(crc_data_valid),
        .crc_clear(crc_clear),
        .crc_out(calc_crc)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            frame_valid <= 0;
            frame_error <= 0;
            crc_clear <= 1;
            crc_data_valid <= 0;
            addr_match <= 0;
        end else begin
            // Default values
            frame_valid <= 0;
            frame_error <= 0;
            crc_data_valid <= 0;
            crc_clear <= 0;

            if (data_valid) begin
                case (state)
                    S_IDLE: begin
                        if (data_in == 8'h05) begin
                            state <= S_START1;
                            crc_clear <= 1;  // Start fresh CRC calculation
                        end
                    end

                    S_START1: begin
                        if (data_in == 8'h64) begin
                            state <= S_START2;
                        end else if (data_in == 8'h05) begin
                            state <= S_START1;  // Restart if another 0x05
                            crc_clear <= 1;
                        end else begin
                            state <= S_IDLE;
                            frame_error <= 1;
                        end
                    end

                    S_START2: begin
                        length <= data_in;
                        state <= S_LENGTH;
                        crc_data_valid <= 1;  // Start CRC from length byte
                    end

                    S_LENGTH: begin
                        control_reg <= data_in;
                        state <= S_CONTROL;
                        crc_data_valid <= 1;
                    end

                    S_CONTROL: begin
                        dest_addr_reg[7:0] <= data_in;
                        state <= S_DEST_L;
                        crc_data_valid <= 1;
                    end

                    S_DEST_L: begin
                        dest_addr_reg[15:8] <= data_in;
                        state <= S_DEST_H;
                        crc_data_valid <= 1;
                    end

                    S_DEST_H: begin
                        src_addr_reg[7:0] <= data_in;
                        state <= S_SRC_L;
                        crc_data_valid <= 1;
                    end

                    S_SRC_L: begin
                        src_addr_reg[15:8] <= data_in;
                        state <= S_SRC_H;
                        crc_data_valid <= 1;
                    end

                    S_SRC_H: begin
                        rx_crc_l <= data_in;
                        state <= S_CRC_L;
                        // Don't include CRC bytes in calculation
                    end

                    S_CRC_L: begin
                        rx_crc_h <= data_in;
                        state <= S_VALIDATE;
                    end

                    S_VALIDATE: begin
                        // Check if received CRC matches calculated CRC
                        if ({rx_crc_h, rx_crc_l} == calc_crc) begin
                            // CRC valid
                            frame_valid <= 1;
                            control <= control_reg;
                            src_addr <= src_addr_reg;
                            dest_addr <= dest_addr_reg;

                            // Check if destination address matches ours
                            if (dest_addr_reg == MY_ADDRESS) begin
                                addr_match <= 1;
                            end else begin
                                addr_match <= 0;
                            end
                        end else begin
                            // CRC error
                            frame_error <= 1;
                            addr_match <= 0;
                        end
                        state <= S_IDLE;
                    end

                    default: begin
                        state <= S_IDLE;
                        frame_error <= 1;
                    end
                endcase
            end
        end
    end

endmodule
