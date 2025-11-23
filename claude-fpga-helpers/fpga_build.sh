#!/bin/bash
# fpga_build.sh - Build FPGA bitstream for iCEBreaker
# Usage: fpga_build.sh <top_module.v> <constraints.pcf> [output_name]

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

# Convert to absolute paths
VERILOG_FILE=$(realpath "$VERILOG_FILE")
PCF_FILE=$(realpath "$PCF_FILE")

# Check if input files exist
if [ ! -f "$VERILOG_FILE" ]; then
    echo -e "${RED}Error: Verilog file not found: $VERILOG_FILE${NC}"
    exit 1
fi

if [ ! -f "$PCF_FILE" ]; then
    echo -e "${RED}Error: PCF file not found: $PCF_FILE${NC}"
    exit 1
fi

# Extract base name and directory
VERILOG_DIR=$(dirname "$VERILOG_FILE")
VERILOG_BASE=$(basename "$VERILOG_FILE" .v)

# Intermediate files (will be created in the same directory as the Verilog file)
JSON_FILE="$VERILOG_DIR/claude-$OUTPUT_NAME.json"
ASC_FILE="$VERILOG_DIR/claude-$OUTPUT_NAME.asc"
BIN_FILE="$VERILOG_DIR/claude-$OUTPUT_NAME.bin"

echo -e "${GREEN}=== FPGA Build Process ===${NC}"
echo "Verilog: $VERILOG_FILE"
echo "PCF: $PCF_FILE"
echo "Output: $BIN_FILE"
echo ""

# Step 1: Synthesis with Yosys
echo -e "${YELLOW}[1/3] Running Yosys synthesis...${NC}"
yosys -p "synth_ice40 -top top -json $JSON_FILE" "$VERILOG_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Yosys synthesis failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Synthesis complete${NC}"
echo ""

# Step 2: Place and Route with nextpnr
echo -e "${YELLOW}[2/3] Running nextpnr place and route...${NC}"
nextpnr-ice40 --up5k --package sg48 --json "$JSON_FILE" --pcf "$PCF_FILE" --asc "$ASC_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Place and route failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Place and route complete${NC}"
echo ""

# Step 3: Generate bitstream with icepack
echo -e "${YELLOW}[3/3] Generating bitstream...${NC}"
icepack "$ASC_FILE" "$BIN_FILE"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Bitstream generation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Bitstream generated${NC}"
echo ""

# Success message
echo -e "${GREEN}=== Build Complete ===${NC}"
echo -e "Bitstream: ${GREEN}$BIN_FILE${NC}"
echo ""
echo "To upload to FPGA, run:"
echo "  $(dirname "$0")/fpga_upload.sh $BIN_FILE"
