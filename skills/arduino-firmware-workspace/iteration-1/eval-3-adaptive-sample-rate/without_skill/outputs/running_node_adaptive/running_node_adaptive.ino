/**
 * running_node_adaptive.ino
 *
 * Adaptive-rate running firmware for:
 *   MCU : Seeed XIAO nRF52840 Sense
 *   IMU : Adafruit BNO085 breakout #4754 (I2C @ 0x4A)
 *
 * Behaviour
 * ─────────
 *  • Starts at 100 Hz (ACTIVE mode).
 *  • ActivityDetector monitors |linear acceleration|.
 *  • If |a| stays below ACCEL_IDLE_THRESHOLD for IDLE_CONFIRM_MS (2 s),
 *    firmware drops the sensor report rate to 25 Hz and notifies the
 *    connected Flutter app via STATUS_CHAR.
 *  • If |a| rises above ACCEL_ACTIVE_THRESHOLD for ACTIVE_CONFIRM_MS (200 ms),
 *    firmware raises the rate back to 100 Hz immediately.
 *  • The Flutter app may override the auto-detection by writing to CONFIG_CHAR:
 *      0x00 = auto (default)
 *      0x01 = force ACTIVE (100 Hz)
 *      0x02 = force IDLE (25 Hz)
 *
 * Battery saving estimate (LiPo 400 mAh)
 * ─────────────────────────────────────
 *  100 Hz → BNO085 active + I2C bus busy   ≈ 9–11 mA total system draw
 *   25 Hz → BNO085 low-duty + I2C quiet    ≈ 6–7 mA total system draw
 *  At 70 % idle time (standing between sets / walking to start):
 *    effective current ≈ 0.3×10.5 + 0.7×6.5 ≈ 7.7 mA → ~52 h estimated
 *    vs constant 100 Hz → ~40 h estimated
 *
 * ─── Adjustable parameters ────────────────────────────────────────────────────
 */

// Node identity — change to "SportBand-R" for the right-ankle node
#define NODE_NAME          "SportBand-L"

// Battery reporting interval (ms)
#define BATTERY_REPORT_INTERVAL_MS   30000UL   // every 30 seconds

// Serial debug verbosity
//   0 = silent (production), 1 = state changes only, 2 = every packet
#define DEBUG_LEVEL  1

// ─── Includes ─────────────────────────────────────────────────────────────────
#include <Wire.h>
#include <ArduinoBLE.h>
#include <Adafruit_BNO08x.h>

#include "sensor.h"
#include "activity_detector.h"
#include "ble_service.h"

// ─── Module state ─────────────────────────────────────────────────────────────
static SensorAngles     angles;
static ActivityDetector detector;
static uint32_t         sessionStart       = 0;
static uint32_t         lastBatteryReport  = 0;

// ─── Battery helpers (XIAO nRF52840 Sense) ───────────────────────────────────

float readBatteryVoltage() {
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  delay(1);
  analogReference(AR_INTERNAL_3_0);
  analogReadResolution(12);
  int raw = analogRead(PIN_VBAT);
  digitalWrite(P0_14, HIGH);
  pinMode(P0_14, INPUT);
  return (raw * 3.0f / 4096.0f) * 2.0f;
}

uint8_t batteryPercent(float v) {
  int pct = (int)((v - 3.2f) / (4.2f - 3.2f) * 100.0f);
  return (uint8_t)constrain(pct, 0, 100);
}

// ─── setup() ─────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000);  // wait for USB serial (max 3 s)

  Serial.println("=== Running Node Adaptive — booting ===");
  Serial.print("Node: ");
  Serial.println(NODE_NAME);

  // ── Initialise BNO085 ────────────────────────────────────────────────────
  if (!initSensor()) {
    Serial.println("[FATAL] BNO085 init failed. Halting.");
    while (1) { delay(1000); }
  }

  // ── Initialise BLE ───────────────────────────────────────────────────────
  if (!initBLE(NODE_NAME)) {
    Serial.println("[FATAL] BLE init failed. Halting.");
    while (1) { delay(1000); }
  }

  // ── Initialise activity detector ─────────────────────────────────────────
  detector.begin();

  sessionStart      = millis();
  lastBatteryReport = millis();

  Serial.println("[main] Setup complete. Waiting for BLE connection...");
}

// ─── loop() ──────────────────────────────────────────────────────────────────

void loop() {
  // ── 1. Handle BLE stack and read any config override from the app ─────────
  uint8_t configByte = bleLoop();

  // ── 2. Read latest sensor data ────────────────────────────────────────────
  bool newSample = getSensorAngles(angles);

  // ── 3. Evaluate activity (only when a new sample arrived) ────────────────
  if (newSample) {
    float mag = getAccelMagnitude();

    ActivityState change = ACTIVITY_NO_CHANGE;

    // Config override from the Flutter app takes priority over auto-detection
    if (configByte == CONFIG_MODE_FORCE_ACTIVE) {
      // Force 100 Hz regardless of motion
      if (detector.getMode() != MODE_ACTIVE) {
        setSampleRate(INTERVAL_ACTIVE_US);
        bleSendStatus(MODE_ACTIVE);
      }
    } else if (configByte == CONFIG_MODE_FORCE_IDLE) {
      // Force 25 Hz regardless of motion
      if (detector.getMode() != MODE_IDLE) {
        setSampleRate(INTERVAL_IDLE_US);
        bleSendStatus(MODE_IDLE);
      }
    } else {
      // CONFIG_MODE_AUTO — let the detector decide
      change = detector.update(mag);

      if (change == ACTIVITY_CHANGED) {
        uint32_t newInterval = detector.getCurrentIntervalUs();
        setSampleRate(newInterval);
        bleSendStatus(detector.getMode());
      }
    }

#if DEBUG_LEVEL >= 2
    Serial.print("[loop] |a|=");
    Serial.print(mag, 3);
    Serial.print(" m/s²  mode=");
    Serial.println(detector.getMode() == MODE_ACTIVE ? "ACTIVE" : "IDLE");
#endif

    // ── 4. Send sensor data via BLE notify ───────────────────────────────
    if (bleConnected()) {
      bleSendSensorData(angles, sessionStart);
    }
  }

  // ── 5. Periodic battery report ────────────────────────────────────────────
  if (millis() - lastBatteryReport >= BATTERY_REPORT_INTERVAL_MS) {
    lastBatteryReport = millis();
    float  v   = readBatteryVoltage();
    uint8_t pct = batteryPercent(v);
    bleSendBattery(pct);

#if DEBUG_LEVEL >= 1
    Serial.print("[battery] ");
    Serial.print(v, 2);
    Serial.print(" V → ");
    Serial.print(pct);
    Serial.println(" %");
#endif
  }
}
