#!/usr/bin/env python3
"""
Debug script to test basic bridge functionality without SWD protocol.
"""

import sys
import serial
import time


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 debug_bridge.py <serial_port>")
        sys.exit(1)

    port = sys.argv[1]

    print("=" * 60)
    print("Bridge Hardware Debug Test")
    print("=" * 60)
    print()

    ser = serial.Serial(port, 115200, timeout=1)
    time.sleep(0.5)

    # Clear buffer
    ser.reset_input_buffer()

    print("Test 1: Status command")
    ser.write(b'?')
    time.sleep(0.1)
    while ser.in_waiting:
        line = ser.readline().decode().strip()
        print(f"  {line}")
    print()

    print("Test 2: Line reset")
    ser.reset_input_buffer()
    ser.write(b'r')
    response = ser.read_until(b'\n').decode().strip()
    print(f"  Response: '{response}'")
    print(f"  Expected: 'OK'")
    print()

    print("Test 3: Manual GPIO test")
    print("  Setting SWCLK high...")
    ser.write(b'C')
    time.sleep(0.01)

    print("  Setting SWCLK low...")
    ser.write(b'c')
    time.sleep(0.01)

    print("  Setting SWDIO to output mode...")
    ser.write(b'O')
    time.sleep(0.01)

    print("  Setting SWDIO high...")
    ser.write(b'D')
    time.sleep(0.01)

    print("  Setting SWDIO low...")
    ser.write(b'd')
    time.sleep(0.01)

    print("  Setting SWDIO to input mode...")
    ser.write(b'I')
    time.sleep(0.01)

    print("  Reading SWDIO...")
    ser.write(b'R')
    bit = ser.read(1)
    print(f"  SWDIO state: {bit.decode() if bit else 'timeout'}")
    print()

    print("Test 4: Write byte")
    ser.write(b'B')
    ser.write(bytes([0xAB]))
    time.sleep(0.01)
    print(f"  Wrote byte 0xAB")
    print()

    print("=" * 60)
    print("Bridge hardware tests complete!")
    print()
    print("If all tests passed, the bridge is working.")
    print("If IDCODE read failed, check:")
    print("  1. Is target Pico connected and powered?")
    print("  2. Are GP2 and GP3 wired to correct target pins?")
    print("  3. Is GND connected?")
    print()
    print("To verify wiring with multimeter:")
    print("  - Bridge GP2 should connect to target GPIO 24 (pin 29)")
    print("  - Bridge GP3 should connect to target GPIO 25 (pin 34)")
    print("  - Measure continuity to verify connections")

    ser.close()


if __name__ == '__main__':
    main()
