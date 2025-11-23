# Quick Start: AES-128 Upgrade

## TL;DR - Get it Running Fast

### 1. Install Python Dependencies
```bash
pip3 install pycryptodome pyserial
```

### 2. Enable AES-128 Top Module
```bash
cd icebreaker
cp top_aes.v top.v
```

### 3. Build and Flash
```bash
make clean
make
make prog
```

### 4. Test
```bash
python3 test_auth.py /dev/tty.usbmodem*
```

You should see 128-bit challenges and successful authentication!

---

## Key Changes

| Item | Old | New |
|------|-----|-----|
| Challenge size | 16-bit (4 hex) | 128-bit (32 hex) |
| Crypto | `(x^k)+k` | AES-128-ECB |
| Security | Weak | Industry standard |
| Key | `0xA5C3` | `0xA5C3DEADBEEFCAFE1337FACEB00BC0DE` |

---

## What to Expect

### Challenge Message
```
CHAL:A1B2C3D4E5F6789012345678ABCDEF01\n
```
(38 bytes: "CHAL:" + 32 hex chars + newline)

### Response Message
```
RESP:9F8E7D6C5B4A39281726354695A8B7C6\n
```
(38 bytes: "RESP:" + 32 hex chars + newline)

### LED Behavior
- **Slow blink**: Not authenticated
- **Fast blink**: Authenticated

### After Authentication
- Send `Y` → CONTROL_PIN = 0V (programming enabled)
- Send `N` → CONTROL_PIN = 3.3V (programming disabled)

---

## Troubleshooting One-Liners

**Build fails?**
```bash
ls icebreaker/aes_*.v | wc -l  # Should show 7 files
```

**Python import error?**
```bash
pip3 install pycryptodome
```

**Wrong serial port?**
```bash
ls /dev/tty.usbmodem*
```

**Test AES in Python?**
```python
from Crypto.Cipher import AES
key = bytes.fromhex('A5C3DEADBEEFCAFE1337FACEB00BC0DE')
cipher = AES.new(key, AES.MODE_ECB)
challenge = bytes.fromhex('00112233445566778899AABBCCDDEEFF')
response = cipher.encrypt(challenge)
print(response.hex().upper())
# Output: 9C50BB5D164B30AAF1537778ABC4025A
```

---

## File Checklist

Required files:

**In [icebreaker/](../icebreaker/):**
- ✅ [top_aes.v](../icebreaker/top_aes.v) - New top module
- ✅ [aes_wrapper.v](../icebreaker/aes_wrapper.v) - Custom AES wrapper
- ✅ [uart_tx.v](../icebreaker/uart_tx.v), [uart_rx.v](../icebreaker/uart_rx.v), [lfsr.v](../icebreaker/lfsr.v) - Supporting modules

**In [external/secworks_aes/src/rtl/](../external/secworks_aes/src/rtl/):**
- ✅ aes_core.v - AES core (from library)
- ✅ aes_encipher_block.v - Encryption
- ✅ aes_decipher_block.v - Decryption
- ✅ aes_key_mem.v - Key expansion
- ✅ aes_sbox.v - S-box
- ✅ aes_inv_sbox.v - Inverse S-box

---

## Security Upgrade Summary

**Before**: Trivially breakable (2^16 keyspace, reversible function)

**After**: Industry-standard AES-128 (2^128 keyspace, no known practical attacks)

**Result**: Billions of years to brute force vs. milliseconds

---

## Full Documentation

See [AES_UPGRADE.md](AES_UPGRADE.md) for complete details.
