module top(
    input CLK,              // 12 MHz clock
    output LED_RED,         // Red LED (active low)
    output LED_GREEN        // Green LED (active low)
);

    // Counter for timing (6M counts = 0.5 seconds at 12 MHz)
    reg [22:0] counter = 0;

    // State machine for LED sequence
    // State 0: All off
    // State 1: Red on
    // State 2: Green on
    // State 3: All off (before cycling back)
    reg [1:0] state = 0;

    // LED control registers (active low: 1=off, 0=on)
    reg led_red = 1;
    reg led_green = 1;

    // Clock divider and state machine
    always @(posedge CLK) begin
        if (counter == 23'd5_999_999) begin
            counter <= 0;

            // Advance state and update LEDs
            case (state)
                2'd0: begin  // All off -> Red on
                    led_red <= 0;    // Turn red ON
                    led_green <= 1;  // Keep green OFF
                    state <= 2'd1;
                end

                2'd1: begin  // Red on -> Green on
                    led_red <= 1;    // Turn red OFF
                    led_green <= 0;  // Turn green ON
                    state <= 2'd2;
                end

                2'd2: begin  // Green on -> All off
                    led_red <= 1;    // Keep red OFF
                    led_green <= 1;  // Turn green OFF
                    state <= 2'd3;
                end

                2'd3: begin  // All off -> cycle back to state 0
                    led_red <= 1;    // Keep red OFF
                    led_green <= 1;  // Keep green OFF
                    state <= 2'd0;
                end
            endcase
        end else begin
            counter <= counter + 1;
        end
    end

    // Output assignments
    assign LED_RED = led_red;
    assign LED_GREEN = led_green;

endmodule
