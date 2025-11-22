#!/bin/bash

# Status checker for Red Team vs Blue Team exercise

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Red vs Blue - Current Status          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

# Current turn
if [ -f shared/turn.txt ]; then
    turn=$(cat shared/turn.txt)
    if [ "$turn" = "RED" ]; then
        echo -e "Current Turn: ${RED}RED TEAM 🔴${NC}"
    else
        echo -e "Current Turn: ${BLUE}BLUE TEAM 🔵${NC}"
    fi
else
    echo "Current Turn: UNKNOWN"
fi

# Current round
if [ -f shared/round.txt ]; then
    round=$(cat shared/round.txt)
    echo -e "Current Round: ${YELLOW}$round${NC}"
else
    echo "Current Round: UNKNOWN"
fi

echo ""

# Red team status
echo -e "${RED}RED TEAM:${NC}"
if [ -f red-team/done.txt ]; then
    echo "  ✓ Turn complete"
    if [ -f red-team/findings.md ]; then
        vuln_count=$(grep -c "^##" red-team/findings.md 2>/dev/null || echo "?")
        echo "  → Findings: $vuln_count vulnerabilities reported"
    fi
else
    echo "  ⏳ Working..."
fi

if [ -f red-team/findings.md ]; then
    size=$(wc -l < red-team/findings.md)
    echo "  → findings.md: $size lines"
fi

echo ""

# Blue team status
echo -e "${BLUE}BLUE TEAM:${NC}"
if [ -f blue-team/done.txt ]; then
    echo "  ✓ Turn complete"
    if [ -f blue-team/patches.md ]; then
        patch_count=$(grep -c "^##" blue-team/patches.md 2>/dev/null || echo "?")
        echo "  → Patches: $patch_count fixes applied"
    fi
else
    echo "  ⏳ Working..."
fi

if [ -f blue-team/patches.md ]; then
    size=$(wc -l < blue-team/patches.md)
    echo "  → patches.md: $size lines"
fi

echo ""

# Target file
echo -e "${YELLOW}TARGET FILE:${NC}"
if [ -f shared/target.v ]; then
    lines=$(wc -l < shared/target.v)
    size=$(ls -lh shared/target.v | awk '{print $5}')
    echo "  → shared/target.v: $lines lines, $size"
    modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" shared/target.v 2>/dev/null || stat -c "%y" shared/target.v 2>/dev/null | cut -d. -f1)
    echo "  → Last modified: $modified"
else
    echo "  ✗ Not found"
fi

echo ""

# Logs
echo -e "${GREEN}LOGS:${NC}"
if [ -d logs ]; then
    log_count=$(ls -1 logs/ 2>/dev/null | wc -l)
    echo "  → $log_count files in logs/"

    # Show latest logs
    latest=$(ls -t logs/ 2>/dev/null | head -3)
    if [ -n "$latest" ]; then
        echo "  → Latest:"
        echo "$latest" | while read file; do
            echo "     - $file"
        done
    fi
else
    echo "  → logs/ directory not found"
fi

echo ""

# Tmux session
echo -e "${BLUE}TMUX SESSION:${NC}"
if tmux has-session -t red-blue-security 2>/dev/null; then
    echo "  ✓ Session 'red-blue-security' is running"
    echo "  → Attach with: tmux attach -t red-blue-security"
else
    echo "  ✗ No active session"
fi

echo ""
