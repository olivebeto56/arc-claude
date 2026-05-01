# Plan de Prototipo Demostrable — Running con 2 Nodos

**Versión:** 1.0  
**Fecha:** 16 de abril 2026  
**Objetivo:** Tener un prototipo funcional de 2 bandas (muñeca + tobillo) que capture datos de carrera en tiempo real, los muestre en una app móvil, y genere al menos 3 recomendaciones biomecánicas accionables.

---

## Visión de la Demo Final

El atleta se coloca una banda en la muñeca y otra en el tobillo del mismo lado. Abre la app, conecta ambos nodos por BLE, y sale a correr. Durante la carrera, la app muestra en tiempo real: cadencia, tiempo de contacto con el suelo, simetría de braceo, y nivel de impacto vertical. Al terminar, recibe un resumen con 3 recomendaciones específicas para mejorar su forma de carrera.

---

## Fase 0 — Completar Hardware (1 semana)

### Objetivo
Tener 2 nodos completos ensamblados y verificados eléctricamente.

### Tareas
1. **Inventario de lo que tienes vs lo que falta.** Componentes necesarios por nodo:
   - [ ] Seeed XIAO nRF52840 Sense × 2
   - [ ] Adafruit BNO085 breakout × 2
   - [ ] Batería LiPo 3.7V 400mAh (602030, JST 1.25mm) × 2
   - [ ] Cable Stemma QT a Stemma QT 100mm × 2
   - [ ] Correa elástica 25mm × 2
2. **Comprar lo que falta.** Proveedores recomendados: Adafruit (BNO085), Seeed Studio (XIAO), Amazon/AliExpress (baterías, correas).
3. **Imprimir 2 carcasas** con el diseño `carcasa_wearable.scad` que ya tienes. Material: PETG. Verificar que el XIAO, BNO085 y batería encajen correctamente.
4. **Ensamblar los 2 nodos:** XIAO ↔ BNO085 vía cable Stemma QT, batería conectada al JST del XIAO, todo dentro de la carcasa.
5. **Verificación eléctrica:** cargar ambos nodos vía USB-C, confirmar que el LED de carga enciende y que el BNO085 responde por I2C (`i2cdetect` o scan sketch).

### Entregable
2 nodos ensamblados, cargados, con BNO085 detectado por I2C.

### Criterio de éxito
Ejecutar un sketch de I2C scan en ambos nodos y ver la dirección `0x4A` (BNO085) responder.

---

## Fase 1 — Firmware Base (1-2 semanas)

### Objetivo
Firmware en Arduino/C++ que lea datos del BNO085 y los transmita vía BLE con identificación de nodo.

### Arquitectura del firmware

