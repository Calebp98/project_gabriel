#!/usr/bin/env python3
"""
Simple SWD Test Script
Tests basic SWD communication with target Pico.
"""

import sys
from swd_bridge import SWDBridge
from swd_protocol import SWDProtocol


def main():
    if len(sys.argv) < 2:
        print("Usage: python test_swd.py <serial_port>")
        print("Example: python test_swd.py /dev/cu.usbmodem1301")
        sys.exit(1)

    port = sys.argv[1]

    print("=" * 60)
    print("SWD Communication Test")
    print("=" * 60)
    print(f"Port: {port}")
    print()

    try:
        # Connect to bridge
        print("Step 1: Connecting to SWD bridge...")
        with SWDBridge(port) as bridge:
            print("✓ Connected")
            print()

            # Create SWD protocol handler
            swd = SWDProtocol(bridge)

            # Switch to SWD mode
            print("Step 2: Switching to SWD mode...")
            swd.switch_to_swd()
            print("✓ SWD mode activated")
            print()

            # Read IDCODE
            print("Step 3: Reading IDCODE...")
            idcode = swd.read_idcode()

            if idcode is None:
                print("✗ Failed to read IDCODE")
                print()
                print("Troubleshooting:")
                print("  1. Check wiring:")
                print("     - Bridge GP2 (SWCLK) → Target GPIO 24")
                print("     - Bridge GP3 (SWDIO) → Target GPIO 25")
                print("     - GND → GND")
                print("  2. Ensure target Pico has power")
                print("  3. Try connecting target Pico's USB (it needs power)")
                return 1

            print(f"✓ IDCODE: 0x{idcode:08X}")
            print()

            # Parse IDCODE
            version = (idcode >> 28) & 0xF
            partno = (idcode >> 12) & 0xFFFF
            designer = (idcode >> 1) & 0x7FF

            print("IDCODE Details:")
            print(f"  Version:  {version}")
            print(f"  PartNo:   0x{partno:04X}", end="")

            # Check if it's RP2040
            if partno == 0x0001:  # RP2040 part number
                print(" (RP2040 - Correct!)")
            else:
                print(" (Unknown part)")

            print(f"  Designer: 0x{designer:03X}", end="")

            # Check designer (ARM = 0x23B)
            if designer == 0x23B:
                print(" (ARM Ltd - Correct!)")
            else:
                print(" (Unknown designer)")

            print()
            print("=" * 60)
            print("SUCCESS! SWD communication is working!")
            print("=" * 60)
            print()
            print("Next steps:")
            print("  - Memory read/write operations")
            print("  - Halt/resume CPU")
            print("  - Flash programming")

            return 0

    except serial.SerialException as e:
        print(f"✗ Serial error: {e}")
        print()
        print("Make sure:")
        print("  1. Bridge Pico is connected via USB")
        print("  2. Bridge firmware is uploaded")
        print("  3. Correct serial port specified")
        return 1

    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        return 1

    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    import serial  # Import here for better error message
    sys.exit(main())
