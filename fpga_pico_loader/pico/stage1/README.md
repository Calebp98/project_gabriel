# Stage 1: Basic UART Reception Test

## Purpose
Verify the Pico can receive UART data on GP0 before involving the FPGA.

## Hardware Setup
- Raspberry Pi Pico only
- Optional: USB-to-Serial adapter (3.3V) connected to GP0

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
3. Drag `uart_test.uf2` to RPI-RP2 drive

## Testing

### Method 1: Using a USB-Serial Adapter
```
USB-Serial (3.3V)     Pico
─────────────────     ────
TX           ───────→ GP0 (Pin 1)
GND          ───────→ GND (Pin 3)
```

1. Open serial terminal at 115200 baud
2. Type any characters
3. **Expected**: LED toggles with each character

### Method 2: Direct FPGA Test (if you have Stage 2 ready)
Connect FPGA UART TX to Pico GP0 and verify LED toggles when FPGA sends data.

## Success Criteria
- [ ] LED blinks 3 times on startup (ready signal)
- [ ] LED toggles each time a byte is received
- [ ] Bytes are echoed back (visible in serial terminal)

## Troubleshooting
- **LED doesn't blink on startup**: Check Pico has power
- **LED doesn't toggle**: Verify UART connection, check baud rate is 115200
- **No echo in terminal**: Check TX pin connection (GP0 is RX only in this test)
