# Secure FPGA-Gated Microcontroller Programming System

A security system where an iCEBreaker FPGA authenticates a laptop via challenge-response protocol before allowing it to program a Raspberry Pi Pico target device. The FPGA uses SWD clock jamming to physically block unauthorized programming attempts.

## System Components

### Hardware Requirements

1. **iCEBreaker FPGA Board** - Security gatekeeper
2. **Raspberry Pi Pico (Target)** - Device to be programmed
3. **Raspberry Pi Pico (Pico Probe)** - UART pass-through and SWD programming
4. **Laptop** - Authentication client and programming host
5. **External Jamming Circuit** - Controlled by FPGA pin 4

### Physical Connections

```
Laptop USB ──┬──> iCEBreaker (programming/power)
             └──> Pico Probe (UART/SWD)
                     │
                     ├─ UART ──> iCEBreaker pins 2,3
                     └─ SWD ───> Target Pico
                                    │
FPGA Pin 4 ─────> Jamming Circuit ─┘
                  (blocks SWD CLK)
```

### Pin Assignments

| Pin | Signal | Direction | Description |
|-----|--------|-----------|-------------|
| 2 | UART_TX | Output | FPGA → Laptop (via Pico Probe) |
| 3 | UART_RX | Input | Laptop → FPGA (via Pico Probe) |
| 4 | JAM_CTRL | Output | SWD jamming control (HIGH=block, LOW=allow) |
| 38 | JAM_STATUS | Input | Loopback of pin 4 for verification |
| 43 | BLINK_IN | Input | Target Pico blink pattern detection |

## Authentication Protocol

### Overview

**Algorithm:** XOR-based challenge-response with 32-bit pre-shared key
**Key:** `0xDEADBEEF` (configurable in code)
**Transport:** UART at 115200 baud, 8N1

### Packet Format

```
[CMD:8] [DATA0:8] [DATA1:8] [DATA2:8] [DATA3:8]
```

Commands (1 byte) + optional 32-bit data payload (big-endian)

### Commands

| Code | Name | Direction | Payload | Description |
|------|------|-----------|---------|-------------|
| 0x01 | PROG_REQUEST | Laptop→FPGA | None | Request programming access |
| 0x02 | CHALLENGE | FPGA→Laptop | 32-bit | Random challenge value |
| 0x03 | RESPONSE | Laptop→FPGA | 32-bit | Encrypted response |
| 0x04 | AUTH_OK | FPGA→Laptop | None | Authentication successful |
| 0x05 | AUTH_FAIL | FPGA→Laptop | None | Authentication failed |
| 0x06 | STATUS | FPGA→Laptop | 32-bit | Status update |

### Authentication Sequence

```
Laptop                    FPGA
  │                         │
  ├─── PROG_REQUEST ──────>│
  │                         │ (generate challenge)
  │<──── CHALLENGE ─────────┤
  │                         │
  │ (compute response)      │
  ├──── RESPONSE ──────────>│
  │                         │ (verify)
  │<──── AUTH_OK ───────────┤
  │                         │ (disable jamming)
  │                         │
  │ [Program target Pico]   │
  │                         │ (detect blink)
  │                         │ (re-enable jamming)
```

**Response Calculation:** `response = challenge XOR 0xDEADBEEF`

## State Machine

```
     ┌──────────────────────────────────────────┐
     │                                          │
     v                                          │
  ┌──────┐    ┌───────────┐    ┌──────────────┐│
  │ IDLE │───>│ CHALLENGE │───>│WAIT_RESPONSE ││
  └──────┘    └───────────┘    └──────────────┘│
     ^                                │         │
     │                                v         │
     │                          ┌────────┐      │
     │                          │ VERIFY │      │
     │                          └────────┘      │
     │                           │      │       │
     │                    (pass) │      │(fail) │
     │                           v      v       │
     │                     ┌──────────────┐     │
     │                     │SEND_AUTH_OK  │     │
     │                     └──────────────┘     │
     │                           │              │
     │                           v              │
     │                    ┌─────────────┐       │
     │                    │DISABLE_JAM  │       │
     │                    └─────────────┘       │
     │                           │              │
     │                           v              │
     │                    ┌────────────┐        │
     │                    │WAIT_BLINK  │        │
     │                    └────────────┘        │
     │                           │              │
     │                           v              │
     │                    ┌────────────┐        │
     └────────────────────┤ENABLE_JAM  │        │
                          └────────────┘        │
                                                │
  ┌──────────────────┐                          │
  │SEND_AUTH_FAIL    │──────────────────────────┘
  └──────────────────┘
```

