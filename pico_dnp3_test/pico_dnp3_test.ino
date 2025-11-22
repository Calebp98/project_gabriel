// DNP3 Link Layer Test Sender for FPGA
// Raspberry Pi Pico sends DNP3 link layer frames
//
// Hardware Setup:
// - Pico GP0 (UART TX) → FPGA Pin 3 (RX)
// - Pico GND → FPGA GND
//
// Expected LED Behavior on FPGA:
// - LED_RX (pin 26): Pulses when each byte is received
// - LED_GREEN (pin 37): ON when valid DNP3 frame with matching address (0x0001)
// - LED_RED (pin 11): ON when frame error detected (bad CRC or invalid format)

// CRC-16 DNP3 calculation
uint16_t calculateDNP3CRC(uint8_t* data, int length) {
  uint16_t crc = 0x0000;

  for (int i = 0; i < length; i++) {
    crc ^= data[i];

    for (int j = 0; j < 8; j++) {
      if (crc & 0x0001) {
        crc = (crc >> 1) ^ 0xA6BC;
      } else {
        crc = crc >> 1;
      }
    }
  }

  return ~crc;  // DNP3 complements the final CRC
}

void sendDNP3Frame(uint16_t dest, uint16_t src, uint8_t control) {
  uint8_t frame[10];

  // Start bytes
  frame[0] = 0x05;
  frame[1] = 0x64;

  // Length (number of bytes after start, including first CRC)
  frame[2] = 0x05;  // 1 (len) + 1 (ctrl) + 2 (dest) + 2 (src) = 6 bytes, but DNP3 counts 5

  // Control byte
  frame[3] = control;

  // Destination address (little-endian)
  frame[4] = dest & 0xFF;
  frame[5] = (dest >> 8) & 0xFF;

  // Source address (little-endian)
  frame[6] = src & 0xFF;
  frame[7] = (src >> 8) & 0xFF;

  // Calculate CRC over bytes 2-7 (length, control, dest, src)
  uint16_t crc = calculateDNP3CRC(&frame[2], 6);

  // CRC bytes (little-endian)
  frame[8] = crc & 0xFF;
  frame[9] = (crc >> 8) & 0xFF;

  // Send the frame
  Serial1.write(frame, 10);
  Serial1.flush();
}

void sendInvalidFrame() {
  uint8_t frame[10];

  // Start bytes
  frame[0] = 0x05;
  frame[1] = 0x64;

  // Length
  frame[2] = 0x05;

  // Control byte
  frame[3] = 0x44;

  // Destination address
  frame[4] = 0x01;
  frame[5] = 0x00;

  // Source address
  frame[6] = 0x10;
  frame[7] = 0x00;

  // Intentionally wrong CRC
  frame[8] = 0xAA;
  frame[9] = 0xBB;

  // Send the frame
  Serial1.write(frame, 10);
  Serial1.flush();
}

void setup() {
  // Initialize USB serial for debugging
  Serial.begin(115200);

  // Initialize UART1 on GP0 (TX) for sending to FPGA
  Serial1.begin(115200);

  delay(2000);  // Wait for serial monitors to connect

  Serial.println("=== FPGA DNP3 Link Layer Test Starting ===");
  Serial.println("Device Address: 0x0001");
  Serial.println("");
}

void loop() {
  // Test 1: Send valid DNP3 frame to address 0x0001 (should match)
  Serial.println("Test 1: Valid DNP3 frame to 0x0001 (FPGA address)");
  Serial.println("  Control: 0x44 (PRI=0, DIR=1, FCB=0, FCV=0, FUNC=4-Reset)");
  Serial.println("  Expected: GREEN LED ON (valid frame, address match)");
  sendDNP3Frame(0x0001, 0x0100, 0x44);
  delay(3000);

  // Test 2: Send valid DNP3 frame to different address (should not match)
  Serial.println("Test 2: Valid DNP3 frame to 0x0002 (different address)");
  Serial.println("  Expected: No GREEN LED (address mismatch)");
  sendDNP3Frame(0x0002, 0x0100, 0x44);
  delay(3000);

  // Test 3: Send frame with bad CRC
  Serial.println("Test 3: Invalid frame (bad CRC)");
  Serial.println("  Expected: RED LED ON (CRC error)");
  sendInvalidFrame();
  delay(3000);

  // Test 4: Send valid frame with different control byte
  Serial.println("Test 4: Valid frame with FUNC=0 (Confirm)");
  Serial.println("  Control: 0x00 (PRI=0, DIR=0, FCB=0, FCV=0, FUNC=0)");
  Serial.println("  Expected: GREEN LED ON");
  sendDNP3Frame(0x0001, 0x0100, 0x00);
  delay(3000);

  // Test 5: Send valid frame with different source address
  Serial.println("Test 5: Valid frame from different source (0x0200)");
  Serial.println("  Expected: GREEN LED ON");
  sendDNP3Frame(0x0001, 0x0200, 0x44);
  delay(3000);

  // Test 6: Send malformed frame (wrong start bytes)
  Serial.println("Test 6: Malformed frame (wrong start bytes)");
  Serial.println("  Expected: RED LED ON or no response");
  uint8_t bad_frame[] = {0x05, 0x65, 0x05, 0x44, 0x01, 0x00, 0x10, 0x00, 0xAA, 0xBB};
  Serial1.write(bad_frame, 10);
  Serial1.flush();
  delay(3000);

  // Test 7: Send rapid sequence of valid frames
  Serial.println("Test 7: Rapid sequence of 3 valid frames");
  Serial.println("  Expected: GREEN LED ON");
  sendDNP3Frame(0x0001, 0x0100, 0x44);
  delay(200);
  sendDNP3Frame(0x0001, 0x0100, 0x44);
  delay(200);
  sendDNP3Frame(0x0001, 0x0100, 0x44);
  delay(3000);

  Serial.println("");
  Serial.println("=== Test sequence complete. Repeating in 5 seconds... ===");
  Serial.println("");
  delay(5000);
}
