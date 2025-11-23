cmake_minimum_required(VERSION 3.13)

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(bootloader C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_executable(bootloader
    bootloader.c
)

target_link_libraries(bootloader
    pico_stdlib
    hardware_uart
)

pico_add_extra_outputs(bootloader)

# Enable USB output for debugging (optional)
pico_enable_stdio_usb(bootloader 1)
pico_enable_stdio_uart(bootloader 0)
