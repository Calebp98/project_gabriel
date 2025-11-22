#!/bin/bash
#
# flash_with_picoprobe.sh
#
# Easy script to flash firmware to a Raspberry Pi Pico via PicoProbe
#
# Usage:
#   ./flash_with_picoprobe.sh firmware.elf
#   ./flash_with_picoprobe.sh firmware.bin 0x10000000
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if firmware file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No firmware file specified${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 firmware.elf"
    echo "  $0 firmware.bin 0x10000000"
    echo ""
    echo "Examples:"
    echo "  $0 build/my_sketch.elf"
    echo "  $0 build/firmware.bin 0x10000000"
    exit 1
fi

FIRMWARE="$1"

# Check if file exists
if [ ! -f "$FIRMWARE" ]; then
    echo -e "${RED}Error: File not found: $FIRMWARE${NC}"
    exit 1
fi

# Check if OpenOCD is installed
if ! command -v openocd &> /dev/null; then
    echo -e "${RED}Error: OpenOCD is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  macOS:  brew install openocd"
    echo "  Linux:  sudo apt install openocd"
    exit 1
fi

# Detect file type
EXT="${FIRMWARE##*.}"
FLASH_CMD=""

if [ "$EXT" == "elf" ]; then
    echo -e "${GREEN}Flashing ELF file: $FIRMWARE${NC}"
    FLASH_CMD="program $FIRMWARE verify reset exit"
elif [ "$EXT" == "bin" ]; then
    # For binary files, need flash address (default to 0x10000000 if not provided)
    FLASH_ADDR="${2:-0x10000000}"
    echo -e "${GREEN}Flashing BIN file: $FIRMWARE at address $FLASH_ADDR${NC}"
    FLASH_CMD="program $FIRMWARE $FLASH_ADDR verify reset exit"
else
    echo -e "${YELLOW}Warning: Unknown file extension .$EXT${NC}"
    echo "Attempting to flash as ELF..."
    FLASH_CMD="program $FIRMWARE verify reset exit"
fi

# Run OpenOCD with PicoProbe config
echo ""
echo "Starting OpenOCD..."
echo "----------------------------------------"

openocd \
    -f interface/cmsis-dap.cfg \
    -f target/rp2040.cfg \
    -c "adapter speed 5000" \
    -c "$FLASH_CMD"

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Programming successful!${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Programming failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Is PicoProbe connected via USB?"
    echo "  2. Are SWCLK, SWDIO, and GND wired correctly?"
    echo "  3. Is the target Pico powered on?"
    echo "  4. Try: openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c init -c targets -c exit"
    echo ""
    echo "See PICOPROBE_SETUP.md for detailed troubleshooting."
    exit 1
fi
