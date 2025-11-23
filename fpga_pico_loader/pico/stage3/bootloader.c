/**
 * Stage 3: Pico Bootloader - RAM Loading
 *
 * Receives exactly 256 bytes via UART into RAM at 0x20001000
 * LED feedback:
 *   - Blinks rapidly while waiting for data
 *   - Solid ON when receiving
 *   - Blinks slowly when complete (success)
 *
 * Test: Use FPGA Stage 5 or send 256 bytes via serial terminal
 */

#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_RX_PIN 0
#define LED_PIN 25

#define PROGRAM_SIZE 256
#define RAM_LOAD_ADDRESS 0x20001000

int main() {
    // Initialize LED
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Initialize UART
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

    // Signal ready: 5 fast blinks
    for (int i = 0; i < 5; i++) {
        gpio_put(LED_PIN, 1);
        sleep_ms(50);
        gpio_put(LED_PIN, 0);
        sleep_ms(50);
    }

    sleep_ms(200);

    // LED ON while receiving
    gpio_put(LED_PIN, 1);

    // Receive 256 bytes into RAM
    uint8_t *program_memory = (uint8_t *)RAM_LOAD_ADDRESS;

    for (int i = 0; i < PROGRAM_SIZE; i++) {
        // Wait for byte to arrive
        while (!uart_is_readable(UART_ID)) {
            tight_loop_contents();
        }

        // Store byte in RAM
        program_memory[i] = uart_getc(UART_ID);
    }

    // Success: slow blinking
    while (1) {
        gpio_put(LED_PIN, 1);
        sleep_ms(500);
        gpio_put(LED_PIN, 0);
        sleep_ms(500);
    }

    return 0;
}
