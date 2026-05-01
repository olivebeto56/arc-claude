/**
 * bno085_i2c_diagnostic.ino
 * ─────────────────────────
 * Diagnostic sketch for XIAO nRF52840 Sense + BNO085 via I2C.
 * Run this BEFORE your main firmware to isolate the root cause of
 * "BNO085 not found at 0x4A".
 *
 * Hardware: Seeed XIAO nRF52840 Sense
 *           Adafruit BNO085 breakout #4754
 *           I2C wiring: SDA → D4 (P0.06), SCL → D5 (P0.07)
 *
 * Required libraries:
 *   - Adafruit BNO08x  (Library Manager)
 *   - Adafruit Unified Sensor  (dependency, Library Manager)
 *
 * Board: Seeed XIAO BLE Sense - nRF52840
 * URL:   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
 */

#include <Wire.h>
#include <Adafruit_BNO08x.h>

// ─── CONFIGURATION ───────────────────────────────────────────────────────────
// I2C addresses to scan (BNO085 is 0x4A by default, 0x4B when SA0 tied HIGH)
#define BNO085_ADDR_DEFAULT  0x4A
#define BNO085_ADDR_ALT      0x4B

// I2C clock speeds to test
#define I2C_STANDARD_HZ   100000UL   // 100 kHz — standard mode
#define I2C_FAST_HZ       400000UL   // 400 kHz — fast mode (needed for 100 Hz+)

// How long to wait after Wire.begin() before scanning (ms)
#define WIRE_SETTLE_MS      200

// Startup delay to let the BNO085 boot its internal SH-2 processor (ms)
#define BNO085_BOOT_MS      500
// ─────────────────────────────────────────────────────────────────────────────

Adafruit_BNO08x bno085(-1);  // -1 = no hardware reset pin used

// ─── HELPERS ─────────────────────────────────────────────────────────────────

/**
 * Scan the entire I2C bus (0x08–0x77) and print every address that ACKs.
 * Returns the count of devices found.
 */
int i2cScan() {
  int found = 0;
  Serial.println("\n[SCAN] I2C bus scan (0x08–0x77)...");

  for (uint8_t addr = 0x08; addr <= 0x77; addr++) {
    Wire.beginTransmission(addr);
    uint8_t err = Wire.endTransmission();

    if (err == 0) {
      Serial.print("  [FOUND] Device at 0x");
      if (addr < 0x10) Serial.print("0");
      Serial.print(addr, HEX);

      // Annotate known addresses
      if (addr == BNO085_ADDR_DEFAULT) Serial.print("  ← BNO085 default");
      if (addr == BNO085_ADDR_ALT)     Serial.print("  ← BNO085 alt (SA0=VCC)");
      if (addr == 0x6A)                Serial.print("  ← LSM6DS3 (XIAO built-in IMU)");
      Serial.println();
      found++;
    } else if (err == 4) {
      // err==4 means the device held the line low (bus error / stuck SDA)
      Serial.print("  [ERROR] Bus error at 0x");
      if (addr < 0x10) Serial.print("0");
      Serial.println(addr, HEX);
    }
  }

  if (found == 0) {
    Serial.println("  [NONE] No I2C devices found.");
    Serial.println("  >>> CHECK: Are SDA/SCL wires connected? Are they swapped?");
    Serial.println("  >>> CHECK: Is VCC (3.3V) and GND connected to the BNO085?");
  }
  return found;
}

/**
 * Test Wire.begin() and scan at a given clock speed.
 */
void testAtClockSpeed(uint32_t hz) {
  Serial.print("\n[TEST] Restarting Wire at ");
  Serial.print(hz / 1000);
  Serial.println(" kHz...");

  Wire.end();
  delay(50);
  Wire.begin();
  Wire.setClock(hz);
  delay(WIRE_SETTLE_MS);

  i2cScan();
}

/**
 * Attempt to initialize the BNO085 library at a given address.
 * Returns true if begin_I2C() succeeds.
 */
bool testBNO085Init(uint8_t addr) {
  Serial.print("\n[BNO085] Trying begin_I2C() at 0x");
  Serial.println(addr, HEX);

  // Give the BNO085 SH-2 processor time to boot
  Serial.print("  Waiting ");
  Serial.print(BNO085_BOOT_MS);
  Serial.println(" ms for sensor boot...");
  delay(BNO085_BOOT_MS);

  if (bno085.begin_I2C(addr)) {
    Serial.println("  [OK] BNO085 initialized successfully!");
    return true;
  } else {
    Serial.println("  [FAIL] begin_I2C() returned false.");
    return false;
  }
}

/**
 * If the BNO085 initialized, try enabling a report and read a few samples.
 */
