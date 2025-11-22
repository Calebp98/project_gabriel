# Quick Start Guide - Red Team vs Blue Team Exercise

Get started with the Verilog security exercise in under 5 minutes!

## Prerequisites Check

```bash
# 1. Check tmux is installed
which tmux
# If not: brew install tmux (macOS) or apt-get install tmux (Linux)

# 2. Check Claude Code is installed
which claude
# If not: Follow installation at https://github.com/anthropics/claude

# 3. Navigate to project
cd /path/to/project_gabriel
```

## Option 1: Full Monitoring Mode (Recommended) 🌟

Start with complete visibility into everything:

```bash
# Start with comprehensive monitoring view
./watch.sh
```

This will:
- Create a 3-pane tmux layout showing:
  - **AI Agents** (Red Team | Blue Team) - Watch them work in real-time!
  - **Status Monitor** - Live game state updates every 10 seconds
  - **Coordinator** - Orchestration logs
- Run up to 5 rounds automatically
- Log all findings and patches
- Stop when Blue Team wins (no vulnerabilities found)

**What you'll see:**
```
┌──────────────────────────┬──────────────┐
│ 🔴 RED | 🔵 BLUE        │ 📊 STATUS    │
│ (AI agents working)      │ (live stats) │
├──────────────────────────┴──────────────┤
│ 🎯 COORDINATOR (logs)                   │
└─────────────────────────────────────────┘
```

**Navigation:**
- Switch panes: `Ctrl+b` then arrow keys
- Zoom a pane: `Ctrl+b` then `z`
- Detach: `Ctrl+b` then `d`

## Option 2: Automatic Mode (Background)

Let the coordinator run without monitoring:

```bash
# Start the automated exercise
./coordinator.sh
```

**To watch after starting:**
```bash
# In another terminal
tmux attach -t red-blue-security

# Detach with: Ctrl+b then d
```

**To check status:**
```bash
./status.sh
```

## Option 3: Manual Mode (For Learning)

Step through each turn manually to understand the process:

```bash
# 1. Initialize
./manual_test.sh init

# 2. Red Team Turn (Round 1)
./manual_test.sh red 1
cd red-team
claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'
# Wait for completion, then check findings.md

# 3. Blue Team Turn (Round 1)
cd ../blue-team
./manual_test.sh blue 1
claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'
# Wait for completion, then check patches.md

# 4. Next round (Red Team again)
cd ../red-team
./manual_test.sh red 2
claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'

# ... and so on
```

## What to Expect

### Round 1

**Red Team:**
- Analyzes `shared/target.v` (grammar FSM)
- Finds 3-5 security vulnerabilities
- Creates `red-team/findings.md`
- Signals completion with `red-team/done.txt`

**Blue Team:**
- Reads `red-team/findings.md`
- Patches vulnerabilities in `shared/target.v`
- Creates `blue-team/patches.md`
- Signals completion with `blue-team/done.txt`

### Round 2

- Red team analyzes the **patched** code
- Finds new vulnerabilities (if any)
- Blue team patches again
- ... continues until no vulnerabilities found

## Monitoring

**Check current status:**
```bash
./status.sh
```

**View findings:**
```bash
cat red-team/findings.md
```

**View patches:**
```bash
cat blue-team/patches.md
```

**Compare versions:**
```bash
# Original
cat grammar_fsm.v

# Current (patched)
cat shared/target.v

# Specific round
cat logs/round_2_target.v
```

## Stopping the Exercise

**Graceful stop:**
```bash
# Press Ctrl+C in the coordinator terminal
```

**Force stop:**
```bash
# Kill tmux session
tmux kill-session -t red-blue-security
```

## Cleaning Up

**Clean everything:**
```bash
./cleanup.sh
# Choose option 1
```

**Keep logs, clean working files:**
```bash
./cleanup.sh
# Choose option 2
```

## Example Session

```
$ ./coordinator.sh

[COORDINATOR] Initializing game state...
[COORDINATOR] Tmux session 'red-blue-security' created
[COORDINATOR] === ROUND 1 ===

╔════════════════════════════════════════╗
║     RED TEAM - ROUND 1                 ║
╚════════════════════════════════════════╝

[COORDINATOR] Launching red team analysis...
[COORDINATOR] RED TEAM completed!

(Red team found 4 vulnerabilities)

╔════════════════════════════════════════╗
║     BLUE TEAM - ROUND 1                ║
╚════════════════════════════════════════╝

[COORDINATOR] Launching blue team patching...
[COORDINATOR] BLUE TEAM completed!

(Blue team patched all 4 vulnerabilities)

[COORDINATOR] Round 1 complete

... (Rounds 2-4 similar) ...

[COORDINATOR] Game over - Blue team wins! No vulnerabilities found.

╔════════════════════════════════════════╗
║          GAME COMPLETE                 ║
╚════════════════════════════════════════╝
```

## Troubleshooting

**"tmux: command not found"**
```bash
# macOS
brew install tmux

# Linux
sudo apt-get install tmux
```

**"claude: command not found"**
- Install Claude Code from https://github.com/anthropics/claude
- Add to PATH

**Teams taking too long**
- Default timeout is 600 seconds (10 minutes)
- Edit `TURN_TIMEOUT` in `coordinator.sh` to adjust

**Want to see what's happening**
```bash
# Attach to the tmux session
tmux attach -t red-blue-security
```

**Prompts not clear enough**
- Edit the prompt generation functions in `coordinator.sh`:
  - `generate_red_prompt()`
  - `generate_blue_prompt()`

## Next Steps

After your first successful run:

1. **Review the logs**: Check `logs/` directory for all rounds
2. **Compare versions**: See how target.v evolved
3. **Try different targets**: Replace `shared/target.v` with another Verilog file
4. **Adjust rounds**: Change `MAX_ROUNDS` in `coordinator.sh`
5. **Add verification**: Insert formal verification checks between rounds

## Tips

- **Start simple**: Use automatic mode first
- **Learn by watching**: Attach to tmux to see Claude Code work
- **Read the logs**: Understand what vulnerabilities were found
- **Experiment**: Try with different Verilog designs
- **Iterate**: Adjust prompts if results aren't good

## Resources

- Full documentation: `RED_BLUE_README.md`
- Manual testing: `manual_test.sh`
- Status checker: `status.sh`
- Cleanup: `cleanup.sh`

Happy hacking! 🔴🔵
