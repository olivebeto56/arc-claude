// running_node.ino — Main firmware for Running Node
// Wearable Sport Monitor — XIAO nRF52840 Sense + BNO085 (I2C)
//
// ADAPTIVE SAMPLE RATE FEATURE:
//   • When the athlete is still  → 25 Hz  (40 ms interval) — saves battery
//   • When the athlete is moving → 100 Hz (10 ms interval) — full precision
//   • Detection is based on linear acceleration magnitude with hysteresis
//     debounce to prevent rapid toggling.
//
// ──────────────────────────────────────────────────────────────────
// Required libraries (install via Arduino Library Manager):
//   - Adafruit BNO08x              (by Adafruit)
//   - Adafruit Unified Sensor      (dependency of BNO08x)
//   - ArduinoBLE                   (by Arduino)
//
// Board (install via Board Manager → add URL below):
//   Name: Seeed nRF52 Boards
//   URL:  https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
//   Select: Seeed XIAO BLE Sense - nRF52840
// ──────────────────────────────────────────────────────────────────

#include <Wire.h>
#include "sensor.h"
#include "motion_detector.h"
#include "ble_service.h"

// ==================================================================
// CONFIGURATION — edit these values before flashing
// ==================================================================

// Node identity: LEFT_ANKLE or RIGHT_ANKLE
// Change to RIGHT_ANKLE when flashing the second node
#define LEFT_ANKLE  0
#define RIGHT_ANKLE 1
#define NODE_ID     LEFT_ANKLE

#if NODE_ID == LEFT_ANKLE
  #define BLE_DEVICE_NAME  "SportBand-L"
#else
  #define BLE_DEVICE_NAME  "SportBand-R"
#endif

// Sample rates
#define SAMPLE_RATE_RUNNING_HZ   100    // Active mode  — 10 ms interval
#define SAMPLE_RATE_IDLE_HZ       25    // Idle mode    — 40 ms interval

// Derived intervals in microseconds (used by BNO085 enableReport)
#define INTERVAL_RUNNING_US  (1000000UL / SAMPLE_RATE_RUNNING_HZ)  // 10,000 µs
#define INTERVAL_IDLE_US     (1000000UL / SAMPLE_RATE_IDLE_HZ)     // 40,000 µs

// Battery read interval (ms) — reading too often wastes power
#define BATTERY_READ_INTERVAL_MS  10000UL   // every 10 seconds

// Serial debug output — set to false to disable before final deployment
#define SERIAL_DEBUG  true

// ==================================================================
// GLOBAL STATE
// ==================================================================

MotionDetector motionDetector;

// Current sample interval (starts at idle to conserve battery on boot)
static uint32_t currentIntervalUs = INTERVAL_IDLE_US;
static MotionState currentMotionState = MOTION_IDLE;

// Timing
static uint32_t sessionStartMs   = 0;
static uint32_t lastBatteryMs    = 0;
static uint32_t lastSampleMs     = 0;

// ==================================================================
// BATTERY HELPERS
// ==================================================================

float readBatteryVoltage() {
  // Enable the voltage divider (active LOW on P0_14)
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  delay(1);

  analogReference(AR_INTERNAL_3_0);
  analogReadResolution(12);
  int raw = analogRead(PIN_VBAT);

  // Disable divider to save power
  digitalWrite(P0_14, HIGH);
  pinMode(P0_14, INPUT);

  // Reference 3.0V, 12-bit ADC, 2x divider
  return (raw * 3.0f / 4096.0f) * 2.0f;
}

uint8_t readBatteryPercent() {
  float v = readBatteryVoltage();
  int pct = (int)((v - 3.2f) / (4.2f - 3.2f) * 100.0f);
  return (uint8_t)constrain(pct, 0, 100);
}

// ==================================================================
// ADAPTIVE RATE HELPERS
// ==================================================================

// Apply a new sample interval to the BNO085 and update local state.
void applyInterval(uint32_t intervalUs, MotionState state) {
  if (intervalUs == currentIntervalUs) return;  // no-op

  if (setSampleInterval(intervalUs)) {
    currentIntervalUs  = intervalUs;
    currentMotionState = state;

    #if SERIAL_DEBUG
    Serial.print("[AdaptiveRate] Switched to ");
    Serial.print(1000000UL / intervalUs);
    Serial.print(" Hz — motion state: ");
    Serial.println((state == MOTION_ACTIVE) ? "ACTIVE" : "IDLE");
    #endif
  } else {
    Serial.println("WARN: setSampleInterval() failed — staying at current rate");
  }
}

