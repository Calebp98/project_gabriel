// Top module for iCEbreaker UART control
// Receives UART characters and controls output pin
// 'Y' or 'y' -> pin LOW (0V)
// 'N' or 'n' -> pin HIGH (3.3V)

module top (
    input  wire CLK,        // 12 MHz clock on iCEbreaker
    input  wire RX,         // UART RX from picoprobe
    output wire CONTROL_PIN, // Output control pin (pin 4)
    output wire LED1,       // Debug LED (optional)
    output wire LED2,       // Debug LED (optional)
    output wire LED3,       // Debug LED (optional)
    output wire LED4,       // Debug LED (optional)
    output wire LED5        // Debug LED (optional)
);

    // Internal signals
    wire [7:0] rx_data;
    wire rx_data_valid;
    reg control_state = 1;  // Default HIGH (3.3V)

    // LED debug outputs
    reg [4:0] led_state = 5'b00001;

    // UART receiver instance
    uart_rx #(
        .CLOCK_FREQ(12_000_000),
        .BAUD_RATE(115200)
    ) uart_receiver (
        .clk(CLK),
        .rst(1'b0),
        .rx(RX),
        .data(rx_data),
        .data_valid(rx_data_valid)
    );

    // Character processing logic
    always @(posedge CLK) begin
        if (rx_data_valid) begin
            case (rx_data)
                8'h59,  // 'Y'
                8'h79:  // 'y'
                begin
                    control_state <= 0;  // Set to LOW (0V)
                    led_state <= 5'b10000;  // LED pattern for 'Y'
                end

                8'h4E,  // 'N'
                8'h6E:  // 'n'
                begin
                    control_state <= 1;  // Set to HIGH (3.3V)
                    led_state <= 5'b00001;  // LED pattern for 'N'
                end

                default: begin
                    // Unknown character - blink all LEDs
                    led_state <= 5'b11111;
                end
            endcase
        end
    end

    // Output assignments
    assign CONTROL_PIN = control_state;

    // LED debug outputs (optional - shows received commands)
    assign LED1 = led_state[0];
    assign LED2 = led_state[1];
    assign LED3 = led_state[2];
    assign LED4 = led_state[3];
    assign LED5 = led_state[4];

endmodule
