#!/usr/bin/env python3
"""
Low-level UART diagnostic tool
Tests basic serial communication with FPGA
"""

import serial
import time
import sys

def test_uart(port):
    """Test UART with verbose output"""
    print(f"Testing UART on {port}")
    print("=" * 60)

    try:
        ser = serial.Serial(
            port,
            115200,
            timeout=2,
            bytesize=8,
            parity='N',
            stopbits=1
        )

        print(f"✓ Port opened successfully")
        print(f"  Baud: {ser.baudrate}")
        print(f"  Timeout: {ser.timeout}s")
        print()

        # Flush buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.1)

        # Test 1: Send single byte
        print("Test 1: Sending PROG_REQUEST (0x01)...")
        ser.write(bytes([0x01]))
        ser.flush()
        print("  Sent: 0x01")

        # Wait and check for response
        time.sleep(0.5)
        waiting = ser.in_waiting
        print(f"  Bytes waiting: {waiting}")

        if waiting > 0:
            data = ser.read(waiting)
            print(f"  Received {len(data)} bytes:")
            print(f"    Hex: {' '.join(f'{b:02X}' for b in data)}")
            print(f"    Dec: {' '.join(str(b) for b in data)}")
        else:
            print("  No response received")

        print()

        # Test 2: Send multiple times
        print("Test 2: Sending 5x PROG_REQUEST with delays...")
        for i in range(5):
            ser.write(bytes([0x01]))
            ser.flush()
            print(f"  Attempt {i+1}: Sent 0x01", end="")
            time.sleep(0.2)

            waiting = ser.in_waiting
            if waiting > 0:
                data = ser.read(waiting)
                print(f" → Received {len(data)} bytes: {' '.join(f'{b:02X}' for b in data)}")
            else:
                print(" → No response")

        print()

        # Test 3: Continuous listen
        print("Test 3: Listening for 3 seconds (any spontaneous FPGA output)...")
        start = time.time()
        total_received = 0

        while time.time() - start < 3:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                total_received += len(data)
                print(f"  [{time.time()-start:.2f}s] Received: {' '.join(f'{b:02X}' for b in data)}")
            time.sleep(0.1)

        print(f"  Total bytes received: {total_received}")
        print()

        # Test 4: Different baud rates (in case there's a mismatch)
        print("Test 4: Testing different baud rates...")
        for baud in [9600, 19200, 38400, 57600, 115200]:
            ser.close()
            ser = serial.Serial(port, baud, timeout=0.5)
            ser.reset_input_buffer()
            ser.reset_output_buffer()

            ser.write(bytes([0x01]))
            ser.flush()
            time.sleep(0.2)

            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                print(f"  Baud {baud}: Received {len(data)} bytes!")
            else:
                print(f"  Baud {baud}: No response")

        ser.close()
        print()
        print("=" * 60)
        print("Diagnostic complete")

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    ports = [
        "/dev/cu.usbmodem1302",
        "/dev/cu.usbmodemSN234567892",
        "/dev/cu.usbserial-1400",
        "/dev/cu.usbserial-1401"
    ]

    if len(sys.argv) > 1:
        test_uart(sys.argv[1])
    else:
        print("Testing all available ports...")
        print()
        for port in ports:
            try:
                test_uart(port)
                print("\n")
            except Exception as e:
                print(f"Skipping {port}: {e}\n")
