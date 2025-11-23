module top(
    input CLK,              // 12 MHz clock
    output LEDR_N,          // Main board red LED (active low)
    output LEDG_N,          // Main board green LED (active low)
    output LED_RGB0,        // RGB LED pins (active low)
    output LED_RGB1,
    output LED_RGB2,
    output LED1,            // 5-LED array (active high on break-off section)
    output LED2,
    output LED3,
    output LED4,
    output LED5
);
    // Counter for timing - create ~200ms delays for visible sequencing
    // 12 MHz / 2,400,000 = 5 Hz (200ms per transition)
    reg [21:0] counter = 0;
    reg [2:0] led_state = 0;  // Which LED is currently on (0-4)

    // Clock divider to create visible LED transitions
    always @(posedge CLK) begin
        if (counter == 22'd2_399_999) begin
            counter <= 0;
            // Move to next LED in sequence
            if (led_state == 3'd4)
                led_state <= 0;
            else
                led_state <= led_state + 1;
        end else begin
            counter <= counter + 1;
        end
    end

    // Turn off main board LEDs (active low, so set to 1)
    assign LEDR_N = 1'b1;
    assign LEDG_N = 1'b1;

    // Turn off RGB LED (active low, so set to 1)
    assign LED_RGB0 = 1'b1;
    assign LED_RGB1 = 1'b1;
    assign LED_RGB2 = 1'b1;

    // Sequence through 5-LED array in circular pattern
    // LEDs on break-off section are active HIGH (1 = ON, 0 = OFF)
    // Diamond/circular pattern: 1 -> 2 -> 3 -> 4 -> 5 -> 1 ...
    assign LED1 = (led_state == 3'd0) ? 1'b1 : 1'b0;
    assign LED2 = (led_state == 3'd1) ? 1'b1 : 1'b0;
    assign LED3 = (led_state == 3'd2) ? 1'b1 : 1'b0;
    assign LED4 = (led_state == 3'd3) ? 1'b1 : 1'b0;
    assign LED5 = (led_state == 3'd4) ? 1'b1 : 1'b0;

endmodule
