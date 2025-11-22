#!/bin/bash
set -e

# Add OSS CAD Suite to PATH
export PATH="$HOME/oss-cad-suite/bin:$PATH"

echo "=== FPGA Build Script: UART RX + DNP3 Link Layer ==="
echo ""

echo "Step 1: Synthesizing design with Yosys..."
yosys -p "synth_ice40 -top top_dnp3 -json top_dnp3.json" top_dnp3.v uart_rx.v dnp3_link_layer.v crc16_dnp.v

echo ""
echo "Step 2: Place and route with nextpnr..."
nextpnr-ice40 --up5k --package sg48 --json top_dnp3.json --pcf icebreaker.pcf --asc top_dnp3.asc

echo ""
echo "Step 3: Generating bitstream with icepack..."
icepack top_dnp3.asc top_dnp3.bin

echo ""
echo "=== Build Complete! ==="
echo "Bitstream: top_dnp3.bin"
echo ""
echo "To program the FPGA, run:"
echo "  ./build_dnp3.sh program"
echo ""
echo "Or manually with:"
echo "  iceprog top_dnp3.bin"

# Optional: program the FPGA if "program" argument is given
if [ "$1" = "program" ]; then
    echo ""
    echo "Programming FPGA..."
    iceprog top_dnp3.bin
fi
