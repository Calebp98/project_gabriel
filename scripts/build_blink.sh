#!/bin/bash
#
# build_blink.sh
#
# Builds the blink project for Raspberry Pi Pico
#
# Usage:
#   ./scripts/build_blink.sh [--clean] [--period=MS]
#
# Options:
#   --clean       Run 'make clean' before building
#   --period=MS   Set LED blink period in milliseconds (default: 200)
#
# Examples:
#   ./scripts/build_blink.sh --period=500     # 500ms blink period
#   ./scripts/build_blink.sh --clean --period=1000  # Clean build with 1s period
#

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
CLEAN=false
PERIOD=""
for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN=true
            ;;
        --period=*)
            PERIOD="${arg#*=}"
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Building blink project ===${NC}"
cd "$PROJECT_ROOT/blink"

# Prepare CMake flags
CMAKE_FLAGS=""
if [ -n "$PERIOD" ]; then
    echo -e "${BLUE}Setting blink period to ${PERIOD}ms${NC}"
    CMAKE_FLAGS="-DLED_DELAY_MS=$PERIOD"
fi

# Create build directory and configure if needed (or reconfigure if period changed)
if [ ! -f build/Makefile ] || [ -n "$PERIOD" ]; then
    if [ -n "$PERIOD" ]; then
        echo -e "${YELLOW}Reconfiguring with custom period...${NC}"
    else
        echo -e "${YELLOW}Build not configured. Running cmake...${NC}"
    fi
    mkdir -p build
    cd build
    cmake $CMAKE_FLAGS ..
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
