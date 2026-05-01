# AI Sport Monitor — Project Context for Claude

## What this project is

A multi-node wearable sport monitor built from scratch: hardware, firmware, and mobile app.
Each node is a small band worn on the wrist or ankle. Nodes capture 9-axis IMU data and
stream it over BLE to a Flutter app that analyzes biomechanics and delivers real-time coaching.

**Differentiator vs Apple Watch / Garmin:** simultaneous multi-limb capture with sport-specific
and exercise-specific biomechanical analysis. Not just step count — actual technique feedback.

**Sports target v1:** running (2 ankle nodes), gym (squat, deadlift), golf (swing).
**Current focus:** running prototype for investor demo.

---

## Hardware (per node) — FIXED, do not suggest alternatives

| Component | Part | Cost |
|---|---|---|
| MCU + BT | Seeed XIAO nRF52840 Sense | ~$15 |
| IMU | Adafruit BNO085 breakout #4754 | ~$17 |
| Battery | LiPo 3.7V 400mAh, JST 1.25mm, format 602030 | ~$4 |
| Enclosure | Custom PLA (prototipo) / PETG (final), Bambu Lab A1 Mini | — |
| **Total** | | **~$36/node** |

### Key hardware facts
- XIAO I2C pins: SDA = D4 (P0.06), SCL = D5 (P0.07)
- BNO085 I2C address: 0x4A (SA0 to GND, default on Adafruit breakout)
- Battery connector: JST 1.25mm 2-pin, plugs directly into XIAO's JST port
- Battery voltage reading: use PIN_VBAT with P0_14 as voltage divider enable, AR_INTERNAL_3_0 reference
- XIAO variant: **nRF52840 Sense** (has onboard LSM6DS3 IMU — we IGNORE it, use BNO085 instead)
- Enclosure design: `carcasa_wearable.scad` (OpenSCAD, parametric) — already in this folder
- USB-C access without disassembly, 25mm elastic strap slots, snap-fit lid

---

## Architecture decisions — WHY, not just what

### 1. Sensor abstraction from day one
Always implement `getSensorAngles()` / `SensorData` behind an interface. The goal: migrating
to a custom PCB in production requires only a driver swap, not a firmware rewrite.

### 2. 9-axis mandatory — never drop the magnetometer
BNO085 delivers fused quaternions via its internal ARM Cortex-M0+ (no Kalman filter needed).
The magnetometer is critical for Z-axis rotation tracking (golf hip rotation, ankle pronation).
Without it, yaw drifts within 30 seconds of continuous movement.
**Always use `SH2_ARVR_STABILIZED_RV`, never `SH2_GAME_ROTATION_VECTOR`.**

### 3. BLE GATT with notify, not polling
The phone never polls. The node pushes data at sensor rate. Characteristics:
- `19B10001-...` — sensor data (NOTIFY, 14-16 bytes packed)
- `19B10002-...` — battery % (READ, 1 byte)
- `19B10003-...` — config / sample rate (WRITE, 1 byte)

### 4. BLE packet format (v3, 22 bytes, little-endian)
```
Bytes 0-1:   uint16  timestamp_ms   (relative to session start)
Bytes 2-3:   int16   qw × 10000
Bytes 4-5:   int16   qx × 10000
Bytes 6-7:   int16   qy × 10000
Bytes 8-9:   int16   qz × 10000
Bytes 10-11: int16   accel_x (milli-g)
Bytes 12-13: int16   accel_y (milli-g)
Bytes 14-15: int16   accel_z (milli-g)
Bytes 16-17: int16   gyro_x  × GYRO_SCALE  (°/s, calibrated)
Bytes 18-19: int16   gyro_y  × GYRO_SCALE  (°/s, calibrated)
Bytes 20-21: int16   gyro_z  × GYRO_SCALE  (°/s, calibrated)
```
Scale: quat ÷ 10000; accel × 9.80665 / 1000 → m/s²; gyro ÷ `GYRO_SCALE` → °/s.
`GYRO_SCALE` defaults to 100 (range ±327 °/s for running/gym); drop to 10 for
golf (range ±3270 °/s on the wrist). Keep firmware and app in sync.

The firmware always emits v3. Parsers must degrade by `bytes.length` and never
throw on shorter packets — the legacy sizes are:
- **v1 = 14 B** — no `accel_z`, no gyro
- **v2 = 16 B** — full accel, no gyro
- **v3 = 22 B** — current format

### 5. Multi-node simultaneous connection
Connect both nodes in parallel — `Future.wait([leftNode.connect(), rightNode.connect()])`.
Never connect sequentially. Node names: `SportBand-XXXX` (XXXX = 4 hex chars
derived from the nRF52840 factory `DEVICEID`; the firmware is identical on
every band and never knows its own side). Left/right assignment is done in the
app at pairing time ("shake the left band") and persisted as a `chip_id → side`
map in app local storage. Identify each band by its BLE local name (stable
across resets and OS-level MAC rotation), not by MAC address.

### 6. Sliding window metrics, not session averages
All biomechanical metrics use the **last 10 steps** per foot. This reflects current technique,
not a diluted average of the whole session. Window resets on reconnect.

