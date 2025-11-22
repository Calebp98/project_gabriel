#!/bin/bash
set -e

echo "=== Legitimate User Build Script ==="
echo ""

echo "Step 1: Checking Python 3..."
if ! command -v python3 &> /dev/null; then
    echo "✗ Error: Python 3 is not installed"
    exit 1
fi
echo "✓ Python 3 found: $(python3 --version)"

echo ""
echo "Step 2: Checking dependencies..."

# Check for pyserial
if python3 -c "import serial" 2>/dev/null; then
    echo "✓ pyserial is installed"
else
    echo "✗ pyserial is not installed"
    echo ""
    echo "To install pyserial, run:"
    echo "  pip3 install pyserial"
    exit 1
fi

echo ""
echo "Step 3: Making send_encrypted.py executable..."
chmod +x send_encrypted.py
echo "✓ Script is now executable"

echo ""
echo "=== Build Complete! ==="
echo ""
echo "To run the script:"
echo "  # Interactive mode"
echo "  ./send_encrypted.py -p /dev/ttyACM0 -i"
echo ""
echo "  # Send specific message"
echo "  ./send_encrypted.py -p /dev/ttyACM0 -m \"CAT\""
echo ""
echo "  # Show help"
echo "  ./send_encrypted.py --help"
echo ""
