# Makefile for iCEbreaker UART project

# Toolchain paths
OSS_CAD_SUITE = /Users/cp/oss-cad-suite/bin
YOSYS = $(OSS_CAD_SUITE)/yosys
NEXTPNR = $(OSS_CAD_SUITE)/nextpnr-ice40
ICEPACK = $(OSS_CAD_SUITE)/icepack
ICEPROG = $(OSS_CAD_SUITE)/iceprog

# Project name
PROJ = uart_control

# AES library path
AES_RTL = ../external/secworks_aes/src/rtl

# Source files
VERILOG_FILES = top.v uart_tx.v uart_rx.v lfsr.v \
                aes_wrapper.v \
                $(AES_RTL)/aes_core.v \
                $(AES_RTL)/aes_encipher_block.v \
                $(AES_RTL)/aes_decipher_block.v \
                $(AES_RTL)/aes_key_mem.v \
                $(AES_RTL)/aes_sbox.v \
                $(AES_RTL)/aes_inv_sbox.v

# Pin constraints
PCF = icebreaker.pcf

# iCE40 device
DEVICE = up5k
PACKAGE = sg48

# Build targets
all: $(PROJ).bin

# Synthesis
$(PROJ).json: $(VERILOG_FILES)
	$(YOSYS) -p "synth_ice40 -top top -json $@" $(VERILOG_FILES)

# Place and route
$(PROJ).asc: $(PROJ).json $(PCF)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

# Generate binary
$(PROJ).bin: $(PROJ).asc
	$(ICEPACK) $< $@

# Program the FPGA
prog: $(PROJ).bin
	$(ICEPROG) $<

# Clean build files
clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

# Timing analysis
timing: $(PROJ).asc
	icetime -d $(DEVICE) -mtr $(PROJ).rpt $<

.PHONY: all prog clean timing
