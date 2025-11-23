# Stage 3: Pico Bootloader - RAM Loading

## Purpose
Verify the Pico can receive exactly 256 bytes via UART and store them in RAM at address `0x20001000`.

## LED Behavior
1. **5 fast blinks** - Bootloader ready, waiting for data
2. **Solid ON** - Receiving data
3. **Slow blinking (500ms)** - Success! 256 bytes received

## Building

```bash
mkdir build
cd build
cmake ..
make
```

## Flashing
1. Hold BOOTSEL button on Pico
2. Plug into USB
3. Drag `bootloader.uf2` to RPI-RP2 drive

## Testing

### Method 1: Python Test Script (Recommended)
```bash
# Find your Pico's serial port
ls /dev/tty*    # Look for /dev/ttyACM0 or /dev/tty.usbmodem*

# Send test pattern
python3 test_sender.py /dev/ttyACM0
```

### Method 2: Manual with Serial Terminal
```bash
# Send exactly 256 bytes of any data
dd if=/dev/zero bs=256 count=1 > /dev/ttyACM0
```

### Method 3: FPGA Stage 5 (preferred for full system test)
Connect FPGA from Stage 5 which sends 256 bytes automatically.

## Hardware Setup

```
USB-Serial OR FPGA     Pico
───────────────────    ────
TX            ───────→ GP0 (Pin 1)  [UART RX]
GND           ───────→ GND (Pin 3)  [Ground]
```

## Success Criteria
- [ ] 5 fast blinks on startup (ready signal)
- [ ] LED stays solid during reception
- [ ] LED blinks slowly after receiving 256 bytes
- [ ] No errors or hangs

## Memory Verification (Optional)
To verify data actually went into RAM, you could use a debugger:
```
(gdb) x/256xb 0x20001000
```

Should show the received bytes starting at that address.

## Troubleshooting
- **LED never stops fast blinking**: No data being received, check connections
- **LED stays solid forever**: Not receiving all 256 bytes, check sender
- **Pico resets**: Check power supply, ensure stable connection

## Next Steps
Once this works, Stage 4 will create an actual executable program to load into this RAM and execute!
