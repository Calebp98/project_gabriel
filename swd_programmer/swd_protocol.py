#!/usr/bin/env python3
"""
SWD Protocol Implementation
Implements ARM Serial Wire Debug (SWD) protocol on top of the bridge interface.
"""

from swd_bridge import SWDBridge, bits_to_int, int_to_bits, calculate_parity
from typing import Tuple, Optional


# SWD Protocol Constants
class SWDPort:
    """SWD Access Port / Debug Port selection."""
    DP = 0  # Debug Port
    AP = 1  # Access Port


class SWDAccess:
    """SWD Read/Write selection."""
    WRITE = 0
    READ = 1


# SWD Acknowledgement responses
class SWDACK:
    """SWD ACK responses."""
    OK = 0b001     # Transaction OK
    WAIT = 0b010   # Target requests wait
    FAULT = 0b100  # Transaction fault
    NONE = 0b111   # No response (protocol error)


# Debug Port (DP) Registers
class DPReg:
    """Debug Port register addresses."""
    DPIDR = 0x0    # DP Identification Register
    CTRL_STAT = 0x4  # Control/Status Register
    SELECT = 0x8   # AP Select Register
    RDBUFF = 0xC   # Read Buffer


# Common AP Registers (when SELECT.APSEL = 0, AHB-AP)
class APReg:
    """Access Port register addresses (AHB-AP)."""
    CSW = 0x00     # Control/Status Word
    TAR = 0x04     # Transfer Address Register
    DRW = 0x0C     # Data Read/Write Register
    IDR = 0xFC     # Identification Register


