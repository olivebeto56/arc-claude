# Handoff: ARC — Sport Monitor App

## Overview

**ARC** es una app móvil de monitoreo deportivo (running, fitness) que se conecta a dos bandas de sensores (SportBand-L y SportBand-R) que el atleta lleva en cada tobillo. Las bandas miden cadencia, simetría L/R, ground contact time (GCT), impacto, ángulo de strike y variabilidad — métricas que la app muestra **en tiempo real** durante una sesión y consolida en un score técnico (0-100) post-sesión.

Componentes principales:
- **Onboarding**: splash → permisos (Bluetooth + ubicación) → escaneo y emparejamiento de las dos bandas
- **Home**: estado de bandas, promedios históricos, recomendación contextual, CTA para iniciar sesión
- **Sesión en vivo**: timer, distancia, ritmo, métricas técnicas, mapa GPS con la ruta, recomendaciones contextuales cuando una métrica sale de rango
- **Post-sesión**: resumen con score, mapa de la ruta, charts de cadencia y simetría, recomendaciones para la próxima sesión
- **Auxiliares**: historial de sesiones con filtros, ajustes (bandas, calibración, datos personales, unidades)

El stack objetivo es **Flutter** (per la conversación con el usuario). El handoff documenta la UI y comportamiento; la integración real con BLE, GPS y el algoritmo de score son responsabilidad del desarrollador.

---

## About the Design Files

Los archivos HTML/JSX en este paquete son **referencias de diseño**, no código de producción para copiar. Son prototipos en React que muestran apariencia, jerarquía visual, copy y comportamiento previsto.

**La tarea es recrear estos diseños en Flutter** siguiendo los patrones y librerías del proyecto Flutter (Material 3 / Cupertino / theme custom según prefiera el equipo). No portear el HTML directamente.

Si el proyecto Flutter aún no existe, recomendamos:
- Flutter 3.x con Material 3 desactivado (el diseño es custom, no Material)
- Theme custom basado en los tokens de este handoff
- State management a elección del equipo (Riverpod recomendado por simplicidad)
- `flutter_blue_plus` para BLE, `geolocator` + `flutter_map` para GPS
- Datos mock al inicio — no implementar lógica real de sensores hasta tener la UI lista

---

## Fidelity

**High-fidelity (hifi)**. Los mockups muestran:
- Colores finales con hex exacto
- Tipografía: Inter (sans) y JetBrains Mono (mono) — con pesos y letter-spacing definidos
- Spacing y radii sobre grid de 4px
- Estados de componentes (active, disabled, conectado/buscando, en rango/fuera de rango)
- Copy en español, listo para usar

El desarrollador debe recrearlos pixel-perfect en Flutter. Si una decisión visual no está documentada, priorizar lo que se ve en el screenshot del HTML.

---

## Tone & Voice

- **Idioma**: español neutro (México). Tuteo (`tu`, `tus`).
- **Tono**: directo, deportivo, técnico pero claro. No motivacional cursi (evitar "¡vamos!", "tú puedes", emojis).
- **Mayúsculas en CTAs**: botones primarios usan UPPERCASE con letter-spacing 0.06em (`INICIAR SESIÓN`, `CONTINUAR`, `TERMINAR`).
- **Captions / labels**: UPPERCASE 10px con letter-spacing 0.14em (`PASO 1 DE 2`, `CADENCIA`, `SCORE TÉCNICO`).
- **Recomendaciones**: instructivas, segunda persona. Ej: "Tu pierna izquierda carga 3% más. Mantén simetría 50/50 hoy."
- **Métricas con unidades**: número grande (tabular-nums) + unidad pequeña en gris (`178` `spm`). Nunca pegadas.

---

## Design Tokens

Todos los valores están en `tokens.js`. Reproducir como un `AppTheme` en Flutter.

### Colors

