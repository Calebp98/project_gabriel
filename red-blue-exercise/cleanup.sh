#!/bin/bash

# Cleanup script for Red Team vs Blue Team exercise

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Red vs Blue - Cleanup                 ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}\n"

# Kill tmux sessions
echo -e "${GREEN}[CLEANUP]${NC} Checking tmux sessions..."

sessions_killed=0

if tmux has-session -t red-blue-security 2>/dev/null; then
    tmux kill-session -t red-blue-security
    echo "  ✓ Game session (red-blue-security) killed"
    sessions_killed=1
fi

if tmux has-session -t red-blue-monitor 2>/dev/null; then
    tmux kill-session -t red-blue-monitor
    echo "  ✓ Monitor session (red-blue-monitor) killed"
    sessions_killed=1
fi

if [ $sessions_killed -eq 0 ]; then
    echo "  → No tmux sessions to kill"
fi

echo ""

# Ask what to clean
echo -e "${YELLOW}What would you like to clean?${NC}"
echo "  1) Everything (reset to initial state)"
echo "  2) Just team working files (keep logs)"
echo "  3) Just logs (keep team files)"
echo "  4) Cancel"
echo ""
read -p "Choice [1-4]: " choice

case $choice in
    1)
        echo -e "\n${RED}[CLEANUP]${NC} Removing all generated files..."

        # Remove team files
        rm -f red-team/findings.md red-team/analysis.md red-team/done.txt red-team/prompt.txt
        rm -f blue-team/patches.md blue-team/changes.md blue-team/done.txt blue-team/prompt.txt

        # Remove shared state files (but keep target.v)
        rm -f shared/turn.txt shared/round.txt shared/game_state.json

        # Remove logs
        rm -rf logs/*

        echo "  ✓ All working files removed"
        echo "  ✓ All logs removed"
        echo "  ✓ Shared state reset"
        echo -e "  ${YELLOW}→${NC} shared/target.v preserved"
        ;;

    2)
        echo -e "\n${GREEN}[CLEANUP]${NC} Removing team working files..."

        # Remove team files
        rm -f red-team/findings.md red-team/analysis.md red-team/done.txt red-team/prompt.txt
        rm -f blue-team/patches.md blue-team/changes.md blue-team/done.txt blue-team/prompt.txt

        # Remove shared state files (but keep target.v)
        rm -f shared/turn.txt shared/round.txt shared/game_state.json

        echo "  ✓ Team files removed"
        echo "  ✓ Shared state reset"
        echo -e "  ${YELLOW}→${NC} Logs preserved"
        echo -e "  ${YELLOW}→${NC} shared/target.v preserved"
        ;;

    3)
        echo -e "\n${GREEN}[CLEANUP]${NC} Removing logs..."

        # Remove logs
        rm -rf logs/*

        echo "  ✓ Logs removed"
        echo -e "  ${YELLOW}→${NC} Team files preserved"
        echo -e "  ${YELLOW}→${NC} shared/target.v preserved"
        ;;

    4)
        echo -e "\n${YELLOW}[CLEANUP]${NC} Cancelled"
        exit 0
        ;;

    *)
        echo -e "\n${RED}[ERROR]${NC} Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}[CLEANUP]${NC} Cleanup complete!"

# Ask if user wants to reset target.v
echo ""
read -p "Reset shared/target.v to original grammar_fsm.v? [y/N]: " reset_target

if [[ "$reset_target" =~ ^[Yy]$ ]]; then
    if [ -f grammar_fsm.v ]; then
        cp grammar_fsm.v shared/target.v
        echo -e "${GREEN}[CLEANUP]${NC} target.v reset to original grammar_fsm.v"
    else
        echo -e "${RED}[ERROR]${NC} grammar_fsm.v not found"
    fi
fi

echo ""
echo -e "${GREEN}Done!${NC} Run ./coordinator.sh to start a new game."
echo ""
