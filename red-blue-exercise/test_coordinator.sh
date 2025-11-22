#!/bin/bash

# Simple test coordinator - uses cheap/fast prompts for debugging
# Only runs ONE red team turn to verify orchestration works

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TMUX_SESSION="red-blue-test"
TURN_TIMEOUT=120  # 2 minutes for test

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Setup
log "Setting up test environment..."

# Create directories
mkdir -p shared red-team blue-team logs

# Copy original file (Claude edits the copy, not the original!)
log "Copying original grammar_fsm.v to shared/target.v..."
if [ -f "../grammar_fsm.v" ]; then
    cp "../grammar_fsm.v" shared/target.v
    log "✓ Original file safe - Claude will edit the copy only"
else
    error "Cannot find ../grammar_fsm.v"
    exit 1
fi

# Create test prompt for red team (super simple, fast task)
cat > red-team/prompt.txt <<'EOF'
# RED TEAM TEST - Simple Orchestration Test

Your task is simple and fast (should take ~10 seconds):

1. Read the file ../shared/target.v
2. Count how many lines it has
3. Create findings.md with this content:
   ```
   # Test Findings
   File analyzed: ../shared/target.v
   Lines counted: [NUMBER]
   Test vulnerability: Line 1 has a comment (LOW severity)
   ```
4. Create done.txt with:
   ```
   COMPLETE
   vulnerabilities_found: 1
   timestamp: [current timestamp]
   ```

This is just a test to verify the orchestration works!
EOF

log "Test prompt created"

# Setup tmux
log "Creating tmux session..."
tmux kill-session -t $TMUX_SESSION 2>/dev/null || true
tmux new-session -d -s $TMUX_SESSION
tmux send-keys -t $TMUX_SESSION "cd '$PROJECT_ROOT/red-team' && clear" C-m

log "Tmux session ready: $TMUX_SESSION"

# Send command
log "Launching red team with test prompt..."
tmux send-keys -t $TMUX_SESSION "claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'" C-m

# Wait for completion
log "Waiting for completion (timeout: ${TURN_TIMEOUT}s)..."
elapsed=0
while [ ! -f "red-team/done.txt" ]; do
    sleep 2
    elapsed=$((elapsed + 2))

    if [ $elapsed -ge $TURN_TIMEOUT ]; then
        error "TIMEOUT: Red team did not complete"
        echo ""
        echo "To view what happened:"
        echo "  tmux attach -t $TMUX_SESSION"
        exit 1
    fi

    if [ $((elapsed % 10)) -eq 0 ]; then
        log "Still waiting... (${elapsed}s elapsed)"
    fi
done

# Success!
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   TEST SUCCESSFUL!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

log "Red team completed in ${elapsed}s"

# Show results
if [ -f "red-team/done.txt" ]; then
    echo -e "${YELLOW}done.txt:${NC}"
    cat red-team/done.txt
    echo ""
fi

if [ -f "red-team/findings.md" ]; then
    echo -e "${YELLOW}findings.md:${NC}"
    head -10 red-team/findings.md
    echo ""
fi

log "Tmux session '$TMUX_SESSION' is still running"
log "To view: tmux attach -t $TMUX_SESSION"
log "To kill: tmux kill-session -t $TMUX_SESSION"

echo ""
echo -e "${GREEN}✓ Orchestration works! Ready for full coordinator.sh${NC}"
