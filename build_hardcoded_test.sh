#!/bin/bash
set -e

echo "=== FPGA Build Script: Hardcoded XOR Cipher Test ==="
echo "Testing encrypted 'CAT' (0x9D 0xEC 0xEA) → Decrypt → Validate"
echo ""

echo "Step 1: Synthesizing design with Yosys..."
yosys -p "synth_ice40 -top top_test -json top_test.json" top_test_hardcoded.v xor_cipher.v grammar_fsm.v

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
echo "Expected behavior:"
echo "  - Activity LED (LEDR_N) toggles every ~1.4 seconds"
echo "  - GREEN LED should light up after 3 bytes (encrypted CAT decrypted successfully)"
echo "  - RED LED should stay off (no reject)"
echo ""
echo "To program the FPGA, run:"
echo "  iceprog top_test.bin"
