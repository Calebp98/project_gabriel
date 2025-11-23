#!/bin/bash
# fpga_full.sh - Build and upload FPGA bitstream in one step
# Usage: fpga_full.sh <top_module.v> <constraints.pcf> [output_name]

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <verilog_file> <pcf_file> [output_name]"
    echo "Example: $0 top.v icebreaker.pcf my_design"
    exit 1
fi

VERILOG_FILE="$1"
PCF_FILE="$2"
OUTPUT_NAME="${3:-output}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${GREEN}=== Full FPGA Build and Upload ===${NC}"
echo ""

# Step 1: Build
echo -e "${YELLOW}Step 1: Building bitstream...${NC}"
"$SCRIPT_DIR/fpga_build.sh" "$VERILOG_FILE" "$PCF_FILE" "$OUTPUT_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed, aborting upload${NC}"
    exit 1
fi

# Determine the bitstream path
VERILOG_DIR=$(dirname "$(realpath "$VERILOG_FILE")")
BITSTREAM="$VERILOG_DIR/claude-$OUTPUT_NAME.bin"

echo ""
echo -e "${YELLOW}Step 2: Uploading to FPGA...${NC}"

# Step 2: Upload
"$SCRIPT_DIR/fpga_upload.sh" "$BITSTREAM"

if [ $? -ne 0 ]; then
    echo -e "${RED}Upload failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== All Done! ===${NC}"
echo "Your FPGA is programmed and running."
