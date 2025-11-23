# Pin State Transfer Experiment

**Date**: 2025-11-23
**Experiment Directory**: `experiments/20251123-134419-pin-state-transfer/`

## Objective

Create a multi-step experiment that:
1. Reads the state of pin 38 and transmits it via UART
2. Captures the serial output to determine pin 38's state
3. Stores the result
4. Creates a new program that drives pin 46 to match pin 38's state
5. Flashes and verifies the final program

## Hardware Configuration

- **Picoprobe Serial**: `/dev/cu.usbmodem1402`
- **UART TX**: Pin 2 (FPGA transmits via picoprobe)
- **Baud Rate**: 115200
- **Pin 38**: PMOD1B input
- **Pin 46**: PMOD1A output

## Results

**Captured Pin 38 State**: `1` (HIGH)

The state was successfully captured and stored in `pin38_state.txt`.

## Files Generated

### Phase 1: Read Pin 38
- `read_pin38.v` - Verilog module that reads pin 38 and transmits state via UART
- `read_pin38.pcf` - Pin constraints for first program
- `claude-read-pin38.bin` - Compiled bitstream
- `capture_pin_state.py` - Python script to capture and parse serial output
- `pin38_state.txt` - Stored result (`1`)

### Phase 2: Drive Pin 46
- `drive_pin46.v` - Verilog module that drives pin 46 to match stored state
- `drive_pin46.pcf` - Pin constraints for second program
- `claude-drive-pin46.bin` - Compiled bitstream

## Implementation Details

### Read Pin 38 Program

The first program implements a simple UART transmitter that:
- Reads the digital state of pin 38
- Transmits ASCII '0' or '1' every 0.5 seconds
- Uses a state machine with baud rate divider (104 for 115200 baud at 12 MHz)

### Drive Pin 46 Program

The second program:
- Drives pin 46 to constant HIGH (1) to match the captured state of pin 38
- Simple combinational logic: `assign PIN_46 = 1'b1;`

## Verification

Pin 46 is now being driven to HIGH, matching the state that was read from pin 38.

To verify:
- Measure pin 46 with a multimeter (should read ~3.3V)
- Connect pin 46 to an LED with appropriate resistor
- Connect pin 46 to another input and read via UART

## Key Learnings

1. The picoprobe UART uses pins 2 (TX) and 3 (RX), not the built-in FTDI pins
2. The capture script needs to handle byte-by-byte reading for non-line-terminated data
3. Pin 38 (PMOD1B) was reading HIGH in the test setup
