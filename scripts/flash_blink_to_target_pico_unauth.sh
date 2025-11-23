#!/bin/bash
#
# flash_blink_to_target_pico_unauth.sh
#
# Attempts to flash the blink project via unauthenticated SWD (should fail)
#
# Usage:
#   ./scripts/flash_blink_to_target_pico_unauth.sh
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

ELF_FILE="$PROJECT_ROOT/blink/build/blink.elf"

echo -e "\n${BLUE}=== Attempting to flash target Pico WITHOUT authentication ===${NC}"
echo -e "${YELLOW}Note: This should fail because the FPGA blocks unauthenticated access${NC}\n"

# Run OpenOCD directly (no authentication, control pin stays at 3.3V)
openocd \
    -f interface/cmsis-dap.cfg \
    -f target/rp2040.cfg \
    -c "adapter speed 5000" \
    -c "program $ELF_FILE verify reset exit"

echo -e "\n${GREEN}✓ Done!${NC}"
