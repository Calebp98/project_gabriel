#!/usr/bin/env python3
"""
Raw SWD protocol debugging - manually step through SWD communication.
"""

import sys
from swd_bridge import SWDBridge, int_to_bits, bits_to_int


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 debug_swd_raw.py <serial_port>")
        sys.exit(1)

    port = sys.argv[1]

    print("=" * 60)
    print("Raw SWD Protocol Debug")
    print("=" * 60)
    print()

    with SWDBridge(port) as bridge:
        print("Step 1: Line reset (50+ clocks with SWDIO=1)")
        bridge.line_reset()
        print("✓ Line reset complete")
        print()

        print("Step 2: JTAG-to-SWD sequence (0xE79E)")
        # Send switching sequence
        sequence = int_to_bits(0xE79E, 16)
        print(f"  Sending: {sequence}")
        bridge.write_bits(sequence)
        print("✓ Sequence sent")
        print()

        print("Step 3: Another line reset")
        bridge.line_reset()
        print("✓ Line reset complete")
        print()

        print("Step 4: Idle cycles")
        bridge.idle_cycles(8)
        print("✓ 8 idle cycles")
        print()

        print("Step 5: Build IDCODE read request")
        # Request format:
        # [0] Start = 1
        # [1] AP/DP = 0 (DP)
        # [2] R/W = 1 (Read)
        # [3] A2 = 0 (address 0x0)
        # [4] A3 = 0
        # [5] Parity = 0 (parity of bits 1-4 = even, so odd parity = 0)
        # [6] Stop = 0
        # [7] Park = 1

        request = 0b10100001  # Start=1, DP, Read, A[3:2]=00, Parity=0, Stop=0, Park=1
        request_bits = int_to_bits(request, 8)
        print(f"  Request: 0x{request:02X} = {request_bits}")
        print("  Breakdown:")
        print(f"    Start:  {request_bits[0]}")
        print(f"    AP/DP:  {request_bits[1]} (0=DP)")
        print(f"    R/W:    {request_bits[2]} (1=Read)")
        print(f"    A[2]:   {request_bits[3]}")
        print(f"    A[3]:   {request_bits[4]}")
        print(f"    Parity: {request_bits[5]}")
        print(f"    Stop:   {request_bits[6]}")
        print(f"    Park:   {request_bits[7]}")
        print()

        print("Step 6: Send request")
        bridge.write_bits(request_bits)
        print("✓ Request sent")
        print()

        print("Step 7: Turnaround (1 clock, switch to input)")
        bridge.turnaround()
        print("✓ Turnaround complete")
        print()

        print("Step 8: Read ACK (3 bits)")
        ack_bits = bridge.read_bits(3)
        ack_value = bits_to_int(ack_bits)
        print(f"  ACK bits: {ack_bits}")
        print(f"  ACK value: 0b{ack_value:03b} (0x{ack_value:X})")

        if ack_value == 0b001:
            print("  ✓ ACK = OK!")
        elif ack_value == 0b010:
            print("  ⚠ ACK = WAIT (target not ready)")
        elif ack_value == 0b100:
            print("  ✗ ACK = FAULT (error)")
        elif ack_value == 0b111 or ack_value == 0b000:
            print("  ✗ ACK = No response (all 1s or all 0s)")
            print()
            print("DIAGNOSIS:")
            print("  - All 1s (111) means SWDIO is floating high (not connected or target off)")
            print("  - All 0s (000) means SWDIO stuck low (wiring issue or target problem)")
            print()
            print("Check:")
            print("  1. Is target Pico powered? (USB LED should be on)")
            print("  2. Is SWDIO (GP3) connected to target GPIO 25?")
            print("  3. Try swapping SWCLK and SWDIO wires (easy mistake)")
        else:
            print(f"  ? ACK = Unknown pattern (0b{ack_value:03b})")
        print()

        if ack_value == 0b001:
            print("Step 9: Read data (32 bits + parity)")
            data_bits = bridge.read_bits(32)
            parity_bit = bridge.read_bits(1)
            data = bits_to_int(data_bits)

            print(f"  Data: 0x{data:08X}")
            print(f"  Parity: {parity_bit}")
            print()
            print(f"SUCCESS! Read IDCODE: 0x{data:08X}")

            version = (data >> 28) & 0xF
            partno = (data >> 12) & 0xFFFF
            designer = (data >> 1) & 0x7FF

            print(f"  Version:  {version}")
            print(f"  PartNo:   0x{partno:04X}")
            print(f"  Designer: 0x{designer:03X}")
        else:
            print("Cannot read data - ACK was not OK")

        print()
        print("=" * 60)


if __name__ == '__main__':
    main()
