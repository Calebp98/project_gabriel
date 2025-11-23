#!/bin/bash
#
# flash_blink_to_target_pico.sh
#
# Builds the blink project and flashes it via authenticated SWD
#
# Usage:
#   ./scripts/flash_blink_to_target_pico.sh [serial_port]
#
# Example:
#   ./scripts/flash_blink_to_target_pico.sh /dev/tty.usbmodem1302
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

SERIAL_PORT="${1:-/dev/tty.usbmodem1302}"

# Build the project
"$SCRIPT_DIR/build_blink.sh"

echo -e "\n${BLUE}=== Flashing to target Pico ===${NC}"
cd "$PROJECT_ROOT"
python3 flash_authenticated.py blink/build/blink.elf "$SERIAL_PORT"

echo -e "\n${GREEN}✓ Done!${NC}"