```dart
// Backgrounds
static const bg         = Color(0xFF0A0A0A);  // App background
static const surface    = Color(0xFF13131F);  // Cards, modals
static const surfaceHi  = Color(0xFF0F0F1A);  // Nested cards
static const surfaceMap = Color(0xFF0F1A1F);  // Map background

// Borders
static const border    = Color(0xFF2B2D3F);   // Subtle
static const borderHi  = Color(0xFF3A3D52);   // More visible

// Text
static const text  = Color(0xFFFFFFFF);       // Primary
static const text2 = Color(0xFF9AA0AB);       // Secondary
static const text3 = Color(0xFF7A7E88);       // Tertiary / captions
static const text4 = Color(0xFF52555E);       // Disabled

// Accent — cyan, the signature color
static const accent     = Color(0xFF00E5FF);
static const accentDim  = Color(0x2600E5FF);  // 15% opacity — backgrounds, glows
static const accentDim2 = Color(0x5400E5FF);  // 33% opacity — stronger glow
static const accentGlow = Color(0x8000E5FF);  // 50% opacity — shadows

// Semantic status
static const ok       = Color(0xFF3DDC84);    // En rango, conectado
static const okDim    = Color(0x2E3DDC84);    // Background variant
static const warn     = Color(0xFFFFB020);    // Atención, fuera de rango leve
static const warnDim  = Color(0x2EFFB020);
static const crit     = Color(0xFFFF4D4F);    // Crítico, terminar, errores
static const critDim  = Color(0x26FF4D4F);

// Brand alt accent (rara vez usado, para highlights especiales)
static const lime = Color(0xFFD6FF00);
```

### Typography

Cargar las fuentes del paquete (`pubspec.yaml`):

- **Inter** (200, 300, 400, 500, 600, 700) — sans-serif principal
- **JetBrains Mono** (400, 500) — para readouts numéricos, MAC addresses, GPS coords

```dart
class AppText {
  static const sans = 'Inter';
  static const mono = 'JetBrains Mono';

  // Activar variant features
  static const TextStyle base = TextStyle(
    fontFamily: sans,
    fontFeatures: [FontFeature.enable('ss01'), FontFeature.tabularFigures()],
  );
}
```

**Type scale** (todos sobre `base`):

| Nombre              | Size | Weight | Letter-spacing | Uso                              |
|---------------------|------|--------|----------------|----------------------------------|
| `display`           | 88   | 300    | -0.04em        | Hero score (Home B)              |
| `display-2`         | 72   | 300    | -0.05em        | Timer en Dashboard B/C           |
| `display-3`         | 64   | 300    | -0.04em        | Timer en Dashboard A, Pause      |
| `display-4`         | 56   | 200-300| -0.04em        | Editorial home, splash logo      |
| `headline`          | 38   | 200    | -0.03em        | "Hola, Alberto" en Home C        |
| `title`             | 28   | 500    | -0.02em        | Greeting en Home A               |
| `title-2`           | 26   | 500    | -0.02em        | Headers de pantalla              |
| `metric-lg`         | 26   | 500    | -0.02em        | Métricas grandes en cards        |
| `metric`            | 22   | 500    | -0.01em        | Stats inline                     |
| `metric-sm`         | 20   | 500    | -0.01em        | Métricas pequeñas                |
| `body-lg`           | 18   | 300-400| -0.01em        | Recomendaciones editoriales      |
| `body`              | 14.5 | 400    | normal         | Body por defecto                 |
| `body-sm`           | 13   | 400    | normal         | Body secundario                  |
| `body-xs`           | 12   | 400    | normal         | Metadata                         |
| `caption`           | 10   | 500    | 0.14em UPPER   | Eyebrows, labels                 |
| `caption-xs`        | 9    | 500    | 0.14em UPPER   | Captions chicas                  |
| `mono-readout`      | 11   | 500    | normal         | RSSI, GPS, MAC address           |
| `mono-tiny`         | 9-10 | 500    | normal         | Versiones, build numbers         |
| `cta`               | 16   | 600    | 0.02em         | Primary button text              |
| `cta-strong`        | 16   | 600    | 0.06-0.08em    | Hero CTAs (uppercase)            |

**Reglas:**
- Números grandes y readouts: `fontFeatures: [FontFeature.tabularFigures()]` siempre
- Captions: SIEMPRE uppercase + letter-spacing 0.14em + color `text3` (gris medio)
- Body normal usa color `text` o `text2` según jerarquía

