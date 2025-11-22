#!/bin/bash

# Add OSS CAD Suite to PATH
export PATH="$HOME/oss-cad-suite/bin:$PATH"

# Check if a bitstream file was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <bitstream.bin>"
    echo ""
    echo "Available bitstreams:"
    ls -1 *.bin 2>/dev/null || echo "  No .bin files found"
    exit 1
fi

# Program the FPGA
echo "Programming FPGA with $1..."
iceprog "$1"
