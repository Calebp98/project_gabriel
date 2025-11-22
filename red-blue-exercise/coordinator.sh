#!/bin/bash

# Red Team vs Blue Team Verilog Security Exercise Coordinator
# This script orchestrates the turn-based security game between two Claude Code instances

set -e

# Configuration
MAX_ROUNDS=5
TURN_TIMEOUT=600  # 10 minutes per turn
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TMUX_SESSION="red-blue-security"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${GREEN}[COORDINATOR]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Initialize game state
init_game() {
    log "Initializing game state..."

    # Create necessary directories if they don't exist
    mkdir -p shared red-team blue-team logs

    # Copy original Verilog file to shared (Claude will edit the copy, not the original!)
    log "Copying original grammar_fsm.v to shared/target.v..."
    if [ -f "../grammar_fsm.v" ]; then
        cp "../grammar_fsm.v" shared/target.v
        log "✓ Original file copied (original remains untouched)"
    else
        error "Cannot find ../grammar_fsm.v"
        exit 1
    fi

    # Initialize state files
    echo "RED" > shared/turn.txt
    echo "1" > shared/round.txt

    # Create initial game state
    cat > shared/game_state.json <<EOF
{
  "current_round": 1,
  "current_turn": "RED",
  "max_rounds": $MAX_ROUNDS,
  "red_score": 0,
  "blue_score": 0,
  "game_active": true
}
EOF

    log "Game state initialized"
}

# Generate prompt for red team
generate_red_prompt() {
    local round=$1
    cat > red-team/prompt.txt <<EOF
# RED TEAM - Round $round (QUICK ANALYSIS)

Quick security scan of ../shared/target.v

Find 1-3 NEW vulnerabilities. Focus on:
- Timing attacks
- FSM security issues
- Metastability

Create ./findings.md with:
- Brief description
- Line numbers
- Severity (HIGH/MEDIUM/LOW)

Create ./done.txt:
COMPLETE
vulnerabilities_found: X
timestamp: \$(date -Iseconds)

Be concise. Target: 30 seconds.
EOF
}

# Generate prompt for blue team
generate_blue_prompt() {
    local round=$1
    cat > blue-team/prompt.txt <<EOF
# BLUE TEAM - Round $round (QUICK PATCH)

Quick fixes for ../red-team/findings.md

1. Read findings
2. Patch ALL issues in ../shared/target.v
3. Add brief comments to fixes

Create ./patches.md with:
- Issue fixed
- How you fixed it

Create ./done.txt:
COMPLETE
patches_applied: X
timestamp: \$(date -Iseconds)

Be fast. Target: 30 seconds.
EOF
}

# Wait for a team to complete their turn
wait_for_done() {
    local team_dir=$1
    local team_name=$2
    local timeout=$3
    local elapsed=0

    log "Waiting for $team_name to complete (timeout: ${timeout}s)..."

    while [ ! -f "$team_dir/done.txt" ]; do
        sleep 2
        elapsed=$((elapsed + 2))

        if [ $elapsed -ge $timeout ]; then
            error "TIMEOUT: $team_name did not complete in time"
            return 1
        fi

        # Show progress
        if [ $((elapsed % 30)) -eq 0 ]; then
            log "$team_name still working... (${elapsed}s elapsed)"
        fi
    done

    log "$team_name completed!"
    return 0
}

# Check if red team found vulnerabilities
check_red_findings() {
    if [ ! -f "red-team/findings.md" ]; then
        warn "Red team did not create findings.md"
        return 1
    fi

    # Check if done.txt reports 0 vulnerabilities
    if grep -q "vulnerabilities_found: 0" red-team/done.txt 2>/dev/null; then
        log "Red team found 0 vulnerabilities - Blue team wins!"
        return 1
    fi

    return 0
}

