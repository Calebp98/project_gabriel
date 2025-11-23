# iCEbreaker UART Control

This project implements UART-based pin control for the iCEbreaker FPGA board. It receives characters via UART and controls an output pin accordingly.

## Functionality

- **UART RX**: Receives characters at 115200 baud from picoprobe
- **Pin Control Logic**:
  - Receives 'Y' or 'y' → Sets CONTROL_PIN to LOW (0V)
  - Receives 'N' or 'n' → Sets CONTROL_PIN to HIGH (3.3V)
- **LED Indicators**:
  - LED1 on = received 'N' (pin HIGH)
  - LED5 on = received 'Y' (pin LOW)
  - All LEDs on = unknown character

## Hardware Setup

### Wiring: Picoprobe to iCEbreaker

| Picoprobe Pin | Function | iCEbreaker Pin | PMOD Pin |
|---------------|----------|----------------|----------|
| GPIO 3        | UART TX  | RX (pin 4)     | PMOD1A-1 |
| GND           | Ground   | GND            | PMOD1A-5 |

### Control Pin

The `CONTROL_PIN` output is mapped to **iCEbreaker pin 2** (PMOD1A-2) by default. You can change this in [icebreaker.pcf](icebreaker.pcf#L14).

## Prerequisites

You need the open-source FPGA toolchain installed:

```bash
# On macOS with Homebrew
brew install icestorm yosys nextpnr-ice40

# On Linux (Ubuntu/Debian)
sudo apt-get install fpga-icestorm yosys nextpnr-ice40
```

## Building

```bash
# Build the bitstream
make

# This will generate gabriel.bin
```

## Programming the iCEbreaker

```bash
# Flash to FPGA (temporary - lost on power cycle)
make prog

# Or manually:
iceprog gabriel.bin
```

## Usage

1. **Connect the hardware**:
   - Wire picoprobe GPIO 3 to iCEbreaker PMOD1A pin 1 (RX)
   - Connect GND between devices

2. **Program the iCEbreaker**:
   ```bash
   make prog
   ```

3. **Connect to picoprobe UART** from your computer:
   ```bash
   # Find the device (macOS)
   ls /dev/tty.usbmodem*

   # Connect with screen
   screen /dev/tty.usbmodemXXXX 115200

   # Or use minicom, picocom, etc.
   ```

4. **Send commands**:
   - Type `Y` and press Enter → CONTROL_PIN goes LOW (0V)
   - Type `N` and press Enter → CONTROL_PIN goes HIGH (3.3V)

## Testing Without Picoprobe

You can test with any USB-to-UART adapter:
- Connect TX to iCEbreaker RX (pin 4 / PMOD1A-1)
- Connect GND to GND
- Use any serial terminal at 115200 baud

## Customization

### Change UART Pins

Edit [icebreaker.pcf](icebreaker.pcf) to assign RX and CONTROL_PIN to different physical pins.

### Change Baud Rate

Edit [top.v](top.v#L26) and change the `BAUD_RATE` parameter:
```verilog
uart_rx #(
    .CLOCK_FREQ(12_000_000),
    .BAUD_RATE(9600)  // Change this
)
```

### Add UART TX (Echo Back)

If you want the iCEbreaker to send responses back, you'll need to add a UART transmitter module.

## File Structure

- `top.v` - Top-level module with control logic
- `uart_rx.v` - UART receiver module (115200 baud)
- `icebreaker.pcf` - Pin constraint file
- `Makefile` - Build script

## Troubleshooting

**No response to commands:**
- Check baud rate is 115200
- Verify RX pin connection
- Check GND is connected
- Use `icetime` to verify timing constraints are met

**LEDs all on:**
- You're sending an unrecognized character
- Check for line endings or extra characters

**iCEbreaker won't program:**
- Check USB connection
- Try: `lsusb | grep Future` (should show FTDI device)
- Check permissions: may need `sudo` or add user to `plugdev` group
