# SWD Programmer

Python library for programming Raspberry Pi Pico via SWD (Serial Wire Debug) using a second Pico as a simple USB-to-GPIO bridge.

## Architecture

```
Laptop (Python)         Pico #1 (Bridge)        Pico #2 (Target)
───────────────         ────────────────        ────────────────
SWD Protocol    ──USB──→ GPIO Bridge     ──SWD──→ RP2040
swd_protocol.py         pico_swd_bridge         (programmed)
swd_bridge.py           (dumb converter)
```

## Files

- **swd_bridge.py** - Low-level bridge interface (serial commands to GPIO)
- **swd_protocol.py** - ARM SWD protocol implementation
- **test_swd.py** - Simple test script to verify communication
- **README.md** - This file

## Requirements

```bash
pip install pyserial
```

## Hardware Setup

### Wiring

```
Pico #1 (Bridge)         Pico #2 (Target)
────────────────         ────────────────
GP2 (SWCLK)      ──────→ GPIO 24 (SWCLK) or debug pin 1
GP3 (SWDIO)      ──────→ GPIO 25 (SWDIO) or debug pin 3
GND              ──────→ GND
USB              ──────→ Laptop
```

### Target Pico Debug Pins

The target Pico has a 3-pin debug header (tiny holes between USB and pin 40):
1. SWCLK (left)
2. GND (middle)
3. SWDIO (right)

Or use regular GPIO pins:
- SWCLK = GPIO 24 (physical pin 29)
- SWDIO = GPIO 25 (physical pin 34)

### Important Notes

⚠️ **Both Picos need power:**
- Bridge Pico: Powered via USB from laptop
- Target Pico: Can be powered from its own USB or from bridge Pico's VBUS pin
- **Easiest**: Connect target Pico's USB to power it

⚠️ **Don't connect VBUS between Picos if both have USB connected** - only connect GND, SWCLK, SWDIO

## Quick Start

### 1. Upload Bridge Firmware

First, program Pico #1 with the bridge firmware:

```bash
cd ../pico_swd_bridge
# Upload pico_swd_bridge.ino via Arduino IDE or CLI
```

### 2. Connect Hardware

Wire Pico #1 (bridge) to Pico #2 (target) as shown above.

### 3. Test Communication

```bash
cd swd_programmer
python test_swd.py /dev/cu.usbmodem1301
```

Replace `/dev/cu.usbmodem1301` with your bridge Pico's serial port.

### Expected Output

```
============================================================
SWD Communication Test
============================================================
Port: /dev/cu.usbmodem1301

Step 1: Connecting to SWD bridge...
✓ Connected

Step 2: Switching to SWD mode...
✓ SWD mode activated

Step 3: Reading IDCODE...
✓ IDCODE: 0x0BC12477

IDCODE Details:
  Version:  0
  PartNo:   0x0001 (RP2040 - Correct!)
  Designer: 0x23B (ARM Ltd - Correct!)

============================================================
SUCCESS! SWD communication is working!
============================================================
```

## Usage Examples

### Basic SWD Communication

```python
from swd_bridge import SWDBridge
from swd_protocol import SWDProtocol

# Connect to bridge
with SWDBridge('/dev/cu.usbmodem1301') as bridge:
    # Create SWD protocol handler
    swd = SWDProtocol(bridge)

    # Initialize SWD
    swd.switch_to_swd()

    # Read IDCODE
    idcode = swd.read_idcode()
    print(f"IDCODE: 0x{idcode:08X}")
```

### Low-Level Bridge Control

```python
from swd_bridge import SWDBridge

with SWDBridge('/dev/cu.usbmodem1301') as bridge:
    # Perform line reset
    bridge.line_reset()

    # Write individual bits
    bridge.write_bit(True)   # Write '1'
    bridge.write_bit(False)  # Write '0'

    # Write multiple bits (faster)
    bridge.write_bits('10110011')

    # Write bytes
    bridge.write_byte(0xAB)

    # Read byte
    data = bridge.read_byte()
```

## SWD Protocol Overview

### Frame Format

SWD uses packet-based communication:

1. **Request (8 bits)**
   - Start bit (1)
   - AP/DP# (1=AP, 0=DP)
   - R/W# (1=Read, 0=Write)
   - Address[3:2]
   - Parity
   - Stop bit (0)
   - Park bit (1)

2. **ACK (3 bits)**
   - OK = 001
   - WAIT = 010
   - FAULT = 100

3. **Data (33 bits)**
   - 32-bit value (LSB first)
   - Parity bit

### Key Concepts

- **Debug Port (DP)**: Gateway to debug system
- **Access Port (AP)**: Interface to target memory/peripherals
- **IDCODE**: Identification register (first thing to read)

## Troubleshooting

### "Failed to read IDCODE"

1. **Check wiring:**
   - SWCLK connected?
   - SWDIO connected?
   - GND connected?

2. **Check power:**
   - Is target Pico powered on?
   - Try connecting target's USB

3. **Check bridge:**
   - Is bridge firmware uploaded?
   - Try running: `python swd_bridge.py /dev/cu.usbmodem1301`

### "No response from bridge"

- Wrong serial port?
- Bridge not programmed?
- USB cable issue?

### Slow performance

This is expected! USB serial has latency (~1-10ms round trip). For production use:
- Consider dedicated debug probe ($12-60)
- Or optimize with buffered commands (implemented in swd_bridge.py)

## Current Capabilities

✅ SWD line reset
✅ JTAG-to-SWD switching
✅ IDCODE reading
✅ Debug Port register access
✅ Access Port register access
❌ Memory read/write (next step)
❌ CPU halt/resume (next step)
❌ Flash programming (next step)

## Next Steps

To complete the programmer, we need to add:

1. **Memory Operations**
   - Read/write RAM and flash via AHB-AP
   - Memory-mapped register access

2. **CPU Control**
   - Halt processor
   - Set breakpoints
   - Single-step execution
   - Resume execution

3. **Flash Programming**
   - Parse `.uf2` files (Arduino output)
   - Erase flash sectors
   - Write firmware
   - Verify programming

4. **Arduino Integration**
   - Auto-detect compiled `.uf2` from Arduino
   - One-command flash from Arduino IDE

## References

- [ARM Debug Interface Architecture Specification](https://developer.arm.com/documentation/ihi0031/latest/)
- [RP2040 Datasheet](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf) - Chapter 2: SWD
- [Cortex-M0+ Technical Reference](https://developer.arm.com/documentation/ddi0484/latest/)

## License

MIT - See project root LICENSE file
