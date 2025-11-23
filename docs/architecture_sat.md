# Project Gabriel - Design Documentation

## Current Design Overview

### System Architecture

**Goal**: Program a target Pico via picoprobe, while simultaneously sending UART messages to control an iCEbreaker FPGA.

```
Computer (VSCode Serial Monitor)
    ↓ USB
Picoprobe (Pico #1 - running picoprobe firmware)
    ├─ SWD Interface ──→ Target Pico (Pico #2 - being programmed)
    └─ UART (GPIO 4 TX) ──→ iCEbreaker FPGA
                              ↓ Controls Pin 4 (0V or 3.3V)
```

**Hardware Components:**
1. **Picoprobe**: Pico #1 running picoprobe firmware for debugging/UART passthrough
2. **Target Pico**: Pico #2 being programmed via SWD from picoprobe
3. **iCEbreaker**: FPGA board receiving UART commands and controlling voltage output

### Hardware Connections

#### Picoprobe → Target Pico (SWD Programming)

| Picoprobe Pin | Function | Target Pico Pin | Notes |
|---------------|----------|-----------------|-------|
| GPIO 2        | SWCLK    | SWCLK (GP2?)    | SWD clock |
| GPIO 3        | SWDIO    | SWDIO (GP3?)    | SWD data |
| GND           | Ground   | GND             | Common ground |
| (Optional) GPIO 6 | UART RX | GP0/GP1 (TX) | Debug UART from target |

#### Picoprobe → iCEbreaker (UART Control)

| Picoprobe Pin | Function | iCEbreaker Pin | Notes |
|---------------|----------|----------------|-------|
| GPIO 4        | UART TX  | Pin 3 (RX)     | Data from computer to FPGA |
| GND           | Ground   | GND            | Common ground (required!) |

#### iCEbreaker Output

| iCEbreaker Pin | Function | Voltage Control |
|----------------|----------|-----------------|
| Pin 4          | CONTROL_PIN | 0V when 'Y' received, 3.3V when 'N' received |

### Protocol

**UART Settings:**
- Baud Rate: 115200
- Data Bits: 8
- Stop Bits: 1
- Parity: None

**Commands:**
- Send `'Y'` or `'y'` → Pin 4 goes LOW (0V)
- Send `'N'` or `'n'` → Pin 4 goes HIGH (3.3V)

**LED Indicators on iCEbreaker:**
- LED1 on = 'N' received (pin HIGH)
- LED5 on = 'Y' received (pin LOW)
- All LEDs on = unknown character received

### Software Components

#### 1. Picoprobe (Pico #1)
- **Firmware**: Standard picoprobe firmware (no custom code needed)
- **Functions**:
  - SWD programming interface for target Pico
  - USB-to-UART passthrough for iCEbreaker control
- **SWD Pins**: GPIO 2 (SWCLK), GPIO 3 (SWDIO)
- **UART Pins**: GPIO 4 (TX to iCEbreaker), GPIO 5 (RX - optional)

#### 2. Target Pico (Pico #2)
- **Purpose**: The Pico being programmed/debugged via picoprobe
- **Connection**: Connected via SWD to picoprobe
- **Programs**: Can run any pico-sdk based code (e.g., blink examples)

#### 3. iCEbreaker FPGA

**Project Location**: `/Users/cp/Documents/projects/project_gabriel/icebreaker_uart/`

**Verilog Modules:**

1. **uart_rx.v** - UART receiver module
   - Receives characters at 115200 baud
   - 12 MHz clock input
   - Outputs 8-bit data + valid signal

2. **top.v** - Top-level module
   - Instantiates UART receiver
   - Parses received characters ('Y' vs 'N')
   - Controls output pin based on character
   - Drives LED indicators

3. **icebreaker.pcf** - Pin constraints
   - CLK: pin 35 (12 MHz)
   - RX: pin 3 (UART input)
   - CONTROL_PIN: pin 4 (voltage output)
   - LEDs: pins 11, 37, 39, 40, 41

**Build System:**
- Uses open-source FPGA toolchain (yosys, nextpnr-ice40, icestorm)
- Makefile for automation
- Target device: iCE40UP5K

### Usage Workflow

1. **Build and Program iCEbreaker:**
   ```bash
   cd /Users/cp/Documents/projects/project_gabriel/icebreaker_uart
   make
   make prog
   ```

2. **Connect to Picoprobe Serial:**
   - Open VSCode
   - Use Arduino plugin serial monitor
   - Select picoprobe port (e.g., `/dev/tty.usbmodem*`)
   - Set baud rate: 115200

3. **Send Commands:**
   - Type 'Y' and press Enter → Pin 4 = 0V
   - Type 'N' and press Enter → Pin 4 = 3.3V
   - Watch LEDs on iCEbreaker for confirmation

### Programming the Target Pico (via picoprobe)

If programming another Pico through the picoprobe:

```bash
cd pico-examples/blink/build
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
    -c "adapter speed 5000" \
    -c "program blink.elf verify reset exit"
```

### Project Files

```
project_gabriel/
├── icebreaker_uart/          # iCEbreaker FPGA project
│   ├── uart_rx.v             # UART receiver module
│   ├── top.v                 # Top-level with control logic
│   ├── icebreaker.pcf        # Pin constraints
│   ├── Makefile              # Build automation
│   └── README.md             # Detailed documentation
│
├── uart_icebreaker/          # [UNUSED] Initial Pico C code (not needed)
│   └── ...                   # (using picoprobe passthrough instead)
│
└── pico-examples/            # Pico SDK examples
    └── ...
```

### Notes

- The picoprobe does NOT need custom firmware - it uses standard picoprobe UART passthrough
- Only the iCEbreaker needs to be programmed with custom logic
- Pin 4 is an OUTPUT from the iCEbreaker, controlled by UART commands
- Common ground between picoprobe and iCEbreaker is critical for reliable UART communication

### Future Enhancements

Potential additions:
- Bidirectional UART (iCEbreaker sends acknowledgments back)
- More control pins with different commands
- PWM control instead of just HIGH/LOW
- Status reporting via UART TX
