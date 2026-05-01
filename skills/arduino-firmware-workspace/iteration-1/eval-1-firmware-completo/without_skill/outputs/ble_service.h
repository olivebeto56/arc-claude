/*
 * ble_service.h
 * Servicio BLE para el nodo del tobillo izquierdo.
 *
 * UUIDs personalizados (128 bits) — cambia el UUID base si convive con
 * otros nodos en la misma aplicacion para evitar colisiones de UUID corto.
 *
 * Servicio IMU:
 *   UUID: 19B10000-E8F2-537E-4F6C-D104768A1214
 *   Caracteristica QUATERNION  (notify, 20 bytes):
 *     UUID: 19B10001-E8F2-537E-4F6C-D104768A1214
 *     Formato: i(float) j(float) k(float) real(float) accuracy(float) — little-endian
 *
 * Servicio Bateria (BLE SIG 0x180F):
 *   Caracteristica BATTERY_LEVEL (notify+read, 1 byte):
 *     UUID: 0x2A19
 *     Formato: uint8 0-100
 */

#pragma once

#include <Arduino.h>
#include "sensor.h"

// ---------- API publica ----------

/**
 * bleInit()
 * Configura el stack BLE, registra los servicios y empieza a hacer advertising.
 * @return true si todo fue bien.
 */
bool bleInit();

/**
 * bleIsConnected()
 * @return true si hay un central conectado actualmente.
 */
bool bleIsConnected();

/**
 * bleSendQuaternion(quat)
 * Serializa los cuaterniones a 20 bytes (5 floats little-endian) y los
 * notifica al central si esta suscrito.
 */
void bleSendQuaternion(const QuaternionData &quat);

/**
 * bleSendBattery(percent)
 * Actualiza y notifica el nivel de bateria (0-100).
 */
void bleSendBattery(uint8_t percent);
