#!/usr/bin/env python3
"""
Authenticated Flash Script for Project Gabriel

This script:
1. Connects to the iCEbreaker via picoprobe serial
2. Responds to challenge-response authentication
3. Sends 'Y' to enable programming (CONTROL_PIN = 0V/ground)
4. Flashes the target Pico with the specified .elf file
5. Sends 'N' to disable programming (CONTROL_PIN = 3.3V)

Usage:
    python3 flash_authenticated.py <elf_file> [serial_port]

Example:
    python3 flash_authenticated.py pico-examples/build/blink/blink.elf /dev/tty.usbmodem14101
"""

import sys
import serial
import subprocess
import time
import glob

# Secret key (must match the one in top.v) - 128-bit
SECRET_KEY = 0xDEAD_BEEF_CAFE_BABE_1337_C0DE_FACE_FEED

def calculate_response(challenge):
    """Calculate the expected response for a given challenge."""
    return ((challenge ^ SECRET_KEY) + SECRET_KEY) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

def authenticate(ser, timeout=15):
    """
    Wait for challenge and authenticate with the iCEbreaker.
    Returns True if authentication succeeds, False otherwise.
    """
    print("[AUTH] Waiting for challenge from iCEbreaker...")
    print("[AUTH] (Challenges are sent every 5 seconds, so this may take a moment...)")

    # Flush any stale data from the serial buffer
    ser.reset_input_buffer()
    time.sleep(0.1)

    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            # Use readline() to block and wait for a complete line
            line = ser.readline().decode('ascii', errors='ignore').strip()

            if line:
                print(f"[AUTH] Received: {line}")

                if line.startswith('CHAL:'):
                    challenge_hex = line[5:37]  # 32 hex characters for 128-bit
                    try:
                        challenge = int(challenge_hex, 16)
                        print(f"[AUTH] Received challenge: 0x{challenge:032X}")

                        # Calculate and send response
                        response = calculate_response(challenge)
                        response_msg = f"RESP:{response:032X}\n"  # 32 hex characters for 128-bit
                        ser.write(response_msg.encode('ascii'))
                        print(f"[AUTH] Sent response: {response_msg.strip()}")
                        print("[AUTH] ✓ Authentication successful!")

                        # Wait a bit for authentication to process
                        time.sleep(0.2)
                        return True
                    except ValueError:
                        print(f"[AUTH] Invalid challenge format: {line}")
                        return False
        except Exception as e:
            print(f"[AUTH] Error reading serial: {e}")
            return False

    print("[AUTH] ✗ Timeout waiting for challenge")
    return False

def send_control_command(ser, command):
    """Send Y or N command to control the CONTROL_PIN."""
    ser.write(command.encode('ascii'))
    if command == 'Y':
        print(f"[CTRL] Sent 'Y' → CONTROL_PIN = 0V (programming enabled)")
    elif command == 'N':
        print(f"[CTRL] Sent 'N' → CONTROL_PIN = 3.3V (programming disabled)")
    time.sleep(0.1)  # Give time for command to process

def flash_pico(elf_file):
    """Flash the target Pico using OpenOCD."""
    print(f"\n[FLASH] Programming {elf_file} to target Pico...")

    cmd = [
        'openocd',
        '-f', 'interface/cmsis-dap.cfg',
        '-f', 'target/rp2040.cfg',
        '-c', 'adapter speed 5000',
        '-c', f'program {elf_file} verify reset exit'
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            print("[FLASH] ✓ Programming successful!")
            return True
        else:
            print(f"[FLASH] ✗ Programming failed!")
            print(f"[FLASH] Error: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print("[FLASH] ✗ Programming timeout!")
        return False
    except FileNotFoundError:
        print("[FLASH] ✗ OpenOCD not found! Make sure it's installed.")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 flash_authenticated.py <elf_file> [serial_port]")
        print("Example: python3 flash_authenticated.py pico-examples/build/blink/blink.elf")
        sys.exit(1)

    elf_file = sys.argv[1]

    # Verify ELF file exists
    try:
        with open(elf_file, 'rb'):
            pass
    except FileNotFoundError:
        print(f"Error: ELF file not found: {elf_file}")
        sys.exit(1)

    # Determine serial port
    if len(sys.argv) >= 3:
        port = sys.argv[2]
    else:
        # Try to auto-detect picoprobe port
        ports = glob.glob('/dev/tty.usbmodem*')
        if not ports:
            print("Error: No serial port found. Please specify port as second argument.")
            sys.exit(1)
        port = ports[0]
        print(f"[INFO] Auto-detected serial port: {port}")

    try:
        # Open serial connection to iCEbreaker via picoprobe
        print(f"[INFO] Opening serial port {port} at 115200 baud...")
        ser = serial.Serial(
            port=port,
            baudrate=115200,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )

        print("[INFO] Connected to iCEbreaker\n")

        # Step 1: Authenticate with iCEbreaker
        if not authenticate(ser):
            print("\n[ERROR] Authentication failed. Exiting.")
            ser.close()
            sys.exit(1)

        # Step 2: Send 'Y' to enable programming (CONTROL_PIN = 0V)
        print()
        send_control_command(ser, 'Y')

        # Step 3: Flash the target Pico
        success = flash_pico(elf_file)

        # Step 4: Send 'N' to disable programming (CONTROL_PIN = 3.3V)
        print()
        send_control_command(ser, 'N')

        # Close serial connection
        ser.close()
        print("\n[INFO] Serial port closed")

        if success:
            print("[INFO] ✓ Complete! Target Pico programmed successfully.")
            sys.exit(0)
        else:
            print("[INFO] ✗ Programming failed.")
            sys.exit(1)

    except serial.SerialException as e:
        print(f"[ERROR] Serial port error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n[INFO] Interrupted by user")
        if 'ser' in locals() and ser.is_open:
            ser.close()
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        if 'ser' in locals() and ser.is_open:
            ser.close()
        sys.exit(1)

if __name__ == "__main__":
    main()
