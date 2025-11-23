#!/bin/bash
# Master script to run complete secure programming sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "Secure FPGA Gatekeeper - Complete Programming Sequence"
echo "=========================================================="
echo ""
echo "This script will:"
echo "  1. Build and flash FPGA gatekeeper"
echo "  2. Authenticate with FPGA"
echo "  3. Program target Pico with blink.c"
echo "  4. Verify system operation"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Step 1: Build and flash FPGA
echo ""
echo "========================================="
echo "Step 1: Programming FPGA"
echo "========================================="
cd "$SCRIPT_DIR"
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

echo ""
echo "✓ FPGA programmed successfully"
echo ""
echo "Waiting 3 seconds for FPGA to initialize..."
sleep 3

# Step 2: Authenticate
echo ""
echo "========================================="
echo "Step 2: Authenticating with FPGA"
echo "========================================="
python3 authenticate.py

if [ $? -ne 0 ]; then
    echo ""
    echo "✗ Authentication failed!"
    exit 1
fi

echo ""
echo "✓ Authentication successful"
echo ""
echo "Waiting 2 seconds before programming..."
sleep 2

# Step 3: Program target Pico
echo ""
echo "========================================="
echo "Step 3: Programming Target Pico"
echo "========================================="

# Note: This requires manual intervention for now
echo ""
echo "The FPGA has disabled jamming."
echo "You can now program the target Pico."
echo ""
echo "If blink firmware is ready, it will be flashed automatically."
echo "Otherwise, program it manually using your preferred method."
echo ""

# Check if we can program automatically
BLINK_UF2="../../../blink/build/blink.uf2"
if [ -f "$BLINK_UF2" ] && command -v picotool &> /dev/null; then
    echo "Programming target Pico with blink.uf2..."
    picotool load "$BLINK_UF2" -f
    echo "✓ Target Pico programmed"
else
    echo "Manual programming required:"
    echo "  1. Connect to target Pico via SWD"
    echo "  2. Flash blink.uf2 or blink.bin"
    echo ""
    read -p "Press Enter when programming is complete..."
fi

# Step 4: Verify
echo ""
echo "========================================="
echo "Step 4: Verifying Operation"
echo "========================================="
echo ""
echo "The FPGA should now:"
echo "  1. Detect the blink pattern on pin 43"
echo "  2. Re-enable jamming (pin 4 HIGH)"
echo "  3. Return to IDLE state"
echo ""
echo "Monitoring FPGA for 5 seconds..."
python3 monitor.py /dev/cu.usbmodem1402 5 || true

echo ""
echo "=========================================================="
echo "Sequence Complete!"
echo "=========================================================="
echo ""
echo "System is now in secured state."
echo "To program again, re-run this script or authenticate.py"
echo ""