// ==================================================================
// SETUP
// ==================================================================

void setup() {
  #if SERIAL_DEBUG
  Serial.begin(115200);
  // Wait up to 3 s for USB serial (omit this wait in battery-only deployments)
  while (!Serial && millis() < 3000);
  Serial.println("=== Running Node Firmware — Adaptive Sample Rate ===");
  Serial.print("Node: ");
  Serial.println(BLE_DEVICE_NAME);
  #endif

  // ── Sensor ──────────────────────────────────────────────────────
  if (!initSensor()) {
    Serial.println("FATAL: Sensor init failed — halting");
    while (1) { delay(1000); }
  }

  // Start in idle mode to save power during warm-up / BLE pairing
  applyInterval(INTERVAL_IDLE_US, MOTION_IDLE);

  #if SERIAL_DEBUG
  Serial.println("BNO085 initialized at 25 Hz (idle)");
  #endif

  // ── BLE ─────────────────────────────────────────────────────────
  if (!initBLE(BLE_DEVICE_NAME)) {
    Serial.println("FATAL: BLE init failed — halting");
    while (1) { delay(1000); }
  }

  sessionStartMs = millis();
  lastBatteryMs  = millis();

  #if SERIAL_DEBUG
  Serial.println("Setup complete — waiting for motion...");
  #endif
}

// ==================================================================
// LOOP
// ==================================================================

void loop() {
  uint32_t now = millis();

  // ── 1. Service BLE events & handle config writes ────────────────
  pollBLE();

  // Handle sample rate override from Flutter app (via configChar)
  uint8_t configHz = consumeConfigRequest();
  if (configHz == 25) {
    applyInterval(INTERVAL_IDLE_US, MOTION_IDLE);
  } else if (configHz == 100) {
    applyInterval(INTERVAL_RUNNING_US, MOTION_ACTIVE);
  }

  // ── 2. Handle BNO085 reset ──────────────────────────────────────
  // (The BNO085 can self-reset after a strong impact)
  extern Adafruit_BNO08x bno085;  // defined in sensor.cpp
  // We use a lightweight proxy: getSensorAngles handles wasReset internally
  // via reinitSensorReports. This is handled below after reading.

  // ── 3. Read sensor (non-blocking) ───────────────────────────────
  SensorAngles angles;
  bool newSample = getSensorAngles(angles);

  // ── 4. Motion detection — update every time we have accel data ──
  float accelMag = 0.0f;
  bool hasAccel  = getLinearAccelMagnitude(accelMag);

  if (hasAccel) {
    bool stateChanged = motionDetector.update(accelMag);

    if (stateChanged) {
      MotionState newState = motionDetector.getState();
      if (newState == MOTION_ACTIVE) {
        applyInterval(INTERVAL_RUNNING_US, MOTION_ACTIVE);
      } else {
        applyInterval(INTERVAL_IDLE_US, MOTION_IDLE);
      }
    }
  }

  // ── 5. Send data over BLE if connected and new sample available ──
  if (newSample && isBLEConnected()) {
    sendSensorData(angles, sessionStartMs);

    #if SERIAL_DEBUG
    // Lightweight debug print — throttle to once per second to avoid
    // flooding the serial port at 100 Hz
    static uint32_t lastDebugMs = 0;
    if (now - lastDebugMs >= 1000) {
      lastDebugMs = now;
      Serial.print("[");
      Serial.print(motionDetector.getStateLabel());
      Serial.print("] ");
      Serial.print(1000000UL / currentIntervalUs);
      Serial.print("Hz | roll=");
      Serial.print(angles.roll, 1);
      Serial.print(" pitch=");
      Serial.print(angles.pitch, 1);
      Serial.print(" yaw=");
      Serial.println(angles.yaw, 1);
    }
    #endif
  }

  // ── 6. Battery update every 10 seconds ──────────────────────────
  if (now - lastBatteryMs >= BATTERY_READ_INTERVAL_MS) {
    lastBatteryMs = now;
    uint8_t pct = readBatteryPercent();
    updateBattery(pct);

    #if SERIAL_DEBUG
    Serial.print("[Battery] ");
    Serial.print(pct);
    Serial.println("%");
    #endif
  }

  // ── 7. Yield — nRF52840 BLE stack needs cooperative scheduling ──
  // Do not add long delay() calls in the loop; BLE events must be
  // serviced frequently. The BNO085 rate controls the effective
  // data output frequency — the loop itself runs as fast as possible.
}
