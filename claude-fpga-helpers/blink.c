/**
* Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
*
* SPDX-License-Identifier: BSD-3-Clause
*/


#include "pico/stdlib.h"


// Pico W devices use a GPIO on the WIFI chip for the LED,
// so when building for Pico W, CYW43_WL_GPIO_LED_PIN will be defined
#ifdef CYW43_WL_GPIO_LED_PIN
#include "pico/cyw43_arch.h"
#endif


#ifndef LED_DELAY_MS
#define LED_DELAY_MS 2000
#endif


// Perform initialisation
int pico_led_init(void) {
   // Initialize pin 16 for external LED
   gpio_init(16);
   gpio_set_dir(16, GPIO_OUT);


#if defined(PICO_DEFAULT_LED_PIN)
   // A device like Pico that uses a GPIO for the LED will define PICO_DEFAULT_LED_PIN
   // so we can use normal GPIO functionality to turn the led on and off
   gpio_init(PICO_DEFAULT_LED_PIN);
   gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
   return PICO_OK;
#elif defined(CYW43_WL_GPIO_LED_PI3N)
   // For Pico W devices we need to initialise the driver etc
   return cyw43_arch_init();
#endif
}


// Turn the led on or off
void pico_set_led(bool led_on) {
   // Set pin 16 to match internal LED
   gpio_put(16, led_on);


#if defined(PICO_DEFAULT_LED_PIN)
   // Just set the GPIO on or off
   gpio_put(PICO_DEFAULT_LED_PIN, led_on);
#elif defined(CYW43_WL_GPIO_LED_PIN)
   // Ask the wifi "driver" to set the GPIO on or off
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, led_on);
#endif
}


int main() {
   int rc = pico_led_init();
   hard_assert(rc == PICO_OK);
   while (true) {
       pico_set_led(true);
       sleep_ms(LED_DELAY_MS);
       pico_set_led(false);
       sleep_ms(LED_DELAY_MS);
   }
}



