#!/usr/bin/env python3
"""
Legitimate User Encryption Script
Encrypts messages with XOR cipher and sends to Translation Pico

The encrypted data flows:
  Legitimate User (this script) → Translation Pico → FPGA (decrypts & validates)

XOR Key: 0xDE 0xAD 0xBE 0xEF (4-byte repeating pattern)
"""

import argparse
import sys
import time
import serial  # Lazy import to allow testing without pyserial


XOR_KEY = [0xDE, 0xAD, 0xBE, 0xEF]


def xor_encrypt(plaintext: str) -> bytes:
    """
    Encrypt plaintext string using repeating XOR key.

    Args:
        plaintext: String to encrypt

    Returns:
        Encrypted bytes
    """
    plaintext_bytes = plaintext.encode("ascii")
    encrypted = bytearray()

    for i, byte in enumerate(plaintext_bytes):
        key_byte = XOR_KEY[i % len(XOR_KEY)]
        encrypted_byte = byte ^ key_byte
        encrypted.append(encrypted_byte)

    return bytes(encrypted)


def send_via_serial(data: bytes, port: str, baudrate: int = 115200):
    """
    Send encrypted data via serial port to Translation Pico.

    Args:
        data: Encrypted bytes to send
        port: Serial port path (e.g., /dev/ttyACM0)
        baudrate: Baud rate (default: 115200)
    """
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"Connected to {port} at {baudrate} baud")
            time.sleep(0.5)  # Allow connection to stabilize

            print(f"Sending {len(data)} encrypted bytes...")
            ser.write(data)
            ser.flush()

            print("✓ Data sent successfully")

    except serial.SerialException as e:
        print(f"✗ Serial error: {e}", file=sys.stderr)
        sys.exit(1)


def display_encryption_details(plaintext: str, encrypted: bytes):
    """Display encryption details for debugging."""
    print("\n" + "=" * 60)
    print("ENCRYPTION DETAILS")
    print("=" * 60)
    print(f"Plaintext:  {plaintext}")
    print(f"Plaintext (hex):  {plaintext.encode('ascii').hex(' ')}")
    print(f"XOR Key:          {' '.join(f'{k:02x}' for k in XOR_KEY)} (repeating)")
    print(f"Encrypted (hex):  {encrypted.hex(' ')}")
    print("=" * 60 + "\n")


def interactive_mode(port: str):
    """
    Interactive mode: repeatedly prompt user for messages to encrypt and send.

    Args:
        port: Serial port path
    """
    print("\n=== Legitimate User Interactive Mode ===")
    print(f"Serial port: {port}")
    print(f"XOR Key: {' '.join(f'0x{k:02X}' for k in XOR_KEY)}")
    print("\nType messages to encrypt and send (Ctrl+C to quit)\n")

    try:
        while True:
            message = input("Enter message: ").strip()

            if not message:
                print("Empty message, skipping.")
                continue

            # Encrypt
            encrypted = xor_encrypt(message)

            # Display details
            display_encryption_details(message, encrypted)

            # Send
            send_via_serial(encrypted, port)
            print()

    except KeyboardInterrupt:
        print("\n\nExiting interactive mode.")
        sys.exit(0)


def main():
    parser = argparse.ArgumentParser(
        description="Encrypt and send messages via serial to Translation Pico",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  %(prog)s -p /dev/ttyACM0 -i

  # Send specific message
  %(prog)s -p /dev/ttyACM0 -m "CAT"

  # Send message and show encryption details
  %(prog)s -p /dev/ttyACM0 -m "CAT" -v
        """,
    )

    parser.add_argument(
        "-p", "--port", required=True, help="Serial port (e.g., /dev/ttyACM0, COM3)"
    )

    parser.add_argument(
        "-m", "--message", help="Message to encrypt and send (plaintext)"
    )

    parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="Interactive mode: repeatedly prompt for messages",
    )

    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Show encryption details"
    )

    parser.add_argument(
        "-b", "--baudrate", type=int, default=115200, help="Baud rate (default: 115200)"
    )

    args = parser.parse_args()

    # Validate arguments
    if not args.interactive and not args.message:
        parser.error("Either --message or --interactive is required")

    if args.interactive:
        interactive_mode(args.port)
    else:
        # Single message mode
        encrypted = xor_encrypt(args.message)

        if args.verbose:
            display_encryption_details(args.message, encrypted)

        send_via_serial(encrypted, args.port, args.baudrate)


if __name__ == "__main__":
    main()
