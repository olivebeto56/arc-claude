/**
 * left_ankle_node.ino
 *
 * Main firmware for the LEFT ANKLE node of the wearable sport monitor system.
 * Hardware: Seeed XIAO nRF52840 Sense + Adafruit BNO085 (#4754) via I2C
 * Sport mode: Running @ 100 Hz
 *
 * Required libraries (install via Arduino Library Manager):
 *   - Adafruit BNO08x (by Adafruit)
 *   - Adafruit Unified Sensor (dependency of BNO08x)
 *   - ArduinoBLE (by Arduino)
 *
 * Board: "Seeed XIAO BLE Sense - nRF52840"
 * Board Manager URL: https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
 */

#include <Wire.h>
#include "sensor.h"
#include "ble_service.h"

// ─── CONFIGURATION — adjust these parameters as needed ───────────────────────

// Node identity
#define NODE_ID       LEFT_ANKLE
#define NODE_NAME     "SportBand-L"      // BLE advertised name

// Sample rate for running mode
#define SAMPLE_RATE_HZ          100      // 100 Hz = 10 ms per sample
#define SAMPLE_INTERVAL_MS      (1000 / SAMPLE_RATE_HZ)

// Battery read interval (don't read too often — takes ~2 ms)
#define BATTERY_READ_INTERVAL_MS  10000  // every 10 seconds

// Serial debug (set to 0 to disable for production / power saving)
#define SERIAL_DEBUG  1

// ─────────────────────────────────────────────────────────────────────────────

// Timing variables
static uint32_t lastSampleTime    = 0;
static uint32_t lastBatteryTime   = 0;
static uint32_t sessionStartTime  = 0;

// Sensor data
static SensorAngles angles;

// Battery
static uint8_t  batteryPct = 0;

// ─── SETUP ────────────────────────────────────────────────────────────────────

void setup() {
#if SERIAL_DEBUG
  Serial.begin(115200);
  // Wait up to 3 s for USB serial (needed when powered via USB)
  while (!Serial && millis() < 3000);
  Serial.println("=== Left Ankle Node — Sport Monitor ===");
#endif

  // Initialize I2C bus (Fast mode required for BNO085 @ 100 Hz)
  Wire.begin();
  Wire.setClock(400000);
  delay(100);  // Let I2C bus and BNO085 stabilize after power-on

  // Initialize BNO085 sensor (9-axis, ARVR stabilized, 100 Hz)
  if (!initSensor()) {
#if SERIAL_DEBUG
    Serial.println("FATAL: Sensor init failed. Check wiring (SDA=D4, SCL=D5).");
#endif
    // Blink LED rapidly to signal hardware error
    pinMode(LED_BUILTIN, OUTPUT);
    while (true) {
      digitalWrite(LED_BUILTIN, HIGH);
      delay(100);
      digitalWrite(LED_BUILTIN, LOW);
      delay(100);
    }
  }

#if SERIAL_DEBUG
  Serial.println("BNO085 initialized OK @ 100 Hz");
#endif

  // Read initial battery level before BLE starts
  float vbat = readBatteryVoltage();
  batteryPct  = batteryPercent(vbat);

#if SERIAL_DEBUG
  Serial.print("Battery: ");
  Serial.print(vbat, 2);
  Serial.print(" V → ");
  Serial.print(batteryPct);
  Serial.println("%");
#endif

  // Initialize BLE GATT service and start advertising
  initBLEService(NODE_NAME, batteryPct);

#if SERIAL_DEBUG
  Serial.print("BLE advertising as: ");
  Serial.println(NODE_NAME);
  Serial.println("Waiting for central connection...");
#endif

  sessionStartTime = millis();
  lastSampleTime   = millis();
  lastBatteryTime  = millis();
}

// ─── MAIN LOOP ────────────────────────────────────────────────────────────────

void loop() {
  // Poll BLE for central connections and events
  BLEDevice central = BLE.central();

  if (central) {
#if SERIAL_DEBUG
    Serial.print("Connected to central: ");
    Serial.println(central.address());
#endif

    // LED on while connected
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, LOW);  // XIAO LED is active-low

    // Data streaming loop — runs while central is connected
    while (central.connected()) {
      uint32_t now = millis();

      // ── Handle reset detection from BNO085 ──────────────────────────────
      if (sensorWasReset()) {
#if SERIAL_DEBUG
        Serial.println("BNO085 reset detected — re-enabling reports");
#endif
        enableSensorReports();  // Re-arm reports without re-running begin_I2C
      }

      // ── Sample sensor at configured rate ────────────────────────────────
      if (now - lastSampleTime >= SAMPLE_INTERVAL_MS) {
        lastSampleTime = now;

        if (getSensorAngles(angles)) {
          // Compute 16-bit relative timestamp (wraps every ~65 s — fine for BLE)
          uint16_t relTs = (uint16_t)(now - sessionStartTime);

          // Send quaternion + timestamp over BLE (notify)
          sendSensorData(relTs, angles);

#if SERIAL_DEBUG
          // Print every 50th sample to avoid flooding serial
          static uint32_t dbgCount = 0;
          if (++dbgCount % 50 == 0) {
            Serial.print("qw="); Serial.print(angles.qw, 4);
            Serial.print(" qx="); Serial.print(angles.qx, 4);
            Serial.print(" qy="); Serial.print(angles.qy, 4);
            Serial.print(" qz="); Serial.print(angles.qz, 4);
            Serial.print(" roll="); Serial.print(angles.roll, 1);
            Serial.print(" pitch="); Serial.print(angles.pitch, 1);
            Serial.print(" yaw="); Serial.println(angles.yaw, 1);
          }
#endif
        }
      }

      // ── Update battery level periodically ───────────────────────────────
      if (now - lastBatteryTime >= BATTERY_READ_INTERVAL_MS) {
        lastBatteryTime = now;
        float vbat = readBatteryVoltage();
        batteryPct  = batteryPercent(vbat);
        updateBatteryCharacteristic(batteryPct);

#if SERIAL_DEBUG
        Serial.print("Battery update: ");
        Serial.print(batteryPct);
        Serial.println("%");
#endif
      }

      // ── Handle config writes from the central (sample rate change) ───────
      handleConfigWrite();
    }

    // Central disconnected
    digitalWrite(LED_BUILTIN, HIGH);  // LED off (active-low)
#if SERIAL_DEBUG
    Serial.println("Central disconnected — resuming advertising");
#endif
  }
}
