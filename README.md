# Project Gabriel

**Claude Code for FPGA Formal Verification**

An exploration of using AI (Claude Code) to accelerate the development of formally verified FPGA security systems through hardware-software feedback loops and adversarial testing.

## Project Overview

This project demonstrates how AI can significantly advance defensive capabilities for critical infrastructure through three progressive stages:

1. **Stage 1**: Formally verified FPGA security gatekeeper
2. **Stage 2**: AI-hardware development loop with direct FPGA feedback
3. **Stage 3**: Adversarial AI verification (red team vs blue team)

### What We Built

We built an FPGA-based authentication system that acts as a hardware-level security gatekeeper for microcontroller programming. The system uses challenge-response cryptography to ensure only authenticated users can program target devices, with the FPGA controlling access by jamming the SWD clock until proper credentials are provided. All FPGA logic is formally verified against specifications using SymbiYosys and standard libraries.

### How This Addresses AI Risk

**AI-Enhanced Critical Infrastructure Defense**: This project demonstrates how AI can significantly advance the defensive capabilities of critical infrastructure that could be targeted under many AI risk scenarios. By using AI to design, specify, and iteratively improve hardware-level security systems, we can protect industrial control systems, power grids, and other essential infrastructure from unauthorized access.

**Verifiable Compute Governance**: The architecture serves as a foundation for cryptographically proving how computing clusters are being used—for example, verifying that a cluster is only performing inference rather than training. This capability is essential for international AI agreements and verification regimes that require proving compliance with compute usage restrictions.

**Scalability through AI**: Claude Code is orders of magnitude cheaper than human Verilog programmers for writing specifications and code. This means hardware security systems that were previously too expensive to be formally verified can be designed and iterated at scale. The formal verification itself uses standard libraries and best practices, but Claude dramatically reduces the cost of producing verifiable code, expanding our ability to secure critical infrastructure against emerging threats.

## Hardware Requirements

- **iCEBreaker FPGA board** (Lattice iCE40UP5K)
- **Raspberry Pi Pico** (2x for full setup - one as picoprobe, one as target)
- Jumper wires
- USB cables

## Project Structure

```
project_gabriel/
├── icebreaker/              # Main FPGA security modules (Stage 1)
│   ├── top.v                # UART control with authentication logic
│   ├── uart_rx.v            # UART receiver (formally verified)
│   ├── uart_tx.v            # UART transmitter (formally verified)
│   ├── lfsr.v               # Linear feedback shift register for crypto
│   ├── *.sby                # Formal verification configurations
│   └── test_auth.py         # Authentication test scripts
│
├── claude-fpga-helpers/     # AI-hardware feedback loops (Stage 2)
│   └── experiments/         # Iterative development experiments
│       ├── 20251123-170039-pin38-to-pin46/
│       ├── 2025-01-23-secure-fpga-gatekeeper/
│       └── ...              # Various LED and control experiments
│
├── red-blue-exercise/       # Adversarial AI testing (Stage 3)
│   ├── blue-team/           # Defensive specifications and patches
│   ├── red-team/            # Attack findings and vulnerabilities
│   └── shared/              # Common target code and state
│
├── docs/
│   ├── architecture_sat.md  # System architecture documentation
│   ├── PICOPROBE_SETUP.md   # Complete picoprobe setup guide
│   └── QUICKSTART_PICOPROBE.md  # 5-minute quick start
│
├── scripts/                 # Helper scripts for development
└── fpga_pico_loader/        # Bootloader infrastructure
```

## Stage 1: Formally Verified FPGA Security System

The core security gatekeeper implementation is in the `icebreaker/` directory.

### Key Features

- **UART-based authentication**: Challenge-response protocol at 115200 baud
- **SWD access control**: FPGA controls clock line to prevent unauthorized programming
- **Formal verification**: All modules verified using SymbiYosys/yosys-smtbmc
- **Hardware enforcement**: Security enforced at hardware level, not bypassable by software

### Building and Running

```bash
cd icebreaker/
make                    # Build the bitstream
make prog               # Flash to FPGA
sby -f uart_rx.sby      # Run formal verification on UART receiver
sby -f top.sby          # Verify top-level module
```

### Formal Verification

We use SymbiYosys for formal verification of all Verilog modules:

```bash
# Verify UART modules
sby -f uart_rx.sby
sby -f uart_tx.sby

# Verify LFSR crypto module
sby -f lfsr.sby

# Verify complete system
sby -f top.sby
```

All assertions must pass for 30+ clock cycles of bounded model checking.

