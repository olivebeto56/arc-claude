---
name: openscad-enclosure
description: >
  Use this skill whenever the user wants to create, modify, or improve parametric OpenSCAD enclosures
  for the wearable sport monitor nodes. Trigger on ANY mention of: carcasa, enclosure, tapa, lid,
  base, cuerpo, PETG, impresión 3D, Bambu, OpenSCAD, .scad, carcasa_wearable, poste, snap-fit,
  USB-C hole, strap slots, tolerancia, separador, cavidad, canal de cable, or any physical housing
  for the XIAO + BNO085 + battery. Also trigger for: "cambiar dimensiones", "agregar abertura",
  "rediseñar carcasa", "preparar para STL", "exportar para impresora", or "ajustar tolerancias".
---

# OpenSCAD Enclosure Skill — Wearable Sport Monitor

## Contexto del proyecto

Este skill genera y modifica **carcasas paramétricas en OpenSCAD** para los nodos del wearable
sport monitor. Cada nodo contiene:

| Componente | Dimensiones (L × W × H) | Posición en carcasa |
|---|---|---|
| Seeed XIAO nRF52840 Sense | 21.0 × 17.5 × 5.0 mm | Capa superior, extremo +X |
| Adafruit BNO085 breakout #4754 | 25.6 × 22.7 × 3.5 mm | Capa superior, extremo -X |
| LiPo 3.7V 602030 (400mAh) | 30.0 × 20.0 × 6.0 mm | Capa inferior, centrada |

**Archivo de referencia existente:** `carcasa_wearable.scad` — ya implementado y funcional.
Siempre leerlo antes de modificar; contiene el layout de 2 capas validado con las dimensiones reales.

---

## Principios de diseño — NO negociables

1. **Paramétrico desde el día 1:** todas las dimensiones derivadas de variables. Nunca hardcodear
   cotas en módulos. El objetivo: cambiar `tol` o `wall` y que todo el diseño se adapte solo.

2. **Sin soportes de impresión:** toda geometría diseñada para imprimirse sin soportes.
   - Base: boca arriba, piso plano sobre la cama
   - Tapa: invertida (techo sobre la cama), con labio y postes colgando hacia arriba
   - Ángulos de voladizo: siempre ≤ 45° o usar chaflán/redondeo

3. **PETG en Bambu Lab A1 Mini:** material principal. Tolerancias y perfiles optimizados para este
   setup. Ver `references/printing_tolerances.md` para valores exactos.

4. **Acceso USB-C sin desmontar:** abertura lateral alineada con el conector del XIAO.
   Dimensiones del conector USB-C: 9.0 mm ancho × 3.5 mm alto (en el XIAO).

5. **Ranuras para correa elástica de 25mm:** 2 ranuras perpendiculares al eje largo, una en cada
   extremo de la base, para pasar la correa del tobillo/muñeca.

---

## Estructura de variables — convención del proyecto

```openscad
// ---- TOLERANCIAS ----
tol      = 0.3;   // holgura general entre piezas encajadas
tol_usbc = 0.4;   // holgura extra para conector USB-C (acceso frecuente)
tol_strap = 0.5;  // holgura en ranuras para correa

// ---- PAREDES ----
wall   = 1.6;   // 2 perímetros × 0.8 mm nozzle = resistencia wearable
floor_t = 1.2;  // piso = 3 capas × 0.4 mm
ceil_t  = 1.2;  // techo de tapa igual que piso

// ---- COMPONENTES ----
xiao_l = 21.0; xiao_w = 17.5; xiao_h = 5.0;
bno_l  = 25.6; bno_w  = 22.7; bno_h  = 3.5;
bat_l  = 30.0; bat_w  = 20.0; bat_h  = 6.0;

// ---- RESOLUCIÓN ----
$fn = 60;  // render de previews; subir a 120 para exportar STL final
```

**Nomenclatura de ejes:**
- **X** = eje largo de la carcasa (dirección de la correa)
- **Y** = eje ancho
- **Z** = altura (del piso hacia arriba)

---

## Módulos reutilizables — base de toda carcasa

### rounded_rect y rounded_box

```openscad
module rounded_rect(l, w, r) {
    offset(r) offset(-r) square([l, w]);
}

module rounded_box(l, w, h, r) {
    linear_extrude(h) rounded_rect(l, w, r);
}
```

