cmake_minimum_required(VERSION 3.13)

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(uart_test C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(uart_test
    uart_test.c
)

target_link_libraries(uart_test
    pico_stdlib
    hardware_uart
)

pico_add_extra_outputs(uart_test)

# Enable USB output for debugging (optional)
pico_enable_stdio_usb(uart_test 1)
pico_enable_stdio_uart(uart_test 0)
