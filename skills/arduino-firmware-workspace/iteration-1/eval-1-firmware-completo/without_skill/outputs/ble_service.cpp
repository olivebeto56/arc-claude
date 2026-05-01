/*
 * ble_service.cpp
 * Implementacion del servicio BLE para el nodo del tobillo izquierdo.
 *
 * Notas de diseno:
 *  - Se usan UUIDs de 128 bits para el servicio IMU y sus caracteristicas.
 *  - El servicio de bateria usa los UUIDs estandar BLE SIG (0x180F / 0x2A19).
 *  - La MTU del XIAO nRF52840 con ArduinoBLE por defecto es 23 bytes
 *    (20 bytes de payload); los 20 bytes de cuaternion caben exactamente.
 *  - writeValue() con BLENotify solo envia si el central esta suscrito.
 */

#include "ble_service.h"
#include <ArduinoBLE.h>
#include <string.h>  // memcpy

// ---- UUIDs ---------------------------------------------------------------
// Servicio IMU personalizado
#define UUID_IMU_SERVICE   "19B10000-E8F2-537E-4F6C-D104768A1214"
// Caracteristica: cuaternion (5 x float = 20 bytes)
#define UUID_QUAT_CHAR     "19B10001-E8F2-537E-4F6C-D104768A1214"

// Servicio de Bateria (BLE SIG)
#define UUID_BAT_SERVICE   "180F"
#define UUID_BAT_LEVEL     "2A19"

// ---- Nombre BLE del dispositivo ------------------------------------------
#define BLE_LOCAL_NAME     "LeftAnkle-Node"

// ---- Objetos BLE ----------------------------------------------------------
static BLEService imuService(UUID_IMU_SERVICE);
static BLEService batteryService(UUID_BAT_SERVICE);

// Cuaternion: notify, 20 bytes (no read para reducir latencia de ATT)
static BLECharacteristic quatCharacteristic(
    UUID_QUAT_CHAR,
    BLENotify,
    20,    // valor maximo en bytes
    true   // valor fijo (fixed length)
);

// Bateria: read + notify, 1 byte
static BLEUnsignedCharCharacteristic batteryLevelCharacteristic(
    UUID_BAT_LEVEL,
    BLERead | BLENotify
);

// ---- Estado interno -------------------------------------------------------
static BLEDevice connectedCentral;
static bool      deviceConnected = false;

// ---- Callbacks de conexion -----------------------------------------------
static void onConnect(BLEDevice central) {
  deviceConnected = true;
  connectedCentral = central;
  Serial.print("[BLE] Conectado: ");
  Serial.println(central.address());
}

static void onDisconnect(BLEDevice central) {
  deviceConnected = false;
  Serial.print("[BLE] Desconectado: ");
  Serial.println(central.address());
  // Reiniciar advertising automaticamente
  BLE.advertise();
  Serial.println("[BLE] Advertising reiniciado.");
}

// ==========================================================================
bool bleInit() {
  if (!BLE.begin()) {
    Serial.println("[BLE] BLE.begin() fallo.");
    return false;
  }

  BLE.setLocalName(BLE_LOCAL_NAME);
  BLE.setDeviceName(BLE_LOCAL_NAME);

  // --- Servicio IMU ---
  imuService.addCharacteristic(quatCharacteristic);
  BLE.addService(imuService);

  // --- Servicio Bateria ---
  batteryService.addCharacteristic(batteryLevelCharacteristic);
  BLE.addService(batteryService);

  // Valor inicial de la bateria
  batteryLevelCharacteristic.writeValue((uint8_t)0);

  // UUID del servicio principal en el advertising packet
  BLE.setAdvertisedService(imuService);

  // Registrar callbacks
  BLE.setEventHandler(BLEConnected,    onConnect);
  BLE.setEventHandler(BLEDisconnected, onDisconnect);

  // Iniciar advertising
  BLE.advertise();

  Serial.print("[BLE] Advertising como \"");
  Serial.print(BLE_LOCAL_NAME);
  Serial.println("\"");

  return true;
}

// ==========================================================================
bool bleIsConnected() {
  return deviceConnected;
}

// ==========================================================================
void bleSendQuaternion(const QuaternionData &quat) {
  if (!deviceConnected) return;

  // Serializar 5 floats en little-endian (IEEE 754, 4 bytes cada uno = 20 B)
  uint8_t buf[20];
  float values[5] = {
    quat.i,
    quat.j,
    quat.k,
    quat.real,
    quat.accuracy
  };
  memcpy(buf, values, 20);

  quatCharacteristic.writeValue(buf, 20);
}

// ==========================================================================
void bleSendBattery(uint8_t percent) {
  batteryLevelCharacteristic.writeValue(percent);
  Serial.print("[BLE] Battery notified: ");
  Serial.print(percent);
  Serial.println("%");
}