### Poste guía con chaflán (imprime sin soporte)

```openscad
// post_d: diámetro del poste | post_h: altura | chamfer_h: altura del chaflán de entrada
module guide_post(post_d, post_h, chamfer_h=0.8) {
    cylinder(d1=post_d + 1.5, d2=post_d, h=chamfer_h);
    translate([0, 0, chamfer_h])
        cylinder(d=post_d, h=post_h - chamfer_h);
}

// Agujero para poste en la tapa (con entrada cónica para facilitar encaje)
module post_hole(post_hole_d, depth, chamfer_d=1.2) {
    cylinder(d=post_hole_d, h=depth + 2);
    translate([0, 0, depth - 0.5])
        cylinder(d1=post_hole_d, d2=post_hole_d + chamfer_d, h=0.6);
}
```

### Ranura para correa elástica

```openscad
// strap_w: ancho de la correa (25mm para este proyecto) | strap_t: grosor de la correa (~2.5mm)
module strap_slot(strap_w=25, strap_t=2.5, wall_t=1.6) {
    // La ranura atraviesa la pared en el eje Y
    cube([strap_t + tol_strap, strap_w + tol_strap, wall_t * 3], center=true);
}
```

### Abertura USB-C

```openscad
module usbc_cutout(w=9.0, h=3.5, depth=4, tol=0.4) {
    // depth: profundidad de la abertura (atraviesa la pared + margen)
    cube([depth, w + tol, h + tol]);
}
```

### Separador entre capas (batería / electrónica)

```openscad
module layer_separator(inner_l, inner_w, thickness=0.8, corner_r=2.0) {
    // Separador con agujero central para paso del cable JST
    difference() {
        rounded_box(inner_l, inner_w, thickness, corner_r);
        // Agujero JST en el centro
        translate([inner_l/2 - 3, inner_w/2 - 2, -0.1])
            cube([6, 4, thickness + 0.2]);
    }
}
```

---

## Layout de componentes — diseño de 2 capas

```
Vista lateral (corte en XZ):
┌─────────────────────────────────────┐  ← tapa (lid)
│  BNO085  │  canal  │      XIAO      │  ← capa electrónica
├──────────┴─────────┴────────────────┤  ← separador (0.8mm)
│              Batería                │  ← capa batería
└─────────────────────────────────────┘  ← piso (base)

Vista superior (corte en XY):
  ←——bno_l——→←—gap—→←—xiao_l—→
  [  BNO085  ][canal][   XIAO  ]    centrado en Y
        [     Batería     ]         centrado en X y Y (capa inferior)
```

**Origen de cada componente** (esquina inferior-izquierda, Z=0 en piso exterior):

```openscad
bno_x  = wall + tol;
bno_y  = wall + (inner_w - bno_w) / 2;
bno_z  = floor_t + bat_h + separator_t;

xiao_x = wall + tol + bno_l + gap + tol * 2;
xiao_y = wall + (inner_w - xiao_w) / 2;
xiao_z = floor_t + bat_h + separator_t;

bat_x  = wall + (inner_l - bat_l) / 2;
bat_y  = wall + (inner_w - bat_w) / 2;
bat_z  = floor_t;
```

---

## Módulo base() — estructura completa

El módulo `base()` sigue esta estructura invariante:

```openscad
module base() {
    difference() {
        // 1. Cuerpo exterior redondeado
        rounded_box(outer_l, outer_w, outer_h, corner_r);

        // 2. Vaciado interior principal
        translate([wall, wall, floor_t])
            rounded_box(inner_l, inner_w, inner_h + 1, corner_r - wall/2);

        // 3. Cavidades de componentes (batería, BNO085, XIAO)
        // 4. Canales de cable (JST vertical + cable horizontal entre PCBs)
        // 5. Abertura USB-C (lateral, lado +X)
        // 6. Ranuras para correa (extremos +X y -X, perpendiculares)
    }

    // Separador entre capas (adición, no sustracción)
    translate([wall + 0.5, wall + 0.5, floor_t + bat_h])
        layer_separator(inner_l - 1, inner_w - 1);

    // Postes guía en las 4 esquinas interiores
    for (pos = post_positions()) {
        translate([pos[0], pos[1], outer_h])
            guide_post(post_d, post_h);
    }
}
```

