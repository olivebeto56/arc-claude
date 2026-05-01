/*
 * sensor.h
 * Abstraccion del BNO085 para el nodo del tobillo izquierdo.
 * Expone un tipo de datos QuaternionData y dos funciones publicas.
 */

#pragma once

#include <Arduino.h>

// ---------- Tipo de dato de salida ----------
struct QuaternionData {
  float    i;          // Componente i (x)
  float    j;          // Componente j (y)
  float    k;          // Componente k (z)
  float    real;       // Componente real (w)
  float    accuracy;   // Estimacion de error (rad) devuelta por el BNO085
  uint32_t timestamp;  // millis() en el momento de la lectura
};

// ---------- API publica ----------

/**
 * sensorInit()
 * Inicializa el bus I2C y el BNO085.
 * Configura el informe de cuaterniones de rotacion a 100 Hz (10 000 us).
 * @return true si el sensor respondio correctamente, false en caso contrario.
 */
bool sensorInit();

/**
 * sensorRead(out)
 * Consulta si hay un nuevo dato disponible en el BNO085 y lo copia en 'out'.
 * No bloquea: si no hay dato nuevo devuelve false inmediatamente.
 * @param out Referencia donde se escribiran los cuaterniones.
 * @return true si se leyo un dato valido, false si no habia dato nuevo.
 */
bool sensorRead(QuaternionData &out);