### Spacing (4px grid)

```dart
class S {
  static const s1 = 4.0;   static const s2 = 8.0;
  static const s3 = 12.0;  static const s4 = 16.0;
  static const s5 = 20.0;  static const s6 = 24.0;
  static const s7 = 32.0;  static const s8 = 40.0;
  static const s9 = 48.0;  static const s10 = 64.0;
}
```

Padding estándar de pantalla: `20-24px` lateral. Cards internas: `14-16px`.

### Radii

```dart
class R {
  static const sm = 8.0;    // Small chips, badges
  static const md = 12.0;   // Inner cards, segmented buttons
  static const lg = 14.0;   // Standard cards
  static const xl = 18.0;   // Hero cards (score circle, summary)
  static const button = 14.0;
  static const full = 999.0;
}
```

### Shadows / glows

El cyan se proyecta como glow en CTAs primarios y elementos destacados:

```dart
// CTA primario
boxShadow: [BoxShadow(color: accentDim2, blurRadius: 32, spreadRadius: 0)]

// Card destacada (recomendación)
boxShadow: [BoxShadow(color: accentDim, blurRadius: 0, spreadRadius: 3)]

// Score circle stroke
// Aplicar como filter blur al SVG/CustomPaint, no como BoxShadow
```

---

## Screens

Mide cada pantalla en **iPhone 15 Pro (393 × 852)** sin status bar nativo (lo dibujamos nosotros). Status bar superior reservada: 56px.

### 0. Splash · `screens-onboarding.jsx → ScreenSplash`

- Background: `bg`
- Centered: logo ARC (símbolo arco + wordmark "RC" Inter ExtraLight, height 56px) + tagline "TU TÉCNICA, EN TIEMPO REAL" (caption style)
- Bottom 100px: barra de loading animada (32px wide, 1px height, dot que se desplaza izq → der en 1.4s ease-in-out infinito)
- Bottom 50px: versión mono "v1.0.0 · build 247"

Se muestra ~1.5s al abrir la app o mientras se inicializa BLE.

### 1. Permisos · `ScreenPermisos`

- Caption "PASO 1 DE 2"
- H1 "Necesitamos algunos permisos" (title-2)
- Body explicativo (body, color text2)
- Lista vertical de 2 cards (gap 10px):
  - **Bluetooth** — icono BT en cuadrado 40×40 con border, título 15px medium, descripción body-xs text2, badge de estado (CONCEDIDO/PENDIENTE/DENEGADO) en caption — verde/amarillo/rojo
  - **Ubicación** — mismo layout
- Link "¿Por qué los necesitamos?" (text-decoration underline color text2)
- Footer con CTA primario "CONTINUAR" full-width

Estado: si los 2 están concedidos, el botón está habilitado; si no, `disabled` (opacity 0.4, sin pointerEvents).

### 2. Scan & Connect · `ScreenScan`

- Caption "PASO 2 DE 2"
- H1 "Conecta tus bandas"
- Body de instrucciones
- Lista de 2 NodeCards:
  - **L** y **R** — círculo 36×36 con la letra, nombre "SportBand-L" + MAC en mono
  - Estado a la derecha: dot verde glow (Conectado) / spinner (Buscando…) / dot gris (Esperando)
  - Footer interno: RSSI · batería · estado label
  - Border: si conectado, `accent` con glow `accentDim` 3px
- Card colapsada "3 dispositivos descartados" (surfaceHi)
- 2 CTAs: "REESCANEAR" (secondary) + "CONTINUAR" (primary, disabled hasta que ambas L+R estén conectadas)

Comportamiento:
- Al entrar, escaneo automático
- Las 2 cards aparecen como "Buscando…", actualizan a "Conectado" cuando se emparejan
- El botón "CONTINUAR" se habilita cuando ambas están conectadas

### 3. Home · 3 variaciones

**Toggle visualmente las 3 variaciones con el dev y elige una. Recomendada: A.**