# Setup tmux session
setup_tmux() {
    log "Setting up tmux session..."

    # Kill existing session if it exists
    tmux kill-session -t $TMUX_SESSION 2>/dev/null || true

    # Create new session with horizontal split
    tmux new-session -s $TMUX_SESSION -d
    tmux split-window -h -t $TMUX_SESSION

    # Set pane titles and navigate
    tmux select-pane -t 0 -T "🔴 RED TEAM"
    tmux select-pane -t 1 -T "🔵 BLUE TEAM"

    tmux send-keys -t $TMUX_SESSION:0.0 "cd '$PROJECT_ROOT/red-team' && clear" C-m
    tmux send-keys -t $TMUX_SESSION:0.1 "cd '$PROJECT_ROOT/blue-team' && clear" C-m

    log "Tmux session '$TMUX_SESSION' created"
}

# Send command to tmux pane
send_to_tmux() {
    local pane=$1
    local command=$2
    tmux send-keys -t $TMUX_SESSION:0.$pane "$command" C-m
}

# Run red team turn
run_red_turn() {
    local round=$1

    echo -e "\n${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     RED TEAM - ROUND $round             ║${NC}"
    echo -e "${RED}╔════════════════════════════════════════╗${NC}\n"

    # Generate prompt
    generate_red_prompt $round

    # Set turn marker
    echo "RED" > shared/turn.txt

    # Clean up any previous done.txt
    rm -f red-team/done.txt

    # Send command to red team pane
    log "Launching red team analysis..."
    send_to_tmux 0 "claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'"

    # Wait for completion
    if ! wait_for_done "red-team" "RED TEAM" $TURN_TIMEOUT; then
        error "Red team turn failed"
        return 1
    fi

    # Check findings
    if ! check_red_findings; then
        log "Game over - Blue team wins! No vulnerabilities found."
        return 2
    fi

    # Log the turn
    cp red-team/findings.md "logs/round_${round}_red_findings.md" 2>/dev/null || true

    return 0
}

# Run blue team turn
run_blue_turn() {
    local round=$1

    echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     BLUE TEAM - ROUND $round            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

    # Generate prompt
    generate_blue_prompt $round

    # Set turn marker
    echo "BLUE" > shared/turn.txt

    # Clean up any previous done.txt
    rm -f blue-team/done.txt

    # Send command to blue team pane
    log "Launching blue team patching..."
    send_to_tmux 1 "claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'"

    # Wait for completion
    if ! wait_for_done "blue-team" "BLUE TEAM" $TURN_TIMEOUT; then
        error "Blue team turn failed"
        return 1
    fi

    # Log the turn
    cp blue-team/patches.md "logs/round_${round}_blue_patches.md" 2>/dev/null || true
    cp shared/target.v "logs/round_${round}_target.v" 2>/dev/null || true

    return 0
}

# Main game loop
main() {
    log "Starting Red Team vs Blue Team Verilog Security Exercise"
    log "Max rounds: $MAX_ROUNDS"
    log "Turn timeout: $TURN_TIMEOUT seconds"

    # Initialize
    init_game
    setup_tmux

    # Attach to tmux in background and run game
    log "Tmux session ready. Starting game loop..."

    for round in $(seq 1 $MAX_ROUNDS); do
        log "=== ROUND $round ==="
        echo "$round" > shared/round.txt

        # Red team turn
        run_red_turn $round
        red_result=$?

        if [ $red_result -eq 2 ]; then
            # Game over - blue team wins
            break
        elif [ $red_result -ne 0 ]; then
            error "Red team turn failed, aborting game"
            break
        fi

        # Blue team turn
        if ! run_blue_turn $round; then
            error "Blue team turn failed, aborting game"
            break
        fi

        log "Round $round complete"
        echo ""
    done

    # Game summary
    echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          GAME COMPLETE                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

    log "Game logs saved in ./logs/"
    log "Final target.v saved in ./shared/target.v"
    log "Tmux session '$TMUX_SESSION' is still running"
    log "To view: tmux attach -t $TMUX_SESSION"
    log "To kill: tmux kill-session -t $TMUX_SESSION"
}

# Handle Ctrl+C gracefully
cleanup() {
    echo ""
    warn "Received interrupt signal"
    log "Cleaning up..."
    tmux kill-session -t $TMUX_SESSION 2>/dev/null || true
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run the game
main "$@"
