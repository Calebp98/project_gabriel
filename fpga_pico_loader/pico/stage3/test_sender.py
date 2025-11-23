#!/usr/bin/env python3
"""
Test script to send 256 bytes to Pico bootloader via serial port.
Sends pattern: 0x00, 0x01, 0x02, ... 0xFF

Usage: python3 test_sender.py /dev/ttyACM0
"""

import serial
import sys
import time

def send_test_pattern(port_name):
    """Send 256 bytes (0x00 to 0xFF) to bootloader"""
    try:
        with serial.Serial(port_name, 115200, timeout=1) as ser:
            print(f"Connected to {port_name}")
            print("Waiting 2 seconds for Pico to boot...")
            time.sleep(2)

            print("Sending 256 bytes...")
            test_data = bytes(range(256))  # 0x00 to 0xFF
            ser.write(test_data)

            print(f"Sent {len(test_data)} bytes")
            print("Pico LED should now be blinking slowly (success)")

    except serial.SerialException as e:
        print(f"Error: {e}")
        print("\nTip: Find your port with:")
        print("  macOS/Linux: ls /dev/tty*")
        print("  Common: /dev/ttyACM0, /dev/tty.usbmodem*")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 test_sender.py <serial_port>")
        print("Example: python3 test_sender.py /dev/ttyACM0")
        sys.exit(1)

    send_test_pattern(sys.argv[1])