#### Home A — Atlético (default)
Top bar: logo izq, settings icono der.
Greeting: caption "Lunes · 16:42" + H1 "Hola, Alberto"
Stats line: 47 sesiones / 218 km totales / 12 racha días — separadas por borders verticales
Card "Promedios — últimas 10": Cadencia / Simetría / GCT / Score técnico (grid 2x2)
**Card recomendación destacada**: borde cyan + glow, caption "RECOMENDACIÓN · HISTÓRICO" en cyan + texto principal
Card bandas: 2 mini-cards L y R con batería y dot "Listo para correr"
Segmented: Libre / Tiempo / Distancia
Footer: HISTORIAL (secondary 100px) + INICIAR SESIÓN (primary full + glow cyan)

#### Home B — Hero score
Mismo top bar. Greeting más compacto.
**Hero score**: card grande con radial gradient cyan, número 88px en cyan + sparkline debajo + "+4 esta semana"
Quick metrics row: 3 mini cards
Recomendación más sutil (borderLeft cyan 3px)
Bandas en row compacta
Same footer

#### Home C — Editorial
Editorial heading "Hola, Alberto." (38px ExtraLight con itálica en el nombre)
"Tu última sesión": número 56px cyan con sparkline al lado
Recomendación entre lines horizontales (no card)
Métricas como tabla minimalista (linea por linea)
Bandas como single line con dot
CTA "INICIAR SESIÓN →" full + glow

### 4. Sesión en vivo · 3 variaciones

#### Dashboard A — Mapa prominente (default)
Top bar status:
- Izq: dot verde glow + "Conectado"
- Centro: "GPS ±4m" en mono
- Der: "L 84%" + "R 89%" en mono

Hero timer: `28:43` en 56px, debajo distancia + ritmo en row
Mapa 220px height con border radius 14, glow cyan en la ruta, current position con halo pulsing
Toggle MAPA/CARDS en esquina sup-der del mapa (pill flotante con backdrop blur)
Grid 3x2 de 6 métricas pequeñas con border-left de color (cyan ok, warn, crit)
Footer: PAUSA (ghost) + TERMINAR (destructive)

#### Dashboard B — Cards prominent
Sin mapa. Big timer 72px. Big metric cards 2x3.

#### Dashboard C — Hero metric
Foco en una sola métrica focal grande (Cadencia 96px cyan con glow), rest abajo en row pequeña.

### 5. Recommendation overlay · `ScreenRecommendation`
Sobre Dashboard A, una card flotante absolutamente posicionada bottom 110px:
- Border cyan + shadow + backdrop blur
- Caption "SIMETRÍA · FUERA DE RANGO" en cyan
- Texto principal en body-lg
- Footer en mono: "Actual 48/52 → Óptimo 50/50"
- Botón × en esquina sup-der

Aparece automáticamente cuando una métrica sale de rango por > 30s. Auto-dismiss 8s o tap close.

### 6. Pause modal · `ScreenPause`
Overlay sobre Dashboard A:
- `rgba(10,10,10,0.85) + backdrop blur 12px`
- Card centrada con: caption "● SESIÓN PAUSADA" en warn, timer grande, snapshot grid 3 métricas, REANUDAR (primary) + TERMINAR SESIÓN (destructive)

### 7. Summary · `ScreenSummary`
Top bar: back arrow + share icon
Header: caption fecha + H1 "Sesión completada" + meta inline (32:18 · 5.78 km · 5:35/km)

**Score circle**: ring 130×130, círculo SVG con stroke cyan (drop-shadow glow) + arco proporcional al score, número 44px cyan al centro con `/100` debajo. Texto al lado describe.

Mapa de la ruta 180px con legend de pace gradient (cyan → green → yellow)
Cadence chart: SVG line con banda óptima 175-185 spm como rect verde semi-transparente
Symmetry bar: barra horizontal dividida 49/51 — fill cyan vs cyan-25
Trio cards GCT / Impacto / Variabilidad
Próxima sesión: 3 recomendaciones con badge numerado cyan-dim
Footer: COMPARTIR + LISTO