### 7. Backend: local for prototype, AWS later
The running prototype does all analysis on-device (phone). No server calls.
AWS data pipeline is planned for post-MVP when logging historical sessions.

---

## Tech stack

### Firmware (Sprint 1)
- Language: C++ (Arduino framework)
- Libraries: `Adafruit BNO08x`, `ArduinoBLE` v1.3+, `Adafruit Unified Sensor`
- Board: `Seeed XIAO BLE Sense - nRF52840`
- Board Manager URL: `https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json`
- I2C: always `Wire.setClock(400000)` (fast mode — required for 100 Hz)
- Sample rate: 100 Hz running/gym, 200 Hz golf, 25 Hz idle

### Mobile App (Sprint 2–4)
- Framework: Flutter (Dart), Material 3 **OFF** (custom dark theme — see `DESIGN.md`)
- BLE: `flutter_blue_plus ^1.32.0`
- State management: **Riverpod** (per Claude Design handoff — overrides earlier Provider mention)
- Charts: `fl_chart ^0.68.0`
- Maps: `flutter_map` or Mapbox (TBD when GPS screen is built)
- Permissions: `permission_handler ^11.3.1`
- Fonts: Inter (200–700) + JetBrains Mono (400, 500) via `assets/fonts/`
- Theme tokens: see `DESIGN.md` and `design/design_handoff_arc_app/README.md` —
  the handoff is the source of truth for colors, typography, spacing (4 px grid),
  radii, and shadows. Do NOT use the values quoted historically here as canonical;
  trust the handoff.

### Analysis (Sprint 3)
- Real-time: Dart classes in `lib/analysis/`
- Offline calibration: Python (`pandas`, `numpy`, `scipy`, `matplotlib`)

---

## Project file structure (planned)

```
firmware/
└── running_node/
    ├── running_node.ino
    ├── sensor.h / sensor.cpp        ← getSensorAngles() abstraction
    ├── ble_service.h / ble_service.cpp
    └── config.h                     ← NODE_ID, UUIDs, sample rates

app/
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── models/
    │   └── sensor_data.dart         ← SensorData, RunningMetrics
    ├── services/
    │   ├── ble_manager.dart         ← scan, connect, subscribe
    │   └── sensor_parser.dart       ← BLE bytes → SensorData
    ├── providers/
    │   └── session_provider.dart    ← ChangeNotifier, metrics, recommendations
    ├── analysis/
    │   ├── event_detector.dart      ← impact / takeoff detection
    │   ├── metrics_calculator.dart  ← cadence, symmetry, contact time
    │   ├── recommendation_engine.dart
    │   └── session_summary.dart
    └── screens/
        ├── scan_screen.dart
        ├── running_screen.dart
        └── summary_screen.dart

analysis/
└── analyze_session.py               ← offline calibration script

skills/                              ← Claude skills (Cowork / Claude Code)
├── arduino-firmware.skill
├── flutter-ble.skill
└── biomechanics-analyzer.skill
```

---

## Sprint plan (6 weeks, investor demo target)

| Sprint | Days | Goal | Done? |
|---|---|---|---|
| 1 | 1–7 | Firmware: BNO085 + BLE GATT on 2 nodes | ☐ |
| 2 | 8–14 | Flutter app: BLE scan + simultaneous multi-node connection | ☐ |
| 3 | 15–21 | Biomechanics engine: event detection + metrics + recommendations | ☐ |
| 4 | 22–28 | Real-time dashboard + post-session summary screen | ☐ |
| 5 | 29–35 | Final PETG enclosure + end-to-end integration | ☐ |
| 6 | 36–42 | Polish, demo video, investor materials | ☐ |

**Prototype budget:** ~$87 USD (2 nodes × $36 + cables + PETG + straps)

---

## Biomechanics reference — running metrics

| Metric | Optimal range | Method |
|---|---|---|
| Cadence | 175–185 spm | Impact peak detection, 60000/avg_interval_ms |
| Symmetry L/R | 46–54% | Contact time ratio left/(left+right) |
| Ground contact time | 200–250 ms (recreational) | Time between IMPACT and TAKEOFF events |
| Strike angle (pitch at impact) | 0–10° (midfoot) | Euler pitch of ankle at impact moment |
| Stride variability | 3–6% CV | Coefficient of variation of step intervals |
| Impact load | 8–15 m/s² | Accel magnitude peak at impact |

### Event detection thresholds (calibrate with real data)
```dart
_impactThreshold  = 12.0   // m/s² — stance start
_takeoffThreshold =  2.5   // m/s² — flight start (hysteresis gap = 9.5 m/s²)
_minStepMs        =  200   // ms   — 300 spm physiological max
_maxContactMs     =  500   // ms   — above this = not running
```
These are scientifically grounded starting points (Heiderscheit 2011, Morin 2011, Lieberman 2010).
**Always calibrate with real session data before the investor demo.**

