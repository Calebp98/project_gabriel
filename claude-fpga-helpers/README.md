# Claude FPGA Helper Scripts

Automated build and upload scripts for the iCEBreaker FPGA. These scripts handle the complete toolchain from Verilog source to programmed hardware.

## Scripts

### `fpga_build.sh` - Build Bitstream
Synthesizes Verilog code and generates a bitstream for the iCEBreaker.

**Usage:**
```bash
./claude-fpga-helpers/fpga_build.sh <verilog_file> <pcf_file> [output_name]
```

**Example:**
```bash
./claude-fpga-helpers/fpga_build.sh top.v icebreaker.pcf my_design
```

**What it does:**
1. Runs Yosys for synthesis
2. Runs nextpnr-ice40 for place and route
3. Generates bitstream with icepack
4. Outputs `claude-<output_name>.bin` in the same directory as your Verilog file

**Output files:**
- `claude-<name>.json` - Synthesis netlist (intermediate)
- `claude-<name>.asc` - Place and route result (intermediate)
- `claude-<name>.bin` - Final bitstream (upload this to FPGA)

---

### `fpga_upload.sh` - Upload to FPGA
Programs the iCEBreaker FPGA with a bitstream file.

**Usage:**
```bash
./claude-fpga-helpers/fpga_upload.sh <bitstream.bin>
```

**Example:**
```bash
./claude-fpga-helpers/fpga_upload.sh claude-my_design.bin
```

**What it does:**
- Uses iceprog to flash the bitstream to the FPGA
- FPGA starts running immediately after upload

---

### `fpga_full.sh` - Build and Upload
One-step convenience script that builds and uploads in sequence.

**Usage:**
```bash
./claude-fpga-helpers/fpga_full.sh <verilog_file> <pcf_file> [output_name]
```

**Example:**
```bash
./claude-fpga-helpers/fpga_full.sh top.v icebreaker.pcf my_design
```

**What it does:**
1. Calls `fpga_build.sh` to generate bitstream
2. Calls `fpga_upload.sh` to program the FPGA
3. Your design is running on hardware after this completes

---

## Pin Configuration Template

### `icebreaker-template.pcf` - Complete Pin Reference

A comprehensive, commented template showing all available pins on the iCEBreaker FPGA.

**How to use:**
1. Copy the template to your project directory
2. Uncomment the pins you need
3. Customize signal names for your design
4. Use with the build scripts

**Example:**
```bash
# Copy template to your project
cp claude-fpga-helpers/icebreaker-template.pcf my_project/my_design.pcf

# Edit to uncomment needed pins (clock, LEDs, etc.)
# Then build with your customized PCF
./claude-fpga-helpers/fpga_build.sh my_project/top.v my_project/my_design.pcf test
```

**What's included:**
- 12 MHz clock input (pin 35)
- 5 bicolor RGB LEDs (red/green)
- User button (active low)
- All PMOD connector pins (1A, 1B, 2)
- Common UART pin mappings
- SPI flash pins
- Example configurations (LED blinker, UART, button input)

**Quick reference:**
- Clock: Always 12 MHz on pin 35
- LEDs: Active LOW (set to 0 to turn on)
- Button: Active LOW (reads 0 when pressed)
- PMODs: 3.3V logic levels

The template includes detailed comments and example configurations to get started quickly.

---

## Requirements

These scripts require the following tools to be installed:
- `yosys` - Verilog synthesis
- `nextpnr-ice40` - Place and route for iCE40 FPGAs
- `icestorm` tools (`icepack`, `iceprog`) - Bitstream generation and upload

**Installation on macOS:**
```bash
brew install icestorm yosys nextpnr-ice40
```

**Installation on Linux:**
```bash
# Debian/Ubuntu
sudo apt-get install fpga-icestorm yosys nextpnr-ice40

# Or build from source:
# https://github.com/YosysHQ/icestorm
# https://github.com/YosysHQ/yosys
# https://github.com/YosysHQ/nextpnr
```

## Usage from Anywhere

All scripts can be called from any directory in your repository. They use absolute paths internally.

**Example workflow from project root:**
```bash
# Build only
./claude-fpga-helpers/fpga_build.sh my_project/top.v my_project/icebreaker.pcf test1

# Upload the built bitstream
./claude-fpga-helpers/fpga_upload.sh my_project/claude-test1.bin

# Or do both at once
./claude-fpga-helpers/fpga_full.sh my_project/top.v my_project/icebreaker.pcf test1
```

**Example from subdirectory:**
```bash
cd my_project/
../claude-fpga-helpers/fpga_build.sh top.v icebreaker.pcf my_design
```

## Naming Convention

All generated bitstreams are prefixed with `claude-` to distinguish them from human-generated builds:
- `claude-output.bin`
- `claude-my_design.bin`
- `claude-test1.bin`

## Troubleshooting

**Build fails at synthesis:**
- Check your Verilog syntax
- Ensure your top module is named `top`
- Check yosys output for specific errors

**Build fails at place and route:**
- Verify your PCF file pin assignments
- Check for resource usage (design might be too large)
- Review nextpnr warnings

**Upload fails:**
- Is the iCEBreaker connected via USB?
- Do you have USB device permissions? Try `sudo iceprog <bitstream>`
- Check if another process is using the device

**Permission denied when running scripts:**
- Make scripts executable: `chmod +x claude-fpga-helpers/*.sh`
