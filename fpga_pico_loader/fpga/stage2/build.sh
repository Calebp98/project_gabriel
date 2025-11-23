#!/bin/bash

set -e

echo "Building FPGA Stage 2: UART Transmitter Test"

# Synthesize
echo "Step 1: Synthesis..."
yosys -p "synth_ice40 -top top -json top.json" top.v uart_tx.v

# Place and route
echo "Step 2: Place and route..."
nextpnr-ice40 --up5k --package sg48 --json top.json --pcf icebreaker.pcf --asc top.asc

# Generate bitstream
echo "Step 3: Generate bitstream..."
icepack top.asc top.bin

echo "Build complete! Bitstream: top.bin"
echo ""
echo "To program FPGA: iceprog top.bin"
