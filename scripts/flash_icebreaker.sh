#!/bin/bash
#
# flash_icebreaker.sh
#
# Flashes the iCEbreaker FPGA with the pre-built bitstream
#
# Usage:
#   ./scripts/flash_icebreaker.sh
#
# Note: Run ./scripts/build_icebreaker.sh first to build the bitstream
#

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if bitstream exists
if [ ! -f "$PROJECT_ROOT/icebreaker/uart_control.bin" ]; then
    echo -e "${RED}Error: Bitstream not found!${NC}"
    echo -e "${YELLOW}Run './scripts/build_icebreaker.sh' first to build the bitstream.${NC}"
    exit 1
fi

# Flash the FPGA
echo -e "${BLUE}=== Flashing iCEbreaker FPGA ===${NC}"
cd "$PROJECT_ROOT/icebreaker"
make prog

echo -e "${GREEN}✓ FPGA flashed successfully!${NC}"
