#!/usr/bin/env python3
import serial
import time
import glob

def capture_pin_state(duration=3, port=None):
    if port is None:
        ports = glob.glob('/dev/tty.usbmodem*') + glob.glob('/dev/cu.usbmodem*')
        if not ports:
            print("Error: No serial port found")
            return None
        port = ports[0]
    print(f"Capturing from {port} for {duration} seconds...")

    try:
        ser = serial.Serial(port, 115200, timeout=1)
        start = time.time()
        received_chars = []

        while time.time() - start < duration:
            if ser.in_waiting:
                byte = ser.read(1)
                if byte:
                    char = byte.decode('ascii', errors='ignore')
                    if char in ['0', '1']:
                        received_chars.append(char)
                        print(f"Received: {char}")

        ser.close()

        if received_chars:
            # Take the most recent value
            pin_state = received_chars[-1]
            print(f"\nPin 38 state: {pin_state}")
            return pin_state
        else:
            print("No data received")
            return None

    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    import sys
    port = sys.argv[1] if len(sys.argv) > 1 else None
    state = capture_pin_state(3, port)
    if state is not None:
        with open('pin38_state.txt', 'w') as f:
            f.write(state)
        print(f"Saved state to pin38_state.txt")
