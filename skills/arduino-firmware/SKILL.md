---
name: arduino-firmware
description: >
  Use this skill whenever the user wants to write, generate, modify, or debug Arduino firmware
  for the wearable sport monitor project. This includes any request involving the XIAO nRF52840 Sense,
  BNO085 IMU sensor, BLE GATT services, battery management, or sensor data pipelines in C++/Arduino.
  Trigger on prompts like: "genera el firmware para el nodo", "escribe el código del sensor",
  "crea el servicio BLE", "cómo inicializo el BNO085", "firmware para running", "código del tobillo",
  "implementa getSensorAngles", or any mention of .ino files, ArduinoBLE, BNO08x library,
  or XIAO firmware. Also trigger if the user asks for "Sprint 1" work or any firmware-related sprint task.
---

# Arduino Firmware Skill — Wearable Sport Monitor

## Contexto del proyecto

Este firmware corre en **nodos sensor** que forman parte de un sistema wearable de análisis biomecánico deportivo. Cada nodo es un **Seeed XIAO nRF52840 Sense** conectado a un **Adafruit BNO085** via I2C. Los nodos se comunican con una app Flutter en el teléfono via **Bluetooth Low Energy (BLE)** usando perfil GATT personalizado.

Hardware fijo por nodo:
- MCU: Seeed XIAO nRF52840 Sense (ARM Cortex-M4 @ 64MHz, BT 5.0)
- IMU: Adafruit BNO085 breakout #4754
- Batería: LiPo 3.7V 400mAh (JST 1.25mm)
- Carcasa: PETG impresa en 3D

Antes de generar cualquier código, **lee los archivos de referencia relevantes** en `references/`:
- `references/bno085.md` — modos de operación, reportes SHTP, inicialización, errores comunes
- `references/xiao_nrf52840.md` — pinout, I2C, carga LiPo, deep sleep, BLE

---

## Cómo generar firmware completo

Cuando el usuario pide firmware, siempre genera **archivos separados** guardados directamente en su carpeta de proyecto. Estructura estándar:

```
<nombre_nodo>/
├── <nombre_nodo>.ino      ← setup() y loop() principales
├── sensor.h               ← interfaz getSensorAngles() + structs
├── sensor.cpp             ← implementación BNO085
├── ble_service.h          ← definición del servicio GATT
└── ble_service.cpp        ← implementación BLE
```

### Principios de diseño que debes respetar siempre

**1. Abstracción del sensor desde el día uno**
Implementa siempre la función `getSensorAngles()` detrás de una interfaz. El objetivo es que migrar a un PCB custom en producción solo requiera cambiar el driver, no el firmware completo.

```cpp
// sensor.h — interfaz que NUNCA cambia
struct SensorAngles {
  float roll;    // grados
  float pitch;   // grados
  float yaw;     // grados
  float qw, qx, qy, qz;  // cuaternión raw
  uint32_t timestamp_ms;
};

bool initSensor();
bool getSensorAngles(SensorAngles& out);
```

**2. 9 ejes obligatorio — nunca uses solo 6**
El magnetómetro (eje Z) es crítico para:
- Tracking de swing de golf (rotación en Z)
- Rotación de cadera en running
- Sin él hay drift acumulativo en movimientos largos

Siempre activa `SENSOR_REPORTID_ARVR_STABILIZED_RV` o `SENSOR_REPORTID_ROTATION_VECTOR` (que incluye mag), nunca solo `SENSOR_REPORTID_GAME_ROTATION_VECTOR` (que omite el magnetómetro).

**3. BLE GATT con notificaciones, no polling**
El teléfono no debe hacer polling. Usa `BLECharacteristic::writeValue()` + notify para enviar datos automáticamente a la frecuencia del sensor. El servicio GATT debe tener:
- Un characteristic de datos de sensor (notify, 20 bytes max por paquete BLE)
- Un characteristic de estado/batería (read)
- Un characteristic de configuración (write) para cambiar frecuencia de muestreo desde la app

**4. Frecuencias de muestreo por deporte**
```cpp
// Running / Gym
#define SAMPLE_RATE_RUNNING_HZ  100   // 10ms interval
// Golf (swing corto, alta precisión)
#define SAMPLE_RATE_GOLF_HZ     200   // 5ms interval
// Reposo / baja actividad
#define SAMPLE_RATE_IDLE_HZ     25    // 40ms interval
```