**Key States:**

- **IDLE:** Jamming enabled, waiting for programming request
- **CHALLENGE:** Send random challenge to laptop
- **WAIT_RESPONSE:** Wait for laptop's encrypted response (5s timeout)
- **VERIFY:** Check if response = challenge XOR key
- **DISABLE_JAM:** Lower pin 4 to allow programming
- **WAIT_BLINK:** Monitor pin 43 for blink pattern (10s timeout)
- **ENABLE_JAM:** Raise pin 4 to block programming, return to IDLE

## Programming Workflow

### Quick Start

```bash
# 1. Program FPGA
cd experiments/2025-01-23-secure-fpga-gatekeeper
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# 2. Run authentication and programming
./run_full_sequence.sh
```

### Manual Steps

```bash
# 1. Build and flash FPGA gatekeeper
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# 2. Authenticate with FPGA
python3 authenticate.py

# 3. Program target Pico (while jamming is disabled)
./flash_target.sh

# 4. Monitor FPGA (optional)
python3 monitor.py
```

## File Descriptions

### FPGA Code

- **secure_gatekeeper.v** - Main Verilog implementation
- **secure_gatekeeper_formal.v** - Version with formal verification assertions
- **secure_gatekeeper.pcf** - Pin constraint file
- **secure_gatekeeper.sby** - SymbiYosys formal verification config

### Laptop Software

- **authenticate.py** - Authentication client
- **monitor.py** - UART monitoring tool
- **flash_target.sh** - Target Pico programming script
- **run_full_sequence.sh** - Master automation script

### Documentation

- **README.md** - This file
- **SPECIFICATION.md** - Detailed technical specification

## Testing and Verification

### FPGA Formal Verification

Run formal verification with SymbiYosys:

```bash
# Install SymbiYosys (if not already installed)
# brew install symbiyosys (macOS)
# or follow instructions at https://github.com/YosysHQ/sby

# Run verification
sby -f secure_gatekeeper.sby
```

**Verified Properties:**

1. Jamming enabled in all states except DISABLE_JAM and WAIT_BLINK
2. Jamming only disabled after successful authentication
3. State machine always in valid state
4. Incorrect response never disables jamming
5. System always returns to IDLE (no deadlocks)

### Functional Testing

#### Test 1: UART Communication

```bash
# Terminal 1: Monitor FPGA
python3 monitor.py

# Terminal 2: Send test commands
python3 authenticate.py
```

**Expected:** See challenge-response exchange in monitor

#### Test 2: Authentication Success

```bash
python3 authenticate.py
```

**Expected:**
- FPGA sends challenge
- Laptop sends correct response
- FPGA sends AUTH_OK
- Pin 4 goes LOW (jamming disabled)

#### Test 3: Authentication Failure

Edit `authenticate.py` and change `SECRET_KEY` to wrong value:

```python
SECRET_KEY = 0xBADC0FFE  # Wrong key
```

Run authentication:

```bash
python3 authenticate.py
```

**Expected:**
- FPGA sends challenge
- Laptop sends incorrect response
- FPGA sends AUTH_FAIL
- Pin 4 stays HIGH (jamming remains enabled)

#### Test 4: Jamming Control

Connect LED to pin 4 (with appropriate resistor):

```bash
# Program FPGA
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# Observe: LED on (jamming enabled)

# Authenticate
python3 authenticate.py

# Observe: LED off (jamming disabled)

# Wait 10 seconds or program target
# Observe: LED on again (jamming re-enabled)
```

#### Test 5: Blink Detection

```bash
# 1. Program FPGA
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# 2. Authenticate
python3 authenticate.py

# 3. Program target Pico with blink.c
./flash_target.sh

# 4. Connect target Pico GPIO to FPGA pin 43

# 5. Observe: FPGA detects blink pattern and re-enables jamming
```

#### Test 6: Full Integration

```bash
./run_full_sequence.sh
```

**Expected:**
1. FPGA programmed successfully
2. Authentication succeeds
3. Target Pico programmed with blink firmware
4. FPGA detects blink pattern on pin 43
5. Jamming re-enabled
6. System returns to IDLE state

### Security Testing

#### Test 7: Programming Without Authentication