## Módulo lid() — estructura de la tapa

```openscad
module lid() {
    difference() {
        union() {
            // 1. Cuerpo exterior de la tapa
            rounded_box(outer_l, outer_w, lid_h, corner_r);

            // 2. Labio interior que encaja dentro de la base (guía de alineación)
            translate([wall + tol, wall + tol, lid_h - 0.01])
                rounded_box(inner_l - tol*2, inner_w - tol*2, 2.0, corner_r - wall);
        }

        // 3. Vaciado interior (aligera la pieza)
        translate([wall, wall, ceil_t])
            rounded_box(inner_l, inner_w, lid_h, corner_r - wall/2);

        // 4. Agujeros para postes guía (con entrada cónica)
        for (pos = post_positions()) {
            translate([pos[0], pos[1], -1])
                post_hole(post_hole_d, lid_h);
        }
    }
}
```

---

## Snap-fit — cierre sin tornillos

Para una versión con cierre snap-fit (evita tornillos en el prototipo):

```openscad
snap_depth  = 0.6;   // profundidad del gancho (PETG flexible)
snap_w      = 8.0;   // ancho del snap
snap_h      = 2.0;   // alto del gancho
snap_angle  = 30;    // ángulo de deslizamiento (carga)

// Gancho macho en la base (lado exterior de la pared)
module snap_hook(depth=snap_depth, w=snap_w, h=snap_h, angle=snap_angle) {
    hull() {
        cube([depth, w, h/2]);
        translate([0, 0, h/2])
            rotate([0, -angle, 0])
                cube([depth * 1.5, w, 0.4]);
    }
}

// Cavidad hembra en la tapa (slot + entrada cónica)
module snap_socket(depth=snap_depth, w=snap_w, h=snap_h, tol=0.3) {
    cube([depth + tol + 2, w + tol, h + tol]);
}
```

**Posición de snaps:** 2 por lado largo, equidistantes. PETG tolera hasta ~0.8mm de deflexión sin fractura.

---

## Instrucciones de exportación para Bambu Lab A1 Mini

```openscad
// ============================================================
// PARA EXPORTAR STL:
// 1. Cambiar $fn = 120 (mayor resolución para STL final)
// 2. Comentar la sección VISUALIZACIÓN
// 3. Descomentar UNA de las siguientes:

// base();  // base boca arriba — sin soportes

// rotate([180,0,0]) translate([0, 0, -outer_h]) lid();
//   ↑ tapa invertida — imprime sin soportes, labio colgando hacia arriba

// 4. F6 (Render) → F7 (Export STL)
// ============================================================
```

**Configuración Bambu Studio recomendada:**

| Parámetro | Valor | Razón |
|---|---|---|
| Material | PETG (Bambu PETG-HF o genérico) | Resistencia a sudor e impactos |
| Altura de capa | 0.16 mm | Balance calidad/velocidad |
| Paredes | 3 | ~1.2mm = resistente para wearable |
| Relleno | 20–25% gyroid | Flexible y resistente |
| Soportes | NO | Diseño lo evita |
| Adhesión | Brim 3mm | PETG levanta esquinas |
| Temp. nozzle | 235°C | Típico PETG |
| Temp. cama | 80°C | Adhesión PETG |
| Orientación base | Piso plano sobre la cama | — |
| Orientación tapa | Invertida (techo sobre la cama) | Sin soportes en postes |

---

## Formato del output

Cuando generes o modifiques código OpenSCAD para este proyecto:

1. **Respetar la estructura existente** de `carcasa_wearable.scad` — leer el archivo antes de
   proponer cambios.
2. **Variables al inicio del archivo** — nunca hardcodear en módulos.
3. **Comentar cada sección** — `// ---- NOMBRE ----` como separadores.
4. **Incluir visualización de componentes** con `color()` y transparencia para facilitar el debug.
5. **Incluir instrucciones de exportación** al final del archivo como comentarios.
6. **Al terminar**, mostrar:
   - Dimensiones exteriores calculadas (outer_l × outer_w × (outer_h + lid_h) mm)
   - Cambios realizados respecto a la versión anterior
   - Advertencias de impresión si aplica (voladizos >45°, paredes muy delgadas, etc.)
   - Qué `$fn` usar para exportación final
