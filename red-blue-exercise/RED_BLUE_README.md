# Red Team vs Blue Team Verilog Security Exercise

An automated security exercise where two Claude Code instances compete to improve Verilog security through adversarial collaboration.

## Overview

- **Red Team**: Analyzes Verilog code to find security vulnerabilities
- **Blue Team**: Patches identified vulnerabilities while maintaining functionality
- **Communication**: Via shared filesystem (no direct interaction)
- **Coordination**: Turn-based orchestration via `coordinator.sh`

## Architecture

```
project_gabriel/
├── coordinator.sh          # Main orchestration script
├── shared/
│   ├── target.v           # The Verilog file being secured
│   ├── turn.txt           # Current turn: "RED" or "BLUE"
│   ├── round.txt          # Current round number
│   └── game_state.json    # Overall game state
├── red-team/
│   ├── findings.md        # Red team vulnerability reports
│   ├── analysis.md        # Analysis notes (optional)
│   ├── done.txt           # Completion signal
│   └── prompt.txt         # Instructions (auto-generated)
├── blue-team/
│   ├── patches.md         # Blue team patch documentation
│   ├── changes.md         # Change log (optional)
│   ├── done.txt           # Completion signal
│   └── prompt.txt         # Instructions (auto-generated)
└── logs/
    ├── round_1_red_findings.md
    ├── round_1_blue_patches.md
    ├── round_1_target.v
    └── ...
```

## Quick Start

### Prerequisites

- `tmux` installed
- `claude` CLI available in PATH
- Bash shell (macOS/Linux)

### Run the Exercise

```bash
# Start the game
./coordinator.sh
```

The coordinator will:
1. Initialize game state
2. Create tmux session with two panes (Red Team | Blue Team)
3. Run alternating turns for up to 5 rounds
4. Log all findings and patches

### View the Game

The tmux session runs in the background. To watch:

```bash
tmux attach -t red-blue-security
```

To detach: `Ctrl+b` then `d`

### Monitor Progress

Check current status:

```bash
./status.sh
```

## How It Works

### Red Team Turn

1. Coordinator generates `red-team/prompt.txt` with instructions
2. Red team analyzes `shared/target.v` for vulnerabilities
3. Writes findings to `red-team/findings.md`
4. Creates `red-team/done.txt` to signal completion
5. If 0 vulnerabilities found → **Blue Team Wins!**

### Blue Team Turn

1. Coordinator generates `blue-team/prompt.txt` with instructions
2. Blue team reads `red-team/findings.md`
3. Patches vulnerabilities in `shared/target.v`
4. Documents fixes in `blue-team/patches.md`
5. Creates `blue-team/done.txt` to signal completion

### Turn Protocol

Each team signals completion by creating a `done.txt` file:

```
COMPLETE
vulnerabilities_found: 3
timestamp: 2024-11-22T10:30:00
```

The coordinator watches for this file, logs the results, and switches turns.

## Configuration

Edit `coordinator.sh` to adjust:

- `MAX_ROUNDS=5` - Maximum number of rounds
- `TURN_TIMEOUT=600` - Timeout per turn (seconds)

## Game Termination

The game ends when:

1. **Blue Team Wins**: Red team finds no new vulnerabilities
2. **Max Rounds Reached**: All rounds completed
3. **Timeout**: A team fails to complete within time limit
4. **Manual Stop**: `Ctrl+C` or critical error

## Vulnerability Types

Red team searches for:

- Timing attacks and race conditions
- Side-channel vulnerabilities (power, EM)
- FSM security issues
- Information leakage
- Glitch vulnerabilities
- Metastability issues
- Buffer/state overflow
- Reset behavior weaknesses
- Cryptographic flaws

## Output

After the game:

- **Logs**: All findings and patches saved in `./logs/`
- **Final Design**: Secured Verilog in `./shared/target.v`
- **Version History**: Each round's target.v saved
- **Tmux Session**: Still running for review

## Cleanup

```bash
# Kill the tmux session
tmux kill-session -t red-blue-security

# Clean generated files
./cleanup.sh
```

## Tips

### For Manual Testing

You can manually step through turns:

```bash
# Red team
cd red-team
claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'

# Blue team
cd blue-team
claude --dangerously-skip-permissions 'Follow the instructions in prompt.txt'
```

### Viewing Logs

```bash
# See all red team findings
cat logs/round_*_red_findings.md

# See all blue team patches
cat logs/round_*_blue_patches.md

# Compare target.v across rounds
diff logs/round_1_target.v logs/round_2_target.v
```

### Advanced Usage

- **Custom target**: Replace `shared/target.v` with your Verilog
- **Verification**: Add formal verification checks between turns
- **Scoring**: Track vulnerabilities found vs. patches applied
- **Replay**: Review tmux logs to see agent interactions

## Example Session

```bash
$ ./coordinator.sh

[COORDINATOR] Initializing game state...
[COORDINATOR] Tmux session 'red-blue-security' created
[COORDINATOR] === ROUND 1 ===

╔════════════════════════════════════════╗
║     RED TEAM - ROUND 1                 ║
╚════════════════════════════════════════╝

[COORDINATOR] Launching red team analysis...
[COORDINATOR] Waiting for RED TEAM to complete...
[COORDINATOR] RED TEAM completed!

╔════════════════════════════════════════╗
║     BLUE TEAM - ROUND 1                ║
╚════════════════════════════════════════╝

[COORDINATOR] Launching blue team patching...
[COORDINATOR] Waiting for BLUE TEAM to complete...
[COORDINATOR] BLUE TEAM completed!
[COORDINATOR] Round 1 complete

...

╔════════════════════════════════════════╗
║          GAME COMPLETE                 ║
╚════════════════════════════════════════╝

[COORDINATOR] Game logs saved in ./logs/
[COORDINATOR] Final target.v saved in ./shared/target.v
[COORDINATOR] Tmux session 'red-blue-security' is still running
```

## Troubleshooting

**Issue**: Tmux session won't start
- Check if tmux is installed: `which tmux`
- Kill existing session: `tmux kill-session -t red-blue-security`

**Issue**: Claude Code not found
- Verify installation: `which claude`
- Check PATH configuration

**Issue**: Team doesn't complete turn
- Check timeout setting in `coordinator.sh`
- Attach to tmux to see what's happening
- Review team's prompt.txt for clarity

**Issue**: Prompts not working well
- Edit the prompt templates in `coordinator.sh`
- Functions: `generate_red_prompt()` and `generate_blue_prompt()`

## Future Enhancements

- [ ] Scoring system (points for vulnerabilities/fixes)
- [ ] Automated formal verification between turns
- [ ] Multiple target files (full Verilog projects)
- [ ] AI referee (third Claude instance judges)
- [ ] Web dashboard for live monitoring
- [ ] Replay mode for conversation logs
- [ ] Difficulty levels (simple → complex designs)

## License

Part of the Gabriel FPGA Security Project.