```bash
# 1. Program FPGA (jamming enabled by default)
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# 2. Try to program target WITHOUT authenticating
picotool load ../../../blink/build/blink.uf2 -f
```

**Expected:** Programming fails due to SWD clock jamming

#### Test 8: Timeout Handling

```bash
# 1. Authenticate
python3 authenticate.py

# 2. Wait more than 10 seconds without programming target
# 3. Try to program target
picotool load ../../../blink/build/blink.uf2 -f
```

**Expected:** Programming fails (FPGA has re-enabled jamming after timeout)

## Troubleshooting

### FPGA Not Responding

**Symptoms:** No UART output, authentication hangs

**Solutions:**
- Check UART connections (pins 2, 3)
- Verify Pico Probe is working: `ls /dev/cu.usbmodem*`
- Re-program FPGA
- Check baud rate (115200)

### Authentication Always Fails

**Symptoms:** FPGA sends AUTH_FAIL

**Solutions:**
- Verify SECRET_KEY matches in both FPGA and laptop code
- Check UART is working (use monitor.py)
- Verify packet format (big-endian 32-bit)

### Jamming Not Working

**Symptoms:** Can program target without authentication

**Solutions:**
- Check pin 4 connection to jamming circuit
- Use pin 38 loopback to verify pin 4 state
- Verify jamming circuit is working
- Check with multimeter: pin 4 should be HIGH (~3.3V) when jammed

### Blink Detection Fails

**Symptoms:** FPGA doesn't detect blink, timeout occurs

**Solutions:**
- Verify target Pico is running blink.c (200ms on/off)
- Check connection from target Pico GPIO to FPGA pin 43
- Use oscilloscope to verify blink timing
- Check if blink frequency matches expected (2.5 Hz)

### Formal Verification Fails

**Symptoms:** SymbiYosys reports assertion failures

**Solutions:**
- Check which assertion failed
- Review state machine logic
- Verify timeout values are correct
- Check for unintended state transitions

## Security Considerations

### Current Implementation

**Strengths:**
- Physical security (jamming physically prevents programming)
- Simple, auditable protocol
- Formal verification of critical properties
- Timeouts prevent indefinite unlocked state

**Weaknesses:**
- XOR encryption is weak (suitable for physical access control only)
- Pre-shared key stored in plaintext in code
- Replay attacks possible (no nonce tracking)
- No mutual authentication (FPGA doesn't prove identity)

### Production Hardening

For production deployment, consider:

1. **Stronger Cryptography:** Use AES or HMAC instead of XOR
2. **Key Storage:** Store key in OTP memory or secure element
3. **Replay Protection:** Track used nonces/challenges
4. **Mutual Authentication:** FPGA proves its identity to laptop
5. **Secure Boot:** Verify FPGA bitstream integrity
6. **Audit Logging:** Log all authentication attempts
7. **Rate Limiting:** Limit failed authentication attempts

## Development Notes

### Modifying the Secret Key

**FPGA (secure_gatekeeper.v):**
```verilog
localparam [31:0] SECRET_KEY = 32'hDEADBEEF;
```

**Laptop (authenticate.py):**
```python
SECRET_KEY = 0xDEADBEEF
```

Both must match exactly.

### Adjusting Timeouts

**secure_gatekeeper.v:**
```verilog
localparam TIMEOUT_5S  = 27'd60_000_000;   // Authentication timeout
localparam TIMEOUT_10S = 27'd120_000_000;  // Programming timeout
```

Calculated as: `timeout_seconds × 12,000,000` (12 MHz clock)

### Changing Blink Pattern

**Target firmware:** Modify `LED_DELAY_MS` in blink.c

**FPGA detector:** Adjust `BLINK_PERIOD_MIN` and `BLINK_PERIOD_MAX` in secure_gatekeeper.v

## License and Credits

This project implements a secure FPGA-gated programming system as specified in the requirements document.

**Hardware:**
- iCEBreaker FPGA: https://github.com/icebreaker-fpga/icebreaker
- Raspberry Pi Pico: https://www.raspberrypi.org/products/raspberry-pi-pico/

**Tools:**
- Yosys, nextpnr, icestorm: Open-source FPGA toolchain
- SymbiYosys: Formal verification
- picotool: Pico programming utility

## Contact and Support

For issues or questions about this implementation, refer to:
- SPECIFICATION.md for technical details
- System logs in monitor.py output
- Formal verification results in sby-* directories
