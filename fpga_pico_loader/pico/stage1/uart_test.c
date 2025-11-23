/**
 * Stage 1: Basic UART Reception Test
 *
 * Receives bytes on UART0 (GP0) and toggles LED for each byte received.
 * This verifies UART communication works before involving the FPGA.
 *
 * Test: Send bytes via serial terminal at 115200 baud
 * Expected: LED toggles with each received byte
 */

#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_RX_PIN 0
#define LED_PIN 25

int main() {
    // Initialize LED
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Initialize UART
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

    // Blink 3 times to show we're ready
    for (int i = 0; i < 3; i++) {
        gpio_put(LED_PIN, 1);
        sleep_ms(100);
        gpio_put(LED_PIN, 0);
        sleep_ms(100);
    }

    bool led_state = false;

    while (1) {
        if (uart_is_readable(UART_ID)) {
            uint8_t byte = uart_getc(UART_ID);

            // Toggle LED for each byte received
            led_state = !led_state;
            gpio_put(LED_PIN, led_state);

            // Optional: Echo back the byte for debugging
            uart_putc(UART_ID, byte);
        }
    }

    return 0;
}
