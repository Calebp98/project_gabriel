# Makefile for iCEbreaker UART project

# Toolchain paths
OSS_CAD_SUITE = /Users/cp/oss-cad-suite/bin
YOSYS = $(OSS_CAD_SUITE)/yosys
NEXTPNR = $(OSS_CAD_SUITE)/nextpnr-ice40
ICEPACK = $(OSS_CAD_SUITE)/icepack
ICEPROG = $(OSS_CAD_SUITE)/iceprog

# Project name
PROJ = uart_control

# Crypto library paths
AES_RTL = ../external/secworks_aes/src/rtl
SIMON_RTL = ../external/simon_cipher

# Source files (using ChaCha20 - compact and efficient)
VERILOG_FILES = top.v uart_tx.v uart_rx.v lfsr.v \
                chacha20_compact.v

# Alternative ciphers (all too large for iCE40UP5K with 5280 LCs):
# SIMON-128/128: 297% of FPGA (15,701 LCs) - stores all 68 round keys
# VERILOG_FILES = top.v uart_tx.v uart_rx.v lfsr.v simon_wrapper.v \
#                 $(SIMON_RTL)/simon.v $(SIMON_RTL)/round.v $(SIMON_RTL)/key_expansion.v
#
# AES-128: 139% of FPGA (7,356 LCs) - stores all 11 round keys + S-boxes
# VERILOG_FILES = top.v uart_tx.v uart_rx.v lfsr.v aes_wrapper.v \
#                 $(AES_RTL)/aes_core.v $(AES_RTL)/aes_encipher_block.v \
#                 $(AES_RTL)/aes_decipher_block.v $(AES_RTL)/aes_key_mem.v \
#                 $(AES_RTL)/aes_sbox.v $(AES_RTL)/aes_inv_sbox.v

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
