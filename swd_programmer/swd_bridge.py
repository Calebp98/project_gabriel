#!/usr/bin/env python3
"""
SWD Bridge Interface
Low-level interface to the Pico SWD bridge hardware.
Provides methods to control SWCLK and SWDIO pins via serial commands.
"""

import serial
import time
from typing import Optional


class SWDBridge:
    """Interface to Pico SWD Bridge hardware."""

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0):
        """
        Initialize connection to SWD bridge.

        Args:
            port: Serial port (e.g., '/dev/cu.usbmodem1301' or 'COM3')
            baudrate: Serial baud rate (default: 115200)
            timeout: Read timeout in seconds
        """
        self.ser = serial.Serial(port, baudrate, timeout=timeout)
        time.sleep(0.5)  # Wait for connection to stabilize

        # Clear any startup messages (bridge sends "SWD Bridge Ready")
        time.sleep(0.1)
        self.ser.reset_input_buffer()

        # Verify connection
        self.ser.write(b'?')
        # Read all lines until timeout (status command returns multiple lines)
        lines = []
        while True:
            line = self.ser.readline().decode().strip()
            if not line:
                break
            lines.append(line)

        response = '\n'.join(lines)
        if 'SWD Bridge' not in response:
            raise RuntimeError(f"Unexpected response from bridge: {response}")

        print(f"Connected to: {lines[0] if lines else 'SWD Bridge'}")

    def close(self):
        """Close serial connection."""
        if self.ser and self.ser.is_open:
            self.ser.close()

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()

    # === Low-level pin control ===

    def swclk_high(self):
        """Set SWCLK pin HIGH."""
        self.ser.write(b'C')

    def swclk_low(self):
        """Set SWCLK pin LOW."""
        self.ser.write(b'c')

    def swdio_high(self):
        """Set SWDIO pin HIGH (requires output mode)."""
        self.ser.write(b'D')

    def swdio_low(self):
        """Set SWDIO pin LOW (requires output mode)."""
        self.ser.write(b'd')

    def swdio_input(self):
        """Set SWDIO to INPUT mode."""
        self.ser.write(b'I')

    def swdio_output(self):
        """Set SWDIO to OUTPUT mode."""
        self.ser.write(b'O')

    def swdio_read(self) -> bool:
        """
        Read SWDIO pin state.

        Returns:
            True if HIGH, False if LOW
        """
        self.ser.write(b'R')
        response = self.ser.read(1)
        return response == b'1'

    def line_reset(self):
        """Perform SWD line reset (50+ clocks with SWDIO high)."""
        self.ser.reset_input_buffer()  # Clear any pending data
        self.ser.write(b'r')
        response = self.ser.read_until(b'\n').decode().strip()
        if response != 'OK':
            raise RuntimeError(f"Line reset failed: {response}")

    # === Bit-level operations ===

    def write_bit(self, bit: bool):
        """
        Write a single bit to SWDIO and pulse clock.

        Args:
            bit: True for 1, False for 0
        """
        self.swdio_output()
        if bit:
            self.swdio_high()
        else:
            self.swdio_low()
        self.swclk_high()
        self.swclk_low()

    def read_bit(self) -> bool:
        """
        Read a single bit from SWDIO with clock pulse.

        Returns:
            True for 1, False for 0
        """
        self.swdio_input()
        self.swclk_high()
        bit = self.swdio_read()
        self.swclk_low()
        return bit

    def write_bits(self, bits: str):
        """
        Write multiple bits using buffered command.

        Args:
            bits: String of '0' and '1' characters (e.g., '10110')
        """
        count = len(bits)
        if count > 255:
            raise ValueError("Maximum 255 bits per write")

        # Send command: 'W' <count> <bit0> <bit1> ...
        self.ser.write(b'W')
        self.ser.write(bytes([count]))
        self.ser.write(bits.encode())

        # Wait for OK
        response = self.ser.read_until(b'\n').decode().strip()
        if response != 'OK':
            raise RuntimeError(f"Write bits failed: {response}")

    def read_bits(self, count: int) -> str:
        """
        Read multiple bits using buffered command.

        Args:
            count: Number of bits to read

        Returns:
            String of '0' and '1' characters
        """
        if count > 255:
            raise ValueError("Maximum 255 bits per read")

        # Send command: 'X' <count>
        self.ser.write(b'X')
        self.ser.write(bytes([count]))

        # Read response (bits + newline)
        response = self.ser.read_until(b'\n').decode().strip()
        if len(response) != count:
            raise RuntimeError(f"Expected {count} bits, got {len(response)}")

        return response

    # === Byte-level operations ===

    def write_byte(self, byte_val: int):
        """
        Write a byte LSB-first.

        Args:
            byte_val: Byte value (0-255)
        """
        if not 0 <= byte_val <= 255:
            raise ValueError("Byte value must be 0-255")

        self.ser.write(b'B')
        self.ser.write(bytes([byte_val]))

    def read_byte(self) -> int:
        """
        Read a byte LSB-first.

        Returns:
            Byte value (0-255)
        """
        self.ser.write(b'b')
        response = self.ser.read(1)
        if len(response) != 1:
            raise RuntimeError("Failed to read byte")

        return response[0]

    # === Word-level operations (32-bit) ===

    def write_word(self, word: int):
        """
        Write a 32-bit word LSB-first.

        Args:
            word: 32-bit value
        """
        if not 0 <= word <= 0xFFFFFFFF:
            raise ValueError("Word must be 32-bit value")

        # Write 4 bytes, LSB first
        for i in range(4):
            byte_val = (word >> (i * 8)) & 0xFF
            self.write_byte(byte_val)

    def read_word(self) -> int:
        """
        Read a 32-bit word LSB-first.

        Returns:
            32-bit value
        """
        word = 0
        for i in range(4):
            byte_val = self.read_byte()
            word |= (byte_val << (i * 8))

        return word

    # === Idle/turnaround cycles ===

    def idle_cycles(self, count: int = 8):
        """
        Generate idle cycles (SWDIO low, clock pulses).

        Args:
            count: Number of idle cycles (default: 8)
        """
        self.swdio_output()
        self.swdio_low()
        for _ in range(count):
            self.swclk_high()
            self.swclk_low()

    def turnaround(self):
        """
        Perform turnaround cycle (switch SWDIO direction).
        One clock cycle with SWDIO in input mode.
        """
        self.swdio_input()
        self.swclk_high()
        self.swclk_low()


