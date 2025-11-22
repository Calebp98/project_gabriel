#!/bin/bash

# Monitoring script for Red Team vs Blue Team exercise
# Sets up a comprehensive tmux view showing all activity

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MONITOR_SESSION="red-blue-monitor"
GAME_SESSION="red-blue-security"

log() {
    echo -e "${GREEN}[WATCH]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if already running
if tmux has-session -t $MONITOR_SESSION 2>/dev/null; then
    error "Monitor session '$MONITOR_SESSION' already exists"
    echo ""
    echo "Options:"
    echo "  1. Attach to existing: tmux attach -t $MONITOR_SESSION"
    echo "  2. Kill and restart:   tmux kill-session -t $MONITOR_SESSION && $0"
    exit 1
fi

log "Setting up monitoring session..."
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Red vs Blue - Comprehensive Monitoring Setup     ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Create main monitor session with layout
log "Creating tmux session with 3-pane layout..."

# Create session with first pane
tmux new-session -d -s $MONITOR_SESSION -x 200 -y 50

# Split horizontally (top and bottom)
tmux split-window -v -t $MONITOR_SESSION -l 15

# Split the top pane vertically (left and right)
tmux split-window -h -t $MONITOR_SESSION:0.0 -l 40

# Now we have:
# Pane 0 (top-left, large): Will show red-blue AI agents
# Pane 1 (top-right, small): Will show status
# Pane 2 (bottom, full width): Will show coordinator

# Set pane titles
tmux select-pane -t $MONITOR_SESSION:0.0 -T "🎮 AI AGENTS"
tmux select-pane -t $MONITOR_SESSION:0.1 -T "📊 STATUS"
tmux select-pane -t $MONITOR_SESSION:0.2 -T "🎯 COORDINATOR"

log "Configuring panes..."

# Pane 0: Show AI agents (will display red-blue-security session)
tmux send-keys -t $MONITOR_SESSION:0.0 "cd '$PROJECT_ROOT'" C-m
tmux send-keys -t $MONITOR_SESSION:0.0 "clear" C-m

# Create a script that monitors the game session
cat > /tmp/monitor_game_session.sh <<'EOF'
#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           AI AGENTS VIEW (Red Team | Blue Team)        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Waiting for game session to start..."
echo ""

# Wait for the game session to be created
while ! tmux has-session -t red-blue-security 2>/dev/null; do
    sleep 1
done

clear
echo -e "${GREEN}Game session detected! Showing live view...${NC}"
echo -e "${YELLOW}(Red Team = Left | Blue Team = Right)${NC}"
echo ""
echo "─────────────────────────────────────────────────────────"

# Watch the red-blue session panes
while true; do
    if tmux has-session -t red-blue-security 2>/dev/null; then
        clear
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}║  🔴 RED TEAM (Left) | 🔵 BLUE TEAM (Right)              ║${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

        # Get content from both panes of the game session
        RED_CONTENT=$(tmux capture-pane -t red-blue-security:0.0 -p -S -20 2>/dev/null || echo "Red team pane not ready...")
        BLUE_CONTENT=$(tmux capture-pane -t red-blue-security:0.1 -p -S -20 2>/dev/null || echo "Blue team pane not ready...")

        echo ""
        echo -e "${RED}🔴 RED TEAM:${NC}"
        echo "───────────────────────────────────────────────────────"
        echo "$RED_CONTENT" | tail -n 10
        echo ""
        echo -e "${BLUE}🔵 BLUE TEAM:${NC}"
        echo "───────────────────────────────────────────────────────"
        echo "$BLUE_CONTENT" | tail -n 10
        echo ""
        echo -e "${YELLOW}Press Ctrl+C to stop monitoring | Ctrl+b then d to detach${NC}"

        sleep 2
    else
        clear
        echo -e "${YELLOW}Game session ended.${NC}"
        break
    fi
done
EOF

chmod +x /tmp/monitor_game_session.sh
tmux send-keys -t $MONITOR_SESSION:0.0 "/tmp/monitor_game_session.sh" C-m

# Pane 1: Status monitor (top-right)
# Create a status monitoring loop (macOS doesn't have 'watch' by default)
cat > /tmp/status_loop.sh <<'STATUSEOF'
#!/bin/bash
cd "$1"
while true; do
    clear
    ./status.sh
    sleep 10
done
STATUSEOF

chmod +x /tmp/status_loop.sh
tmux send-keys -t $MONITOR_SESSION:0.1 "cd '$PROJECT_ROOT'" C-m
tmux send-keys -t $MONITOR_SESSION:0.1 "clear" C-m
tmux send-keys -t $MONITOR_SESSION:0.1 "/tmp/status_loop.sh '$PROJECT_ROOT'" C-m

# Pane 2: Coordinator (bottom)
tmux send-keys -t $MONITOR_SESSION:0.2 "cd '$PROJECT_ROOT'" C-m
tmux send-keys -t $MONITOR_SESSION:0.2 "clear" C-m
tmux send-keys -t $MONITOR_SESSION:0.2 "echo 'Starting coordinator in 3 seconds...'" C-m
tmux send-keys -t $MONITOR_SESSION:0.2 "sleep 3 && ./coordinator.sh" C-m

log "Monitor session created successfully!"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Layout Overview:                                      ║${NC}"
echo -e "${GREEN}║                                                        ║${NC}"
echo -e "${GREEN}║  ┌────────────────────┬─────────────┐                 ║${NC}"
echo -e "${GREEN}║  │ AI AGENTS          │ STATUS      │                 ║${NC}"
echo -e "${GREEN}║  │ (Red | Blue)       │ (Live)      │                 ║${NC}"
echo -e "${GREEN}║  │                    │             │                 ║${NC}"
echo -e "${GREEN}║  ├────────────────────┴─────────────┤                 ║${NC}"
echo -e "${GREEN}║  │ COORDINATOR                      │                 ║${NC}"
echo -e "${GREEN}║  │ (Orchestration logs)             │                 ║${NC}"
echo -e "${GREEN}║  └──────────────────────────────────┘                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Navigation:${NC}"
echo "  • Switch panes: Ctrl+b then arrow keys"
echo "  • Zoom a pane:  Ctrl+b then z (toggle)"
echo "  • Scroll up:    Ctrl+b then [ (press q to exit)"
echo "  • Detach:       Ctrl+b then d (keeps running)"
echo ""
echo -e "${YELLOW}Attaching to monitor session in 2 seconds...${NC}"
sleep 2

# Attach to the monitor session
tmux attach -t $MONITOR_SESSION
