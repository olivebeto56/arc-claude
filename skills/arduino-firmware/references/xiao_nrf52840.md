# Seeed XIAO nRF52840 Sense — Referencia Técnica para Firmware Arduino

## Especificaciones del chip
- SoC: Nordic nRF52840
- CPU: ARM Cortex-M4 @ 64 MHz (con FPU)
- RAM: 256 KB SRAM
- Flash: 1 MB (programa) + 2 MB QSPI externa
- Bluetooth: 5.0 + BLE (antena PCB integrada)
- USB: USB-C (native USB, puede emular serial, HID, etc.)
- Consumo deep sleep: ~5 µA

## Diferencia entre variantes
| Variante | IMU integrada | Micrófono | PDM |
|---|---|---|---|
| XIAO nRF52840 | ❌ | ❌ | ❌ |
| **XIAO nRF52840 Sense** | ✅ LSM6DS3TR-C (6 ejes) | ✅ | ✅ |

**Importante:** Usamos la variante **Sense**. Tiene un IMU LSM6DS3 de 6 ejes integrado en la placa — pero en este proyecto lo **ignoramos** y usamos el BNO085 externo de 9 ejes como IMU principal.

## Pinout (vista superior, conector hacia abajo)

```
         USB-C
    ┌─────────────┐
D0  │ 1         14│ 3.3V
D1  │ 2         13│ GND  
D2  │ 3         12│ VIN (5V)
D3  │ 4         11│ A5 / D10
D4  │ 5 [SDA]   10│ A4 / D9
D5  │ 6 [SCL]    9│ A3 / D8
D6  │ 7 [TX]     8│ A2 / D7
    └─────────────┘
         ↑
    [BAT+] [BAT-]  (conector JST 1.25mm 2 pines, cara inferior)
```

**Pines I2C (para BNO085):**
- SDA → **D4** (P0.06)
- SCL → **D5** (P0.07)

**Pin de batería:**
- `PIN_VBAT` — definido en el BSP, lee voltaje de batería via ADC

## Configuración del entorno Arduino

### Board Manager URL
```
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
```

### Selección de placa en Arduino IDE
```
Tools → Board → Seeed nRF52 Boards → Seeed XIAO BLE Sense - nRF52840
```

### Configuración del puerto serie
El XIAO usa USB nativo. Para que `Serial` funcione:
```cpp
void setup() {
  Serial.begin(115200);
  // En XIAO nRF52840, esperar que el puerto serie esté listo
  // (importante cuando está conectado por USB y no por batería)
  while (!Serial && millis() < 3000);
}
```

## I2C — Configuración

```cpp
#include <Wire.h>

void setup() {
  // Wire usa D4/D5 por defecto en el XIAO nRF52840
  Wire.begin();
  Wire.setClock(400000);  // Fast mode — NECESARIO para BNO085 a 100Hz+
}
```

**Nota:** El XIAO nRF52840 soporta I2C hasta 400kHz (Fast Mode). Para frecuencias de sensor > 200Hz considerar SPI.

## BLE con ArduinoBLE

```cpp
#include <ArduinoBLE.h>

// UUIDs para el servicio del wearable
// Generar UUIDs únicos en: https://www.uuidgenerator.net/
#define SERVICE_UUID         "19B10000-E8F2-537E-4F6C-D104768A1214"
#define SENSOR_CHAR_UUID     "19B10001-E8F2-537E-4F6C-D104768A1214"
#define BATTERY_CHAR_UUID    "19B10002-E8F2-537E-4F6C-D104768A1214"
#define CONFIG_CHAR_UUID     "19B10003-E8F2-537E-4F6C-D104768A1214"

BLEService sensorService(SERVICE_UUID);

// Characteristic de datos con propiedad NOTIFY (20 bytes)
BLECharacteristic sensorChar(SENSOR_CHAR_UUID,
  BLERead | BLENotify, 20);

// Characteristic de batería (1 byte: 0-100%)
BLEByteCharacteristic batteryChar(BATTERY_CHAR_UUID, BLERead);

// Characteristic de configuración (1 byte: frecuencia de muestreo)
BLEByteCharacteristic configChar(CONFIG_CHAR_UUID, BLEWrite);

void setupBLE(const char* deviceName) {
  if (!BLE.begin()) {
    Serial.println("ERROR: BLE init failed");
    while (1);
  }
  
  BLE.setLocalName(deviceName);          // e.g., "SportBand-L" o "SportBand-R"
  BLE.setAdvertisedService(sensorService);
  
  sensorService.addCharacteristic(sensorChar);
  sensorService.addCharacteristic(batteryChar);
  sensorService.addCharacteristic(configChar);
  
  BLE.addService(sensorService);
  BLE.advertise();
  
  Serial.print("BLE advertising as: ");
  Serial.println(deviceName);
}
```