class SWDProtocol:
    """ARM SWD Protocol implementation."""

    def __init__(self, bridge: SWDBridge):
        """
        Initialize SWD protocol handler.

        Args:
            bridge: SWDBridge instance
        """
        self.bridge = bridge
        self.current_ap = 0  # Currently selected AP

    def line_reset(self):
        """Perform SWD line reset."""
        self.bridge.line_reset()

    def switch_to_swd(self):
        """
        Switch from JTAG to SWD mode.
        Sends JTAG-to-SWD sequence: 0xE79E (16 bits)
        """
        # Line reset first
        self.line_reset()

        # JTAG-to-SWD sequence: 0xE79E
        # Sent as: 0111 1001 1110 0111 (LSB first in groups)
        sequence = int_to_bits(0xE79E, 16)
        self.bridge.write_bits(sequence)

        # More idle cycles
        self.bridge.idle_cycles(8)

        # Another line reset
        self.line_reset()

        # Idle
        self.bridge.idle_cycles(8)

    def build_request(self, ap_ndp: int, read_nwrite: int, addr: int) -> int:
        """
        Build SWD request packet (8 bits).

        Format:
        [0] Start bit (always 1)
        [1] AP/DP# (1=AP, 0=DP)
        [2] R/W# (1=Read, 0=Write)
        [3:4] Address[2:3]
        [5] Parity (odd parity of bits 1-4)
        [6] Stop bit (always 0)
        [7] Park bit (always 1)

        Args:
            ap_ndp: 0 for DP, 1 for AP
            read_nwrite: 0 for write, 1 for read
            addr: Register address (only bits [3:2] used)

        Returns:
            8-bit request value
        """
        # Extract address bits [3:2]
        a2 = (addr >> 2) & 1
        a3 = (addr >> 3) & 1

        # Build request
        request = 0b10000001  # Start=1, Stop=0, Park=1 in positions 0,6,7

        request |= (ap_ndp << 1)
        request |= (read_nwrite << 2)
        request |= (a2 << 3)
        request |= (a3 << 4)

        # Calculate parity of bits [1:4]
        parity_bits = (request >> 1) & 0xF
        parity = calculate_parity(parity_bits, 4)
        request |= (int(parity) << 5)

        return request

    def send_request(self, ap_ndp: int, read_nwrite: int, addr: int):
        """
        Send SWD request packet.

        Args:
            ap_ndp: 0 for DP, 1 for AP
            read_nwrite: 0 for write, 1 for read
            addr: Register address
        """
        request = self.build_request(ap_ndp, read_nwrite, addr)
        request_bits = int_to_bits(request, 8)
        self.bridge.write_bits(request_bits)

    def read_ack(self) -> int:
        """
        Read 3-bit ACK response.

        Returns:
            ACK value (SWDACK.OK, WAIT, FAULT, or NONE)
        """
        # Turnaround cycle (host->target transition)
        self.bridge.turnaround()

        # Read 3 ACK bits
        ack_bits = self.bridge.read_bits(3)
        ack = bits_to_int(ack_bits)

        return ack

    def read_data(self) -> Tuple[int, bool]:
        """
        Read 32-bit data word + parity.

        Returns:
            Tuple of (data_value, parity_ok)
        """
        # Read 32 data bits + 1 parity bit
        data_bits = self.bridge.read_bits(32)
        parity_bit = self.bridge.read_bits(1)

        data = bits_to_int(data_bits)
        received_parity = (parity_bit == '1')

        # Calculate expected parity
        expected_parity = calculate_parity(data, 32)

        parity_ok = (received_parity == expected_parity)

        return data, parity_ok

    def write_data(self, data: int):
        """
        Write 32-bit data word + parity.

        Args:
            data: 32-bit value to write
        """
        # Turnaround cycle (target->host transition)
        self.bridge.turnaround()

        # Send 32 data bits
        data_bits = int_to_bits(data, 32)
        self.bridge.write_bits(data_bits)

        # Calculate and send parity
        parity = calculate_parity(data, 32)
        self.bridge.write_bits('1' if parity else '0')

    def read_dp(self, addr: int, retries: int = 100) -> Optional[int]:
        """
        Read from Debug Port register.

        Args:
            addr: DP register address (0x0, 0x4, 0x8, 0xC)
            retries: Max retry attempts for WAIT

        Returns:
            32-bit value, or None on error
        """
        for attempt in range(retries):
            # Send read request
            self.send_request(SWDPort.DP, SWDAccess.READ, addr)

            # Read ACK
            ack = self.read_ack()

            if ack == SWDACK.OK:
                # Read data + parity
                data, parity_ok = self.read_data()

                # Turnaround back to output
                self.bridge.turnaround()

                # Idle cycles
                self.bridge.idle_cycles(8)

                if not parity_ok:
                    print(f"Warning: Parity error reading DP {addr:#x}")

                return data

            elif ack == SWDACK.WAIT:
                # Target not ready, retry
                self.bridge.turnaround()  # Back to output
                self.bridge.idle_cycles(8)
                continue

            elif ack == SWDACK.FAULT:
                print(f"FAULT reading DP {addr:#x}")
                self.bridge.turnaround()
                return None

            else:
                print(f"No ACK reading DP {addr:#x}")
                self.line_reset()
                return None

        print(f"Timeout reading DP {addr:#x} after {retries} WAIT responses")
        return None

    def write_dp(self, addr: int, data: int, retries: int = 100) -> bool:
        """
        Write to Debug Port register.

        Args:
            addr: DP register address
            data: 32-bit value to write
            retries: Max retry attempts for WAIT

        Returns:
            True on success, False on error
        """
        for attempt in range(retries):
            # Send write request
            self.send_request(SWDPort.DP, SWDAccess.WRITE, addr)

            # Read ACK
            ack = self.read_ack()

            if ack == SWDACK.OK:
                # Write data + parity
                self.write_data(data)

                # Idle cycles
                self.bridge.idle_cycles(8)

                return True

            elif ack == SWDACK.WAIT:
                # Target not ready, retry
                self.bridge.turnaround()
                self.bridge.idle_cycles(8)
                continue

            elif ack == SWDACK.FAULT:
                print(f"FAULT writing DP {addr:#x}")
                self.bridge.turnaround()
                return False

            else:
                print(f"No ACK writing DP {addr:#x}")
                self.line_reset()
                return False

        print(f"Timeout writing DP {addr:#x} after {retries} WAIT responses")
        return False

    def read_ap(self, addr: int, retries: int = 100) -> Optional[int]:
        """
        Read from Access Port register.

        Args:
            addr: AP register address
            retries: Max retry attempts

        Returns:
            32-bit value, or None on error
        """
        # First read posts the request
        self.send_request(SWDPort.AP, SWDAccess.READ, addr)
        ack = self.read_ack()

        if ack != SWDACK.OK:
            self.bridge.turnaround()
            print(f"Failed to post AP read {addr:#x}")
            return None

        # Dummy read to get turnaround
        _, _ = self.read_data()
        self.bridge.turnaround()
        self.bridge.idle_cycles(8)

        # Read RDBUFF to get actual data
        return self.read_dp(DPReg.RDBUFF, retries)

    def write_ap(self, addr: int, data: int, retries: int = 100) -> bool:
        """
        Write to Access Port register.

        Args:
            addr: AP register address
            data: 32-bit value
            retries: Max retry attempts

        Returns:
            True on success
        """
        return self.write_dp(addr | 0x10, data, retries)  # AP writes use different encoding

    def read_idcode(self) -> Optional[int]:
        """
        Read IDCODE from Debug Port.

        Returns:
            32-bit IDCODE, or None on error
        """
        return self.read_dp(DPReg.DPIDR)


if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python swd_protocol.py <serial_port>")
        sys.exit(1)

    port = sys.argv[1]

    print(f"Testing SWD protocol on {port}...")

    with SWDBridge(port) as bridge:
        swd = SWDProtocol(bridge)

        print("Switching to SWD mode...")
        swd.switch_to_swd()

        print("Reading IDCODE...")
        idcode = swd.read_idcode()

        if idcode:
            print(f"IDCODE: 0x{idcode:08X}")
            print(f"  Version: {(idcode >> 28) & 0xF}")
            print(f"  PartNo: 0x{(idcode >> 12) & 0xFFFF:04X}")
            print(f"  Designer: 0x{(idcode >> 1) & 0x7FF:03X}")
        else:
            print("Failed to read IDCODE")
