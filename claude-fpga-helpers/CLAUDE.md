# Claude Code: FPGA Development Workflow for iCEBreaker

## End-to-End Process: Create and Upload FPGA Programs

## Documentation Structure

Board documentation is located in `docs/` directory:

### Main Documentation

- `docs/README.md` - Board overview and getting started guide

### Images & Diagrams

- `docs/img/icebreaker-block-diagram.jpg` - System block diagram
- `docs/img/icebreaker-v1_0b-legend.jpg` - Board layout with component labels
- `docs/img/icebreaker-v1_0b-legend-jumpers.jpg` - Jumper configuration guide
- `docs/img/icebreaker-v1_0a-legend.jpg` - Older version reference

### Hardware Files (v1.0e)

- `docs/v1.0e/icebreaker-sch.pdf` - Complete schematic (USE THIS for pin details)
- `docs/v1.0e/icebreaker.kicad_*` - KiCad source files (reference only)

**To understand the board layout and pins, read:**

1. `docs/README.md` for overview
2. `docs/v1.0e/icebreaker-sch.pdf` for detailed pin information
3. `docs/img/icebreaker-v1_0b-legend.jpg` for physical component locations

## iCEBreaker Pin Reference (Quick Guide)

### Built-in Components

- **CLK**: Pin 35 (12 MHz oscillator)
- **LED_RED**: Pin 11 (active-low)
- **LED_GREEN**: Pin 37 (active-low)
- **LEDRX**: Pin 26 (active-high) - labeled "LEDG_N" on v1.0e
- **BTN_N**: Pin 10 (active-low, user button)

### RGB LED (on snap-off section - NOT AVAILABLE)

**Note**: The snap-off section with RGB LED has been removed.

- Do NOT use pins: 39, 40, 41 (RGB LED pins)

### PMOD Connectors

**PMOD1A** (pins 4, 2, 47, 45, 3, 48, 46, 44)
**PMOD1B** (pins 43, 38, 34, 31, 42, 36, 32, 28)
**PMOD2** (pins 27, 25, 21, 19, 26, 23, 20, 18)

### UART (via Picoprobe)

- **TX**: Pin 2 (FPGA transmits to host)
- **RX**: Pin 3 (FPGA receives from host)
- **Port**: /dev/cu.usbmodem1402
- **Baud**: 115200

### Available LEDs

Only **LED_RED** (pin 11) and **LED_GREEN** (pin 37) are available.
The RGB LED was on the snap-off section and is not present.

For complete pinout, reference `icebreaker-template.pcf` or `docs/v1.0e/icebreaker-sch.pdf`

````
## Serial Communication & Testing

### Reading Serial Output from FPGA

To read data sent by the FPGA via UART (TX pin 2) through the picoprobe:

```bash
./read_serial.py [duration_seconds] [port]
```

**Recommended usage** (specify the picoprobe port):
```bash
./read_serial.py 5 /dev/cu.usbmodem1402
```

**Auto-detection fallback** (searches for available ports):
```bash
./read_serial.py 5  # May find wrong port if multiple devices connected
```

The FPGA UART should be configured as:
- **Baud rate**: 115200
- **TX**: Pin 2 (FPGA transmits to host via picoprobe)
- **RX**: Pin 3 (FPGA receives from host via picoprobe)
- **Port**: /dev/cu.usbmodem1402

### Multi-Step Testing Workflow

For experiments that require capturing FPGA output and using it in subsequent programs:

1. Flash initial test program
2. Run `./read_serial.py` to capture output
3. Parse output and store results in `experiments/[NAME]/results.txt`
4. Write new program using stored data
5. Flash and verify

Store intermediate results in the experiment directory for reference.


### Simple 4-Step Workflow

When asked to create an FPGA program for the iCEBreaker, follow these steps:

# Experiment Isolation

**CRITICAL**: Do NOT reference or look at any code in `experiments/` from previous experiments unless explicitly asked. Each experiment must be developed independently from scratch using only the board documentation in `docs/`.

**Step 0: Create a project folder**

- Make a new directory in `experiments/` for all files
- Use a meaningful name based on the prompt and include the current date and time e.g. `experiments/[TIME]-[DATE]-[PROJECT_NAME]/`