### 8. History · `ScreenHistory`
Top bar: back + título "Historial" + search icon
Segmented Semana/Mes/Todo
Aggregate stats line: 12 sesiones / 52.4 km / 7:42 h / 78 score avg
Lista de cards de sesión (cada una):
- Mini map 48×48 (route preview)
- Fecha + tipo (Libre / Tiempo / Distancia)
- Duración + km + sparkline cadencia
- Score grande cyan a la derecha (22px)

### 9. Settings · `ScreenSettings`
Sections agrupadas:
- **Bandas**: SportBand-L y -R con batería y chevron
- **Calibración**: 3 sliders (Impact threshold, Takeoff threshold, Min step duration) con valor mono cyan + "Restaurar defaults"
- **Personal**: Altura / Peso / Longitud zancada (chevron rows)
- **Unidades**: Sistema (Métrico) / Idioma (Español)
- **Datos**: Exportar CSV / Borrar historial (en rojo)
- **Acerca de**: Versión / Política de privacidad

Cada section: caption uppercase + card con rows separadas por borders.

---

## Componentes reutilizables

| Componente          | Descripción |
|---------------------|-------------|
| `ARCButton`         | Variantes: primary (cyan/dark), secondary (transparent/border), ghost, destructive (rojo outline), danger (rojo fill). Sizes: lg / md / sm. |
| `ARCCard`           | Surface + border 1px + radius 14px. Optional `accent` prop para borderLeft cyan. |
| `Caption`           | Eyebrow uppercase 10px |
| `Dot`               | Status dot con glow opcional |
| `Sparkline`         | SVG polyline normalizada con dot final |
| `BatteryReading`    | Icono batería SVG con color según pct + label |
| `ARCTopBar`         | 44px alto, 3 slots flex (left, center, right) |
| `Segmented`         | 3 opciones, pill activo en background bg, inactive transparente |
| `ARCMap`            | SVG dark map con grid, parques verdes semi, río azul, ruta cyan glowy, marcador current con halo |
| `ARCMapMini`        | Versión 48×48 para list items |
| `ARCLogo`           | Símbolo + wordmark "RC" Inter ExtraLight |

Todos los iconos en `atoms.jsx → Icon = {...}` son SVG inline 24×24, stroke 1.5, line-cap round. **Reproducir en Flutter usando `flutter_svg`** o `CustomPainter`. La lista mínima: settings, bluetooth, location, check, chevR, chevL, pause, play, stop, share, search, trend, filter, battery (custom), arcSym (logo).

---

## Interactions & Behavior

### Onboarding flow
- Splash → automático 1.5s → Permisos
- Permisos: tap en cada permission row dispara native prompt iOS/Android
- Cuando los 2 están granted: enable CONTINUAR → tap → Scan
- Scan: auto-start scan al montar; cuando ambas están connected: enable CONTINUAR → tap → Home

### Home → Sesión
- Tap "INICIAR SESIÓN":
  - Si bandas no conectadas → toast / modal de error
  - Si OK → fade transition a Dashboard, start timer, start GPS recording
- Segmented (Libre/Tiempo/Distancia): si Tiempo o Distancia, muestra modal de configuración de objetivo

### Sesión live
- Updates de métricas: 1Hz (cada segundo) — no más rápido
- Mapa: actualizar position cada 1s con animation suave (lerp)
- Toggle Mapa/Cards: instant, sin transition
- Métrica fuera de rango por >30s → mostrar Recommendation overlay (slide up animation 250ms ease-out, auto-dismiss 8s)
- Tap PAUSA → Pause modal (fade in 180ms), GPS y timer pausan
- En pause: REANUDAR (close modal, resume) o TERMINAR (confirmation → Summary)

### Summary
- Aparece al finalizar sesión
- Datos persistidos a local DB (SQLite/Isar)
- Share → native share sheet con imagen renderizada del summary

### History
- Pull to refresh sync
- Tap card → abre Summary read-only de esa sesión
- Search → filtra por fecha/tipo

### Settings sliders
- Drag con haptic feedback ligero cada step
- "Restaurar defaults" → confirmation dialog

---

## State Management

Mínimo necesario (con Riverpod):

