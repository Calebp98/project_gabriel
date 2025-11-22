#!/bin/bash
set -e

# Add OSS CAD Suite to PATH
export PATH="$HOME/oss-cad-suite/bin:$PATH"

echo "=== FPGA Build Script: UART RX + Grammar FSM ==="
echo ""

echo "Step 1: Synthesizing design with Yosys..."
yosys -p "synth_ice40 -top top_test -json top_test.json" top_test.v uart_rx.v grammar_fsm.v

echo ""
echo "Step 2: Place and route with nextpnr..."
nextpnr-ice40 --up5k --package sg48 --json top_test.json --pcf icebreaker.pcf --asc top_test.asc

echo ""
echo "Step 3: Generating bitstream with icepack..."
icepack top_test.asc top_test.bin

echo ""
echo "=== Build Complete! ==="
echo "Bitstream: top_test.bin"
echo ""
echo "To program the FPGA, run:"
echo "  iceprog top_test.bin"
