/*
 * left_ankle_node.ino
 * Firmware base para el nodo del tobillo izquierdo — Running
 * Hardware : Seeed XIAO nRF52840 Sense + Adafruit BNO085 (BNO08x)
 * Libraries: ArduinoBLE, Adafruit BNO08x
 *
 * Funcionalidad:
 *  - Inicializa el BNO085 a 100 Hz en modo cuaternion de rotacion
 *  - Expone un servicio BLE con caracteristica de cuaternion (notificaciones)
 *  - Lee el nivel de bateria cada 30 s y lo notifica por BLE
 *  - LED de estado: parpadeo lento = BLE sin conectar / solido = conectado
 */

#include <ArduinoBLE.h>
#include "sensor.h"
#include "ble_service.h"

// ---------- Pines ----------
#define PIN_BATTERY_ADC   A0   // Divisor resistivo hacia la LiPo
#define PIN_LED_STATUS    LED_BUILTIN

// ---------- Intervalos ----------
#define IMU_INTERVAL_MS       10    // 100 Hz
#define BATTERY_INTERVAL_MS   30000 // 30 s
#define LED_BLINK_INTERVAL_MS 500

// ---------- Variables de tiempo ----------
static unsigned long lastImuTime     = 0;
static unsigned long lastBatteryTime = 0;
static unsigned long lastLedTime     = 0;
static bool          ledState        = false;

// ---------- Prototipos ----------
uint8_t  readBatteryPercent();
void     updateStatusLed(bool connected);

// ============================================================
void setup() {
  Serial.begin(115200);
  // No bloqueamos en Serial para produccion; descomentar para debug:
  // while (!Serial) delay(10);

  pinMode(PIN_LED_STATUS, OUTPUT);
  digitalWrite(PIN_LED_STATUS, LOW);

  // --- Sensor ---
  if (!sensorInit()) {
    Serial.println("[BOOT] ERROR: BNO085 no encontrado. Halt.");
    while (true) {
      digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
      delay(100);
    }
  }
  Serial.println("[BOOT] BNO085 OK @ 100 Hz");

  // --- BLE ---
  if (!bleInit()) {
    Serial.println("[BOOT] ERROR: BLE no inicializado. Halt.");
    while (true) {
      digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
      delay(200);
    }
  }
  Serial.println("[BOOT] BLE OK. Advertising...");

  lastImuTime     = millis();
  lastBatteryTime = millis();
  lastLedTime     = millis();
}

// ============================================================
void loop() {
  unsigned long now = millis();

  // --- Polling BLE ---
  BLE.poll();
  bool connected = bleIsConnected();

  // --- LED de estado ---
  if (now - lastLedTime >= LED_BLINK_INTERVAL_MS) {
    lastLedTime = now;
    if (connected) {
      digitalWrite(PIN_LED_STATUS, HIGH);
    } else {
      ledState = !ledState;
      digitalWrite(PIN_LED_STATUS, ledState);
    }
  }

  // --- Lectura IMU y envio BLE @ 100 Hz ---
  if (now - lastImuTime >= IMU_INTERVAL_MS) {
    lastImuTime = now;

    QuaternionData quat;
    if (sensorRead(quat)) {
      bleSendQuaternion(quat);
    }
  }

  // --- Bateria cada 30 s ---
  if (now - lastBatteryTime >= BATTERY_INTERVAL_MS) {
    lastBatteryTime = now;
    uint8_t pct = readBatteryPercent();
    bleSendBattery(pct);
    Serial.print("[BAT] ");
    Serial.print(pct);
    Serial.println("%");
  }
}

// ============================================================
// readBatteryPercent()
//   Lee el ADC conectado a un divisor resistivo 2:1 sobre la LiPo (4.2 V max).
//   El XIAO nRF52840 tiene referencia interna de 3.6 V y ADC de 12 bits.
//   Ajusta VDIV_RATIO y VREF si tu circuito es distinto.
// ============================================================
uint8_t readBatteryPercent() {
  const float VREF       = 3.6f;   // Voltaje de referencia ADC (V)
  const float VDIV_RATIO = 2.0f;   // Divisor resistivo (R1=R2 => x2)
  const float VBAT_MAX   = 4.2f;   // LiPo cargada al 100%
  const float VBAT_MIN   = 3.0f;   // LiPo descargada al 0%
  const int   ADC_RES    = 4095;   // 12 bits

  analogReadResolution(12);
  int   raw  = analogRead(PIN_BATTERY_ADC);
  float vAdc = (float)raw / ADC_RES * VREF;
  float vBat = vAdc * VDIV_RATIO;

  // Mapear a 0-100%
  float pct = (vBat - VBAT_MIN) / (VBAT_MAX - VBAT_MIN) * 100.0f;
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;

  return (uint8_t)pct;
}

void updateStatusLed(bool connected) {
  // Logica movida al loop principal para no bloquear.
  (void)connected;
}
