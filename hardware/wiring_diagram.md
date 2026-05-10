# Diagrama de cableado — Nodo individual (Sprint 1)

Este documento describe el cableado físico de un nodo del wearable AI Sport
Monitor. Aplica para los dos nodos del prototipo de running (tobillo izquierdo
y derecho) — el cableado es **idéntico** en ambos.

> **Nota sobre la variante de XIAO**: el BOM original del proyecto contemplaba
> el XIAO nRF52840 **Sense** (con LSM6DS3 y micrófono onboard). Para el
> prototipo se está usando el XIAO nRF52840 **base** (sin Sense). El pinout
> I2C, los pads BAT+/BAT- y el firmware son **idénticos** entre ambas
> versiones — la única diferencia es que la versión Sense incluye sensores
> onboard que el proyecto explícitamente ignora (ver CLAUDE.md). El cambio
> reduce el costo por nodo de ~$36 a ~$31 USD sin impacto funcional.

## Componentes por nodo

| Componente | Modelo | Cantidad |
|---|---|---|
| MCU + BLE | Seeed XIAO nRF52840 (base o Sense) | 1 |
| IMU 9-DOF | Adafruit BNO085 STEMMA QT (#4754) | 1 |
| Batería | LiPo 3.7 V 400 mAh, JST 1.25 mm, formato 602030 | 1 |
| Cable I2C | STEMMA QT JST-SH 4-pin (cortado a la mitad) | 1 |
| Cable batería | JST 1.25 mm 2-pin macho con cables | 1 |

## Resumen de conexiones

Cada nodo requiere **6 puntos de soldadura en el XIAO** y ningún soldado en el
BNO085 (todo va por STEMMA QT) ni en la batería (usa su conector original).

### Conexión 1 — BNO085 ↔ XIAO (I2C)

| Cable STEMMA QT | Color | Pin XIAO | Función |
|---|---|---|---|
| Pin 1 | Negro | **GND** | Tierra |
| Pin 2 | Rojo | **3V3** | Alimentación 3.3 V |
| Pin 3 | Azul | **D4** (P0.06) | SDA — datos I2C |
| Pin 4 | Amarillo | **D5** (P0.07) | SCL — reloj I2C |

> El cable STEMMA QT estándar de Adafruit se corta por la mitad. Un extremo
> (con conector JST-SH intacto) se enchufa al puerto STEMMA QT del BNO085. El
> otro extremo (cables pelados) se suelda al XIAO según la tabla de arriba.

### Conexión 2 — Batería ↔ XIAO

| Cable JST macho | Color | Pad XIAO | Función |
|---|---|---|---|
| Positivo | Rojo | **BAT+** (pad inferior) | + batería |
| Negativo | Negro | **BAT-** (pad superior) | − batería |

> Del kit de conectores JST, se toma un cable macho con conector. Se corta
> a ~3 cm del conector, se sueldan los cables al XIAO en los pads BAT+/BAT-.
> La batería original con su conector hembra se enchufa al conector macho
> expuesto.

## Diagrama ASCII del nodo ensamblado

```
                    ┌──────────────────────────────┐
                    │         BNO085               │
                    │    (Adafruit #4754)          │
                    │                              │
                    │   STEMMA QT port  ●          │
                    └─────────────┬────────────────┘
                                  │
                                  │ Cable STEMMA QT
                                  │ (4 hilos)
                                  │
                ┌─────────┬───────┴───────┬─────────┐
                │         │               │         │
              negro     rojo            azul     amarillo
               GND      3V3             SDA       SCL
                │         │               │         │
                ▼         ▼               ▼         ▼
        ┌─────────────────────────────────────────────────┐
        │                                                 │
        │            XIAO nRF52840                        │
        │                                                 │
        │   GND ●                                         │
        │   3V3 ●        Cara superior                    │
        │   D4  ●        (pines)                          │
        │   D5  ●                                         │
        │                                                 │
        │  ─────────────────────────────────────────      │
        │                                                 │
        │   BAT+ ▼   BAT- ▼     Cara inferior             │
        │                       (pads SMD)                │
        └──────┬─────────┬────────────────────────────────┘
               │         │
              rojo     negro
               │         │
               └────┬────┘
                    │
                    │ Cable JST macho cortado
                    │ (~3 cm)
                    │
                    ▼
            ┌────────────────┐
            │   Conector     │
            │   JST macho    │
            └────────────────┘
                    ↕  enchufa
            ┌────────────────┐
            │   Conector     │
            │   JST hembra   │  ← original de la batería
            └────────────────┘
                    │
                    ▼
            ┌────────────────┐
            │   Batería LiPo │
            │   3.7 V 400 mAh│
            │   602030       │
            └────────────────┘
```

## Pinout I2C del XIAO nRF52840 (referencia)

```
D4 = P0.06 = SDA  (datos I2C)
D5 = P0.07 = SCL  (reloj I2C)
```

Estos son los pines I2C **por defecto** cuando se usa `Wire.begin()` en el
framework Arduino. No requiere configuración adicional en código. El firmware
debe llamar `Wire.setClock(400000)` para fast-mode I2C — necesario para
sostener 100 Hz en running.

## Checklist antes de la primera energización

1. ☐ Continuidad GND: pin GND del XIAO ↔ GND del BNO085
2. ☐ Continuidad 3V3: pin 3V3 del XIAO ↔ Vin del BNO085
3. ☐ NO hay continuidad entre 3V3 y GND (descartar corto)
4. ☐ NO hay continuidad entre BAT+ y BAT- (descartar corto)
5. ☐ Polaridad de batería confirmada con multímetro: con USB-C conectado,
      BAT+ debe leer ~4.0–4.2 V respecto a GND
6. ☐ El conector de la batería entra firmemente en el conector macho del XIAO

## Orden de armado recomendado

1. **Soldar cable STEMMA QT al XIAO** (4 cables del BNO085).
2. **Conectar el otro extremo al BNO085** vía conector JST-SH.
3. **Conectar XIAO por USB-C** y subir el sketch de test del BNO085.
4. **Validar lecturas**: cuaterniones cambiando al mover el sensor →
   cableado del sensor correcto.
5. **Soldar cable JST de batería** a los pads BAT+/BAT-.
6. **Verificar polaridad** con multímetro.
7. **Enchufar la batería** y desconectar USB-C — el XIAO debe seguir corriendo.

## Advertencias

- El BNO085 funciona a **3.3 V**. Nunca conectar a 5V — daño permanente.
- Polaridad de batería invertida puede dañar el XIAO **y** hinchar la batería
  LiPo (riesgo de incendio). Verificar siempre con multímetro antes del primer
  enchufe.
- Los pads SMD del XIAO son frágiles. Soldar con cautín ≤30W, tiempo de
  contacto <3 segundos por punto, y aplicar flux para evitar levantar el pad.
- El cable STEMMA QT tiene asignación de colores **estándar Adafruit**
  (rojo=V+, negro=GND, azul=SDA, amarillo=SCL). Cables genéricos pueden
  variar — verificar con multímetro continuidad antes de soldar.

## UUIDs BLE (referencia para el firmware)

```
Servicio:       19B10000-E8F2-537E-4F6C-D104768A1214
Sensor data:    19B10001-E8F2-537E-4F6C-D104768A1214  (NOTIFY)
Battery:        19B10002-E8F2-537E-4F6C-D104768A1214  (READ)
Config:         19B10003-E8F2-537E-4F6C-D104768A1214  (WRITE)
```

## Referencias cruzadas

- [`firmware/running_node/README.md`](../firmware/running_node/README.md) —
  guía de flasheo y formato del paquete BLE
- [`skills/arduino-firmware/references/xiao_nrf52840.md`](../skills/arduino-firmware/references/xiao_nrf52840.md) —
  detalles del MCU y pinout completo
- [`skills/arduino-firmware/references/bno085.md`](../skills/arduino-firmware/references/bno085.md) —
  driver, modos de operación y reportes
- [`CLAUDE.md`](../CLAUDE.md) — contexto general del proyecto y BOM
