# DNP3 Link Layer Implementation

This extension to Project Gabriel implements the DNP3 (Distributed Network Protocol 3) link layer parser on the iCEBreaker FPGA.

## What's New

The FPGA now validates DNP3 link layer frames instead of simple ASCII patterns. This includes:
- Frame start sequence detection (0x05 0x64)
- CRC-16 validation using the DNP3 polynomial
- Address filtering (device address: 0x0001)
- Control byte and source address extraction

## Architecture

### New Modules

1. **crc16_dnp.v** - CRC-16 calculator using DNP3 polynomial (0xA6BC)
   - Byte-wise calculation with bit-serial processing
   - Complements result per DNP3 specification
   - Supports clear and continuous calculation

2. **dnp3_link_layer.v** - Link layer frame parser FSM
   - Validates frame start bytes (0x05 0x64)
   - Parses header fields: length, control, destination, source
   - Validates header CRC-16
   - Filters frames by destination address
   - Outputs: frame_valid, frame_error, control, src_addr, dest_addr, addr_match

3. **top_dnp3.v** - Top-level module integrating UART + DNP3
   - Green LED: Valid frame with matching address
   - Red LED: Frame error (CRC fail or invalid format)
   - RX LED: UART data received indicator

### Unchanged Modules

- **uart_rx.v** - UART receiver (115200 baud, 8N1)
- Pin configuration and hardware setup remain the same

## DNP3 Link Layer Frame Format

```
Byte:  0     1     2      3       4       5       6       7       8      9
     +-----+-----+------+-------+-------+-------+-------+-------+------+------+
     | 0x05| 0x64| LEN  | CTRL  | DEST_L| DEST_H| SRC_L | SRC_H | CRC_L| CRC_H|
     +-----+-----+------+-------+-------+-------+-------+-------+------+------+
     |<-- Start -->|<---------------- CRC Coverage ----------------->|<-CRC->|
```

- **Start**: Always 0x05 0x64
- **LEN**: Length byte (0x05 for header-only frame)
- **CTRL**: Control byte (function code and flags)
- **DEST**: Destination address (little-endian, 2 bytes)
- **SRC**: Source address (little-endian, 2 bytes)
- **CRC**: CRC-16 DNP3 over bytes 2-7 (little-endian, 2 bytes)

### Control Byte Format

```
Bit 7  6   5   4   3   2   1   0
   +---+---+---+---+---+---+---+---+
   |DIR|PRM|FCB|FCV| FUNC CODE     |
   +---+---+---+---+---+---+-------+
```

Common function codes:
- 0x00: Confirm
- 0x01: Read
- 0x02: Write
- 0x04: Reset Link

## Building

Use the new build script for the DNP3 implementation:

```bash
./build_dnp3.sh
```

This will synthesize all four modules (uart_rx, crc16_dnp, dnp3_link_layer, top_dnp3) and generate `top_dnp3.bin`.

Program the FPGA:
```bash
iceprog top_dnp3.bin
```

## Testing

### Hardware Setup (Same as Before)
- Pico GP0 (UART TX) to FPGA pin 3 (RX)
- Pico GND to FPGA GND
- USB cables for both boards

### Test Code
Upload `pico_dnp3_test/pico_dnp3_test.ino` to your Raspberry Pi Pico.

The test code will send:
1. Valid DNP3 frame to address 0x0001 (should light GREEN LED)
2. Valid frame to different address (no LED change)
3. Frame with bad CRC (should light RED LED)
4. Various control bytes and source addresses
5. Malformed frames

### Expected LED Behavior

- **LED_RX (pin 26)**: Pulses briefly when each UART byte is received
- **LED_GREEN (pin 37)**: Stays ON when a valid DNP3 frame with matching address (0x0001) is received
- **LED_RED (pin 11)**: Stays ON when a frame error is detected (bad CRC, wrong start bytes, etc.)

## Configuration

### Changing Device Address
Edit the parameter in [top_dnp3.v:37](top_dnp3.v#L37):
```verilog
dnp3_link_layer #(
    .MY_ADDRESS(16'h0001)  // Change this value
) dnp3_inst (
    ...
);
```

### Changing Baud Rate
Edit the CLKS_PER_BIT parameter in [top_dnp3.v:24](top_dnp3.v#L24):
```verilog
uart_rx #(
    .CLKS_PER_BIT(104)  // 12MHz / 115200 = 104
) uart_inst (
    ...
);
```

For other baud rates: `CLKS_PER_BIT = 12,000,000 / baud_rate`

## Resource Utilization

Estimated FPGA resource usage (iCE40UP5K):
- **LUTs**: ~800-1000 (15-20% of 5280 available)
- **FFs**: ~400-500 (8-10% of 5280 available)
- **RAM**: Minimal (logic only, no buffers)

This is a basic implementation focused on header validation. Adding data block support would increase resource usage.

## Limitations (Phase 1)

This implementation only handles the DNP3 link layer header:
- ✅ Start byte detection
- ✅ Header parsing (length, control, addresses)
- ✅ CRC-16 validation
- ✅ Address filtering
- ❌ Data blocks (not implemented)
- ❌ Multi-block CRCs (not implemented)
- ❌ Transport layer (not implemented)
- ❌ Application layer (not implemented)

## Next Steps (Future Phases)

### Phase 2: Data Block Support
- Parse data blocks following the header
- Validate CRC-16 for each 16-byte data chunk
- Buffer received data in block RAM

### Phase 3: Transport/Application Layers
- Consider using a soft processor (RISC-V core)
- Implement transport layer reassembly
- Add basic application layer object support

## References

- DNP3 Specification: IEEE 1815-2012
- CRC-16 DNP3 Polynomial: 0xA6BC (reversed representation)
- iCE40 Documentation: Lattice Semiconductor

## Reverting to Original "CAT" Pattern

To switch back to the original simple pattern matcher:
```bash
./build.sh
iceprog top_test.bin
```

The original code in `top_test.v`, `grammar_fsm.v` remains unchanged.
