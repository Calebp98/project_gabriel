#!/bin/bash
# Flash the target Raspberry Pi Pico via Pico Probe SWD
# MUST be run after successful authentication (jamming disabled)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINK_DIR="$SCRIPT_DIR/../../../blink"
TARGET_UF2="$BLINK_DIR/build/blink.uf2"

echo "=================================================="
echo "Secure FPGA Gatekeeper - Target Pico Programming"
echo "=================================================="
echo ""

# Check if authentication has been performed
echo "[WARNING] This script assumes you have already authenticated!"
echo "          If you haven't run authenticate.py, the FPGA will block programming."
echo ""
read -p "Have you authenticated? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run authenticate.py first!"
    exit 1
fi

# Check if blink firmware exists
if [ ! -f "$TARGET_UF2" ]; then
    echo "Building blink firmware..."
    cd "$BLINK_DIR"
    mkdir -p build
    cd build
    cmake ..
    make
    cd "$SCRIPT_DIR"
fi

if [ ! -f "$TARGET_UF2" ]; then
    echo "ERROR: Blink firmware not found at $TARGET_UF2"
    echo "Please build it first using the build scripts."
    exit 1
fi

echo ""
echo "Target firmware: $TARGET_UF2"
echo ""

# Flash using openocd (standard Pico Probe method)
echo "Flashing target Pico via SWD..."
echo ""

# Using picotool (simpler if available)
if command -v picotool &> /dev/null; then
    echo "Using picotool..."
    picotool load "$TARGET_UF2" -f
    echo ""
    echo "✓ Programming complete!"
else
    echo "ERROR: picotool not found"
    echo "Please install picotool or use openocd manually"
    exit 1
fi

echo ""
echo "=================================================="
echo "Programming successful!"
echo "The FPGA should detect the blink pattern and"
echo "re-enable jamming automatically."
echo "=================================================="