# === Utility functions ===

def bits_to_int(bits: str) -> int:
    """
    Convert bit string to integer (LSB first).

    Args:
        bits: String of '0' and '1' (e.g., '10110')

    Returns:
        Integer value
    """
    value = 0
    for i, bit in enumerate(bits):
        if bit == '1':
            value |= (1 << i)
    return value


def int_to_bits(value: int, width: int) -> str:
    """
    Convert integer to bit string (LSB first).

    Args:
        value: Integer value
        width: Number of bits

    Returns:
        String of '0' and '1'
    """
    bits = ''
    for i in range(width):
        bits += '1' if (value & (1 << i)) else '0'
    return bits


def calculate_parity(value: int, width: int) -> bool:
    """
    Calculate odd parity for a value.

    Args:
        value: Integer value
        width: Number of bits to consider

    Returns:
        Parity bit (True/False)
    """
    count = 0
    for i in range(width):
        if value & (1 << i):
            count += 1
    return count % 2 == 1  # Odd parity


if __name__ == '__main__':
    # Simple test
    import sys

    if len(sys.argv) < 2:
        print("Usage: python swd_bridge.py <serial_port>")
        print("Example: python swd_bridge.py /dev/cu.usbmodem1301")
        sys.exit(1)

    port = sys.argv[1]

    print(f"Testing SWD bridge on {port}...")

    with SWDBridge(port) as bridge:
        print("Performing line reset...")
        bridge.line_reset()

        print("Testing bit write/read...")
        bridge.write_bit(True)
        bridge.write_bit(False)
        bridge.write_bit(True)

        print("Testing buffered write...")
        bridge.write_bits('10110011')

        print("Testing byte operations...")
        bridge.write_byte(0xAB)

        print("Success! Bridge is working.")
