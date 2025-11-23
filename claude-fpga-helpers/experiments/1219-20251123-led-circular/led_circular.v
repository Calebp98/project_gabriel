module top(
    input CLK,              // 12 MHz clock
    output LED_RED,         // Red LED (active low)
    output LED_GREEN        // Green LED (active low)
);
    // Counter for timing (0.5 second intervals at 12 MHz)
    reg [22:0] counter = 0;
    localparam HALF_SECOND = 23'd5_999_999;

    // State machine for LED pattern
    reg [1:0] state = 0;

    // LED states (remember: active low, 0 = ON, 1 = OFF)
    reg led_red = 1;
    reg led_green = 1;

    always @(posedge CLK) begin
        if (counter == HALF_SECOND) begin
            counter <= 0;
            state <= state + 1;  // Automatically wraps from 3 to 0

            // Update LED pattern based on state (circular pattern)
            case (state)
                2'd0: begin  // All off
                    led_red <= 1;
                    led_green <= 1;
                end
                2'd1: begin  // Red only
                    led_red <= 0;
                    led_green <= 1;
                end
                2'd2: begin  // Both on
                    led_red <= 0;
                    led_green <= 0;
                end
                2'd3: begin  // Green only
                    led_red <= 1;
                    led_green <= 0;
                end
            endcase
        end else begin
            counter <= counter + 1;
        end
    end

    assign LED_RED = led_red;
    assign LED_GREEN = led_green;
endmodule