```
┌─────────────────────────────────┐
│         main.cpp                │
│  ┌───────────┐  ┌────────────┐ │
│  │ SensorHAL │  │ BLEService │ │
│  │ (BNO085)  │  │  (Nordic)  │ │
│  └─────┬─────┘  └─────┬──────┘ │
│        │               │        │
│  getSensorData()  notifyData()  │
│        │               │        │
│  ┌─────▼───────────────▼─────┐  │
│  │     Pipeline Loop         │  │
│  │  read → pack → notify     │  │
│  │       (50 Hz)             │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

### Tareas
1. **Configurar entorno Arduino** con board package de Seeed nRF52840 y librería `Adafruit_BNO08x`.
2. **Implementar `SensorHAL`** — abstracción del sensor con interfaz:
   ```cpp
   struct SensorData {
     float quat[4];        // cuaternión (w, x, y, z)
     float accel[3];       // aceleración lineal (sin gravedad)
     float gyro[3];        // velocidad angular
     uint32_t timestamp;   // millis()
   };
   bool initSensor();
   SensorData getSensorData();
   ```
   Configurar BNO085 para reportar: `ROTATION_VECTOR` (100 Hz) + `LINEAR_ACCELERATION` (50 Hz) + `GYROSCOPE` (50 Hz).
3. **Implementar servicio BLE** con un Custom Service que contenga:
   - Characteristic de datos (notify, 20 bytes): empaqueta `SensorData` en formato binario compacto.
   - Characteristic de config (read/write): ID de nodo (0 = muñeca, 1 = tobillo), frecuencia de muestreo.
   - Device name: `SportBand-W` / `SportBand-A` (Wrist / Ankle).
4. **Loop principal a 50 Hz:** leer sensor → empaquetar → notificar por BLE. Usar `millis()` para mantener timing consistente.
5. **Protocolo binario del paquete BLE (20 bytes):**
   ```
   [0]     node_id (1 byte: 0x00=muñeca, 0x01=tobillo)
   [1-2]   timestamp_ms (uint16, wraps cada 65s)
   [3-10]  quaternion (4 × int16, escalado ×10000)
   [11-16] accel_xyz (3 × int16, escalado ×1000, en mg)
   [17-18] gyro_z (int16, escalado ×100, en °/s) — solo Z para ahorrar espacio
   [19]    battery_pct (uint8)
   ```
6. **Modo bajo consumo:** activar deep sleep cuando no hay conexión BLE por >60 segundos. Wake-up al detectar movimiento (interrupt del BNO085) o reconexión BLE.

### Entregable
Firmware flasheado en ambos nodos. Datos verificables con nRF Connect (app móvil).

### Criterio de éxito
Abrir nRF Connect, conectar a `SportBand-W` y `SportBand-A`, suscribirse a la characteristic de datos, y ver valores de cuaternión que cambian coherentemente al rotar el nodo.

---

## Fase 2 — App Móvil: Conexión y Visualización Raw (2 semanas)

### Objetivo
App en React Native que conecte a ambos nodos simultáneamente y muestre datos en tiempo real.

### Stack recomendado
- **React Native** (Expo bare workflow o CLI)
- **react-native-ble-plx** para BLE
- **zustand** para state management
- **react-native-reanimated** para animaciones de visualización fluidas

### Tareas
1. **Scaffold del proyecto** con estructura modular:
   ```
   src/
   ├── ble/
   │   ├── BleManager.ts        # singleton, scan + connect + reconnect
   │   ├── protocol.ts          # decode del paquete binario de 20 bytes
   │   └── types.ts
   ├── stores/
   │   ├── sensorStore.ts       # estado de datos por nodo
   │   └── sessionStore.ts      # estado de sesión activa
   ├── analysis/
   │   ├── running/
   │   │   ├── cadence.ts       # detector de cadencia
   │   │   ├── groundContact.ts # tiempo de contacto
   │   │   ├── impact.ts        # nivel de impacto vertical
   │   │   └── armSwing.ts      # análisis de braceo
   │   └── types.ts
   ├── screens/
   │   ├── HomeScreen.tsx        # scan + connect
   │   ├── LiveRunScreen.tsx     # dashboard en tiempo real
   │   └── SummaryScreen.tsx     # resumen post-carrera
   └── components/
       ├── MetricCard.tsx
       ├── LiveGraph.tsx
       └── RecommendationCard.tsx
   ```
2. **BLE Manager** que maneje:
   - Escaneo filtrado por nombre (`SportBand-*`).
   - Conexión simultánea a 2 dispositivos.
   - Reconexión automática si se pierde señal.
   - Decodificación del paquete binario en `SensorData`.
   - Buffer circular de últimos 5 segundos de datos por nodo.
3. **Pantalla de conexión (HomeScreen):**
   - Lista de dispositivos encontrados.
   - Estado de conexión de cada nodo (desconectado → conectando → conectado).
   - Indicador de batería de cada nodo.
   - Botón "Iniciar carrera" habilitado solo cuando ambos nodos están conectados.
4. **Pantalla de carrera en vivo (LiveRunScreen):**
   - Dashboard con 4 métricas principales en tarjetas grandes:
     - **Cadencia** (pasos/min) — derivada del tobillo
     - **Tiempo de contacto** (ms) — derivada del tobillo
     - **Oscilación vertical** (cm) — derivada del tobillo
     - **Simetría de braceo** (%) — derivada de la muñeca
   - Gráfico en tiempo real de aceleración vertical (últimos 10 segundos).
   - Timer de sesión y distancia estimada (por cadencia × longitud de zancada estimada).
   - Botón "Detener carrera".
5. **Pantalla de resumen (SummaryScreen):**
   - Promedios y tendencias de cada métrica durante la carrera.
   - Gráfico de cadencia a lo largo del tiempo.
   - Sección de recomendaciones (placeholder por ahora, se implementa en Fase 3).

### Entregable
App instalable en teléfono Android que conecta a ambos nodos y muestra datos en vivo.

### Criterio de éxito
Caminar/correr 2 minutos con ambos nodos puestos y ver las 4 métricas actualizándose en tiempo real en la app con valores que tienen sentido biomecánico (cadencia 150-190 spm al correr, tiempo de contacto 200-350ms).

---

## Fase 3 — Motor de Análisis Biomecánico (2 semanas)

### Objetivo
Algoritmos que extraigan métricas biomecánicas reales de los datos crudos del sensor y generen recomendaciones.

### Métricas a implementar

| Métrica | Sensor | Algoritmo |
|---------|--------|-----------|
| **Cadencia** | Tobillo | Detección de picos en aceleración vertical. Cada pico = un paso. Contar picos en ventana deslizante de 10s. |
| **Tiempo de contacto** | Tobillo | Fase de contacto = aceleración vertical > umbral (pie en suelo). Medir duración entre inicio y fin del contacto. |
| **Oscilación vertical** | Tobillo | Doble integración de aceleración vertical durante fase de vuelo. Resetear cada paso. Rango típico: 6-13 cm. |
| **Ratio vuelo/contacto** | Tobillo | Tiempo de vuelo ÷ tiempo de contacto. Runners eficientes: >1.0. |
| **Simetría de braceo** | Muñeca | Amplitud de oscilación del brazo (rango de pitch del cuaternión). Comparar brazo izquierdo vs movimiento esperado. |
| **Impacto vertical** | Tobillo | Pico de aceleración en el momento del contacto con el suelo. Expresado en g's. Alto impacto: >8g. |

### Tareas
1. **Detector de pasos (step detector):**
   - Filtro paso-bajo en aceleración vertical del tobillo (Butterworth 2do orden, fc=5 Hz).
   - Detección de picos con umbral adaptativo (media móvil + 1.5 desviaciones estándar).
   - Cada par de picos consecutivos = 1 ciclo de zancada.
   - Validación: comparar con cadencia manual contada en video.
2. **Segmentador de fases de zancada:**
   - Fase de contacto: aceleración vertical > umbral dinámico (pie aplicando fuerza al suelo).
   - Fase de vuelo: aceleración vertical < umbral (pie en el aire).
   - Output: timestamps de inicio/fin de cada fase para cada paso.
3. **Calculador de métricas por paso:**
   - Usar el segmentador para calcular cada métrica individualmente.
   - Mantener estadísticas running (media, desviación, min, max) por ventana de 30 segundos.
4. **Motor de recomendaciones (rule-based v1):**
   - Reglas basadas en rangos biomecánicos de la literatura:
     ```
     SI cadencia < 170 spm:
       → "Intenta aumentar tu cadencia. Pasos más cortos y frecuentes
          reducen el impacto y mejoran la eficiencia."
     
     SI tiempo_contacto > 300 ms:
       → "Tu pie pasa mucho tiempo en el suelo. Enfócate en un despegue
          rápido y activo."
     
     SI oscilacion_vertical > 10 cm:
       → "Estás rebotando demasiado. Visualiza correr 'bajo un techo
          imaginario' para reducir oscilación vertical."
     
     SI impacto > 8g:
       → "Tu impacto al aterrizar es alto. Intenta aterrizar con el
          mediopié en lugar del talón."
     
     SI ratio_vuelo_contacto < 0.8:
       → "Pasas más tiempo en contacto que en vuelo. Trabaja en la
          fuerza de despegue con ejercicios de pliometría."
     
     SI simetria_braceo < 85%:
       → "Tu braceo es asimétrico. Relaja los hombros y asegura que
          ambos brazos oscilen igual."
     ```
   - Priorizar las 3 recomendaciones con mayor desviación del rango óptimo.
5. **Testing con datos reales:**
   - Grabar 5 sesiones de carrera de 5 minutos cada una (distintas velocidades).
   - Logging completo de datos raw + métricas calculadas en archivo JSON.
   - Validar visualmente contra video de la carrera.

### Entregable
Módulo `analysis/running/` integrado en la app. Recomendaciones visibles en `SummaryScreen`.

### Criterio de éxito
Correr 5 minutos a ritmo moderado y recibir al menos 3 recomendaciones que sean biomecánicamente correctas y accionables (validadas comparando con video de la sesión).

---

## Fase 4 — Pulido de UX y Demo (1 semana)

### Objetivo
Llevar la app de "funcional" a "demostrable" con una experiencia fluida y profesional.

### Tareas
1. **Onboarding de primera vez:**
   - Instrucciones visuales de cómo colocar cada banda (muñeca y tobillo).
   - Calibración rápida: "quédate quieto 3 segundos" para establecer baseline.
2. **Indicadores de estado claros:**
   - Señal BLE de cada nodo (iconos de intensidad).
   - Batería restante.
   - Calidad de datos (si el sensor está dando lecturas erráticas, alertar).
3. **Animación de avatar simple (opcional pero impactante para demo):**
   - Stick figure 2D que mueve brazo y pierna en sync con los datos del sensor.
   - Usa los cuaterniones de muñeca y tobillo para animar.
4. **Pantalla de resumen mejorada:**
   - Gráficos con colores (verde/amarillo/rojo) según rango biomecánico.
   - Recomendaciones con iconos y explicación corta + detallada (expandible).
5. **Modo demo:** datos pregrabados que reproducen una sesión real para demostrar sin necesidad de correr.
6. **Branding básico:** nombre de la app, ícono, splash screen, colores consistentes.

### Entregable
App lista para demostrar a inversores, amigos, o usuarios beta.

### Criterio de éxito
Una persona que no conoce el producto puede entender qué hace y ver valor en menos de 3 minutos de demo.

---

## Timeline Consolidada

```
Semana 1        │ Fase 0: Completar y ensamblar hardware
Semana 2-3      │ Fase 1: Firmware (sensor + BLE)
Semana 4-5      │ Fase 2: App móvil (conexión + visualización)
Semana 6-7      │ Fase 3: Análisis biomecánico + recomendaciones
Semana 8        │ Fase 4: Pulido UX + demo
                │
                ▼
           PROTOTIPO DEMOSTRABLE (8 semanas)
