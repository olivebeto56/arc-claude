// ============================================================================
//  AI Sport Monitor — Carcasa wearable v5 (caja vacia)
//
//  ALCANCE DE ESTA VERSION:
//      Solo BASE rectangular hueca + TAPA snap-fit. Interior completamente
//      vacio: sin separaciones, sin postes, sin guias para componentes.
//
//  CAMBIO IMPORTANTE EN ESTA REVISION:
//      Cierre rediseñado con sistema TETONES + RANURAS:
//        - Labio mas grueso (1.2 mm) para mas resistencia
//        - Tolerancia mas ajustada (0.15 mm) para encaje preciso
//        - 4 tetones rectangulares en el labio que encajan en 4 ranuras
//          en la pared del rebaje del cuerpo, produciendo un CLIC firme
//        - Las dimensiones de tetones y ranuras estan asimetricas con
//          interferencia controlada para garantizar el snap.
//
//  Lenguaje formal:
//      - Caja rectangular con esquinas redondeadas (R = 3 mm)
//      - Chaflanes superior e inferior de 0.8 mm
//      - Marca L / R grabada en la tapa
//
//  Convenciones:
//      Eje X = largo
//      Eje Y = ancho
//      Eje Z = alto
// ============================================================================

// ----------------------------------------------------------------------------
//  PARAMETROS
// ----------------------------------------------------------------------------

PART = "both";   // "body", "lid", "both", "exploded"

TOL       = 0.15;    // tolerancia general (antes 0.30, ahora encaje justo)
WALL      = 1.8;
FLOOR     = 1.6;
LID_TOP   = 1.6;
LID_LIP_H = 3.0;     // labio mas alto (antes 2.5) para mas guiado
LID_LIP_T = 1.2;     // labio mas grueso (antes 1.0) para resistir el snap

CORNER_R  = 3.0;
CHAMFER   = 0.8;

NODE_LABEL = "L";    // "L" o "R"

// --- Parametros del sistema snap (tetones + ranuras) ---
DETENT_W   = 5.0;    // largo del teton (en X) en los lados largos
DETENT_H   = 1.0;    // alto del teton en Z
DETENT_P   = 0.5;    // protrusion del teton hacia fuera del labio (interferencia
                     // con la pared del rebaje — esto es lo que da el "clic")
DETENT_Z_FROM_BOTTOM_OF_LIP = 0.6;  // distancia desde la cara inferior del
                                     // labio al borde inferior del teton

$fa = 2;
$fs = 0.3;

// ----------------------------------------------------------------------------
//  DIMENSIONES INTERIORES
// ----------------------------------------------------------------------------

INNER_X = 50.9;
INNER_Y = 23.3;
INNER_Z = 14.0;

BODY_X = INNER_X + 2 * WALL;     // 54.5
BODY_Y = INNER_Y + 2 * WALL;     // 26.9
BODY_Z = FLOOR + INNER_Z;        // 15.6

// ----------------------------------------------------------------------------
//  PRIMITIVAS
// ----------------------------------------------------------------------------

module rounded_rect(x, y, r) {
    hull() {
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*(x/2 - r), sy*(y/2 - r), 0])
                circle(r = r);
    }
}

module whoop_box(x, y, z, r, ch) {
    hull() {
        translate([0, 0, 0])
            linear_extrude(height = 0.01)
                rounded_rect(x - 2*ch, y - 2*ch, max(0.5, r - ch));
        translate([0, 0, ch])
            linear_extrude(height = z - 2*ch)
                rounded_rect(x, y, r);
        translate([0, 0, z - 0.01])
            linear_extrude(height = 0.01)
                rounded_rect(x - 2*ch, y - 2*ch, max(0.5, r - ch));
    }
}

// ----------------------------------------------------------------------------
//  POSICIONES DE LOS 4 TETONES (en los lados LARGOS del labio)
//  2 tetones por lado largo (lado +Y y lado -Y), espaciados en X.
// ----------------------------------------------------------------------------
DETENT_X_OFFSETS = [-BODY_X/4, BODY_X/4];

// Y del centro del teton (sobre la cara exterior del labio en el lado largo).
// El labio exterior llega hasta Y = ±(INNER_Y/2 + LID_LIP_T)
DETENT_Y = INNER_Y/2 + LID_LIP_T;

// ----------------------------------------------------------------------------
//  CUERPO  (caja hueca + ranuras receptoras de los tetones)
// ----------------------------------------------------------------------------

