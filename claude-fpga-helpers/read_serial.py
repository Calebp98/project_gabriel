#!/usr/bin/env python3
import sys
import serial
import time
import glob

def read_serial(duration=5, port=None):
    if port is None:
        # Auto-detect: prefer picoprobe ports
        ports = glob.glob('/dev/cu.usbmodem*') + glob.glob('/dev/tty.usbmodem*')
        if not ports:
            print("Error: No serial port found")
            sys.exit(1)
        port = ports[0]
        print(f"Warning: Using auto-detected port {port}")
        print(f"Recommend specifying port explicitly: ./read_serial.py {duration} /dev/cu.usbmodem1402")

    print(f"Reading from {port} for {duration} seconds...")
    
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        start = time.time()
        
        while time.time() - start < duration:
            if ser.in_waiting:
                line = ser.readline().decode('ascii', errors='ignore').strip()
                if line:
                    print(line)
        
        ser.close()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    port = sys.argv[2] if len(sys.argv) > 2 else None
    read_serial(duration, port)