void testSensorReadback() {
  Serial.println("\n[READBACK] Enabling ARVR_STABILIZED_RV report at 100 Hz...");

  // 10000 µs = 100 Hz
  if (!bno085.enableReport(SH2_ARVR_STABILIZED_RV, 10000)) {
    Serial.println("  [FAIL] enableReport() returned false.");
    Serial.println("  >>> CHECK: Is the sensor in a crashed state? Try hardware reset.");
    return;
  }
  Serial.println("  [OK] Report enabled.");

  Serial.println("  Reading 10 samples (timeout 5 s each)...");
  sh2_SensorValue_t sv;
  int count = 0;
  uint32_t t0 = millis();

  while (count < 10 && (millis() - t0) < 5000UL) {
    if (bno085.getSensorEvent(&sv)) {
      if (sv.sensorId == SH2_ARVR_STABILIZED_RV) {
        float qw = sv.un.arvrStabilizedRV.real;
        float qx = sv.un.arvrStabilizedRV.i;
        float qy = sv.un.arvrStabilizedRV.j;
        float qz = sv.un.arvrStabilizedRV.k;
        uint8_t acc = sv.un.arvrStabilizedRV.accuracy;

        Serial.print("  Sample ");
        Serial.print(++count);
        Serial.print(": qw=");
        Serial.print(qw, 4);
        Serial.print(" qx=");
        Serial.print(qx, 4);
        Serial.print(" qy=");
        Serial.print(qy, 4);
        Serial.print(" qz=");
        Serial.print(qz, 4);
        Serial.print(" accuracy=");
        Serial.println(acc);   // 0=uncalibrated, 3=fully calibrated
      }
    }
  }

  if (count == 0) {
    Serial.println("  [WARN] No samples received within 5 s.");
    Serial.println("  >>> CHECK: enableReport() may have silently failed.");
    Serial.println("  >>> CHECK: Is there a long delay() blocking the loop?");
  } else {
    Serial.println("  [OK] Readback successful.");
  }
}

// ─── SETUP ───────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);

  // Wait up to 3 s for USB serial (important on XIAO nRF52840 over USB)
  while (!Serial && millis() < 3000);

  Serial.println("\n========================================");
  Serial.println("  BNO085 I2C Diagnostic — XIAO nRF52840");
  Serial.println("========================================");

  // ── STEP 1: Standard I2C scan at 100 kHz ──────────────────────────────────
  Serial.println("\n─── STEP 1: Wire.begin() + scan at 100 kHz ───");
  Wire.begin();
  Wire.setClock(I2C_STANDARD_HZ);
  delay(WIRE_SETTLE_MS);
  int found100 = i2cScan();

  // ── STEP 2: Repeat scan at 400 kHz ────────────────────────────────────────
  Serial.println("\n─── STEP 2: Scan at 400 kHz (fast mode) ───");
  testAtClockSpeed(I2C_FAST_HZ);

  // ── STEP 3: Attempt BNO085 init at default address ────────────────────────
  Serial.println("\n─── STEP 3: BNO085 begin_I2C() at 0x4A (default) ───");
  Wire.end();
  Wire.begin();
  Wire.setClock(I2C_FAST_HZ);
  delay(WIRE_SETTLE_MS);

  bool ok4A = testBNO085Init(BNO085_ADDR_DEFAULT);

  // ── STEP 4: If 0x4A failed, try alternate address 0x4B ───────────────────
  if (!ok4A) {
    Serial.println("\n─── STEP 4: BNO085 begin_I2C() at 0x4B (SA0=VCC) ───");
    bool ok4B = testBNO085Init(BNO085_ADDR_ALT);

    if (ok4B) {
      Serial.println("\n  >>> DIAGNOSIS: BNO085 found at 0x4B!");
      Serial.println("  >>> FIX: SA0/ADDR pin on breakout is pulled HIGH.");
      Serial.println("  >>> Either tie SA0 to GND, or change your code to use 0x4B.");
    } else {
      Serial.println("\n─── DIAGNOSIS SUMMARY ───────────────────────────────");
      Serial.println("  BNO085 NOT found at 0x4A or 0x4B.");
      Serial.println();
      Serial.println("  Most likely causes (in order):");
      Serial.println("  1. SDA/SCL wires are SWAPPED or disconnected.");
      Serial.println("     Fix: SDA → D4 (P0.06), SCL → D5 (P0.07).");
      Serial.println("  2. VCC or GND not connected to BNO085 breakout.");
      Serial.println("     Fix: VCC → 3.3V pin on XIAO, GND → GND pin.");
      Serial.println("  3. Faulty cable or breadboard contact (check continuity).");
      Serial.println("  4. BNO085 breakout damaged (try replacing sensor).");
      Serial.println("  5. I2C bus stuck LOW (another device holding SDA down).");
      Serial.println("     Fix: power-cycle everything, or add 4.7kΩ pull-ups on");
      Serial.println("     SDA and SCL to 3.3V if the breakout lacks them.");
    }
  } else {
    // ── STEP 5: Sensor found — test data readback ──────────────────────────
    Serial.println("\n─── STEP 5: Sensor readback test ───");
    testSensorReadback();

    Serial.println("\n─── DIAGNOSIS SUMMARY ───────────────────────────────");
    Serial.println("  BNO085 is present and responding correctly.");
    Serial.println("  If your main sketch still fails, check:");
    Serial.println("  1. Wire.begin() is called BEFORE bno085.begin_I2C().");
    Serial.println("  2. Wire.setClock(400000) is set before begin_I2C().");
    Serial.println("  3. No other code path calls Wire.end() or reinits Wire.");
    Serial.println("  4. The BNO085 object is declared globally, not inside setup().");
  }

  Serial.println("\n========================================");
  Serial.println("  Diagnostic complete. Check output above.");
  Serial.println("========================================\n");
}

// ─── LOOP ────────────────────────────────────────────────────────────────────

void loop() {
  // Nothing to do — all diagnostics run once in setup().
  // Re-open Serial Monitor and press RESET to run again.
  delay(10000);
}
