#!/bin/bash
#
# build_blink.sh
#
# Builds the blink project for Raspberry Pi Pico
#
# Usage:
#   ./scripts/build_blink.sh [--clean]
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
if [ "$1" == "--clean" ]; then
    CLEAN=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building blink project ===${NC}"
cd "$PROJECT_ROOT/blink"

# Create build directory and configure if needed
if [ ! -f build/Makefile ]; then
    echo -e "${YELLOW}Build not configured. Running cmake...${NC}"
    mkdir -p build
    cd build
    cmake ..
    cd ..
fi

cd build

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    make clean
fi

make -j4

echo -e "${GREEN}✓ Build complete!${NC}"
echo -e "Output: blink/build/blink.elf"
