// Pico SWD Bridge - Simple Serial-to-GPIO Converter
// Acts as a dumb USB-to-SWD bridge for programming another Pico
//
// Hardware Setup:
// - This Pico (Bridge) connects to laptop via USB
// - GP2 (SWCLK) connects to target Pico's SWCLK (GPIO 24 or debug pin 1)
// - GP3 (SWDIO) connects to target Pico's SWDIO (GPIO 25 or debug pin 3)
// - GND connects to target Pico's GND
//
// Protocol: Simple ASCII commands over USB Serial
// Commands:
//   'C' - Set SWCLK HIGH
//   'c' - Set SWCLK LOW
//   'D' - Set SWDIO HIGH (when in output mode)
//   'd' - Set SWDIO LOW (when in output mode)
//   'I' - Set SWDIO to INPUT mode (for reading)
//   'O' - Set SWDIO to OUTPUT mode (for writing)
//   'R' - Read SWDIO state (returns '1' or '0')
//   'r' - Reset target (pulse SWDIO low while SWCLK high)
//   '?' - Get version/status
//
// Advanced commands (buffered operations for speed):
//   'W' followed by binary data - Write multiple bits
//   Format: 'W' <count_byte> <data_bytes>

#define SWCLK_PIN 2   // GP2 - SWD Clock output
#define SWDIO_PIN 3   // GP3 - SWD Data I/O (bidirectional)
#define LED_PIN LED_BUILTIN

// Timing configuration
#define SWD_DELAY_US 1  // Microsecond delay between clock edges

void setup() {
  // Initialize USB serial at high speed
  Serial.begin(115200);

  // Initialize SWD pins
  pinMode(SWCLK_PIN, OUTPUT);
  pinMode(SWDIO_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);

  // Start with clock and data low
  digitalWrite(SWCLK_PIN, LOW);
  digitalWrite(SWDIO_PIN, LOW);

  // Wait for USB serial to be ready
  while (!Serial && millis() < 3000) {
    digitalWrite(LED_PIN, (millis() / 100) % 2);  // Blink while waiting
  }

  digitalWrite(LED_PIN, HIGH);  // Solid LED when ready

  // Send ready message
  Serial.println("SWD Bridge Ready");
  Serial.flush();
}

void loop() {
  if (Serial.available()) {
    char cmd = Serial.read();

    switch(cmd) {
      // === Basic GPIO Control ===

      case 'C':  // SWCLK HIGH
        digitalWrite(SWCLK_PIN, HIGH);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'c':  // SWCLK LOW
        digitalWrite(SWCLK_PIN, LOW);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'D':  // SWDIO HIGH (output mode)
        digitalWrite(SWDIO_PIN, HIGH);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'd':  // SWDIO LOW (output mode)
        digitalWrite(SWDIO_PIN, LOW);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'I':  // SWDIO INPUT mode
        pinMode(SWDIO_PIN, INPUT);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'O':  // SWDIO OUTPUT mode
        pinMode(SWDIO_PIN, OUTPUT);
        delayMicroseconds(SWD_DELAY_US);
        break;

      case 'R':  // Read SWDIO
        Serial.write(digitalRead(SWDIO_PIN) ? '1' : '0');
        Serial.flush();
        break;

      // === Utility Commands ===

      case 'r':  // Reset sequence (line reset)
        // SWD line reset: 50+ clocks with SWDIO high
        pinMode(SWDIO_PIN, OUTPUT);
        digitalWrite(SWDIO_PIN, HIGH);
        for (int i = 0; i < 60; i++) {
          digitalWrite(SWCLK_PIN, HIGH);
          delayMicroseconds(SWD_DELAY_US);
          digitalWrite(SWCLK_PIN, LOW);
          delayMicroseconds(SWD_DELAY_US);
        }
        Serial.println("OK");
        break;

      case '?':  // Status/version
        Serial.println("SWD Bridge v1.0");
        Serial.print("SWCLK: GP");
        Serial.println(SWCLK_PIN);
        Serial.print("SWDIO: GP");
        Serial.println(SWDIO_PIN);
        break;

      // === Buffered Operations (for speed) ===

      case 'W':  // Write multiple bits
        // Format: 'W' <count> <bit_0> <bit_1> ... <bit_n-1>
        // Each bit is '0' or '1' character
        if (Serial.available() >= 1) {
          int count = Serial.read();
          pinMode(SWDIO_PIN, OUTPUT);

          for (int i = 0; i < count; i++) {
            // Wait for bit data
            while (!Serial.available()) {}
            char bit = Serial.read();

            // Set data line
            digitalWrite(SWDIO_PIN, (bit == '1') ? HIGH : LOW);
            delayMicroseconds(SWD_DELAY_US);

            // Clock pulse
            digitalWrite(SWCLK_PIN, HIGH);
            delayMicroseconds(SWD_DELAY_US);
            digitalWrite(SWCLK_PIN, LOW);
            delayMicroseconds(SWD_DELAY_US);
          }
          Serial.println("OK");
        }
        break;

      case 'X':  // Read multiple bits
        // Format: 'X' <count>
        // Returns: <bit_0> <bit_1> ... <bit_n-1> followed by newline
        if (Serial.available() >= 1) {
          int count = Serial.read();
          pinMode(SWDIO_PIN, INPUT);

          for (int i = 0; i < count; i++) {
            // Clock pulse
            digitalWrite(SWCLK_PIN, HIGH);
            delayMicroseconds(SWD_DELAY_US);

            // Sample data line
            Serial.write(digitalRead(SWDIO_PIN) ? '1' : '0');

            digitalWrite(SWCLK_PIN, LOW);
            delayMicroseconds(SWD_DELAY_US);
          }
          Serial.println();  // Newline after bits
        }
        break;

      // === Fast byte-oriented operations ===

      case 'B':  // Write byte LSB-first (common in SWD)
        // Format: 'B' <byte_value>
        if (Serial.available() >= 1) {
          uint8_t byte_val = Serial.read();
          pinMode(SWDIO_PIN, OUTPUT);

          for (int i = 0; i < 8; i++) {
            // Set data line (LSB first)
            digitalWrite(SWDIO_PIN, (byte_val & (1 << i)) ? HIGH : LOW);
            delayMicroseconds(SWD_DELAY_US);

            // Clock pulse
            digitalWrite(SWCLK_PIN, HIGH);
            delayMicroseconds(SWD_DELAY_US);
            digitalWrite(SWCLK_PIN, LOW);
            delayMicroseconds(SWD_DELAY_US);
          }
        }
        break;

      case 'b':  // Read byte LSB-first
        {
          uint8_t byte_val = 0;
          pinMode(SWDIO_PIN, INPUT);

          for (int i = 0; i < 8; i++) {
            // Clock pulse
            digitalWrite(SWCLK_PIN, HIGH);
            delayMicroseconds(SWD_DELAY_US);

            // Sample data line (LSB first)
            if (digitalRead(SWDIO_PIN)) {
              byte_val |= (1 << i);
            }

            digitalWrite(SWCLK_PIN, LOW);
            delayMicroseconds(SWD_DELAY_US);
          }

          Serial.write(byte_val);
          Serial.flush();
        }
        break;

      default:
        // Unknown command, ignore
        break;
    }
  }
}
