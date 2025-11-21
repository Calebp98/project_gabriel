// UART Test Sender for FPGA UART Receiver Validation
// Raspberry Pi Pico sends test byte patterns to verify UART RX module
//
// Hardware Setup:
// - Pico GP0 (UART TX) → FPGA Pin 3 (RX)
// - Pico GND → FPGA GND
//
// Expected LED Behavior on FPGA:
// - Blue LED: Pulses briefly when each byte is received
// - Green LED: Shows bit 0 (LSB) of last received byte
// - Red LED: Shows bit 7 (MSB) of last received byte

void setup() {
  // Initialize USB serial for debugging (optional)
  Serial.begin(115200);

  // Initialize UART1 on GP0 (TX) and GP1 (RX)
  // We only use TX (GP0) to send to FPGA
  Serial1.begin(115200);

  delay(2000);  // Wait for serial monitors to connect

  Serial.println("=== FPGA UART RX Test Starting ===");
  Serial.println("Sending test byte patterns...");
  Serial.println("");
}

void loop() {
  // Test 1: Send 'A' (0x41 = 0b01000001)
  // Expected: Blue pulse, Green ON, Red OFF
  Serial.println("Sending: 'A' (0x41 = 0b01000001)");
  Serial.println("  Expected: Green LED ON, Red LED OFF");
  Serial1.write('A');
  delay(2000);

  // Test 2: Send 'C' (0x43 = 0b01000011)
  // Expected: Blue pulse, Green ON, Red OFF
  Serial.println("Sending: 'C' (0x43 = 0b01000011)");
  Serial.println("  Expected: Green LED ON, Red LED OFF");
  Serial1.write('C');
  delay(2000);

  // Test 3: Send 0x80 (0b10000000)
  // Expected: Blue pulse, Green OFF, Red ON
  Serial.println("Sending: 0x80 (0b10000000)");
  Serial.println("  Expected: Green LED OFF, Red LED ON");
  Serial1.write((uint8_t)0x80);
  delay(2000);

  // Test 4: Send 0xFF (0b11111111)
  // Expected: Blue pulse, Green ON, Red ON
  Serial.println("Sending: 0xFF (0b11111111)");
  Serial.println("  Expected: Green LED ON, Red LED ON");
  Serial1.write((uint8_t)0xFF);
  delay(2000);

  // Test 5: Send 0x00 (0b00000000)
  // Expected: Blue pulse, Green OFF, Red OFF
  Serial.println("Sending: 0x00 (0b00000000)");
  Serial.println("  Expected: Green LED OFF, Red LED OFF");
  Serial1.write((uint8_t)0x00);
  delay(2000);

  // Test 6: Send 0x01 (0b00000001)
  // Expected: Blue pulse, Green ON, Red OFF
  Serial.println("Sending: 0x01 (0b00000001)");
  Serial.println("  Expected: Green LED ON, Red LED OFF");
  Serial1.write((uint8_t)0x01);
  delay(2000);

  Serial.println("");
  Serial.println("=== Test sequence complete. Repeating... ===");
  Serial.println("");
  delay(1000);
}
