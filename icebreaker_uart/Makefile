# Makefile for iCEbreaker UART project

# Project name
PROJ = uart_control

# Source files
VERILOG_FILES = top.v uart_rx.v

# Pin constraints
PCF = icebreaker.pcf

# iCE40 device
DEVICE = up5k
PACKAGE = sg48

# Build targets
all: $(PROJ).bin

# Synthesis
$(PROJ).json: $(VERILOG_FILES)
	yosys -p "synth_ice40 -top top -json $@" $(VERILOG_FILES)

# Place and route
$(PROJ).asc: $(PROJ).json $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

# Generate binary
$(PROJ).bin: $(PROJ).asc
	icepack $< $@

# Program the FPGA
prog: $(PROJ).bin
	iceprog $<

# Clean build files
clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

# Timing analysis
timing: $(PROJ).asc
	icetime -d $(DEVICE) -mtr $(PROJ).rpt $<

.PHONY: all prog clean timing