module body() {
    difference() {
        whoop_box(BODY_X, BODY_Y, BODY_Z, CORNER_R, CHAMFER);

        // Vaciado interior (caja completamente vacia)
        translate([0, 0, FLOOR])
            linear_extrude(height = INNER_Z + LID_LIP_H + 1)
                rounded_rect(INNER_X, INNER_Y, max(1.0, CORNER_R - WALL/2));

        // Rebaje perimetral para el labio de la tapa
        // Notese: el rebaje es 0.15 mm mas ancho que el labio (TOL),
        // muy poco — esto fuerza un encaje justo.
        translate([0, 0, BODY_Z - LID_LIP_H])
            linear_extrude(height = LID_LIP_H + 0.1)
                difference() {
                    rounded_rect(INNER_X + 2*LID_LIP_T + 2*TOL,
                                 INNER_Y + 2*LID_LIP_T + 2*TOL,
                                 max(0.8, CORNER_R - WALL/2 + LID_LIP_T));
                    rounded_rect(INNER_X, INNER_Y,
                                 max(1.0, CORNER_R - WALL/2));
                }

        // ---------- RANURAS para los 4 tetones ----------
        // Cada ranura es un pequeño bolsillo en la pared del rebaje
        // (en los lados largos +Y / -Y) donde encaja el teton de la tapa.
        // Z del centro de la ranura: medido desde el fondo del rebaje
        // (Z = BODY_Z - LID_LIP_H) hacia arriba.
        detent_z_center = BODY_Z - LID_LIP_H + DETENT_Z_FROM_BOTTOM_OF_LIP + DETENT_H/2;

        for (sy = [-1, 1])
            for (xpos = DETENT_X_OFFSETS)
                translate([xpos,
                           sy * (DETENT_Y + DETENT_P/2),  // dentro de la pared
                           detent_z_center])
                    cube([DETENT_W,
                          DETENT_P + 0.4,   // profundidad ligera
                          DETENT_H + 0.2],  // un pelin mas alta para tolerancia
                         center = true);

        // ---------- Pestana de apertura de la tapa ----------
        // Pequeño rebaje en uno de los lados largos para meter la uña
        // y hacer palanca al abrir.
        translate([0, BODY_Y/2 - 0.5, BODY_Z - LID_LIP_H/2])
            cube([10, 2, LID_LIP_H + 0.6], center = true);
    }
}

// ----------------------------------------------------------------------------
//  TAPA  (con tetones que encajan en las ranuras del cuerpo)
// ----------------------------------------------------------------------------

module lid() {
    union() {
        difference() {
            whoop_box(BODY_X - 0.4, BODY_Y - 0.4, LID_TOP, CORNER_R - 0.2, CHAMFER);

            // Grabado del label centrado
            translate([0, 0, LID_TOP - 0.6])
                linear_extrude(height = 0.8)
                    text(NODE_LABEL, size = 8, halign = "center",
                         valign = "center",
                         font = "Liberation Sans:style=Bold");
        }

        // ---------- Labio perimetral ----------
        // Macizo: rectangulo de paredes de LID_LIP_T mm de grosor,
        // que encaja en el rebaje del cuerpo.
        translate([0, 0, -LID_LIP_H + 0.01])
            linear_extrude(height = LID_LIP_H)
                difference() {
                    rounded_rect(INNER_X + 2*LID_LIP_T,
                                 INNER_Y + 2*LID_LIP_T,
                                 max(0.8, CORNER_R - WALL/2 + LID_LIP_T));
                    rounded_rect(INNER_X,
                                 INNER_Y,
                                 max(1.0, CORNER_R - WALL/2));
                }

        // ---------- 4 tetones rectangulares en lados largos ----------
        // Sobresalen DETENT_P (0.5 mm) hacia fuera de la pared del labio.
        // Esa interferencia con la pared del rebaje es la que produce el
        // CLIC al cerrar y la fuerza de retencion al estar puesto.
        // El borde superior del teton tiene un chaflan ligero de entrada
        // para que la tapa "monte" facil al cerrar.
        detent_z_center = -LID_LIP_H + DETENT_Z_FROM_BOTTOM_OF_LIP + DETENT_H/2;

        for (sy = [-1, 1])
            for (xpos = DETENT_X_OFFSETS)
                translate([xpos,
                           sy * (DETENT_Y + DETENT_P/2),
                           detent_z_center])
                    detent_block();
    }
}

// Bloque de teton con chaflan superior (rampa de entrada)
//   Ejes locales: X = largo del teton, Y = profundidad (protrusion),
//                 Z = altura del teton, centrado en origen.
module detent_block() {
    hull() {
        // base inferior (la cara que mira al fondo del rebaje) — completa
        translate([0, 0, -DETENT_H/2 + 0.001])
            cube([DETENT_W, DETENT_P + 0.4, 0.001], center = true);
        // cintura (cara plana que hace tope contra la ranura)
        translate([0, 0, -DETENT_H/2 + DETENT_H * 0.6])
            cube([DETENT_W, DETENT_P + 0.4, 0.001], center = true);
        // cara superior reducida en Y => crea rampa de entrada
        // (chaflan que ayuda a montar la tapa)
        translate([0, 0, DETENT_H/2 - 0.001])
            cube([DETENT_W, 0.3, 0.001], center = true);
    }
}

// ----------------------------------------------------------------------------
//  VISTA EXPLODED
// ----------------------------------------------------------------------------

module exploded_view() {
    body();
    translate([0, 0, BODY_Z + 15])
        lid();
}

// ----------------------------------------------------------------------------
//  RENDER
// ----------------------------------------------------------------------------

if (PART == "body") {
    body();
} else if (PART == "lid") {
    rotate([180, 0, 0]) lid();
} else if (PART == "both") {
    body();
    translate([0, BODY_Y + 15, 0])
        rotate([180, 0, 0])
            lid();
} else if (PART == "exploded") {
    exploded_view();
}

// ----------------------------------------------------------------------------
//  ECHO
// ----------------------------------------------------------------------------
echo(str("BODY  X=", BODY_X, "  Y=", BODY_Y, "  Z=", BODY_Z, "  mm"));
echo(str("INNER X=", INNER_X, "  Y=", INNER_Y, "  Z=", INNER_Z));
echo(str("Snap: tetones de ", DETENT_W, "x", DETENT_H,
        " mm con interferencia ", DETENT_P, " mm"));
echo(str("Tolerancia labio/rebaje: ", TOL, " mm"));
