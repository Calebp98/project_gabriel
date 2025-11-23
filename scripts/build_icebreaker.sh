#!/bin/bash
#
# build_icebreaker.sh
#
# Builds the iCEbreaker FPGA project (UART control with authentication)
#
# Usage:
#   ./scripts/build_icebreaker.sh [--clean]
#
# Options:
#   --clean    Run 'make clean' before building
#

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
CLEAN=false
for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN=true
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building iCEbreaker FPGA project ===${NC}"
cd "$PROJECT_ROOT/icebreaker"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    make clean
fi

# Build the project
echo -e "${BLUE}Running synthesis and place & route...${NC}"
make

echo -e "${GREEN}✓ Build complete!${NC}"
echo -e "Output: icebreaker/gabriel.bin"
