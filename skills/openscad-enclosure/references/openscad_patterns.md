# Patrones OpenSCAD para Carcasas de Electrónica

## Operaciones booleanas — fundamentos

```openscad
// DIFERENCIA: vaciar material (cavidades, agujeros)
difference() {
    body();        // sólido principal
    cutout();      // lo que se resta
}

// UNIÓN: combinar sólidos
union() {
    part_a();
    part_b();
}

// INTERSECCIÓN: conservar solo la zona común
intersection() {
    shape_a();
    shape_b();
}

// Regla: siempre añadir 0.01–0.2 mm de margen (epsilon) en sustracciones
// para evitar superficies coplanares que confunden al renderer
translate([x, y, z - 0.1]) cube([l, w, h + 0.2]);
//                   ↑ margen inferior     ↑ margen superior
```

---

## Patrón boss (poste de montaje para PCB)

Un boss es un cilindro hueco que recibe un tornillo M2/M2.5 o un pin de presión:

```openscad
// boss_d_outer: diámetro exterior | boss_d_inner: diámetro del agujero | h: altura
module boss(boss_d_outer=5.0, boss_d_inner=2.2, h=4.0) {
    difference() {
        cylinder(d=boss_d_outer, h=h);
        translate([0, 0, -0.1])
            cylinder(d=boss_d_inner, h=h + 0.2);
    }
}

// Para tornillo M2 autoperforante (PCB mounting): boss_d_inner = 1.7mm
// Para tornillo M2 con tuerca: boss_d_inner = 2.2mm
// Para pin de presión Ø 2mm (XIAO tiene 4 agujeros de 2mm): boss_d_inner = 1.9mm
```

---

## Patrón snap-fit — gancho PETG

PETG tiene módulo de elasticidad ~2.0–2.5 GPa y elongación a rotura 50–200%.
Deflexión segura para snap: δ ≤ 0.7 × espesor del brazo.

```openscad
snap_arm_l    = 8.0;   // largo del brazo (cuánto dobla)
snap_arm_t    = 1.0;   // grosor del brazo
snap_hook_h   = 0.5;   // altura del gancho
snap_hook_ang = 20;    // ángulo de salida (ángulo bajo = más fácil cerrar)
snap_return_ang = 70;  // ángulo de retención (>45° = necesita herramienta para abrir)

module snap_cantilever(arm_l, arm_t, hook_h, return_ang=70, entry_ang=20) {
    // Brazo flexible
    cube([arm_l, arm_t, arm_t]);
    // Gancho en el extremo
    translate([arm_l, 0, 0])
        hull() {
            cube([0.1, arm_t, arm_t]);
            translate([hook_h * tan(entry_ang), 0, arm_t + hook_h])
                cube([0.1, arm_t, 0.1]);
        }
}
```

---

## Patrón labio de encaje (lid lip joint)

Más robusto que snap-fit para carcasas wearable sometidas a vibración:

```openscad
// El labio de la tapa encaja DENTRO de la base
// inner_clearance: holgura entre labio y pared interior de la base
lip_depth  = 2.0;         // cuánto profundiza el labio en la base
lip_height = 2.0;         // altura del reborde del labio
inner_clearance = tol;    // holgura lateral (0.2–0.3mm para PETG)

// En la tapa: labio añadido en la cara inferior
module lid_lip(inner_l, inner_w, depth, height, clearance, corner_r) {
    translate([wall + clearance, wall + clearance, -depth + 0.01])
        rounded_box(inner_l - clearance*2, inner_w - clearance*2, depth + height, corner_r);
}

// La base NO necesita modificación — el labio encaja en el vaciado interior
```

---

## Patrón de ranura para correa (strap slot)

```openscad
// Ranura rectangular que atraviesa la pared lateral de la base
// strap_w: ancho de la correa (25mm) | strap_t: grosor (~2–3mm) | extra: margen impresión
strap_w = 25.0;
strap_t = 2.5;
strap_tol = 0.5;

module strap_slot(strap_w, strap_t, depth, tol=0.5) {
    // Centrar en Y, traversar en X (profundidad = depth)
    cube([depth + 1, strap_w + tol, strap_t + tol]);
}

// Posición: en los extremos de la carcasa, centrado en Y y Z
// Lado -X:
translate([-0.1, outer_w/2 - (strap_w + strap_tol)/2, outer_h/2 - (strap_t + strap_tol)/2])
    strap_slot(strap_w, strap_t, wall + 0.2);

// Lado +X:
translate([outer_l - wall - 0.1, outer_w/2 - (strap_w + strap_tol)/2, outer_h/2 - (strap_t + strap_tol)/2])
    strap_slot(strap_w, strap_t, wall + 0.2);
```

