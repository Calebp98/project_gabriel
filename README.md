# Project Gabriel

A hardware-based input filter implemented on an iCEBreaker FPGA that validates serial data against a grammar pattern using a finite state machine.

## Overview

This project implements a UART receiver that accepts serial data at 115200 baud and validates it against the pattern "CAT" using a hardware FSM. The system provides visual feedback via LEDs to indicate whether incoming data matches the expected pattern.

The design consists of three main components: a UART receiver module that handles serial communication, a grammar-based FSM that validates incoming bytes against the target pattern, and LED outputs that show the current state. When the correct sequence is received, the green LED lights up. Invalid sequences trigger the red LED.

## Hardware Requirements

- iCEBreaker FPGA board (Lattice iCE40UP5K)
- Raspberry Pi Pico
- 3 jumper wires
- USB cables for both boards

## Project Structure

- `uart_rx.v` - UART receiver module (115200 baud, 8N1)
- `grammar_fsm.v` - Finite state machine for pattern validation
- `top_test.v` - Top-level module integrating UART and FSM
- `icebreaker.pcf` - Pin constraints for iCEBreaker board
- `build.sh` - Build script using yosys, nextpnr, and icepack
- `pico_uart_test/` - Arduino test code for Raspberry Pi Pico

## Building

The project uses the open-source iCE40 toolchain. Run the build script to synthesize, place and route, and generate the bitstream:

```
./build.sh
```

Program the FPGA with:

```
iceprog top_test.bin
```

## Connections

- Pico GP0 (UART TX) to FPGA pin 3 (RX)
- Pico GND to FPGA GND
- FPGA LED_GREEN (pin 37, active-low) - accept state
- FPGA LED_RED (pin 11, active-low) - reject state
- FPGA LED_RX (pin 26, active-high) - data received indicator
