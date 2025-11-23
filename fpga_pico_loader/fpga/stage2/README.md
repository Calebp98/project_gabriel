# Stage 2: FPGA UART Transmitter Test

## Purpose
Verify the FPGA can transmit UART data at 115200 baud before implementing the full program loader.

## Functionality
- Sends alternating bytes: `0xAA`, `0x55`, `0xAA`, `0x55`, ...
- 100ms delay between bytes
- Red LED: ON while transmitting
- Green LED: Toggles with each byte sent

## Hardware Setup

### Standalone Test (with logic analyzer)
```
iCEBreaker FPGA
───────────────
PMOD1A Pin 1 (GPIO 4) → Logic analyzer probe
GND                   → Logic analyzer ground
```

### Combined Test (with Pico Stage 1)
```
iCEBreaker FPGA          Raspberry Pi Pico
───────────────          ─────────────────
PMOD1A Pin 1    ───────→ GP0 (Pin 1)  [UART RX]
PMOD1A Pin 5    ───────→ GND (Pin 3)  [Ground]
```

## Building

```bash
cd fpga/stage2
chmod +x build.sh
./build.sh
```

## Programming

```bash
iceprog top.bin
```

## Testing

### Method 1: Visual LED Test
1. Program FPGA
2. **Expected**:
   - Red LED pulses briefly every ~100ms (transmission indicator)
   - Green LED toggles every ~100ms (byte sent indicator)

### Method 2: Logic Analyzer
1. Connect probe to PMOD1A Pin 1
2. Set protocol decoder to UART: 115200 baud, 8N1
3. **Expected**: Alternating 0xAA and 0x55 bytes

### Method 3: Combined with Pico Stage 1
1. Flash Pico with Stage 1 firmware
2. Connect FPGA TX to Pico RX
3. Program FPGA
4. **Expected**:
   - Pico LED toggles rapidly (every 100ms)
   - FPGA green LED matches Pico LED toggling

## Success Criteria
- [ ] FPGA LEDs show activity
- [ ] Logic analyzer shows correct UART signal at 115200 baud
- [ ] Pico Stage 1 receiver toggles LED in sync with transmission
- [ ] Pattern alternates between 0xAA and 0x55

## Troubleshooting
- **No LED activity**: Check FPGA programming, verify clock is running
- **Wrong baud rate**: Verify CLKS_PER_BIT = 104 for 12 MHz / 115200
- **Pico doesn't respond**: Check wiring, ensure common ground
- **Continuous transmission**: Normal - FPGA sends continuously every 100ms

## Files
- `uart_tx.v` - Reusable UART transmitter module
- `top.v` - Test pattern generator
- `icebreaker.pcf` - Pin constraints
- `build.sh` - Build script
