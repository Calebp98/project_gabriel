# PicoProbe Setup Guide

This guide shows how to use a Raspberry Pi Pico as a debug probe (PicoProbe) to program another Pico via SWD.

## What is PicoProbe?

PicoProbe is Raspberry Pi's official debug probe firmware for the Pico. It turns one Pico into a CMSIS-DAP compliant debug probe that can program and debug other RP2040 boards via SWD. It's much more robust than a custom bridge and works with standard tools like OpenOCD and GDB.

## Hardware Setup

### Required Hardware
- **Pico #1**: Debug probe (will run PicoProbe firmware)
- **Pico #2**: Target board (the one you want to program)
- **3 jumper wires**: For SWD connections
- **2 USB cables**: One for each Pico

### Wiring Connections

```
Pico #1 (Probe)          Pico #2 (Target)
───────────────          ────────────────
GP2 (SWCLK)      ──────→ SWCLK (debug pin 1 or GPIO 24)
GP3 (SWDIO)      ──────→ SWDIO (debug pin 3 or GPIO 25)
GND (any GND)    ──────→ GND
[USB to laptop]          [USB for power]
```

### Target Pico Debug Connector

The target Pico has a 3-pin SWD debug header (small holes between USB connector and pin 40):

```
┌─────────┐
│  USB-C  │
└─────────┘
  │ │ │     <- Debug connector (view from top)
  1 2 3

1. SWCLK (left)
2. GND (middle)
3. SWDIO (right)
```

**Tip**: Use fine jumper wires or solder header pins for reliable connections.

Alternatively, use the GPIO pins directly:
- SWCLK = GPIO 24 (physical pin 29)
- SWDIO = GPIO 25 (physical pin 34)
- GND = Any GND pin

## Installing PicoProbe Firmware

### Method 1: Pre-built Binary (Easiest)

1. **Download the latest PicoProbe firmware:**
   ```bash
   wget https://github.com/raspberrypi/picoprobe/releases/latest/download/picoprobe.uf2
   ```

   Or download manually from: https://github.com/raspberrypi/picoprobe/releases

2. **Flash to Pico #1:**
   - Hold BOOTSEL button on Pico #1 while connecting USB
   - Pico appears as USB mass storage device (RPI-RP2)
   - Drag and drop `picoprobe.uf2` to the drive
   - Pico will reboot automatically

3. **Verify installation:**
   ```bash
   # macOS/Linux
   ls /dev/cu.usbmodem*
   # Should show something like: /dev/cu.usbmodem142101

   # Linux
   lsusb | grep CMSIS-DAP
   # Should show: "CMSIS-DAP v2 interface"
   ```

### Method 2: Build from Source

If you want the latest features or need to customize:

```bash
# Clone the repository
git clone https://github.com/raspberrypi/picoprobe.git
cd picoprobe

# Install dependencies (requires pico-sdk)
export PICO_SDK_PATH=/path/to/pico-sdk

# Build
mkdir build
cd build
cmake ..
make

# Flash picoprobe.uf2 to Pico #1 as described above
```

## Installing OpenOCD

OpenOCD (Open On-Chip Debugger) is the software that communicates with PicoProbe.

### macOS
```bash
brew install openocd
```

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install openocd
```

### Verify Installation
```bash
openocd --version
# Should show version 0.11.0 or newer
```

## OpenOCD Configuration

Create a configuration file for your setup:

### Option 1: Using Raspberry Pi's Official Config

The Pico SDK includes OpenOCD configs. If you have pico-sdk installed:

```bash
# Test connection
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000"
```

### Option 2: Custom Configuration File

Create `openocd.cfg` in your project:

```tcl
# Interface configuration for PicoProbe
source [find interface/cmsis-dap.cfg]

# Target configuration for RP2040
source [find target/rp2040.cfg]

# Set adapter speed (kHz)
adapter speed 5000

# Optional: Enable reset support
# reset_config none
```

Then run simply:
```bash
openocd -f openocd.cfg
```

## Programming the Target Pico

### Quick Test: Read Chip Info

```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000" \
  -c "init" \
  -c "targets" \
  -c "exit"
```

Expected output should show:
```
    TargetName         Type       Endian TapName            State
--  ------------------ ---------- ------ ------------------ ------------
 0* rp2040.core0       cortex_m   little rp2040.dap          running
 1  rp2040.core1       cortex_m   little rp2040.dap          running
```

### Flash a UF2 File

Most Arduino/Pico projects compile to `.uf2` format. To flash via SWD:

1. **Convert UF2 to binary** (if needed):
   ```bash
   # UF2 can be flashed directly with picotool, or converted to .bin for OpenOCD
   # We'll use .elf files which Arduino IDE also generates
   ```

2. **Flash using OpenOCD** (with .elf or .bin file):
   ```bash
   openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
     -c "adapter speed 5000" \
     -c "program firmware.elf verify reset exit"
   ```

### Flash a Binary File

If you have a raw binary (e.g., `firmware.bin`):

```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000" \
  -c "program firmware.bin 0x10000000 verify reset exit"
