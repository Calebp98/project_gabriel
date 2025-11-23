#!/usr/bin/env python3
"""
Secure FPGA Gatekeeper - Monitoring Tool

Monitors UART communication from FPGA for debugging and verification.
Displays FPGA state, jamming status, and other diagnostic information.
"""

import serial
import time
import sys

# Configuration
DEFAULT_PORT = "/dev/cu.usbmodem1402"
BAUD_RATE = 115200

# Command codes
COMMANDS = {
    0x01: "PROG_REQUEST",
    0x02: "CHALLENGE",
    0x03: "RESPONSE",
    0x04: "AUTH_OK",
    0x05: "AUTH_FAIL",
    0x06: "STATUS"
}


def monitor_fpga(port, duration=None):
    """Monitor FPGA UART output"""
    try:
        ser = serial.Serial(
            port,
            BAUD_RATE,
            timeout=1,
            bytesize=8,
            parity='N',
            stopbits=1
        )
        print(f"Connected to {port} at {BAUD_RATE} baud")
        print("=" * 60)
        print("Monitoring FPGA output... (Ctrl+C to stop)")
        print("=" * 60)
        print()

        start_time = time.time()
        byte_count = 0

        while True:
            # Check duration if specified
            if duration and (time.time() - start_time) > duration:
                break

            # Read available data
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                byte_count += len(data)

                # Display as hex
                timestamp = time.time() - start_time
                print(f"[{timestamp:7.2f}s] Received {len(data)} bytes:")

                # Format as hex dump
                for i in range(0, len(data), 16):
                    chunk = data[i:i+16]
                    hex_str = ' '.join(f'{b:02X}' for b in chunk)
                    ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                    print(f"  {hex_str:<48}  {ascii_str}")

                # Try to parse as commands
                if len(data) > 0:
                    cmd = data[0]
                    if cmd in COMMANDS:
                        print(f"  → Command: {COMMANDS[cmd]}")
                        if len(data) >= 5 and cmd in [0x02, 0x06]:  # CHALLENGE or STATUS
                            value = int.from_bytes(data[1:5], 'big')
                            print(f"  → Data: 0x{value:08X}")
                print()

            time.sleep(0.1)

        print(f"\nTotal bytes received: {byte_count}")
        ser.close()

    except serial.SerialException as e:
        print(f"Error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped by user")
        sys.exit(0)


def main():
    """Main entry point"""
    port = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PORT
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else None

    print("=" * 60)
    print("Secure FPGA Gatekeeper - Monitor")
    print("=" * 60)
    print()

    monitor_fpga(port, duration)


if __name__ == "__main__":
    main()
