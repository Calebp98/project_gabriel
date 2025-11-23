# Quick Testing Guide

## Prerequisites

1. **Hardware Setup:**
   - iCEBreaker FPGA connected via USB
   - Pico Probe connected via USB (acts as UART bridge)
   - Target Pico connected to Pico Probe via SWD
   - Jamming circuit connected between FPGA pin 4 and target Pico SWD clock

2. **Software Dependencies:**
   ```bash
   # Python dependencies
   pip3 install pyserial

   # FPGA toolchain (should already be installed)
   # yosys, nextpnr-ice40, icestorm

   # Optional: Formal verification
   # brew install symbiyosys boolector

   # Pico programming tool
   # brew install picotool
   ```

## Test Sequence

### Test 1: Build and Program FPGA (5 minutes)

This test verifies the FPGA toolchain and uploads the gatekeeper design.

```bash
cd /path/to/claude-fpga-helpers/experiments/2025-01-23-secure-fpga-gatekeeper

# Build and program FPGA
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper
```

**Expected Output:**
```
Building FPGA bitstream...
✓ Synthesis complete
✓ Place and route complete
✓ Programming FPGA...
✓ Done
```

**Success Criteria:**
- No synthesis errors
- FPGA programmed successfully
- Green LED on iCEBreaker indicates power

### Test 2: UART Communication (2 minutes)

This test verifies UART connectivity between laptop and FPGA.

```bash
# Terminal 1: Start monitor
./monitor.py

# Keep this running to observe UART traffic
```

**Expected Output:**
```
Connected to /dev/cu.usbmodem1402 at 115200 baud
Monitoring FPGA output... (Ctrl+C to stop)
```

**Success Criteria:**
- No connection errors
- Monitor tool is receiving data (may be idle initially)

### Test 3: Authentication Success (3 minutes)

This test verifies the challenge-response authentication protocol.

```bash
# Terminal 2: Run authentication
./authenticate.py
```

**Expected Output:**
```
=== Starting Authentication ===

[1/4] Sending programming request...
Sent: CMD=0x01

[2/4] Waiting for challenge...
Received: CMD=0x02 DATA=0x12345678
Challenge received: 0x12345678

[3/4] Computing response...
Response computed: 0xCCCCBBA7

[3/4] Sending response...
Sent: CMD=0x03 DATA=0xCCCCBBA7

[4/4] Waiting for authentication result...
Received: CMD=0x04

✓ SUCCESS: Authentication approved!
FPGA has disabled jamming - you may now program the target Pico
```

**In Terminal 1 (monitor.py), you should see:**
```
[0.50s] Received 1 bytes:
  01
  → Command: PROG_REQUEST

[0.52s] Received 5 bytes:
  02 12 34 56 78
  → Command: CHALLENGE
  → Data: 0x12345678

[0.60s] Received 5 bytes:
  03 CC CC BB A7
  → Command: RESPONSE
  → Data: 0xCCCCBBA7

[0.61s] Received 1 bytes:
  04
  → Command: AUTH_OK
```

**Success Criteria:**
- Authentication completes successfully
- Challenge value is random (changes each time)
- Response = Challenge XOR 0xDEADBEEF
- AUTH_OK received
- FPGA pin 4 should go LOW (use multimeter or oscilloscope to verify)

### Test 4: Authentication Failure (2 minutes)

This test verifies that incorrect authentication is rejected.

**Modify authenticate.py temporarily:**
```python
# Line 13: Change SECRET_KEY
SECRET_KEY = 0xBADC0FFE  # Wrong key for testing
```

```bash
./authenticate.py
```

**Expected Output:**
```
=== Starting Authentication ===
[1/4] Sending programming request...
[2/4] Waiting for challenge...
Challenge received: 0x12345678
[3/4] Computing response...
Response computed: 0xA8F6B886
[3/4] Sending response...
[4/4] Waiting for authentication result...

✗ FAILURE: Authentication denied!
Incorrect response - check SECRET_KEY
```

**Success Criteria:**
- FPGA sends AUTH_FAIL (0x05)
- Pin 4 remains HIGH (jamming still enabled)
- System returns to IDLE state

**Important:** Restore the correct key after testing:
```python
SECRET_KEY = 0xDEADBEEF  # Correct key
```

### Test 5: Jamming Verification (5 minutes)

This test verifies that the jamming control works correctly.

**Setup:** Connect an LED (with 330Ω resistor) between FPGA pin 4 and GND, or use a multimeter.

```bash
# 1. Program FPGA (if not already)
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# Observe: Pin 4 HIGH (~3.3V) - LED on / jamming enabled

# 2. Authenticate
./authenticate.py

# Observe: Pin 4 LOW (0V) - LED off / jamming disabled

# 3. Wait 10 seconds (timeout)
sleep 10

# Observe: Pin 4 HIGH again - LED on / jamming re-enabled
```

**Success Criteria:**
- Pin 4 HIGH in IDLE state
- Pin 4 LOW after authentication
- Pin 4 returns HIGH after timeout
- Pin 38 (loopback) reads same value as pin 4

### Test 6: Blink Detection (10 minutes)

This test verifies that the FPGA can detect the blink pattern from the target Pico.

**Prerequisites:** Target Pico must be programmed with blink.c (200ms on/off)

```bash
# 1. Ensure target Pico is running blink firmware
# If not, build and flash it first:
cd ../../../blink
./build_blink.sh  # Use appropriate build script for your setup

# 2. Connect target Pico GPIO (running blink) to FPGA pin 43
# Use a jumper wire from target Pico LED pin to iCEBreaker pin 43

# 3. Return to experiment directory
cd /path/to/experiments/2025-01-23-secure-fpga-gatekeeper

# 4. Start monitoring
./monitor.py &

# 5. Authenticate (this starts blink detection)
./authenticate.py

# 6. Observe FPGA detecting blink pattern
# Within 2 seconds, FPGA should detect the 2.5 Hz blink
# Pin 4 will go HIGH again (jamming re-enabled)
```

