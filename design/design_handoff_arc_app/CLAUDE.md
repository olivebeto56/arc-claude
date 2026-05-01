# CLAUDE.md — Instrucciones para Claude Code

Estás implementando la app **ARC — Sport Monitor** en Flutter. Este archivo es tu guía de trabajo.

## Lee primero

1. **`README.md`** — overview completo del proyecto, fidelity, behavior
2. **`design/Brand Guidelines.html`** — sistema visual (ábrelo en browser)
3. **`design/ARC App.html`** — todas las pantallas en un canvas (ábrelo en browser, pan/zoom)

Los archivos `design/screens/*.jsx` son **referencia de implementación, no código a portar**. Léelos para extraer:
- Valores exactos de tokens (`tokens.js`)
- Estructura de cada pantalla (`screens-*.jsx`)
- Comportamiento de componentes (`atoms.jsx`)

---

## Stack y convenciones

- **Flutter 3.x**
- **Material 3 OFF** — el diseño es custom dark. `useMaterial3: false` o un theme custom completo
- **State management**: Riverpod (a menos que el equipo diga otra cosa)
- **Estructura**:
  ```
  lib/
    main.dart
    theme/                 ← colors, text styles, spacing, radii
    widgets/               ← atoms reusables (ARCButton, ARCCard, etc.)
    screens/               ← una pantalla por archivo
    providers/             ← state (riverpod providers)
    models/                ← Session, Band, Metric, etc.
    services/              ← BLE, GPS, persistence (mocks al inicio)
    utils/
  ```

---

## Orden de implementación (NO desviarse)

### Fase 1 — Foundation
1. `theme/app_colors.dart` con todos los hex del README
2. `theme/app_text.dart` con todos los text styles del README
3. `theme/app_spacing.dart` y `theme/app_radii.dart`
4. Carga de fuentes (Inter + JetBrains Mono) — descargar TTFs de Google Fonts a `assets/fonts/`
5. `MaterialApp` con `darkTheme` custom y `themeMode: ThemeMode.dark`
6. **Stop. Verifica visualmente con un test screen** que muestre samples de cada text style sobre `bg`.

### Fase 2 — Atoms
1. `ARCButton` (todas las variantes)
2. `ARCCard`
3. `Caption`, `Dot`, `BatteryReading`
4. `Sparkline` (CustomPainter)
5. Iconos como `CustomPainter` o SVG con `flutter_svg`
6. **Stop. Crea un Storybook screen con todos los atoms.**

### Fase 3 — Pantallas (en este orden)
1. **Splash** (más simple, valida fuentes y logo)
2. **Permisos**
3. **Scan & Connect**
4. **Home A** (la más densa — si esto sale, el resto sale)
5. **Dashboard A** + **Recommendation overlay** + **Pause modal**
6. **Summary** (chart + score circle son los retos)
7. **History**
8. **Settings**
9. **Home B y C** (variaciones, el equipo elegirá una)
10. **Dashboard B y C** (variaciones)

### Fase 4 — Lógica
**Solo después de tener todas las pantallas con datos mock funcionando:**
- BLE con `flutter_blue_plus`
- GPS con `geolocator`
- Mapa con `flutter_map` o Mapbox
- Persistencia con `drift` o `isar`
- Algoritmo de score (probablemente requiere consulta con el equipo de producto)

---

## Reglas duras

- **NO uses Material widgets directamente** (ElevatedButton, AppBar, Scaffold default). Construye los atoms desde `Container` + `GestureDetector` + custom styling. La excepción: `Scaffold` solo como root con `backgroundColor: AppColors.bg` y sin appBar default.
- **NO inventes colores.** Si necesitas un color que no está en `AppColors`, pregunta antes.
- **NO inventes tamaños de fuente.** Usa solo los del scale en el README.
- **NO uses gradients excepto los explícitos** (radial cyan en Hero score y Pause modal). El resto es flat.
- **Tabular numbers siempre** en métricas, timers, GPS, batería. `fontFeatures: [FontFeature.tabularFigures()]`.
- **Captions siempre uppercase** con letter-spacing 0.14em.
- **Validar pixel-perfect**: después de cada pantalla, comparar side-by-side con el screenshot del HTML. Si no coincide, ajustar.

---

## Datos mock

Mientras no haya BLE/GPS reales, todos los providers retornan datos hardcodeados de `mock/`:

```dart
// mock/mock_data.dart
class Mock {
  static const userName = 'Alberto';
  static const totalSessions = 47;
  static const totalKm = 218.0;
  static const streakDays = 12;
  // ... ver el HTML para todos los valores exactos
}
```

Las métricas en vivo: simular con un `Timer.periodic` que actualice valores con pequeñas variaciones random alrededor de los valores del mockup (cadencia 175-182, etc).

---

## Cuando termines una pantalla

1. Compara con el screenshot del HTML (ábrelo en `design/ARC App.html`)
2. Verifica: colores exactos, font weights, spacing, line-heights, letter-spacing
3. Test en un emulador iPhone 15 Pro (393×852)
4. Captura screenshot Flutter y nómbralo `flutter_screenshots/<screen-name>.png`

---

## Cosas a NO hacer (errores comunes)

- ❌ Usar `Theme.of(context).primaryColor` — usa `AppColors.accent` directo
- ❌ `TextStyle(fontWeight: FontWeight.w400)` sin `fontFamily` — siempre incluir family
- ❌ `BoxShadow` con blur enorme — los glows del diseño son sutiles, blurRadius máximo 32
- ❌ `Padding(padding: EdgeInsets.all(16))` arbitrario — usa `S.s4`
- ❌ Crear un nuevo widget para cada cosa — reusa los atoms

---

## Cuando no estés seguro

Pregunta. El diseño es opinionado. Si una decisión no está documentada, **no improvises** — el equipo prefiere explicar 2 minutos a refactorizar 2 horas.
