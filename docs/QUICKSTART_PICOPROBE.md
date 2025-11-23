# PicoProbe Quick Start

Get up and running with PicoProbe in 5 minutes.

## What You Need

- 2× Raspberry Pi Pico boards
- 3× jumper wires
- 2× USB cables

## Step 1: Flash PicoProbe Firmware (2 minutes)

1. **Download firmware:**
   ```bash
   wget https://github.com/raspberrypi/picoprobe/releases/latest/download/picoprobe.uf2
   ```

2. **Flash to Pico #1:**
   - Hold BOOTSEL button on Pico #1
   - Connect USB while holding BOOTSEL
   - Drag `picoprobe.uf2` to RPI-RP2 drive
   - Wait for Pico to reboot (LED will be solid)

## Step 2: Wire the Boards (1 minute)

```
Pico #1 (Probe)          Pico #2 (Target)
───────────────          ────────────────
GP2              ──────→ Debug Pin 1 (SWCLK)
GP3              ──────→ Debug Pin 3 (SWDIO)
GND              ──────→ GND
```

**Target Debug Pins**: Small 3-pin header between USB and pin 40
- Pin 1 (left): SWCLK
- Pin 2 (middle): GND
- Pin 3 (right): SWDIO

**Power both Picos**: Connect USB to both boards.

## Step 3: Install OpenOCD (1 minute)

```bash
# macOS
brew install openocd

# Linux
sudo apt install openocd
```

## Step 4: Test Connection (30 seconds)

```bash
cd /path/to/project_gabriel
openocd -f openocd.cfg -c "init" -c "targets" -c "exit"
```

**Expected output:**
```
    TargetName         Type       Endian TapName            State
--  ------------------ ---------- ------ ------------------ ------------
 0* rp2040.core0       cortex_m   little rp2040.dap          running
 1  rp2040.core1       cortex_m   little rp2040.dap          running
```

✅ **Success!** Your PicoProbe is working.

## Step 5: Flash Your Firmware (30 seconds)

### Method 1: Using the helper script

```bash
./flash_with_picoprobe.sh /path/to/your/firmware.elf
```

### Method 2: Direct OpenOCD command

```bash
openocd -f openocd.cfg -c "program firmware.elf verify reset exit"
```

**That's it!** Your target Pico is now programmed via SWD.

## Quick Commands

```bash
# Flash firmware
./flash_with_picoprobe.sh sketch.elf

# Test connection
openocd -f openocd.cfg -c "init" -c "targets" -c "exit"

# Start debug server (for GDB)
openocd -f openocd.cfg
```

## Troubleshooting

### "Error: unable to find CMSIS-DAP device"
- Check USB cable to Pico #1 (probe)
- Verify PicoProbe firmware is installed
- Try different USB port

### "Error: Failed to connect to target"
- Check wiring (especially GND!)
- Power on Pico #2 (target)
- Verify solid connections on debug pins

### Still having issues?
See [PICOPROBE_SETUP.md](PICOPROBE_SETUP.md) for detailed troubleshooting.

## Next Steps

- **Debug with GDB**: See [PICOPROBE_SETUP.md](PICOPROBE_SETUP.md#debugging-with-gdb)
- **Serial output**: PicoProbe provides USB-UART on GP4/GP5
- **Arduino integration**: Find `.elf` files in Arduino's verbose output

## Why PicoProbe?

✅ Official Raspberry Pi solution
✅ No BOOTSEL button needed
✅ Industry-standard CMSIS-DAP
✅ Full debugging support (breakpoints, GDB)
✅ Much faster than custom solutions
✅ Free (just needs a spare Pico)

Enjoy your $4 debug probe! 🎉