## Batería LiPo — Lectura de nivel

```cpp
// El XIAO nRF52840 Sense tiene divisor de voltaje para leer la batería
// El divisor está controlado por P0.14 (activo en bajo)

float readBatteryVoltage() {
  // Habilitar el divisor de voltaje (pin a LOW activa la lectura)
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  delay(1);
  
  // Referencia interna de 3.0V para mayor precisión en batería
  analogReference(AR_INTERNAL_3_0);
  analogReadResolution(12);  // 12 bits = 0..4095
  
  int raw = analogRead(PIN_VBAT);
  
  // Deshabilitar divisor para ahorrar energía
  digitalWrite(P0_14, HIGH);
  pinMode(P0_14, INPUT);
  
  // Conversión: referencia 3.0V, divisor 2x
  return (raw * 3.0 / 4096.0) * 2.0;
}

uint8_t batteryPercent(float v) {
  // LiPo: 4.2V lleno, 3.2V vacío
  int pct = (int)((v - 3.2) / (4.2 - 3.2) * 100.0);
  return (uint8_t)constrain(pct, 0, 100);
}
```

## Deep Sleep para ahorro de batería

```cpp
#include "nrf_power.h"

// Entrar en deep sleep (System OFF — consume ~5µA)
// El dispositivo solo despierta con reset o pin configurado como DETECT
void enterDeepSleep() {
  BLE.end();
  Wire.end();
  Serial.end();
  
  // Asegurarse que todos los periféricos estén apagados
  nrf_power_system_off(NRF_POWER);
  // El código no continúa después de esta línea
}
```

**Nota:** Para prototipo Sprint 1-4, no es necesario implementar deep sleep. Agregar en Sprint 5+ para optimización de batería.

## IMU integrada (LSM6DS3) — ignorar en este proyecto

El XIAO nRF52840 Sense tiene un LSM6DS3 de 6 ejes en la placa (I2C address 0x6A). Para este proyecto usamos el BNO085 externo. No es necesario inicializarlo, pero si de casualidad entra en conflicto:

```cpp
// Si el LSM6DS3 interfiere con el bus I2C, apagarlo explícitamente:
// No hay una API oficial para esto en el BSP del XIAO.
// En la práctica, el LSM6DS3 no interfiere con el BNO085 porque tienen
// direcciones I2C diferentes (0x6A vs 0x4A).
```

## Errores frecuentes

**El XIAO no aparece como puerto serie**
- Verificar que el cable USB-C soporta datos (no solo carga)
- Si está en loop de crash, entrar en modo bootloader: doble-click rápido en el botón RESET

**`Wire.begin()` no encuentra el BNO085**
- Verificar que los cables van a D4 (SDA) y D5 (SCL), no a otros pines
- Agregar `delay(100)` después de `Wire.begin()` antes del primer scan I2C

**BLE no conecta desde Flutter**
- El XIAO puede tardar 2-3 segundos en empezar a advertise después del boot
- Verificar que `BLE.advertise()` se llamó en `setup()` y no en `loop()`
- En Android, el pairing puede requerir que el servicio sea "discoverable" — usar `BLE.setConnectable(true)`

**El sketch no compila ("undefined reference to...")**
- Asegurarse de que la placa seleccionada sea **"Seeed XIAO BLE Sense - nRF52840"** y no otra variante del XIAO
- La librería ArduinoBLE puede dar conflictos con las librerías nativas de Nordic — preferir ArduinoBLE v1.3+
