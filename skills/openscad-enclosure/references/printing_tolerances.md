# Tolerancias de Impresión 3D — PETG en Bambu Lab A1 Mini

## Principio general

Las tolerancias dependen de 3 factores: material, impresora, y orientación de impresión.
Para PETG en Bambu Lab A1 Mini con perfil estándar:

| Tipo de ajuste | Tolerancia total (por lado) | Holgura total (suma de ambos lados) |
|---|---|---|
| Piezas encajadas (libre) | 0.2–0.3 mm | 0.4–0.6 mm |
| Labio de tapa (ajustado) | 0.15–0.2 mm | 0.3–0.4 mm |
| Agujero para poste (press fit) | 0.05–0.1 mm | 0.1–0.2 mm |
| Cavidad de componente (holgura) | 0.3 mm | 0.6 mm |
| Conector USB-C / JST | 0.4 mm | 0.8 mm |
| Ranura para correa | 0.5 mm | 1.0 mm |

---

## Valores usados en carcasa_wearable.scad

```openscad
tol      = 0.3;   // holgura general (cavidades, labio tapa, postes en base)
                  // → cavidades de componentes: dim + tol en cada lado

// Postes guía: diámetro del agujero = post_d + tol*2
// Con post_d = 3.0mm y tol = 0.3mm → agujero = 3.6mm
// Resultado: encaje libre pero sin holgura excesiva
post_hole_d = post_d + tol * 2;

// Labio de tapa: clearance = tol (0.3mm por lado)
// El labio mide inner_l - tol*2 × inner_w - tol*2
// → 0.3mm de holgura por lado = encaje suave con ligera fricción
```

---

## Comportamiento del PETG en impresión

### Shrinkage (contracción)
- PETG encoge ~0.3–0.5% al enfriar
- Bambu Lab A1 Mini compensa esto automáticamente en el calibrado de la impresora
- **Para este proyecto:** no ajustar manualmente el shrinkage en OpenSCAD

### First layer squish
- La primera capa se aplana ligeramente (~0.1mm de deformación en Z)
- **Impacto:** el piso de la base puede ser ligeramente más grueso de lo modelado
- **Mitigación:** modelar `floor_t = 1.2mm` (3 capas × 0.4mm) da margen suficiente

### Stringing y puentes
- PETG hace stringing si la temperatura es alta o la retracción es insuficiente
- Bambu Studio con perfil PETG tiene retracción optimizada — no modificar
- **Puentes:** PETG soporta puentes de hasta ~40mm sin problema; la cavidad interior
  del nodo (~55mm) puede requerir una línea de puente en el slicer o reducir velocidad

### Tolerancias en agujeros circulares
- Los círculos impresos son ligeramente más pequeños que el modelo (efecto "arc compensation")
- Para agujeros de postes: el slicer de Bambu compensa automáticamente con "hole compensation"
- Si los postes no encajan: aumentar `tol` de 0.3 a 0.35mm

---

## Ajuste de tolerancias por situación

### Si el labio de la tapa no entra (demasiado apretado):
```openscad
// Cambiar en SKILL.md y en carcasa_wearable.scad:
lip_clearance = 0.25;  // era 0.15, subir en pasos de 0.05mm
```

### Si los postes no entran en los agujeros de la tapa:
```openscad
post_hole_d = post_d + tol * 2 + 0.1;  // añadir 0.1mm de margen extra
```

### Si hay holgura excesiva en los componentes (se mueven dentro):
```openscad
tol = 0.2;  // reducir de 0.3 a 0.2mm (imprime bien con PETG en A1 Mini)
```

### Si la ranura de correa está demasiado apretada:
```openscad
tol_strap = 0.7;  // era 0.5, subir si la correa no pasa
```

---

## Grosor de paredes — guía de robustez para wearable

| Espesor | Perímetros (@0.4mm) | Resistencia | Uso recomendado |
|---|---|---|---|
| 0.4 mm | 1 | Frágil | Solo geometría decorativa |
| 0.8 mm | 2 | Baja | Separadores internos ligeros |
| 1.2 mm | 3 | Media | Paredes interiores |
| 1.6 mm | 4 | **Alta** | **Paredes exteriores wearable** ← usamos esto |
| 2.0 mm | 5 | Muy alta | Zonas de impacto frecuente |

**Para el nodo wearable (tobillo/muñeca):** `wall = 1.6mm` es suficiente para running.
Aumentar a `2.0mm` si se usa para deportes de contacto.

---

## Relleno — impacto en resistencia y peso

| Relleno | Patrón | Peso relativo | Resistencia | Uso |
|---|---|---|---|---|
| 15% | Gyroid | Base | Media | Piezas decorativas |
| 20–25% | Gyroid | +10% | **Buena** | **← Este proyecto** |
| 40% | Gyroid | +25% | Alta | Zonas de estrés |
| 100% | Solid | +60% | Máxima | Postes, bisagras |

Para los postes de encaje, considerar `Modifier Mesh` en Bambu Studio para ponerlos a 100%.

---

## Resolución OpenSCAD → calidad STL

| `$fn` | Uso | Notas |
|---|---|---|
| 30 | Desarrollo rápido | Bordes escalonados visibles |
| 60 | Preview normal | Bueno para validar encaje |
| 120 | **Exportación STL** | Bordes suaves, archivo más pesado (~3–8 MB) |
| 200+ | Innecesario | Bambu A1 Mini no puede renderizar más fino que 0.05mm |

```openscad
// En la cabecera del archivo:
$fn = 60;  // cambiar a 120 solo para exportar STL final
```

---

## Protocolo de calibración del encaje tapa–base

1. **Primera impresión:** usar los valores base (`tol = 0.3`)
2. **Test de encaje:** intentar encajar tapa y base — debe entrar con ligera presión de dedos
3. **Si no entra:** aumentar `tol` en 0.05mm y reimprimir solo la tapa (más rápido)
4. **Si hay demasiada holgura:** reducir `tol` en 0.05mm
5. **Objetivo:** encaje que requiere presión con los pulgares pero no herramientas
6. **Documentar:** anotar el valor final de `tol` validado en `analysis/calibration_notes.md`

Valores típicos reportados en comunidad OpenSCAD + PETG + impresoras de cama caliente:
- Bambu Lab series: `tol = 0.25–0.30mm` suele funcionar sin ajuste
- Prusa MK4: `tol = 0.30–0.35mm`
- Ender 3 (sin calibración fina): `tol = 0.35–0.45mm`
