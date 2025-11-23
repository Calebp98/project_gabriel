# FPGA to Raspberry Pi Pico Program Loader

## Hardware Setup
```
iCEBreaker FPGA          Raspberry Pi Pico
─────────────────        ─────────────────
PMOD1A Pin 1    ───────→ GP0 (Pin 1)  [UART RX]
PMOD1A Pin 2    ───────→ RUN (Pin 30) [Reset]
PMOD1A Pin 5    ───────→ GND (Pin 3)  [Ground]
```

## Testing Stages

### Stage 1: Basic UART Test (Pico only)
**Goal**: Verify Pico can receive UART data
**Test**: Send bytes from computer/FPGA, LED toggles
**Files**: `pico/stage1/`

### Stage 2: FPGA UART Transmitter
**Goal**: FPGA sends test pattern over UART
**Test**: Verify signal with logic analyzer or Pico receiver
**Files**: `fpga/stage2/`

### Stage 3: Pico Bootloader - RAM Loading
**Goal**: Pico receives 256 bytes into RAM
**Test**: FPGA sends data, Pico LED confirms reception
**Files**: `pico/stage3/`

### Stage 4: RAM Program Execution
**Goal**: Create and test minimal blink program for RAM
**Test**: Bootloader executes received program
**Files**: `pico/stage4/`

### Stage 5: FPGA Reset Control
**Goal**: FPGA controls Pico reset via RUN pin
**Test**: FPGA holds/releases reset at right times
**Files**: `fpga/stage5/`

### Stage 6: Full Integration
**Goal**: Complete program loading system
**Test**: Power cycle both, Pico executes FPGA-sent program
**Files**: `fpga/stage6/`

## Current Stage Progress
See individual stage directories for specific instructions and code.
