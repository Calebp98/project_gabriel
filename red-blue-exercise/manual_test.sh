#!/bin/bash

# Manual testing script - run one turn at a time
# Useful for debugging and understanding the exercise flow

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_usage() {
    echo -e "${GREEN}Manual Testing Script${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  init          - Initialize game state"
    echo "  red <round>   - Generate red team prompt for round"
    echo "  blue <round>  - Generate blue team prompt for round"
    echo "  status        - Show current status"
    echo ""
    echo "Example workflow:"
    echo "  1. ./manual_test.sh init"
    echo "  2. cd red-team && claude"
    echo "  3. (Red team analyzes target.v and creates findings)"
    echo "  4. cd ../blue-team && claude"
    echo "  5. (Blue team patches vulnerabilities)"
    echo ""
}

init_game() {
    echo -e "${GREEN}[INIT]${NC} Initializing game state..."

    # Create directories
    mkdir -p shared red-team blue-team logs

    # Copy initial target
    if [ ! -f shared/target.v ]; then
        if [ -f grammar_fsm.v ]; then
            cp grammar_fsm.v shared/target.v
            echo "  ✓ Copied grammar_fsm.v to shared/target.v"
        else
            echo -e "  ${RED}✗${NC} grammar_fsm.v not found"
            exit 1
        fi
    else
        echo "  → shared/target.v already exists"
    fi

    # Initialize state
    echo "RED" > shared/turn.txt
    echo "1" > shared/round.txt

    cat > shared/game_state.json <<EOF
{
  "current_round": 1,
  "current_turn": "RED",
  "game_active": true
}
EOF

    echo "  ✓ State files created"
    echo -e "${GREEN}[INIT]${NC} Ready! Use './manual_test.sh red 1' to start"
}

generate_red_prompt() {
    local round=$1

    echo -e "${RED}[RED TEAM]${NC} Generating prompt for round $round..."

    cat > red-team/prompt.txt <<EOF
# RED TEAM - Round $round

Your mission: Find security vulnerabilities in the Verilog design.

## Current State
- Round: $round
- Target file: ../shared/target.v
- Previous findings: ./findings.md (if exists from previous rounds)

## Your Task

1. Analyze ../shared/target.v for security vulnerabilities:
   - Timing attacks and race conditions
   - Side-channel vulnerabilities (power analysis, EM)
   - FSM security issues (unreachable states, improper transitions)
   - Information leakage through outputs or timing
   - Glitch vulnerabilities and fault injection weaknesses
   - Metastability issues in clock domain crossings
   - Buffer overflow or state overflow conditions
   - Reset behavior and power-on state security
   - Cryptographic weaknesses (if applicable)

2. Document NEW vulnerabilities in ./findings.md:
   - Clear description of the vulnerability
   - Exact line numbers in target.v
   - Severity: HIGH / MEDIUM / LOW
   - Exploitation scenario (how an attacker could exploit this)
   - Recommended fix (optional)

3. When complete, create ./done.txt with:
   \`\`\`
   COMPLETE
   vulnerabilities_found: X
   timestamp: \$(date -Iseconds)
   \`\`\`

## Rules
- Only report NEW vulnerabilities not already fixed
- Be specific with line numbers and code examples
- If no new vulnerabilities found, state this clearly in findings.md
- Focus on realistic attack scenarios
- Consider both hardware and protocol-level vulnerabilities

## Output Files
- ./findings.md - Your vulnerability report (REQUIRED)
- ./analysis.md - Your working notes (optional)
- ./done.txt - Signal completion (REQUIRED)

## Important
Do NOT modify ../shared/target.v - you are analyzing only!
Your findings will be shared with the blue team for patching.

Good luck! 🔴
EOF

    echo "  ✓ Prompt created at red-team/prompt.txt"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. cd red-team"
    echo "  2. claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'"
    echo "  3. (Or just) claude (and paste the prompt manually)"
}

generate_blue_prompt() {
    local round=$1

    echo -e "${BLUE}[BLUE TEAM]${NC} Generating prompt for round $round..."

    cat > blue-team/prompt.txt <<EOF
# BLUE TEAM - Round $round

Your mission: Fix vulnerabilities identified by the red team.

## Current State
- Round: $round
- Target file: ../shared/target.v (you WILL modify this)
- Vulnerabilities to fix: ../red-team/findings.md

## Your Task

1. Read ../red-team/findings.md for identified vulnerabilities

2. Fix ALL identified vulnerabilities in ../shared/target.v:
   - Apply security patches directly to the file
   - Maintain original functionality
   - Add comments explaining your fixes
   - Ensure no new vulnerabilities are introduced
   - Preserve synthesizability

3. Document changes in ./patches.md:
   - Which vulnerability you addressed
   - How you fixed it (code changes)
   - Verification approach
   - Any trade-offs made

4. When complete, create ./done.txt with:
   \`\`\`
   COMPLETE
   patches_applied: X
   timestamp: \$(date -Iseconds)
   \`\`\`

## Rules
- Fix ALL reported vulnerabilities
- Preserve original functionality (FSM behavior)
- Add clear comments to patched code
- Verify your changes don't break the design
- Document each fix thoroughly

## Output Files
- ../shared/target.v - Modified Verilog (REQUIRED - edit this file!)
- ./patches.md - Your patch documentation (REQUIRED)
- ./changes.md - Detailed change log (optional)
- ./done.txt - Signal completion (REQUIRED)

## Important
You MUST edit ../shared/target.v directly!
Your fixes will be analyzed by red team in next round.

Good luck! 🔵
EOF

    echo "  ✓ Prompt created at blue-team/prompt.txt"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. cd blue-team"
    echo "  2. claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'"
    echo "  3. (Or just) claude (and paste the prompt manually)"
}

# Main script
case "${1:-}" in
    init)
        init_game
        ;;

    red)
        round="${2:-1}"
        generate_red_prompt "$round"
        ;;

    blue)
        round="${2:-1}"
        generate_blue_prompt "$round"
        ;;

    status)
        if [ -f status.sh ]; then
            ./status.sh
        else
            echo "Run ./status.sh for detailed status"
        fi
        ;;

    *)
        show_usage
        exit 1
        ;;
esac
