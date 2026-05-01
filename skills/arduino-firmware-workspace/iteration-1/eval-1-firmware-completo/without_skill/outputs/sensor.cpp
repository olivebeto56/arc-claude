/*
 * sensor.cpp
 * Implementacion de la abstraccion del BNO085.
 * Usa la libreria Adafruit BNO08x sobre I2C.
 *
 * Conexion por defecto (XIAO nRF52840 Sense):
 *   SDA -> D4 (Pin 4)
 *   SCL -> D5 (Pin 5)
 *   VIN -> 3.3 V
 *   GND -> GND
 *   PS1 -> GND  (selecciona I2C, direccion 0x4A)
 *   PS0 -> GND
 *
 * Direccion I2C: 0x4A (PS1=0, PS0=0) o 0x4B (PS1=1, PS0=0)
 */

#include "sensor.h"
#include <Adafruit_BNO08x.h>
#include <Wire.h>

// ---------- Configuracion ----------
#define BNO085_I2C_ADDR   0x4A
#define BNO085_REPORT_US  10000   // 10 000 us = 100 Hz
#define BNO085_RESET_PIN  -1      // Sin pin de reset hardware (-1 = no usado)

// ---------- Objeto del sensor ----------
static Adafruit_BNO08x bno(BNO085_RESET_PIN);
static sh2_SensorValue_t sensorValue;

// ============================================================
bool sensorInit() {
  Wire.begin();
  Wire.setClock(400000); // I2C Fast Mode 400 kHz

  if (!bno.begin_I2C(BNO085_I2C_ADDR)) {
    Serial.println("[SENSOR] begin_I2C fallo.");
    return false;
  }

  // Habilitar informe: cuaterniones de rotacion (Rotation Vector)
  // SH2_ROTATION_VECTOR incluye precision de referencia magnetica.
  // Si no necesitas fusion con magnetometro usa SH2_GAME_ROTATION_VECTOR.
  if (!bno.enableReport(SH2_ROTATION_VECTOR, BNO085_REPORT_US)) {
    Serial.println("[SENSOR] enableReport(ROTATION_VECTOR) fallo.");
    return false;
  }

  Serial.println("[SENSOR] BNO085 inicializado OK @ 100 Hz (ROTATION_VECTOR).");
  return true;
}

// ============================================================
bool sensorRead(QuaternionData &out) {
  // getSensorEvent() es no bloqueante: devuelve false si no hay dato nuevo.
  if (!bno.getSensorEvent(&sensorValue)) {
    return false;
  }

  // Verificar que el tipo de informe es el que esperamos.
  if (sensorValue.sensorId != SH2_ROTATION_VECTOR) {
    return false;
  }

  out.i         = sensorValue.un.rotationVector.i;
  out.j         = sensorValue.un.rotationVector.j;
  out.k         = sensorValue.un.rotationVector.k;
  out.real      = sensorValue.un.rotationVector.real;
  out.accuracy  = sensorValue.un.rotationVector.accuracy;
  out.timestamp = millis();

  return true;
}
