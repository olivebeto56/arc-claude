---
name: flutter-design-system
description: Translate Claude Design assets (HTML, CSS, JSX components, SVG logos) into Flutter widgets, ThemeData, TextStyles, and Color tokens for the AI Sport Monitor app. Use when generating any UI code in Flutter that should match the visual system defined in DESIGN.md and design/.
---

# Flutter Design System — Claude Design → Flutter translation

## When to invoke this skill

Use this skill whenever the task involves:

- Creating or modifying any Flutter screen (`lib/screens/*.dart`)
- Creating or modifying any reusable widget (`lib/widgets/*.dart`)
- Building or updating the theme (`lib/theme/*.dart`)
- Translating a specific HTML mockup from `design/pages/` or `design/screens/`
- Translating a JSX component from `design/components/` to a Flutter widget
- Adding/replacing logos, icons, or illustrations from `design/assets/`

Do NOT use this skill for non-UI code (BLE, sensor parsing, biomechanics
algorithms, firmware). Use the corresponding domain skill instead.

## Reading order — always

Before writing any Flutter UI code, read in this order:

1. `CLAUDE.md` (project root) — non-visual conventions (BLE, biomechanics, hardware).
2. `DESIGN.md` (project root) — the index pointing to the design system handoff.
3. `design/design_handoff_arc_app/CLAUDE.md` — implementation rules from Claude Design.
4. `design/design_handoff_arc_app/README.md` — **the source of truth for all visual tokens**.
5. The specific `screens-*.jsx` and `atoms.jsx` in `design/design_handoff_arc_app/design/` for the screen or component you are building.
6. Existing `app/lib/theme/app_colors.dart`, `app/lib/theme/app_text.dart`, `app/lib/theme/app_spacing.dart`, `app/lib/theme/app_radii.dart` to see which tokens already exist.

**The handoff wins on visual tokens.** If `CLAUDE.md` quotes a hex value that differs from the handoff, use the handoff value.

## Core translation rules

### Colors

- HTML hex (`#00E5FF`) → `Color(0xFF00E5FF)` defined as a static const in
  `AppColors`. Never inline.
- HTML rgba alpha → `.withOpacity(0.NN)` on the corresponding `AppColors` const.
- Linear gradients → `LinearGradient(colors: [AppColors.x, AppColors.y])` inside
  `BoxDecoration`.

### Typography

- Always use `AppText.<token>` from `lib/theme/app_text_styles.dart`.
- For numeric metric displays use `AppText.monoMetric` which carries
  `FontFeature.tabularFigures()` so digits don't shift width on update.
- Line height: HTML `line-height: 1.4` → Flutter `height: 1.4` in TextStyle.
- Letter spacing: HTML `letter-spacing: -0.02em` → Flutter `letterSpacing: -0.32`
  for an 18 px font (multiply em by font size in px).

### Layout

| HTML/CSS                             | Flutter                                                    |
|--------------------------------------|------------------------------------------------------------|
| `flex-direction: row` + `gap: N`     | `Row(children: [...])` with `SizedBox(width: N)` separators or `Wrap(spacing: N)` |
| `flex-direction: column` + `gap: N`  | `Column(...)` + `SizedBox(height: N)` separators           |
| `justify-content: space-between`     | `MainAxisAlignment.spaceBetween`                           |
| `align-items: center`                | `CrossAxisAlignment.center`                                |
| `padding: 16px 24px`                 | `Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16))` |
| `margin: 0 auto`                     | `Center(child: ...)`                                       |
| `position: absolute`                 | `Stack` + `Positioned`                                     |
| `display: grid; grid-template-columns: 1fr 1fr` | `GridView.count(crossAxisCount: 2)` or `Row` + `Expanded` |
| `overflow-y: scroll`                 | `SingleChildScrollView` or `ListView`                      |

### Borders & shadows

- `border-radius: 12px` → `BorderRadius.circular(12)`.
- `border: 1px solid #X` → `Border.all(color: AppColors.x, width: 1)`.
- `box-shadow: 0 4px 24px rgba(0, 229, 255, 0.08)` →
  ```dart
  BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 24,
    color: AppColors.accentPrimary.withOpacity(0.08),
  )
  ```

### Motion