**5. Empaquetado eficiente de datos BLE**
BLE Classic tiene MTU de 20 bytes por defecto. Empaqueta los datos así:
```cpp
struct __attribute__((packed)) BLEPacket {
  uint16_t timestamp_ms;  // 2 bytes — relativo al inicio de sesión
  int16_t  qw;            // 4 bytes — cuaternión escalado x10000
  int16_t  qx;
  int16_t  qy;
  int16_t  qz;
  int16_t  accel_x;       // 6 bytes — aceleración mg (mili-g)
  int16_t  accel_y;
  int16_t  accel_z;
                          // Total: 14 bytes ← cabe en MTU de 20
};
```

---

## Manejo de batería

El XIAO nRF52840 Sense tiene carga LiPo integrada (chip BQ25101). Para leer el nivel de batería:

```cpp
// Pin analógico para lectura de voltaje de batería
// El XIAO usa un divisor de voltaje interno
#define BATTERY_PIN  PIN_VBAT   // definido en el BSP del XIAO

float getBatteryVoltage() {
  // Deshabilitar el divisor de voltaje antes de leer (ahorra energía)
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);
  delay(1);
  
  int raw = analogRead(BATTERY_PIN);
  
  // Restaurar
  pinMode(P0_14, INPUT);
  
  // Conversión: ADC 12-bit, referencia 3.3V, divisor 2x
  return (raw * 3.3 / 4096.0) * 2.0;
}

uint8_t getBatteryPercent(float voltage) {
  // LiPo: 4.2V = 100%, 3.2V = 0%
  float pct = (voltage - 3.2) / (4.2 - 3.2) * 100.0;
  return (uint8_t)constrain(pct, 0, 100);
}
```

---

## Manejo de errores comunes

Siempre incluye manejo robusto de estos errores:

| Error | Causa | Solución |
|---|---|---|
| BNO085 no responde en I2C | Dirección incorrecta o cable suelto | Verificar `Wire.begin()` y dirección 0x4A |
| BLE no conecta | Advertising no activo | Llamar `BLE.advertise()` en setup |
| Cuaternión = (0,0,0,0) | Sensor no calibrado o reporte incorrecto | Esperar `sensor.wasReset()` y re-enviar config |
| Pérdida de datos en movimiento rápido | I2C a 100kHz | Usar `Wire.setClock(400000)` (fast mode) |
| Batería no lee bien | Pin no configurado | Usar `analogReference(AR_INTERNAL_3_0)` antes de leer |

---

## Formato del output

Cuando generes firmware:

1. **Crea cada archivo por separado** usando el Write tool, guardándolo en la carpeta del proyecto del usuario
2. **Agrega comentarios en inglés** en el código (variables, funciones, bloques lógicos)
3. **Incluye un bloque de configuración al inicio del .ino** con todos los parámetros ajustables (frecuencia, UUIDs BLE, nombre del nodo)
4. **Al terminar**, muestra al usuario:
   - Lista de archivos creados con sus rutas
   - Librerías Arduino necesarias (nombre exacto para instalar desde el Board Manager)
   - Instrucciones de configuración del board (Board Manager URL del XIAO)
   - Próximos pasos sugeridos (calibración, test BLE, etc.)

### Librerías requeridas (siempre menciónalas)
```
Board: "Seeed nRF52 Boards" via Board Manager
URL: https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json

Librerías (Library Manager):
- Adafruit BNO08x (by Adafruit)
- ArduinoBLE (by Arduino)
- Adafruit Unified Sensor (dependencia de BNO08x)
```

---

## Ejemplo de respuesta a "genera el firmware base para un nodo de running"

Cuando el usuario pide firmware para running con 2 nodos (tobillos), el output debe incluir:
- `running_node/running_node.ino` — setup, loop, modo running activado
- `running_node/sensor.h` y `sensor.cpp` — interfaz + driver BNO085 a 100Hz
- `running_node/ble_service.h` y `ble_service.cpp` — servicio GATT con UUID específico para running
- Configuración para distinguir nodo izquierdo vs derecho (via `#define NODE_ID LEFT_ANKLE`)

Lee `references/bno085.md` para los detalles exactos de inicialización del sensor y `references/xiao_nrf52840.md` para el pinout y configuración de I2C antes de escribir el código.
