#!/usr/bin/env python3
"""Test the XOR encryption logic"""

import sys
sys.path.insert(0, '.')
from send_encrypted import xor_encrypt, XOR_KEY


def xor_encrypt_bytes(data: bytes) -> bytes:
    """XOR encrypt bytes directly (for testing symmetric property)."""
    encrypted = bytearray()
    for i, byte in enumerate(data):
        key_byte = XOR_KEY[i % len(XOR_KEY)]
        encrypted_byte = byte ^ key_byte
        encrypted.append(encrypted_byte)
    return bytes(encrypted)


def test_xor_encryption():
    """Test XOR encryption with known values."""
    print("Testing XOR encryption logic...")
    print()

    # Test 1: Encrypt "CAT"
    plaintext = "CAT"
    encrypted = xor_encrypt(plaintext)

    print(f"Test 1: Encrypt '{plaintext}'")
    print(f"  Plaintext bytes: {plaintext.encode('ascii').hex(' ')}")
    print(f"  XOR Key:         {' '.join(f'{k:02x}' for k in XOR_KEY)}")
    print(f"  Expected:        C(67)^DE=B9, A(65)^AD=C8, T(84)^BE=DA")

    # Calculate expected manually
    expected = bytes([
        ord('C') ^ 0xDE,  # 0x43 ^ 0xDE = 0x9D
        ord('A') ^ 0xAD,  # 0x41 ^ 0xAD = 0xEC
        ord('T') ^ 0xBE,  # 0x54 ^ 0xBE = 0xEA
    ])

    print(f"  Encrypted:       {encrypted.hex(' ')}")
    print(f"  Expected:        {expected.hex(' ')}")

    if encrypted == expected:
        print("  ✓ PASS")
    else:
        print("  ✗ FAIL")
        return False

    print()

    # Test 2: Symmetric property (XOR twice returns original)
    print("Test 2: Symmetric property (encrypt twice = original)")
    decrypted = xor_encrypt_bytes(encrypted)
    print(f"  Encrypted again: {decrypted.hex(' ')}")
    print(f"  Original:        {plaintext.encode('ascii').hex(' ')}")

    if decrypted == plaintext.encode('ascii'):
        print("  ✓ PASS - XOR is symmetric")
    else:
        print("  ✗ FAIL - XOR should be symmetric")
        return False

    print()

    # Test 3: Key rotation (4-byte key repeats)
    print("Test 3: Key rotation with longer message")
    long_plaintext = "CATDOG"
    long_encrypted = xor_encrypt(long_plaintext)

    print(f"  Plaintext: {long_plaintext}")
    print(f"  Plaintext bytes: {long_plaintext.encode('ascii').hex(' ')}")
    print(f"  Encrypted bytes: {long_encrypted.hex(' ')}")

    # Verify key rotation: positions 0 and 4 should use same key byte
    if long_encrypted[0] == (ord('C') ^ XOR_KEY[0]) and \
       long_encrypted[4] == (ord('O') ^ XOR_KEY[0]):
        print("  ✓ PASS - Key rotates correctly")
    else:
        print("  ✗ FAIL - Key rotation incorrect")
        return False

    print()
    print("="*60)
    print("ALL TESTS PASSED ✓")
    print("="*60)
    return True


if __name__ == '__main__':
    success = test_xor_encryption()
    sys.exit(0 if success else 1)