```

Note: `0x10000000` is the start of flash memory on RP2040.

## Arduino IDE Integration

### Finding Your Compiled Binary

When Arduino compiles a sketch, it creates files in a temp directory. To find them:

1. **Enable verbose output:**
   - Arduino IDE → Preferences → "Show verbose output during: compilation"

2. **Compile your sketch** - look for lines like:
   ```
   /path/to/sketch.ino.elf
   /path/to/sketch.ino.bin
   ```

3. **Flash using OpenOCD:**
   ```bash
   openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
     -c "adapter speed 5000" \
     -c "program /path/to/sketch.ino.elf verify reset exit"
   ```

### Automated Flash Script

Create `flash.sh`:

```bash
#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./flash.sh <firmware.elf>"
  exit 1
fi

openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000" \
  -c "program $1 verify reset exit"
```

Make it executable:
```bash
chmod +x flash.sh
./flash.sh /path/to/sketch.ino.elf
```

## Debugging with GDB

PicoProbe also supports interactive debugging:

### Terminal 1: Start OpenOCD Server
```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000"
```

Leave this running in the background.

### Terminal 2: Connect GDB
```bash
arm-none-eabi-gdb firmware.elf
```

In GDB:
```gdb
# Connect to OpenOCD
target remote localhost:3333

# Load program
load

# Reset and halt
monitor reset init

# Set breakpoint
break main

# Run
continue

# Standard GDB commands work now
step
next
print variable_name
backtrace
```

## Troubleshooting

### "Error: unable to find CMSIS-DAP device"

**Solutions:**
1. Check USB cable is connected to Pico #1 (probe)
2. Verify PicoProbe firmware is installed (Pico LED should be on)
3. Try a different USB port
4. On Linux: Check permissions (`sudo openocd ...` or add udev rules)

### "Error: Failed to connect to target"

**Solutions:**
1. **Check wiring**: SWCLK, SWDIO, and GND connected?
2. **Power target**: Is Pico #2 powered on? Connect its USB
3. **Try slower speed**: Change `adapter speed 5000` to `adapter speed 1000`
4. **Check with multimeter**: Ensure continuity on SWD wires

### "Error: SWD/JTAG communication failure"

**Solutions:**
1. Power cycle both Picos
2. Ensure solid connections (wiggle test)
3. Try different ground connection
4. For debug connector: solder header pins for reliable contact

### Linux: Permission Denied

Add udev rules for PicoProbe:

```bash
# Create udev rule
sudo tee /etc/udev/rules.d/99-picoprobe.rules > /dev/null <<EOF
# CMSIS-DAP for PicoProbe
ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000c", MODE="0666"
EOF

# Reload rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then reconnect the PicoProbe.

## LED Indicators

**PicoProbe (Pico #1):**
- **Solid ON**: Ready and idle
- **Blinking**: Active communication with target

**Target (Pico #2):**
- Depends on your program

## Pinout Reference

### PicoProbe Default Pins (Pico #1)

```
GP2  → SWCLK (Clock output to target)
GP3  → SWDIO (Data I/O to target)
GP4  → UART TX (optional: target serial output)
GP5  → UART RX (optional: target serial input)
GND  → GND
```

**Note**: PicoProbe also provides a USB-to-UART bridge on GP4/GP5, which you can use to get serial output from your target while debugging!

### Target Pico Pins (Pico #2)

```
SWCLK Debug Pin 1 or GPIO 24 (pin 29)
SWDIO Debug Pin 3 or GPIO 25 (pin 34)
GND   Any GND pin
```

## Advantages Over Custom Bridge

✅ **Industry standard**: CMSIS-DAP compliant
✅ **Well-tested**: Used by thousands of developers
✅ **Full debug support**: Breakpoints, single-step, GDB
✅ **Faster**: Optimized communication protocol
✅ **Built-in UART**: Get serial output while debugging
✅ **OpenOCD support**: Works with standard tools
✅ **No Python needed**: Direct flashing with OpenOCD
✅ **Active maintenance**: Official Raspberry Pi project

## References

- [PicoProbe GitHub Repository](https://github.com/raspberrypi/picoprobe)
- [Getting Started with Pico (Appendix A: Debug Probe)](https://datasheets.raspberrypi.com/pico/getting-started-with-pico.pdf)
- [RP2040 Datasheet - Chapter 2: SWD](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf)
- [OpenOCD User Guide](https://openocd.org/doc/html/index.html)
- [ARM CMSIS-DAP Specification](https://arm-software.github.io/CMSIS_5/DAP/html/index.html)

## Quick Reference Commands

```bash
# Flash firmware
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000" \
  -c "program firmware.elf verify reset exit"

# Start debug server
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000"

# Connect GDB
arm-none-eabi-gdb firmware.elf
> target remote localhost:3333
> load
> continue

# Read chip info
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "adapter speed 5000" -c "init" -c "targets" -c "exit"
```
