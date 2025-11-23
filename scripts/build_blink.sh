#!/bin/bash
#
# build_blink.sh
#
# Builds the blink project for Raspberry Pi Pico
#
# Usage:
#   ./scripts/build_blink.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building blink project ===${NC}"
cd blink

# Create build directory and configure if needed
if [ ! -f build/Makefile ]; then
    echo -e "${YELLOW}Build not configured. Running cmake...${NC}"
    mkdir -p build
    cd build
    cmake ..
    cd ..
fi

cd build
make -j4
cd ../..

echo -e "${GREEN}✓ Build complete!${NC}"
echo -e "Output: blink/build/blink.elf"