- `bleProvider`: estado de las dos bandas (disconnected / scanning / connected), batería, RSSI, MAC
- `permissionsProvider`: status de Bluetooth y Location
- `liveSessionProvider`: timer, distancia, ritmo, métricas instant + history (array de samples), GPS waypoints, route polyline, paused/active
- `historyProvider`: lista de sesiones pasadas, filtros activos
- `settingsProvider`: tokens de calibración, datos personales, unidades, idioma — persistido a SharedPreferences
- `recommendationProvider`: queue de recomendaciones a mostrar (basado en reglas sobre métricas live)

---

## Assets

**Necesarios en `pubspec.yaml`:**

```yaml
fonts:
  - family: Inter
    fonts:
      - asset: assets/fonts/Inter-ExtraLight.ttf
        weight: 200
      - asset: assets/fonts/Inter-Light.ttf
        weight: 300
      - asset: assets/fonts/Inter-Regular.ttf
        weight: 400
      - asset: assets/fonts/Inter-Medium.ttf
        weight: 500
      - asset: assets/fonts/Inter-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Inter-Bold.ttf
        weight: 700
  - family: JetBrainsMono
    fonts:
      - asset: assets/fonts/JetBrainsMono-Regular.ttf
        weight: 400
      - asset: assets/fonts/JetBrainsMono-Medium.ttf
        weight: 500
```

Fuentes en Google Fonts (descargar TTF):
- https://fonts.google.com/specimen/Inter
- https://fonts.google.com/specimen/JetBrains+Mono

**Logo**: el símbolo arco + dot está como SVG inline en `atoms.jsx → Icon.arcSym`. Reproducir como `CustomPainter` o exportar a SVG y usar `flutter_svg`.

**Mapa**: en producción usar Mapbox o Maps SDK con dark style. El mockup usa SVG estático estilizado — referencia visual del look final, no de implementación.

**Iconos**: todos los SVG paths están en `atoms.jsx → Icon`. Reproducir 1:1 en Flutter con `Icon` o `flutter_svg`.

---

## Files in this Bundle

```
design_handoff_arc_app/
├── README.md                         ← este archivo
├── design/
│   ├── ARC App.html                  ← canvas con todas las pantallas
│   ├── Brand Guidelines.html         ← guidelines de marca
│   └── screens/
│       ├── tokens.js                 ← TOKENS de colores, spacing, fonts
│       ├── atoms.jsx                 ← ARCButton, Card, Icon, Sparkline, etc.
│       ├── map.jsx                   ← ARCMap component
│       ├── screens-onboarding.jsx    ← Splash, Permisos, Scan, Home A/B/C
│       ├── screens-live.jsx          ← Dashboard A/B/C, Recommendation, Pause
│       └── screens-post.jsx          ← Summary, History, Settings
└── screenshots/                       ← (si se incluyen)
```

**Cómo navegar**: abrir `ARC App.html` en un navegador. Cada pantalla está en un artboard con label. Pan/zoom con scroll/trackpad. Tap el ⛶ en hover de cualquier artboard para verla fullscreen.

---

## Recommended implementation order

1. **`theme/`**: AppColors, AppText, AppSpacing, AppRadii. Probar con un Storybook simple antes de pantallas reales.
2. **Atoms**: `ARCButton`, `Caption`, `ARCCard`, `Dot`, `BatteryReading`. Test cada uno.
3. **Onboarding flow** (Splash → Permisos → Scan) — usa estos para validar tipografía y tokens.
4. **Home A** — la pantalla más densa. Si esto sale bien, el resto fluye.
5. **Dashboard A** + Recommendation + Pause — todo el flow live.
6. **Summary** — chart custom y score circle son los dos challenges visuales.
7. **History + Settings** — auxiliares.

**No implementar lógica real de BLE/GPS/score hasta tener toda la UI con datos mock.**

---

## Questions to resolve with the team

- ¿Material 3 default off (recomendado)?
- ¿State management: Riverpod / BLoC / Provider?
- ¿Map provider: Mapbox / Google Maps / OpenStreetMap (flutter_map)?
- ¿Persistencia: SQLite (drift) / Isar / Hive?
- ¿Share image rendering: `screenshot` package o custom?