## Stage 2: AI-Hardware Development Loop

The `claude-fpga-helpers/` directory contains experiments demonstrating iterative development with real hardware feedback.

### How It Works

1. Claude writes Verilog code based on specifications
2. Code is compiled and flashed to FPGA
3. Hardware behavior is observed via UART/LEDs
4. Feedback is provided back to Claude
5. Claude iteratively improves the design

### Example Experiments

- **LED patterns**: Progressive complexity in LED control
- **Pin state transfer**: Reading and controlling FPGA pins
- **Secure gatekeeper**: Challenge-response authentication

This dramatically accelerates development by allowing Claude to "see" what's happening on the hardware and debug accordingly.

## Stage 3: Adversarial AI Verification

The `red-blue-exercise/` directory implements a red team/blue team methodology using separate Claude instances.

### Methodology

**Blue Team (Defensive)**:
- Writes formal specifications
- Implements Verilog modules
- Adds security properties
- Patches vulnerabilities

**Red Team (Offensive)**:
- Analyzes specifications for gaps
- Identifies potential exploits
- Documents attack vectors
- Shares findings with blue team

### Running the Exercise

See `red-blue-exercise/shared/` for the current target code and game state. Each team has prompts that guide their respective Claude instances.

## Additional Features

### Programming with PicoProbe

This project includes comprehensive tooling for programming Picos via SWD:

- **Quick Start**: See `docs/QUICKSTART_PICOPROBE.md` (5 minutes)
- **Full Setup**: See `docs/PICOPROBE_SETUP.md`
- **Helper Script**: `./flash_with_picoprobe.sh firmware.elf`

### Branch Overview

- `main` - Stable integration of core features
- `swd-programming` - SWD programming infrastructure
- `better_crypto` - Enhanced cryptographic authentication
- `claude-fpga-upload` - Latest AI-hardware feedback experiments
- `red-blue-security-exercise` - Adversarial testing framework
- `vhong/verify` - Formal verification (merged to main)
- `dnp3-link-layer` - DNP3 protocol implementation

## Results and Impact

We didn't get to a production-ready solution, but we **derisked some of our largest uncertainties** and have an **MVP of a formal verification workflow** that can be used on FPGAs.

### What We Proved

1. **AI can write formally verifiable hardware** - Claude successfully wrote Verilog modules that pass formal verification
2. **Hardware feedback loops work** - Direct FPGA feedback dramatically accelerates AI-driven development
3. **Adversarial AI improves security** - Red team/blue team methodology uncovers vulnerabilities that single-agent development misses

### Scalability

The key insight: **Claude Code is orders of magnitude cheaper than human Verilog engineers**. This means:

- Hardware security systems too expensive to formally verify become feasible
- Iteration cycles drop from days to hours
- More critical infrastructure can be protected at scale

## Prerequisites

### Software

```bash
# macOS
brew install icestorm yosys nextpnr-ice40 symbiyosys z3

# Linux (Ubuntu/Debian)
sudo apt-get install fpga-icestorm yosys nextpnr-ice40
# Install SymbiYosys separately: https://symbiyosys.readthedocs.io/
```

### Python Dependencies

```bash
pip install -r requirements.txt
```

## Quick Start

1. **Clone and navigate**:
   ```bash
   cd project_gabriel/icebreaker
   ```

2. **Build and flash**:
   ```bash
   make && make prog
   ```

3. **Test UART control**:
   ```bash
   screen /dev/tty.usbmodem* 115200
   # Type 'Y' or 'N' to control pins
   ```

4. **Run formal verification**:
   ```bash
   sby -f uart_rx.sby
   ```

## Documentation

- `docs/architecture_sat.md` - Complete system architecture
- `docs/PICOPROBE_SETUP.md` - PicoProbe configuration and troubleshooting
- `docs/QUICKSTART_PICOPROBE.md` - 5-minute quick start guide
- `icebreaker/README.md` - FPGA module details

## Future Work

Potential enhancements for production deployment:

- Public key cryptography instead of symmetric keys
- Secure key storage in FPGA NVCM
- Multiple authentication levels
- Audit logging of all access attempts
- Integration with hardware security modules (HSMs)
- Extended formal verification (unbounded proofs)

## License

Research and educational use.

## Acknowledgments

Built with Claude Code - demonstrating how AI can accelerate the development of formally verified security-critical hardware systems.

## Contact

For questions about this project or formal verification workflows, please open an issue on GitHub: https://github.com/Calebp98/project_gabriel
