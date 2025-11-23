#!/usr/bin/env python3
"""
Secure FPGA Gatekeeper - Laptop Authentication Client

Authenticates with FPGA to gain programming access to target Raspberry Pi Pico.
Uses challenge-response protocol over UART via Pico Probe.
"""

import serial
import time
import sys
import struct

# Configuration
DEFAULT_PORT = "/dev/cu.usbmodem1402"  # Pico Probe UART port
BAUD_RATE = 115200
TIMEOUT = 10  # seconds

# Pre-shared secret key
SECRET_KEY = 0xDEADBEEF

# Command codes
CMD_PROG_REQUEST = 0x01
CMD_CHALLENGE    = 0x02
CMD_RESPONSE     = 0x03
CMD_AUTH_OK      = 0x04
CMD_AUTH_FAIL    = 0x05
CMD_STATUS       = 0x06


class FPGAAuthenticator:
    """Handles authentication with FPGA gatekeeper"""

    def __init__(self, port=DEFAULT_PORT, baud=BAUD_RATE, timeout=TIMEOUT):
        """Initialize serial connection to FPGA via Pico Probe"""
        self.port = port
        self.baud = baud
        self.timeout = timeout
        self.ser = None

    def connect(self):
        """Open serial connection"""
        try:
            self.ser = serial.Serial(
                self.port,
                self.baud,
                timeout=self.timeout,
                bytesize=8,
                parity='N',
                stopbits=1
            )
            time.sleep(0.1)  # Allow connection to stabilize
            # Flush any existing data
            self.ser.reset_input_buffer()
            self.ser.reset_output_buffer()
            print(f"Connected to {self.port} at {self.baud} baud")
            return True
        except serial.SerialException as e:
            print(f"Error connecting to {self.port}: {e}")
            return False

    def disconnect(self):
        """Close serial connection"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("Disconnected")

    def send_packet(self, cmd, data=None):
        """Send a packet to FPGA"""
        if data is None:
            # Command only
            packet = bytes([cmd])
        else:
            # Command + 32-bit data (big-endian)
            packet = struct.pack('>BI', cmd, data)

        self.ser.write(packet)
        print(f"Sent: CMD=0x{cmd:02X}", end="")
        if data is not None:
            print(f" DATA=0x{data:08X}", end="")
        print()

    def receive_packet(self):
        """Receive a packet from FPGA"""
        # Read command byte
        cmd_byte = self.ser.read(1)
        if len(cmd_byte) == 0:
            print("Timeout: No response from FPGA")
            return None, None

        cmd = cmd_byte[0]

        # Check if this command has data payload
        if cmd in [CMD_CHALLENGE, CMD_STATUS]:
            # Read 4 bytes of data
            data_bytes = self.ser.read(4)
            if len(data_bytes) < 4:
                print("Timeout: Incomplete packet received")
                return None, None
            data = struct.unpack('>I', data_bytes)[0]
            print(f"Received: CMD=0x{cmd:02X} DATA=0x{data:08X}")
            return cmd, data
        else:
            # Command only
            print(f"Received: CMD=0x{cmd:02X}")
            return cmd, None

    def authenticate(self):
        """Perform full authentication sequence"""
        print("\n=== Starting Authentication ===\n")

        # Step 1: Send programming request
        print("[1/4] Sending programming request...")
        self.send_packet(CMD_PROG_REQUEST)

        # Step 2: Receive challenge
        print("[2/4] Waiting for challenge...")
        cmd, challenge = self.receive_packet()

        if cmd != CMD_CHALLENGE or challenge is None:
            print("ERROR: Did not receive valid challenge")
            return False

        print(f"Challenge received: 0x{challenge:08X}")

        # Step 3: Compute and send response
        print("[3/4] Computing response...")
        response = challenge ^ SECRET_KEY
        print(f"Response computed: 0x{response:08X}")

        print("[3/4] Sending response...")
        self.send_packet(CMD_RESPONSE, response)

        # Step 4: Wait for authentication result
        print("[4/4] Waiting for authentication result...")
        cmd, _ = self.receive_packet()

        if cmd == CMD_AUTH_OK:
            print("\n✓ SUCCESS: Authentication approved!")
            print("FPGA has disabled jamming - you may now program the target Pico")
            return True
        elif cmd == CMD_AUTH_FAIL:
            print("\n✗ FAILURE: Authentication denied!")
            print("Incorrect response - check SECRET_KEY")
            return False
        else:
            print(f"\n✗ ERROR: Unexpected response (CMD=0x{cmd:02X})")
            return False

    def monitor_status(self, duration=5):
        """Monitor FPGA status messages for a duration"""
        print(f"\nMonitoring FPGA status for {duration} seconds...")
        start_time = time.time()

        while time.time() - start_time < duration:
            if self.ser.in_waiting > 0:
                cmd, data = self.receive_packet()
                if cmd == CMD_STATUS:
                    print(f"Status update: 0x{data:08X}")
            time.sleep(0.1)

        print("Monitoring complete")


def main():
    """Main entry point"""
    # Parse command line arguments
    port = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PORT

    print("=" * 60)
    print("Secure FPGA Gatekeeper - Authentication Client")
    print("=" * 60)

    # Create authenticator
    auth = FPGAAuthenticator(port=port)

    try:
        # Connect to FPGA
        if not auth.connect():
            sys.exit(1)

        # Perform authentication
        success = auth.authenticate()

        if success:
            print("\n" + "=" * 60)
            print("Authentication successful!")
            print("You can now program the target Pico using:")
            print("  ./flash_target.sh")
            print("=" * 60)
            sys.exit(0)
        else:
            print("\n" + "=" * 60)
            print("Authentication failed!")
            print("Check that:")
            print("  1. FPGA is programmed with secure_gatekeeper.v")
            print("  2. SECRET_KEY matches (0xDEADBEEF)")
            print("  3. UART connections are correct")
            print("=" * 60)
            sys.exit(1)

    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        auth.disconnect()


if __name__ == "__main__":
    main()