- CSS `transition: all 200ms ease-out` → `AnimatedContainer(duration: Duration(milliseconds: 200), curve: Curves.easeOut)`.
- For value swaps (metric updating in real time) prefer `AnimatedSwitcher`.
- For route changes use the platform-native page route.

### Iconography

- Use `lucide_icons` package (matches Claude Design's default icon style).
- Sizes: 16 / 20 / 24 / 32. Default color: `AppColors.textSecondary`.
- Active/selected color: `AppColors.accentPrimary`.

### SVG / logos

- Use `flutter_svg` package.
- Place SVGs in `app/assets/logos/` and `app/assets/icons/` and register them
  in `pubspec.yaml` under `flutter.assets`.
- Never re-export SVGs as PNG unless required — keep vectors.

## JSX components → Flutter widgets

When you see a React component in `design/components/*.jsx`:

1. Identify its props — these become constructor parameters.
2. Identify its variants (e.g. `variant="primary" | "secondary"`) — these
   become an `enum` in Flutter.
3. Identify hover/focus/pressed states — translate to `MaterialState`-aware
   styling via `WidgetStateProperty.resolveWith` or `InkWell`.
4. Place the resulting Dart widget in `app/lib/widgets/` with a name in
   `PascalCase` matching the JSX component.

### Example translation

JSX (simplified):
```jsx
function MetricCard({ label, value, unit, status = "neutral" }) {
  return (
    <div className={`card card-${status}`}>
      <div className="label">{label}</div>
      <div className="value-row">
        <span className="value">{value}</span>
        <span className="unit">{unit}</span>
      </div>
    </div>
  );
}
```

Flutter equivalent:
```dart
// lib/widgets/metric_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum MetricStatus { neutral, success, warning, danger }

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final MetricStatus status;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.status = MetricStatus.neutral,
  });

  Color get _accent => switch (status) {
    MetricStatus.success => AppColors.success,
    MetricStatus.warning => AppColors.warning,
    MetricStatus.danger  => AppColors.danger,
    MetricStatus.neutral => AppColors.accentPrimary,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 24,
            color: _accent.withOpacity(0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppText.monoMetric.copyWith(color: _accent)),
              const SizedBox(width: 6),
              Text(unit, style: AppText.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
```

## Theme bootstrap (Material 3 OFF, custom dark)

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: false,                                  // handoff requirement
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,                // #0A0A0A
    fontFamily: 'Inter',                                  // loaded from assets/fonts/
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // No appBarTheme, no cardTheme: build atoms manually per handoff.
  );
}
```

Wrap your app root with `ProviderScope` (Riverpod):

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const ProviderScope(child: ARCApp()));

class ARCApp extends StatelessWidget {
  const ARCApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARC',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
```

## Pre-flight checklist

Before submitting any UI code, verify:

- [ ] No raw hex colors (`Color(0xFF...)`) outside `app_colors.dart`.
- [ ] No inline `TextStyle(fontSize: ...)` outside `app_text_styles.dart`.
- [ ] No magic spacing numbers — use the spacing tokens from `DESIGN.md`.
- [ ] All UI strings routed through `lib/l10n/` (or marked TODO if l10n not set up yet).
- [ ] Component stored in `lib/widgets/` (reusable) or `lib/screens/<screen>/widgets/` (screen-local).
- [ ] If translating a specific HTML/JSX file, the source path is referenced in a `// from: design/...` comment at the top of the Dart file.

## What NOT to do

- Do NOT use Material 3 widgets directly (ElevatedButton, AppBar, default
  Scaffold). The handoff requires `useMaterial3: false` and atoms built from
  `Container` + `GestureDetector` + custom styling.
- Do NOT replicate CSS pixel-by-pixel ignoring Flutter conventions, but DO aim
  for pixel-perfect visual match — the handoff specifies *high fidelity*.
- Do NOT introduce new color tokens without updating the handoff `tokens.js`
  reference and `DESIGN.md` first. If you really need one, ask.
- Do NOT add a new font family. Inter + JetBrains Mono only.
- Do NOT use `setState` for shared state — route through **Riverpod** providers.
- Do NOT skip the visual verification step at the end of each phase (Foundation,
  Atoms, Screens). The handoff requires a test/storybook screen between phases.
