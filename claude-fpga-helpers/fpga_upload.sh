#!/bin/bash
# fpga_upload.sh - Upload bitstream to iCEBreaker FPGA
# Usage: fpga_upload.sh <bitstream.bin>

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing bitstream file${NC}"
    echo "Usage: $0 <bitstream.bin>"
    echo "Example: $0 claude-output.bin"
    exit 1
fi

BITSTREAM_FILE="$1"

# Convert to absolute path
BITSTREAM_FILE=$(realpath "$BITSTREAM_FILE")

# Check if bitstream exists
if [ ! -f "$BITSTREAM_FILE" ]; then
    echo -e "${RED}Error: Bitstream file not found: $BITSTREAM_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}=== FPGA Upload ===${NC}"
echo "Bitstream: $BITSTREAM_FILE"
echo ""

# Upload with iceprog
echo -e "${YELLOW}Uploading to iCEBreaker FPGA...${NC}"
iceprog "$BITSTREAM_FILE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Upload failed${NC}"
    echo "Troubleshooting:"
    echo "  - Is the iCEBreaker connected via USB?"
    echo "  - Do you have permission to access USB devices?"
    echo "  - Try: sudo iceprog $BITSTREAM_FILE"
    exit 1
fi

echo -e "${GREEN}✓ Upload complete!${NC}"
echo "Your FPGA is now programmed and running."