```

**Nota:** Los tiempos asumen dedicación parcial (~3-4 horas/día). Con dedicación completa se puede comprimir a 5-6 semanas.

---

## Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| BLE pierde paquetes durante carrera | Métricas erráticas | Implementar sequence number en paquete + interpolación en app |
| Drift del cuaternión durante carrera larga | Orientación incorrecta | BNO085 tiene fusión interna con magnetómetro — verificar que esté activo. Recalibrar cada 10 min si es necesario |
| Latencia BLE > 100ms con 2 nodos | Dashboard no se siente "en vivo" | Usar connection interval de 15ms, MTU de 23 bytes (1 paquete), priorizar throughput sobre ahorro de batería en prototipo |
| Detección de pasos falla en velocidades bajas | Cadencia reportada es 0 | Umbral adaptativo + fallback a frecuencia dominante en FFT de aceleración |
| Carcasa impresa no cierra bien | Nodo se suelta durante carrera | Imprimir 2-3 versiones de prueba, ajustar tolerancias en OpenSCAD antes de ensamblaje final |

---

## Decisiones Técnicas Clave (ya tomadas)

- **Lenguaje firmware:** Arduino/C++ (ecosistema maduro para XIAO + BNO085)
- **App móvil:** React Native (cross-platform, buen soporte BLE)
- **Frecuencia de muestreo:** 50 Hz notify BLE (suficiente para running, BNO085 muestrea internamente a 100 Hz)
- **Formato de paquete:** Binario de 20 bytes (cabe en 1 paquete BLE sin fragmentación)
- **Análisis:** En el teléfono, no en el firmware (más flexibilidad para iterar algoritmos)
- **Recomendaciones v1:** Basadas en reglas (no ML), con umbrales de la literatura biomecánica

---

## Lo Que No Incluye Este Prototipo (v2+)

- Soporte para 4 nodos simultáneos
- Análisis de gym y golf
- Machine learning para detección de ejercicio
- Backend/cloud para histórico de sesiones
- App para iOS (primero Android)
- PCB custom (seguimos con breakout boards)
- Sincronización temporal precisa entre nodos (usamos timestamps individuales)
