# AI Sport Monitor — Design System (índice)

> **Fuente de verdad del sistema visual:**
> [`design/design_handoff_arc_app/README.md`](design/design_handoff_arc_app/README.md)
>
> **Reglas de implementación para Claude Code:**
> [`design/design_handoff_arc_app/CLAUDE.md`](design/design_handoff_arc_app/CLAUDE.md)
>
> Este archivo (`DESIGN.md`) es solo un **índice y resumen ejecutivo**. Cuando
> Claude Code vaya a generar UI, debe leer **el handoff completo**, no este
> archivo. Aquí solo dejamos los punteros, las decisiones de proyecto que
> orquestan al handoff con el resto del código (BLE, biomecánica, firmware), y
> las divergencias acordadas (si las hay).

---

## 1. Fuentes de verdad y orden de lectura

Antes de escribir cualquier widget, archivo de tema, o pantalla, **lee en este orden**:

1. `CLAUDE.md` (raíz) — convenciones del proyecto, BLE, biomecánica, "what NOT to do".
2. `design/design_handoff_arc_app/CLAUDE.md` — instrucciones específicas del handoff: stack, orden de implementación de pantallas, reglas duras.
3. `design/design_handoff_arc_app/README.md` — overview, design tokens (colors, typography, spacing, radii, shadows), specs por pantalla.
4. `design/design_handoff_arc_app/design/Brand Guidelines.html` — sistema visual visual.
5. `design/design_handoff_arc_app/design/ARC App.html` — todas las pantallas en un canvas.
6. `design/design_handoff_arc_app/design/screens/*.jsx` — referencia de implementación por pantalla y componentes (`atoms.jsx`, `tokens.js`).

> Los archivos `.jsx` son **referencia, no código a portar**. Extrae estructura, jerarquía, copy y tokens — no copies JSX literal.

---

## 2. Decisiones de proyecto (qué manda cuando hay conflicto)

Estas decisiones cierran ambigüedades entre el `CLAUDE.md` raíz (escrito antes
del handoff) y el handoff. **Si encuentras conflicto, gana esta tabla.**

| Tema                      | Decisión                                                                |
|---------------------------|-------------------------------------------------------------------------|
| State management          | **Riverpod** (handoff manda — supera al "Provider" del CLAUDE.md raíz)  |
| Material 3                | **OFF** — theme 100 % custom (`useMaterial3: false`)                    |
| Tipografía                | **Inter (200–700) + JetBrains Mono (400, 500)** según tabla del handoff |
| Spacing grid              | **4 px** (handoff: `s1=4 ... s10=64`) — supera al "8 px" del CLAUDE.md  |
| Color de superficie       | **`#13131F`** (handoff) — supera al `#1A1A2E` del CLAUDE.md             |
| Mapa GPS                  | `flutter_map` o Mapbox (decidir al llegar a la pantalla con mapa)       |
| Idioma de la UI           | Español neutro MX, tuteo                                                |
| Plataforma de referencia  | iPhone 15 Pro (393 × 852) — el handoff mide pantallas en este viewport  |
| Status bar                | **Dibujada por nosotros** (no la nativa). Reservar 56 px arriba         |
| Persistencia              | `drift` o `isar` (decidir al llegar a Fase 4)                           |

---

## 3. Cómo se conecta el diseño con el resto del proyecto

```
firmware/                  ← Sprint 1 (Arduino + BNO085)
   ↓ BLE 14–16 byte packets
app/                       ← Sprint 2–4 (Flutter)
   ├── lib/services/       ← BLE, GPS (al final)
   ├── lib/models/         ← SensorData, Session, Band, Metric
   ├── lib/analysis/       ← biomechanics-analyzer (Sprint 3)
   ├── lib/theme/          ← TOKENS DEL HANDOFF — lo primero que se construye
   ├── lib/widgets/        ← atoms del handoff (ARCButton, ARCCard, Caption…)
   ├── lib/screens/        ← una pantalla por archivo, en el orden del handoff
   └── lib/providers/      ← Riverpod providers
design/                    ← input de diseño, no se modifica desde código
```

El **diseño manda en lo visual**; el **CLAUDE.md raíz manda en lo no visual**
(BLE, formato de paquete, biomecánica, hardware, sliding window 10 pasos).

---

## 4. Orden de implementación (resumen, ver handoff `CLAUDE.md` para detalle)

**Fase 1 — Foundation:** `theme/app_colors.dart`, `theme/app_text.dart`,
`theme/app_spacing.dart`, `theme/app_radii.dart`, fuentes Inter + JetBrains Mono
en `assets/fonts/`. Test screen visual antes de pasar de fase.

**Fase 2 — Atoms:** `ARCButton` (todas las variantes), `ARCCard`, `Caption`,
`Dot`, `BatteryReading`, `Sparkline`. Storybook screen al terminar.

**Fase 3 — Pantallas (en este orden):** Splash → Permisos → Scan → Home A →
Dashboard A + Recommendation overlay + Pause modal → Summary → History →
Settings → variantes Home B/C → variantes Dashboard B/C.

**Fase 4 — Lógica real:** BLE (`flutter_blue_plus`), GPS (`geolocator`),
mapa, persistencia, score real. **Solo después de Fase 3 con datos mock.**

---

## 5. Reglas duras (resumen, ver handoff para la lista completa)

- **No usar widgets de Material directamente** (ElevatedButton, AppBar, Scaffold default). Construir atoms desde `Container` + `GestureDetector`.
- **No inventar colores** fuera de `AppColors`. Si necesitas un matiz, derivarlo con `withOpacity` desde un token existente.
- **No inventar tamaños de fuente** fuera de la escala del handoff.
- **Tabular numbers obligatorios** en métricas, timers, GPS, batería: `fontFeatures: [FontFeature.tabularFigures()]`.
- **Captions siempre uppercase** + letter-spacing `0.14em` + color `text3`.
- **Validar pixel-perfect** después de cada pantalla comparando con el screenshot del HTML.
- **Datos mock** durante toda la Fase 3 — no integrar BLE/GPS hasta tener UI lista.

---

## 6. Inventario rápido de qué hay en `design/design_handoff_arc_app/`

```
design/design_handoff_arc_app/
├── README.md                  ← overview + tokens + specs de pantallas (LEER)
├── CLAUDE.md                  ← instrucciones de implementación (LEER)
└── design/
    ├── ARC App.html           ← canvas con todas las pantallas
    ├── Brand Guidelines.html  ← guidelines de marca
    ├── design-canvas.jsx      ← canvas global de referencia (no portar)
    └── screens/
        ├── tokens.js               ← TOKENS de colores, spacing, fonts
        ├── atoms.jsx               ← ARCButton, ARCCard, Icon, Sparkline, …
        ├── ios-frame.jsx           ← wrapper iPhone 15 Pro 393×852 (no portar)
        ├── map.jsx                 ← ARCMap component
        ├── screens-onboarding.jsx  ← Splash, Permisos, Scan, Home A/B/C
        ├── screens-live.jsx        ← Dashboard A/B/C, Recommendation, Pause
        └── screens-post.jsx        ← Summary, History, Settings
```

---

## 7. Cuándo cargar el skill `flutter-design-system`

Claude Code cargará automáticamente el skill cuando detecte que el trabajo es UI
(crear pantalla, crear widget, crear theme, traducir HTML/JSX). El skill aplica
las reglas de traducción HTML/CSS/JSX → Flutter usando los tokens del handoff
como fuente única.
