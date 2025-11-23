#!/bin/bash
#
# build_and_flash.sh
#
# Builds the blink project and flashes it via authenticated SWD
#
# Usage:
#   ./build_and_flash.sh [serial_port]
#
# Example:
#   ./build_and_flash.sh /dev/tty.usbmodem1302
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERIAL_PORT="${1:-/dev/tty.usbmodem1302}"

echo -e "${BLUE}=== Building blink project ===${NC}"
cd blink/build
make -j4
cd ../..

echo -e "\n${BLUE}=== Flashing to target Pico ===${NC}"
python3 flash_authenticated.py blink/build/blink.elf "$SERIAL_PORT"

echo -e "\n${GREEN}✓ Done!${NC}"
