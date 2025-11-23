# Secure FPGA-Gated Programming System - Technical Specification

## System Overview

A security system where an FPGA authenticates a laptop before allowing it to program a Raspberry Pi Pico target device via SWD clock jamming control.

## Design Decisions

### Authentication Algorithm
**Choice: XOR-based Challenge-Response with 32-bit Pre-Shared Key**

Rationale:
- Simple to implement in Verilog (minimal logic gates)
- Adequate security for physical access control scenario
- No complex arithmetic or lookup tables required
- Fast verification (single clock cycle)

### UART Protocol
**Baud Rate:** 115200
**Frame:** 8N1 (8 data bits, no parity, 1 stop bit)
**Packet Format:**

```
[CMD] [DATA0] [DATA1] [DATA2] [DATA3]
```

- CMD: 8-bit command byte
- DATA: 32-bit payload (big-endian)

**Commands:**
- `0x01` - PROG_REQUEST: Laptop requests programming access
- `0x02` - CHALLENGE: FPGA sends 32-bit challenge
- `0x03` - RESPONSE: Laptop sends encrypted response
- `0x04` - AUTH_OK: FPGA grants access
- `0x05` - AUTH_FAIL: FPGA denies access
- `0x06` - STATUS: FPGA status update

### Timing Requirements

**UART RX Timeout:** 5 seconds per command
**Blink Detection Window:** 10 seconds after jamming disabled
**Blink Pattern:** 200ms ON, 200ms OFF (detected via edge counting)

**Blink Detection Logic:**
- Count rising edges on pin 43
- Measure time between edges
- Valid if: 3+ edges detected with ~400ms period (±20% tolerance)
- Verification window: 2 seconds

### State Machine

```
IDLE → CHALLENGE → WAIT_RESPONSE → VERIFY → DISABLE_JAM → WAIT_BLINK → ENABLE_JAM → IDLE
                                      ↓
                                   (fail) → IDLE
```

**States:**

1. **IDLE**: Jamming enabled (pin 4 HIGH), waiting for PROG_REQUEST
2. **CHALLENGE**: Generate and send 32-bit challenge
3. **WAIT_RESPONSE**: Wait for laptop response (5s timeout)
4. **VERIFY**: Check response = challenge XOR key
5. **DISABLE_JAM**: Lower pin 4 (LOW) to allow programming
6. **WAIT_BLINK**: Monitor pin 43 for blink pattern (10s timeout)
7. **ENABLE_JAM**: Raise pin 4 (HIGH) to block programming
8. **TIMEOUT/FAIL**: Return to IDLE with jamming enabled

### Pin Assignments

| Pin | Signal | Direction | Description |
|-----|--------|-----------|-------------|
| 2 | UART_TX | Output | FPGA transmit to laptop via Pico Probe |
| 3 | UART_RX | Input | FPGA receive from laptop via Pico Probe |
| 4 | JAM_CTRL | Output | SWD clock jamming control (HIGH=jam, LOW=allow) |
| 38 | JAM_STATUS | Input | Loopback of pin 4 for verification |
| 43 | BLINK_IN | Input | Target Pico blink pattern detection |

### Security Parameters

**Pre-Shared Key:** `0xDEADBEEF` (configurable parameter)
**Challenge Generation:** Linear Feedback Shift Register (LFSR) for pseudo-random values
**LFSR Polynomial:** x^32 + x^22 + x^2 + x^1 + 1 (maximal length)

### Error Handling

**Timeout Conditions:**
- No response within 5s → Return to IDLE with jamming enabled
- No blink detected within 10s → Return to IDLE with jamming enabled

**Invalid Command:**
- Ignore and remain in current state

**Authentication Failure:**
- Send AUTH_FAIL
- Return to IDLE immediately
- Jamming remains enabled

## Formal Verification Requirements

### Properties to Verify

1. **Safety Properties:**
   - Jamming is always enabled except after successful authentication
   - Pin 4 can only be LOW in DISABLE_JAM and WAIT_BLINK states
   - Authentication must complete before jamming is disabled

2. **Liveness Properties:**
   - System always returns to IDLE state (no deadlocks)
   - Timeouts always trigger state transitions

3. **Security Properties:**
   - Incorrect response never transitions to DISABLE_JAM
   - Jamming re-enables after any error or timeout
   - State machine cannot be bypassed

### Verification Method

Using `sby` (SymbiYosys) with formal verification assertions:
- BMC (Bounded Model Checking) for 100 cycles
- Induction proofs for safety properties
- Cover statements for reachability

## Target Blink Pattern

**From blink.c analysis:**
- LED toggles every 200ms
- Period: 400ms (2.5 Hz)
- Pattern: HIGH → wait 200ms → LOW → wait 200ms → repeat

**FPGA Detection:**
- Monitor rising edges on pin 43
- Count edges over 2-second window
- Expect 5 rising edges (±1 for tolerance)
- Verify timing between edges: 380ms - 420ms

## Laptop Software Requirements

### Authentication Client

**Language:** Python 3
**Dependencies:** pyserial

**Functions:**
1. Send PROG_REQUEST
2. Receive CHALLENGE
3. Compute response = challenge XOR 0xDEADBEEF
4. Send RESPONSE
5. Wait for AUTH_OK or AUTH_FAIL

### Programming Interface

**Method:** Use standard `picotool` or `openocd` for SWD programming
**Timing:** Wait for AUTH_OK before initiating programming sequence

### Monitoring Tools

**Serial Monitor:** Display FPGA status messages
**Pin Verification:** Read STATUS messages to verify pin 4 state during development

## Testing Plan

### Phase 1: UART Communication
- Test TX/RX at 115200 baud
- Verify packet reception and parsing
- Confirm bidirectional communication

### Phase 2: Authentication
- Test challenge generation (LFSR)
- Verify correct response acceptance
- Verify incorrect response rejection

### Phase 3: Jamming Control
- Verify pin 4 HIGH in IDLE
- Verify pin 4 LOW after authentication
- Confirm pin 38 loopback reads correctly

### Phase 4: Blink Detection
- Flash blink.c to target Pico
- Verify FPGA detects 2.5 Hz pattern on pin 43
- Test with incorrect blink rates (should fail)

### Phase 5: Integration
- Complete authentication sequence
- Program target Pico with blink.c
- Verify jamming re-enables after blink detected
- Test full cycle multiple times

### Phase 6: Security Testing
- Attempt programming without authentication (should fail due to jamming)
- Test with wrong key (should fail authentication)
- Test timeout conditions (should return to secured state)

## Implementation Notes

### Clock Divider
- System clock: 12 MHz
- UART bit period: 1/115200 = 8.68 µs
- Clock cycles per bit: 12,000,000 / 115200 = 104.17 ≈ 104 cycles

### Edge Detection
- Synchronize pin 43 input (2-stage flip-flop)
- Detect rising edge: ~sync_pin[1] & sync_pin[0]

### Counter Sizing
- Blink period counter: 400ms × 12 MHz = 4,800,000 cycles → 23 bits
- Timeout counter: 10s × 12 MHz = 120,000,000 cycles → 27 bits

## Success Criteria

1. FPGA successfully authenticates with correct key
2. FPGA rejects authentication with incorrect key
3. Pin 4 controls jamming as specified
4. Blink pattern detection works reliably
5. System returns to secured state after programming
6. All formal verification properties pass
7. System handles timeouts and errors gracefully