Calibration protocol:
1. Record 5-min easy run, export CSV
2. Count steps manually for 30s, compare with detector
3. Adjust `_impactThreshold` until step count matches
4. Verify GCT: should be 200–280 ms for recreational pace
5. Verify symmetry: should be 47–53% on a straight run

---

## BLE UUIDs (fixed — shared between firmware and app)

```
Service:        19B10000-E8F2-537E-4F6C-D104768A1214
Sensor data:    19B10001-E8F2-537E-4F6C-D104768A1214  (NOTIFY)
Battery:        19B10002-E8F2-537E-4F6C-D104768A1214  (READ)
Config:         19B10003-E8F2-537E-4F6C-D104768A1214  (WRITE)
```

---

## Key conventions

- **Code and comments:** English
- **Conversation:** Spanish
- **Side identifiers (app-side only):** `"LEFT_ANKLE"`, `"RIGHT_ANKLE"` (string constants, not enums). The firmware does not know its own side; the app maps each band's chip-ID-derived BLE name to a side at pairing time.
- **Device names:** `SportBand-XXXX` where XXXX is 4 hex chars derived from the nRF52840 factory DEVICEID. Identical firmware on every band — no compile-time L/R selection.
- **Quaternion convention:** Hamilton (w, x, y, z), BNO085 output
- **Euler convention:** ZYX Tait-Bryan (roll=X, pitch=Y, yaw=Z)
- **Accel units in app:** m/s² (converted from milli-g in `SensorParser`)
- **Timestamps:** relative to session start in ms (uint16, wraps every ~65s — use modular arithmetic)

---

## What NOT to do

- Do not suggest replacing BNO085 with a 6-axis IMU — the magnetometer is non-negotiable
- Do not use `SH2_GAME_ROTATION_VECTOR` anywhere — yaw drift will break golf and hip rotation tracking
- Do not connect BLE nodes sequentially — always `Future.wait()`
- Do not compute metrics over the whole session — always use the sliding 10-step window
- Do not add AWS/backend calls to the prototype — everything stays local until post-MVP
- Do not use `setState` for shared state in Flutter — always route through Riverpod providers
- Do not use Material widgets directly (ElevatedButton, AppBar, default Scaffold) — build atoms from `Container` + `GestureDetector` per the handoff
- Do not pick visual tokens from this CLAUDE.md if they differ from `DESIGN.md` / handoff — the handoff wins
- Do not hardcode MAC addresses for node identification — use the BLE local name (`SportBand-XXXX`), which is derived from the nRF52840 chip ID and stable across resets and OS-level MAC rotation
- Do not reintroduce a compile-time `NODE_SIDE` switch in firmware — the L/R role is an app-level concept (multi-sport: golf wrist+hip, gym wrist+ankle, etc.)

---

## Skills available (install in Claude Code via .skill files in skills/)

These skills carry deep project context and should be loaded when working on:

- `arduino-firmware` — firmware generation for XIAO nRF52840 + BNO085, BLE GATT, battery reading
- `flutter-ble` — Flutter widgets, BleManager, SensorParser, Provider patterns, scan/connect UI
- `biomechanics-analyzer` — event detection, metrics calculation, recommendation engine, Python analysis scripts
- `flutter-design-system` — translates Claude Design HTML/JSX assets in `design/` into Flutter widgets, ThemeData, TextStyle, and Color tokens

---

## Design system (Claude Design → Flutter)

The visual system for the app lives in two places:

1. **`DESIGN.md`** (project root) — the design system index: color tokens,
   typography scale, spacing, component catalog, screen catalog, and the rules
   for translating HTML/CSS/JSX into Flutter widgets. **Always read this file
   before generating any UI code.**

2. **`design/`** (project root) — raw assets exported from Claude Design:
   - `design/pages/*.html` — full page mockups (ARC App, Brand Guidelines,
     Logo Exploration, Assets)
   - `design/components/*.jsx` — React reference components (brand.jsx,
     logos.jsx, design-canvas.jsx)
   - `design/screens/*` — individual screen mockups
   - `design/assets/` — logo SVGs, icons, illustrations
   - `design/design_handoff_arc_app/` — official Claude Design handoff package

### Workflow when generating UI code

When asked to build any Flutter screen, widget, or theme:

1. Read `DESIGN.md` first.
2. Read the relevant HTML/JSX from `design/` for the specific screen or
   component being built.
3. Verify required tokens exist in `app/lib/theme/app_colors.dart` and
   `app/lib/theme/app_text_styles.dart` — create them if missing.
4. Generate the widget honoring the design system tokens. Adapt layout to
   idiomatic Flutter (Material 3) but **never invent colors, sizes, or
   typography** outside the tokens defined in `DESIGN.md`.
5. Reusable visual elements go in `app/lib/widgets/`, not inline in screens.

### What NOT to do for UI

- Do not use raw `Color(0xFF...)` literals — always reference `AppColors`.
- Do not use `TextStyle(fontSize:...)` inline — always reference `AppText`.
- Do not hardcode UI strings — route through `app/lib/l10n/` for i18n.
- Do not skip reading `DESIGN.md` "to save time" — the tokens are not derivable
  from a screenshot alone.
