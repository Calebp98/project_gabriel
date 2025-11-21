// UART Test Sender for FPGA Grammar FSM
// Raspberry Pi Pico sends test strings to validate "CAT" pattern
//
// Hardware Setup:
// - Pico GP0 (UART TX) → FPGA Pin 3 (RX)
// - Pico GND → FPGA GND
//
// Expected LED Behavior on FPGA:
// - LED_RX (pin 26): Pulses briefly when each byte is received
// - LED_GREEN (pin 37): ON when "CAT" pattern is accepted
// - LED_RED (pin 11): ON when pattern is rejected

void setup() {
  // Initialize USB serial for debugging (optional)
  Serial.begin(115200);

  // Initialize UART1 on GP0 (TX) and GP1 (RX)
  // We only use TX (GP0) to send to FPGA
  Serial1.begin(115200);

  delay(2000);  // Wait for serial monitors to connect

  Serial.println("=== FPGA Grammar FSM Test Starting ===");
  Serial.println("Testing 'CAT' pattern validation...");
  Serial.println("");
}

void loop() {
  // Test 1: Send "CAT" - Valid pattern
  // Expected: LED_RX pulses 3x, then GREEN LED stays ON
  Serial.println("Test 1: Sending 'CAT'");
  Serial.println("  Expected: GREEN LED ON (accept)");
  Serial1.print("CAT");
  delay(3000);

  // Test 2: Send "DOG" - Invalid pattern (wrong first character)
  // Expected: LED_RX pulses 1x, then RED LED stays ON
  Serial.println("Test 2: Sending 'DOG'");
  Serial.println("  Expected: RED LED ON (reject on 'D')");
  Serial1.print("DOG");
  delay(3000);

  // Test 3: Send "CAR" - Invalid pattern (wrong third character)
  // Expected: LED_RX pulses 3x, then RED LED stays ON
  Serial.println("Test 3: Sending 'CAR'");
  Serial.println("  Expected: RED LED ON (reject on 'R')");
  Serial1.print("CAR");
  delay(3000);

  // Test 4: Send "CA" only - Incomplete pattern
  // Expected: LED_RX pulses 2x, FSM waits (no accept/reject yet)
  Serial.println("Test 4: Sending 'CA' (incomplete)");
  Serial.println("  Expected: No LED change (waiting for 'T')");
  Serial1.print("CA");
  delay(3000);

  // Test 5: Now complete it with "T" to accept
  // Expected: LED_RX pulses 1x, GREEN LED turns ON
  Serial.println("Test 5: Sending 'T' (completing 'CAT')");
  Serial.println("  Expected: GREEN LED ON (accept)");
  Serial1.print("T");
  delay(3000);

  // Test 6: Send "CAT" again to verify reset works
  // Expected: GREEN LED ON again
  Serial.println("Test 6: Sending 'CAT' again");
  Serial.println("  Expected: GREEN LED ON (accept)");
  Serial1.print("CAT");
  delay(3000);

  // Test 7: Send single wrong character after accept
  // Expected: RED LED ON
  Serial.println("Test 7: Sending 'X' after accept");
  Serial.println("  Expected: RED LED ON (reject)");
  Serial1.print("X");
  delay(3000);

  Serial.println("");
  Serial.println("=== Test sequence complete. Repeating in 5 seconds... ===");
  Serial.println("");
  delay(5000);
}