---

## Patrón de abertura para conector (USB-C, JST, botón)

```openscad
// Abertura con chaflán interior para facilitar inserción de cables
module connector_cutout(port_w, port_h, wall_depth, tol=0.4, chamfer=0.8) {
    w = port_w + tol;
    h = port_h + tol;
    hull() {
        cube([wall_depth, w, h]);
        translate([-chamfer, -chamfer/2, -chamfer/2])
            cube([wall_depth + chamfer, w + chamfer, h + chamfer]);
    }
}

// Para USB-C del XIAO (9.0 × 3.5 mm):
connector_cutout(port_w=9.0, port_h=3.5, wall_depth=wall + 2, tol=0.4);

// Para conector JST 1.25mm 2-pin (2.5 × 4.0 mm aproximado):
connector_cutout(port_w=4.0, port_h=4.0, wall_depth=wall + 2, tol=0.5);
```

---

## Patrón de canal de cable (cable routing)

```openscad
// Canal en el separador para pasar cables entre capas
module cable_channel(width, height, length, tol=0.3) {
    // width: ancho del canal | height: alto (a través del separador) | length: largo del canal
    cube([length, width + tol, height + tol]);
}

// Canal JST vertical (pasa entre capa batería y electrónica):
translate([jst_x, inner_w/2 - 3, floor_t - 0.1])
    cable_channel(width=6, height=bat_h + separator_t + 2, length=4);
```

---

## Función de posiciones en esquinas

```openscad
// Retorna los 4 puntos de esquina interior para postes/agujeros
function corner_positions(outer_l, outer_w, wall, offset_d) = [
    [wall + offset_d,              wall + offset_d],
    [outer_l - wall - offset_d,    wall + offset_d],
    [wall + offset_d,              outer_w - wall - offset_d],
    [outer_l - wall - offset_d,    outer_w - wall - offset_d]
];

// Uso:
for (pos = corner_positions(outer_l, outer_w, wall, post_d)) {
    translate([pos[0], pos[1], z]) guide_post(post_d, post_h);
}
```

---

## Visualización de componentes (modo debug)

```openscad
// Siempre incluir visualización de componentes con transparencia para verificar encaje
module visualize_components() {
    // BNO085
    color("Green", 0.4)
        translate([bno_x, bno_y, bno_z])
            cube([bno_l, bno_w, bno_h]);
    // XIAO
    color("Blue", 0.4)
        translate([xiao_x, xiao_y, xiao_z])
            cube([xiao_l, xiao_w, xiao_h]);
    // Batería
    color("Orange", 0.4)
        translate([bat_x, bat_y, bat_z])
            cube([bat_l, bat_w, bat_h]);
    // USB-C (para verificar que la abertura está alineada)
    color("Silver", 0.8)
        translate([xiao_x + xiao_l, xiao_y + (xiao_w - 9)/2, xiao_z])
            cube([2, 9, 3.5]);
}

// Llamar en sección VISUALIZACIÓN (comentar para exportar STL)
color("DimGray") base();
translate([0, 0, outer_h + post_h + 5]) color("SlateGray", 0.7) lid();
visualize_components();
```

---

## Errores comunes y cómo evitarlos

| Error | Causa | Solución |
|---|---|---|
| Manifold error al exportar | Superficies coplanares | Añadir epsilon (±0.1mm) en sustracciones |
| Postes no imprimen bien | Puente largo sobre la cavidad | Usar chaflán en base del poste (d1 > d2) |
| Labio no encaja | Tolerancia insuficiente | Aumentar `tol` de 0.2 a 0.3mm para PETG |
| Tapa se tuerce al enfriar | Área grande sin brim | Brim ≥ 3mm en Bambu Studio |
| USB-C sin acceso | Abertura demasiado pequeña | Añadir tol_usbc = 0.4mm extra en ancho y alto |
| Ranura de correa frágil | Pared muy delgada alrededor | Mantener ≥ 1.2mm de material en los lados |
