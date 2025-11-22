// Simplified top module - sends "HELLO\n" every 1 second

module top (
    input  wire CLK,         // 12 MHz clock on iCEbreaker
    output wire TX,          // UART TX to picoprobe
    output wire LED1         // Debug LED
);

    // Timer for 1 second interval: 12,000,000 clock cycles at 12 MHz
    localparam SECOND_CYCLES = 26'd12_000_000;

    // UART signals
    reg [7:0] tx_data;
    reg tx_data_valid;
    wire tx_busy;

    // State machine
    reg [2:0] send_index = 0;
    reg [25:0] timer = 0;
    reg sending = 0;
    reg tx_busy_prev = 0;

    // UART transmitter instance
    uart_tx #(
        .CLOCK_FREQ(12_000_000),
        .BAUD_RATE(115200)
    ) uart_transmitter (
        .clk(CLK),
        .rst(1'b0),
        .data(tx_data),
        .data_valid(tx_data_valid),
        .tx(TX),
        .busy(tx_busy)
    );

    // Main logic
    always @(posedge CLK) begin
        tx_data_valid <= 0;  // Default: no data to send
        tx_busy_prev <= tx_busy;

        if (!sending) begin
            // Increment timer when not sending
            timer <= timer + 1;

            // Start sending when 1 second has elapsed
            if (timer >= SECOND_CYCLES) begin
                timer <= 0;
                send_index <= 0;
                sending <= 1;
            end
        end else begin
            // Sending message "HELLO\n"
            // Detect falling edge of tx_busy (transmission complete)
            if (tx_busy_prev && !tx_busy) begin
                send_index <= send_index + 1;
            end

            // Send character when not busy and haven't just sent
            if (!tx_busy && !tx_busy_prev) begin
                if (send_index < 6) begin
                    case (send_index)
                        0: tx_data <= 8'h48;  // 'H'
                        1: tx_data <= 8'h45;  // 'E'
                        2: tx_data <= 8'h4C;  // 'L'
                        3: tx_data <= 8'h4C;  // 'L'
                        4: tx_data <= 8'h4F;  // 'O'
                        5: tx_data <= 8'h0A;  // '\n'
                    endcase
                    tx_data_valid <= 1;
                end else begin
                    // Done sending
                    sending <= 0;
                end
            end
        end
    end

    // Blink LED with the timer (heartbeat)
    assign LED1 = timer[23];  // Blink at ~1.4 Hz

endmodule
