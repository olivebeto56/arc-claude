# Running Biomechanics — Rangos Normativos y Referencias

## Cadencia (pasos por minuto)

| Rango | Clasificación | Notas |
|---|---|---|
| < 150 spm | Muy baja | Riesgo de sobrecarga articular, zancada muy larga |
| 150–159 spm | Baja | Común en corredores recreativos principiantes |
| 160–174 spm | Aceptable | Rango de corredores recreativos intermedios |
| 175–185 spm | Óptimo | Rango recomendado para reducir impacto y lesiones |
| 186–200 spm | Alto | Común en élite, aceptable si la técnica es buena |
| > 200 spm | Muy alta | Raro en distancias largas, puede indicar zancada muy corta |

**Referencia:** Heiderscheit et al. (2011) — Aumentar cadencia 5–10% reduce carga en rodilla hasta 20%.

**Nota de implementación:** Cadencia = 60000 / intervalo_promedio_entre_pasos. Cada pie da un paso;
dos pasos = una zancada. El intervalo se mide entre impactos consecutivos del MISMO pie.

---

## Simetría L/R (tiempo de contacto)

| Rango | Clasificación | Acción |
|---|---|---|
| < 43% | Asimetría significativa (carga derecha) | Recomendación activa |
| 43–46% | Asimetría leve (carga derecha) | Aviso leve |
| 46–54% | Simétrico — rango normal | Sin acción |
| 54–57% | Asimetría leve (carga izquierda) | Aviso leve |
| > 57% | Asimetría significativa (carga izquierda) | Recomendación activa |

**Referencia:** Zifchock et al. (2006) — >10% asymmetry is clinically significant.
Solo reportar si la asimetría persiste > 20 pasos consecutivos.

---

## Tiempo de contacto (Ground Contact Time)

| Rango | Clasificación |
|---|---|
| < 160 ms | Élite / muy rápido |
| 160–200 ms | Rápido |
| 200–250 ms | Moderado (recreativo típico) |
| 250–280 ms | Lento |
| > 280 ms | Muy lento / técnica deficiente |

**Referencia:** Morin et al. (2011) — Runners at 12 km/h have ~250 ms GCT. Elite marathoners ~185 ms.
Valores < 50ms o > 500ms son ruido del sensor — descartar.

---

## Ángulo de pisada (Foot Strike Angle)

Medido como el pitch del tobillo en el momento del impacto:

| Ángulo | Patrón | Descripción |
|---|---|---|
| > 20° | Heel strike severo | Alto impacto articular |
| 10–20° | Heel strike moderado | Común en recreativos |
| 0–10° | Midfoot strike | Más eficiente biomecánicamente |
| < 0° | Forefoot strike | Punta primero, velocistas |

**Referencia:** Lieberman et al. (2010), Nature. Los umbrales son orientativos — calibrar con datos reales.

---

## Variabilidad de zancada (CV de intervalos entre pasos)

| CV | Clasificación |
|---|---|
| < 3% | Muy regular |
| 3–6% | Normal |
| 6–8% | Ligeramente irregular |
| > 8% | Alta variabilidad — fatigado o irregular |

**Referencia:** Jordan et al. (2007) — Healthy runners show 3–5% CV in stride time.

---

## Carga de impacto (magnitud de pico de aceleración)

| Magnitud (m/s²) | Interpretación |
|---|---|
| 8–15 | Normal para running moderado |
| 15–25 | Alto |
| > 25 | Muy alto — riesgo de lesión |

Valores típicos en BNO085 en tobillo a 10–12 km/h: picos de 10–20 m/s². Calibrar siempre.

---

## Constantes de referencia para el código

```dart
// event_detector.dart
static const double _impactThreshold  = 12.0;  // m/s²
static const double _takeoffThreshold =  2.5;  // m/s²
static const int    _minStepMs        =  200;  // ms (300 spm max)
static const int    _maxContactMs     =  500;  // ms

// recommendation_engine.dart — cadencia
static const double _cadenceLowCritical = 150;
static const double _cadenceLow         = 160;
static const double _cadenceHigh        = 200;

// simetría
static const double _symmetryCriticalLow  = 43.0;
static const double _symmetryWarningLow   = 46.0;
static const double _symmetryWarningHigh  = 54.0;
static const double _symmetryCriticalHigh = 57.0;

// contacto, pisada, variabilidad
static const double _contactTimeHigh     = 280.0;
static const double _contactTimeLow      = 160.0;
static const double _strikeAngleCritical =  20.0;
static const double _strikeAngleWarning  =  10.0;
static const double _variabilityHigh     =   8.0;
```

---

## Protocolo de calibración para el prototipo

1. Correr 5 min a ritmo cómodo con los 2 nodos, exportar CSV
2. Contar 30s de pasos manualmente, comparar con detector
3. Ajustar `_impactThreshold` hasta que el conteo sea correcto
4. Verificar GCT: debe estar en 200–280 ms para running recreativo
5. Verificar simetría: en línea recta debe estar en 47–53%
6. Documentar umbrales calibrados en `analysis/calibration_notes.md`