**Step 1: Create the Verilog file**

- familiarise yourself with the docs in `docs/`, in particular the board structure and pinout
- Write a Verilog module with `module top(...)` as the top-level module
- Use meaningful signal names that match the PCF file
- Save as `<project_name>.v`

**Step 2: Create the PCF (Pin Constraint File)**

- Copy the template: `cp icebreaker-template.pcf <project_name>.pcf`
- Uncomment only the pins needed for your design
- Ensure signal names match your Verilog module
- Save in the same directory as your Verilog file

**Step 3: Build the bitstream**

```bash
./fpga_build.sh <project_name>.v <project_name>.pcf <output_name>
````

This creates `claude-<output_name>.bin`

**Step 4: Upload to FPGA**

```bash
./fpga_upload.sh claude-<output_name>.bin
```

**Or use the one-step command:**

```bash
./fpga_full.sh <project_name>.v <project_name>.pcf <output_name>
```

---

## Example: LED Blinker

**User request:** "Make an LED blinker that toggles the red LED every second"

**Step 1: Write Verilog** (`blinker.v`)

```verilog
module top(
    input CLK,           // 12 MHz clock
    output LED_RED       // Red LED (active low)
);
    reg [23:0] counter = 0;
    reg led_state = 1;   // Start with LED off (active low)

    // 12 MHz / 12,000,000 = 1 Hz
    always @(posedge CLK) begin
        if (counter == 24'd11_999_999) begin
            counter <= 0;
            led_state <= ~led_state;
        end else begin
            counter <= counter + 1;
        end
    end

    assign LED_RED = led_state;
endmodule
```

**Step 2: Create PCF** (`blinker.pcf`)

```
set_io CLK 35
set_io LED_RED 11
```

**Step 3 & 4: Build and upload**

```bash
./fpga_full.sh blinker.v blinker.pcf blinker
```

Done! The LED should now blink every second.

---

## Key Points to Remember

1. **Top module must be named `top`**

   - Yosys synthesis expects this by default

2. **Clock is always 12 MHz**

   - Pin 35
   - Use clock dividers for slower frequencies

3. **LEDs are active LOW**

   - Set to 0 to turn ON
   - Set to 1 to turn OFF

4. **Button is active LOW**

   - Reads 0 when pressed
   - Reads 1 when not pressed

5. **All outputs prefixed with `claude-`**

   - `claude-<name>.json` (intermediate)
   - `claude-<name>.asc` (intermediate)
   - `claude-<name>.bin` (final bitstream)

6. **Scripts work from any directory**
   - Always use relative or absolute paths
   - Files are created in the same directory as the Verilog source

---

## Common Patterns

### Clock Divider (12 MHz → 1 Hz)

```verilog
reg [23:0] counter = 0;  // 24 bits for counting to 12M
always @(posedge CLK) begin
    if (counter == 24'd11_999_999)
        counter <= 0;
    else
        counter <= counter + 1;
end
```

### Button Debouncer (Simple)

```verilog
reg [19:0] debounce_counter = 0;
reg button_state = 1;

always @(posedge CLK) begin
    if (BTN_N == 0) begin  // Button pressed (active low)
        if (debounce_counter == 20'd999_999)
            button_state <= 0;
        else
            debounce_counter <= debounce_counter + 1;
    end else begin
        debounce_counter <= 0;
        button_state <= 1;
    end
end
```

---

## Troubleshooting

**Synthesis fails:**

- Check Verilog syntax
- Ensure top module is named `top`
- Check for undefined signals

**Place and route fails:**

- Signal name mismatch between Verilog and PCF
- Wrong pin numbers in PCF
- Design too large for FPGA (rare with iCE40UP5K)

**Upload fails:**

- Check USB connection to iCEBreaker
- Try with sudo: `sudo iceprog claude-<name>.bin`

**FPGA doesn't behave as expected:**

- Remember LEDs are active LOW
- Check clock divider calculations
- Verify signal names match between Verilog and PCF

---

## Reference

- Pin template: `icebreaker-template.pcf`
- Full documentation: `README.md`
- iCEBreaker GitHub: https://github.com/icebreaker-fpga/icebreaker

We've given you a uart implementation (uart_rx.v)
