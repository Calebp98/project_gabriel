#!/usr/bin/env python3
"""
Test script for iCEbreaker challenge-response authentication

Usage:
    python3 test_auth.py /dev/tty.usbmodemXXXX

The iCEbreaker will send a new challenge every 5 seconds.
After authentication, you can type:
    Y - Set CONTROL_PIN to 0V (LOW/ground)
    N - Set CONTROL_PIN to 3.3V (HIGH)
    Q - Quit

The LED will blink fast when authenticated, slow when not.
"""

import sys
import serial
import time
import threading
import queue

# Secret key (must match the one in top.v)
SECRET_KEY = bytes.fromhex('A5C3DEADBEEFCAFE1337FACEB00BC0DE')

def compute_response(challenge):
    """Compute response from challenge using AES-128"""
    from Crypto.Cipher import AES
    cipher = AES.new(SECRET_KEY, AES.MODE_ECB)
    response = cipher.encrypt(challenge)
    return response

def read_serial(ser, msg_queue):
    """Background thread to read serial data"""
    while True:
        try:
            line = ser.readline().decode('ascii', errors='ignore').strip()
            if line:
                msg_queue.put(line)
        except Exception as e:
            print(f"Read error: {e}")
            break

def handle_challenge(ser, challenge_line):
    """Handle a challenge from the iCEbreaker"""
    print(f"\n[AUTH] Received: {challenge_line}")

    # Parse challenge
    if not challenge_line.startswith("CHAL:"):
        print(f"[ERROR] Expected 'CHAL:XXXX', got '{challenge_line}'")
        return False

    challenge_str = challenge_line.split(':')[1].strip()  # Get hex string after 'CHAL:'

    # Convert hex string to bytes (128-bit = 32 hex chars = 16 bytes)
    try:
        challenge = bytes.fromhex(challenge_str)
        print(f"[AUTH] Challenge: {challenge_str}")
    except ValueError as e:
        print(f"[ERROR] Invalid challenge hex: {e}")
        return False

    # Compute response using AES-128
    response = compute_response(challenge)
    response_hex = response.hex().upper()
    print(f"[AUTH] Response:  {response_hex}")

    # Send response
    response_msg = f"RESP:{response_hex}\n"
    ser.write(response_msg.encode('ascii'))
    print(f"[AUTH] ✓ Authenticated!\n")
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 test_auth.py <serial_port>")
        print("Example: python3 test_auth.py /dev/tty.usbmodem14101")
        sys.exit(1)

    port = sys.argv[1]

    try:
        # Open serial port
        print(f"Opening {port} at 115200 baud...")
        ser = serial.Serial(port, 115200, timeout=0.1)
        time.sleep(0.1)

        # Message queue for serial reads
        msg_queue = queue.Queue()

        # Start background reader thread
        reader_thread = threading.Thread(target=read_serial, args=(ser, msg_queue), daemon=True)
        reader_thread.start()

        print("\nWaiting for initial challenge from iCEbreaker...")
        print("(iCEbreaker will re-challenge every 5 seconds)\n")

        authenticated = False

        # Main loop
        while True:
            # Check for messages from iCEbreaker
            try:
                msg = msg_queue.get_nowait()
                if msg.startswith("CHAL:"):
                    authenticated = handle_challenge(ser, msg)
            except queue.Empty:
                pass

            # If authenticated, allow user to send commands
            if authenticated:
                # Non-blocking check for user input
                import select
                if sys.stdin in select.select([sys.stdin], [], [], 0)[0]:
                    cmd = sys.stdin.readline().strip().upper()
                    if cmd == 'Y':
                        ser.write(cmd.encode('ascii'))
                        print(f"[CMD] Sent: Y → CONTROL_PIN = 0V (LOW/ground)")
                    elif cmd == 'N':
                        ser.write(cmd.encode('ascii'))
                        print(f"[CMD] Sent: N → CONTROL_PIN = 3.3V (HIGH)")
                    elif cmd == 'Q':
                        print("Exiting...")
                        break
                    elif cmd:
                        print(f"[CMD] Invalid: {cmd}. Use Y (0V), N (3.3V), or Q to quit.")

            time.sleep(0.01)  # Small delay to prevent busy-waiting

    except KeyboardInterrupt:
        print("\n\nExiting...")
    except serial.SerialException as e:
        print(f"Serial port error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        if 'ser' in locals():
            ser.close()

if __name__ == "__main__":
    main()