**Success Criteria:**
- FPGA detects valid blink pattern (4+ edges with ~400ms period)
- Jamming re-enables automatically after blink detected
- If no valid blink, timeout after 10 seconds and jamming re-enables anyway

### Test 7: Full Integration (15 minutes)

This test runs the complete secure programming workflow.

```bash
# Run the complete sequence
./run_full_sequence.sh
```

**The script will:**
1. Build and program FPGA
2. Authenticate with FPGA
3. Program target Pico with blink firmware
4. Wait for FPGA to detect blink and re-secure

**Expected Output:**
```
==========================================================
Secure FPGA Gatekeeper - Complete Programming Sequence
==========================================================

Step 1: Programming FPGA
✓ FPGA programmed successfully

Step 2: Authenticating with FPGA
✓ Authentication successful

Step 3: Programming Target Pico
✓ Target Pico programmed

Step 4: Verifying Operation
The FPGA should now:
  1. Detect the blink pattern on pin 43
  2. Re-enable jamming (pin 4 HIGH)
  3. Return to IDLE state

==========================================================
Sequence Complete!
==========================================================
```

**Success Criteria:**
- All steps complete without errors
- Target Pico is running blink firmware
- FPGA is back in secured state (jamming enabled)
- System ready for next programming cycle

### Test 8: Security Test - Unauthorized Programming (5 minutes)

This test verifies that programming is blocked without authentication.

```bash
# 1. Reset FPGA (or just wait for jamming to re-enable)
../../../fpga_full.sh secure_gatekeeper.v secure_gatekeeper.pcf secure-gatekeeper

# 2. Try to program target WITHOUT authenticating
picotool load ../../../blink/build/blink.uf2 -f
```

**Expected Result:**
```
ERROR: Failed to program device
SWD communication error
```

**Success Criteria:**
- Programming attempt fails
- SWD communication is blocked by jamming
- FPGA remains in IDLE state with jamming enabled

### Test 9: Timeout Test (2 minutes)

This test verifies timeout behavior.

```bash
# 1. Authenticate successfully
./authenticate.py

# 2. Wait more than 10 seconds without programming
sleep 12

# 3. Try to program (should fail - jamming re-enabled)
picotool load ../../../blink/build/blink.uf2 -f
```

**Expected Result:**
- Programming fails due to jamming
- FPGA timeout worked correctly

**Success Criteria:**
- FPGA returns to secured state after 10s timeout
- Must re-authenticate to program again

## Formal Verification (Optional, 10 minutes)

If you have SymbiYosys installed:

```bash
# Run formal verification
sby -f secure_gatekeeper.sby

# Check results
cat sby-*/logfile.txt
```

**Expected Output:**
```
SBY  [bmc] engine_0: Status: PASS
SBY  [cover] engine_0: Status: PASS
SBY  [prove] engine_0: Status: PASS
```

**Success Criteria:**
- All BMC assertions pass (no counterexamples found)
- All cover statements reachable
- All proofs pass

## Common Issues and Solutions

### Issue: "No such file or directory: /dev/cu.usbmodem1402"

**Solution:** Find the correct port:
```bash
ls /dev/cu.usbmodem*
# Use the correct port in your commands:
./authenticate.py /dev/cu.usbmodem14201
```

### Issue: "Authentication timeout - no response"

**Possible causes:**
1. FPGA not programmed correctly - re-flash FPGA
2. Wrong UART port - check port with `ls /dev/cu.*`
3. Bad UART connection - check Pico Probe wiring
4. Baud rate mismatch - verify 115200 in all components

### Issue: "Authentication denied"

**Possible causes:**
1. Wrong SECRET_KEY - verify both FPGA and Python have `0xDEADBEEF`
2. Endianness mismatch - check packet format is big-endian
3. Packet corruption - check UART wiring and grounding

### Issue: "Blink detection fails"

**Possible causes:**
1. Target Pico not running blink firmware
2. Wrong GPIO pin connected to FPGA pin 43
3. Blink timing doesn't match (should be 200ms on/off)
4. Weak or noisy signal - add pull-up resistor

### Issue: "Programming succeeds when it should be blocked"

**Possible causes:**
1. Jamming circuit not working - test with multimeter
2. Pin 4 not connected to jamming circuit
3. External jamming hardware issue

## Next Steps

After completing all tests:

1. **Document Results:** Record test outcomes, timing measurements, and any issues
2. **Hardware Integration:** Build permanent jamming circuit (if using breadboard)
3. **Production Hardening:** See README.md "Security Considerations" section
4. **Custom Firmware:** Replace blink.c with your target application
5. **Key Management:** Change SECRET_KEY for your deployment

## Test Completion Checklist

- [ ] Test 1: FPGA programming works
- [ ] Test 2: UART communication established
- [ ] Test 3: Authentication succeeds with correct key
- [ ] Test 4: Authentication fails with wrong key
- [ ] Test 5: Jamming control verified (pin 4 HIGH/LOW)
- [ ] Test 6: Blink detection works
- [ ] Test 7: Full integration successful
- [ ] Test 8: Unauthorized programming blocked
- [ ] Test 9: Timeout behavior correct
- [ ] Formal verification passes (optional)

## Support

For detailed technical information, see:
- `README.md` - Complete system documentation
- `SPECIFICATION.md` - Protocol and design specifications
- Monitor output for debugging UART communication
- Formal verification logs in `sby-*` directories
