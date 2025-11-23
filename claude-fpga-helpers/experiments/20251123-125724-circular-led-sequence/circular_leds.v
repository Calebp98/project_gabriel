module top(
    input CLK,              // 12 MHz clock

    // Main board LEDs (active low)
    output LED_RED,         // Pin 11
    output LED_GREEN,       // Pin 37

    // Snap-off section LEDs (active high)
    output P2_1,            // Pin 27
    output P2_2,            // Pin 25
    output P2_3,            // Pin 21
    output P2_7,            // Pin 26
    output P2_8,            // Pin 23

    // RGB LED (active low for common anode)
    output LED_RGB0,        // Pin 39 - Red channel
    output LED_RGB1,        // Pin 40 - Green channel
    output LED_RGB2         // Pin 41 - Blue channel
);

    // Clock divider: 12 MHz / 3,000,000 = 4 Hz (250ms per LED)
    reg [22:0] counter = 0;
    reg [3:0] led_state = 0;  // 0-10: which LED is currently on (11 total states)

    // Clock divider
    always @(posedge CLK) begin
        if (counter == 23'd2_999_999) begin
            counter <= 0;
            // Advance to next LED
            if (led_state == 10)
                led_state <= 0;
            else
                led_state <= led_state + 1;
        end else begin
            counter <= counter + 1;
        end
    end

    // LED control based on current state
    // Active LOW outputs: write 0 to turn on, 1 to turn off
    // Active HIGH outputs: write 1 to turn on, 0 to turn off

    // Main board LEDs (active low)
    assign LED_RED     = (led_state == 0) ? 1'b0 : 1'b1;
    assign LED_GREEN   = (led_state == 1) ? 1'b0 : 1'b1;

    // Snap-off section LEDs (active high)
    assign P2_1        = (led_state == 2) ? 1'b1 : 1'b0;
    assign P2_2        = (led_state == 3) ? 1'b1 : 1'b0;
    assign P2_3        = (led_state == 4) ? 1'b1 : 1'b0;
    assign P2_7        = (led_state == 5) ? 1'b1 : 1'b0;
    assign P2_8        = (led_state == 6) ? 1'b1 : 1'b0;

    // RGB LED channels (active low for common anode)
    assign LED_RGB0    = (led_state == 7) ? 1'b0 : 1'b1;  // Red
    assign LED_RGB1    = (led_state == 8) ? 1'b0 : 1'b1;  // Green
    assign LED_RGB2    = (led_state == 9) ? 1'b0 : 1'b1;  // Blue

    // State 10: All LEDs off (blank state before cycling back)
    // This is implicitly handled by the above assignments

endmodule
