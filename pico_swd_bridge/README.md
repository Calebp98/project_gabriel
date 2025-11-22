# Pico SWD Bridge

A simple USB-to-SWD (Serial Wire Debug) bridge firmware for Raspberry Pi Pico. Acts as a "dumb" GPIO converter, allowing a laptop to program another Pico via SWD.

## Hardware Setup

### Wiring

```
Pico #1 (Bridge)         Pico #2 (Target)
────────────────         ────────────────
GP2 (SWCLK)      ──────→ SWCLK (GPIO 24 / debug pin 1)
GP3 (SWDIO)      ──────→ SWDIO (GPIO 25 / debug pin 3)
GND              ──────→ GND
USB              ──────→ Laptop (power + serial)
```

### Target Pico Debug Pins

The target Pico has a 3-pin debug header between the USB connector and pin 40:
```
1. SWCLK (left)
2. GND (middle)
3. SWDIO (right)
```

Alternatively, use the GPIO pins directly:
- SWCLK = GPIO 24 (pin 29)
- SWDIO = GPIO 25 (pin 34)

## Installation

1. Open `pico_swd_bridge.ino` in Arduino IDE
2. Select **Board**: Raspberry Pi Pico
3. Select **Port**: Your Pico's USB port
4. Upload to Pico #1 (the one that will be the bridge)

## Protocol

### Basic Commands (ASCII over USB Serial at 115200 baud)

| Command | Description |
|---------|-------------|
| `C` | Set SWCLK HIGH |
| `c` | Set SWCLK LOW |
| `D` | Set SWDIO HIGH (output mode) |
| `d` | Set SWDIO LOW (output mode) |
| `I` | Set SWDIO to INPUT mode |
| `O` | Set SWDIO to OUTPUT mode |
| `R` | Read SWDIO state (returns '1' or '0') |
| `r` | SWD line reset (50+ clock pulses) |
| `?` | Get version/status |

### Buffered Commands (for speed)

| Command | Format | Description |
|---------|--------|-------------|
| `W` | `W<count><bit0><bit1>...` | Write multiple bits (each bit is '0' or '1' char) |
| `X` | `X<count>` | Read multiple bits (returns '0'/'1' chars + newline) |
| `B` | `B<byte>` | Write byte LSB-first (fast byte write) |
| `b` | `b` | Read byte LSB-first (fast byte read) |

### Example Usage (Python)

```python
import serial

# Open serial connection to bridge Pico
swd = serial.Serial('/dev/cu.usbmodem1301', 115200, timeout=1)

# Wait for ready message
print(swd.readline().decode())  # "SWD Bridge Ready"

# Get status
swd.write(b'?')
print(swd.read_until(b'\n').decode())

# Perform SWD line reset
swd.write(b'r')
print(swd.read_until(b'\n').decode())  # "OK"

# Write a bit
swd.write(b'O')  # Set SWDIO to output
swd.write(b'D')  # Set SWDIO high
swd.write(b'C')  # Clock high
swd.write(b'c')  # Clock low

# Read a bit
swd.write(b'I')  # Set SWDIO to input
swd.write(b'C')  # Clock high
bit = swd.read(1)  # Read '0' or '1'
swd.write(b'c')  # Clock low

# Close connection
swd.close()
```

## Pin Configuration

- **SWCLK**: GP2 (physical pin 4)
- **SWDIO**: GP3 (physical pin 5)
- **LED**: Built-in LED (indicates ready state)

To change pins, modify the defines at the top of the sketch:
```c
#define SWCLK_PIN 2
#define SWDIO_PIN 3
```

## Timing

Default clock delay: 1 microsecond between edges

This gives approximately:
- Clock frequency: ~500 kHz (with overhead)
- Suitable for SWD which typically runs 1-10 MHz

For faster operation, reduce `SWD_DELAY_US` (minimum: 0 for fastest possible).

## Testing

### Quick Test
1. Upload firmware to bridge Pico
2. Open Arduino Serial Monitor at 115200 baud
3. Type `?` - should see version info
4. Type `r` - should see "OK" (line reset)

### With Target Pico Connected
1. Wire bridge Pico to target Pico as shown above
2. Run Python test script (see example above)
3. Use laptop-side SWD library to program target

## Features

✅ Simple ASCII protocol (easy to debug)
✅ Buffered operations for speed
✅ Byte-oriented commands (faster than bit-by-bit)
✅ Built-in SWD line reset
✅ Status/version reporting
✅ ~500 kHz operation (adequate for SWD)

## Limitations

⚠️ No protocol knowledge - purely GPIO control
⚠️ Timing is software-based (not cycle-accurate)
⚠️ USB latency affects speed (~1ms round-trip)
⚠️ Not as fast as dedicated debug probes (but good enough!)

## Next Steps

This bridge works with the companion Python SWD library to:
1. Read RP2040 IDCODE (verify communication)
2. Access memory via SWD
3. Flash firmware to target Pico
4. Full SWD programming without BOOTSEL button

See the main project README for Python library usage.
