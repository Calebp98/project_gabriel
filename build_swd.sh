#!/bin/bash
set -e

echo "=== FPGA Build Script: SWD Passthrough Test ==="
echo ""

echo "Step 1: Synthesizing design with Yosys..."
yosys -p "synth_ice40 -top swd_passthrough_test -json swd_passthrough.json" swd_passthrough_test.v

echo ""
echo "Step 2: Place and route with nextpnr..."
nextpnr-ice40 --up5k --package sg48 --json swd_passthrough.json --pcf swd_passthrough.pcf --asc swd_passthrough.asc

echo ""
echo "Step 3: Generating bitstream with icepack..."
icepack swd_passthrough.asc swd_passthrough.bin

echo ""
echo "=== Build Complete! ==="
echo "Bitstream: swd_passthrough.bin"
echo ""
echo "To program the FPGA, run:"
echo "  iceprog swd_passthrough.bin"
echo ""
echo "Pin Connections:"
echo "  Picoprobe (PMOD 1A):"
echo "    GP2 (SWCLK) → Pin 4"
echo "    GP3 (SWDIO) → Pin 2"
echo "    GND         → GND"
echo ""
echo "  Target Pico (PMOD 1B):"
echo "    SWCLK ← Pin 43"
echo "    SWDIO ← Pin 38"
echo "    GND   ← GND"
echo ""
echo "  Control:"
echo "    BTN1 (Pin 10) - Press to enable passthrough"
echo "    Red LED (Pin 11) - Shows when enabled"
echo ""
