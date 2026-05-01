// ============================================================================
//  AI Sport Monitor — Carcasa wearable v6 (caja vacia + arcos para correa)
//
//  Identica a la v5 (caja rectangular hueca + tapa snap-fit), con la unica
//  diferencia de que el cuerpo lleva DOS ARCOS RECTANGULARES (uno en cada
//  extremo corto). La correa entra por dentro del arco, rodea la barra
//  externa del arco y sale por el otro lado, igual que un mosqueton o
//  hebilla rectangular.
//
//  Vista en planta:
//
//          ┌─────┐                          ┌─────┐
//          │     │  ┌────────────────────┐  │     │
//          │  ▢  │──│      cuerpo        │──│  ▢  │
//          │     │  └────────────────────┘  │     │
//          └─────┘                          └─────┘
//          arco                              arco
//          (correa pasa por                  (correa pasa por
//           el hueco rectangular)             el hueco rectangular)
//
//  Lenguaje formal:
//      - Caja rectangular con esquinas redondeadas (R = 3 mm)
//      - Chaflanes superior e inferior de 0.8 mm
//      - Cierre snap-fit con labio perimetral (sin tornillos)
//      - Marca L / R grabada en la tapa
//      - Arcos integrados con el cuerpo, mismo lenguaje formal
//
//  Convenciones:
//      Eje X = largo
//      Eje Y = ancho
//      Eje Z = alto
// ============================================================================

// ----------------------------------------------------------------------------
//  PARAMETROS
// ----------------------------------------------------------------------------

PART = "exploded";   // "body", "lid", "both", "exploded"

TOL       = 0.30;
WALL      = 1.8;
FLOOR     = 1.6;
LID_TOP   = 1.6;
LID_LIP_H = 2.5;
LID_LIP_T = 1.0;

CORNER_R  = 3.0;
CHAMFER   = 0.8;

NODE_LABEL = "L";    // "L" o "R"

// --- Parametros de los arcos para correa ---
ARC_OUT      = 8.0;    // cuanto sobresale el arco del cuerpo en X
ARC_BAR_T    = 3.0;    // grosor de la "varilla" del arco en X
ARC_SIDE_T   = 3.0;    // grosor de los laterales del arco en Y
ARC_OUT_R    = 3.0;    // radio de las esquinas exteriores del arco
ARC_IN_R     = 1.5;    // radio de las esquinas interiores del arco (donde
                       // pasa la correa) — pequenas para maximizar paso util
ARC_Z_RATIO  = 0.20;   // altura del arco como fraccion de la altura del
                       // cuerpo (0.20 = 20% del alto del cuerpo)

$fa = 2;
$fs = 0.3;

// ----------------------------------------------------------------------------
//  DIMENSIONES INTERIORES (iguales a v5)
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

// Caja con esquinas redondeadas y chaflanes arriba/abajo
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

// Marco rectangular extruido en Z con esquinas exteriores e interiores
// redondeadas y chaflanes arriba/abajo. Usado para construir cada arco.
//   x_out, y_out: dimensiones exteriores en planta
//   x_in,  y_in:  dimensiones interiores (hueco por el que pasa la correa)
//   z:           altura del marco
//   r_out, r_in: radios de las esquinas exterior e interior
//   ch:          chaflan superior / inferior
module ring_frame(x_out, y_out, x_in, y_in, z, r_out, r_in, ch) {
    difference() {
        whoop_box(x_out, y_out, z, r_out, ch);
        // Vaciado interior pasante (un poco mas alto para garantizar el
        // booleano completo a traves del chaflan)
        translate([0, 0, -0.5])
            linear_extrude(height = z + 1)
                rounded_rect(x_in, y_in, r_in);
    }
}

// ----------------------------------------------------------------------------
//  ARCO DE CORREA
//   sx = +1 lado +X, -1 lado -X
//   El arco solapa OVERLAP mm con el cuerpo para que la union booleana
//   produzca una pieza solida.
// ----------------------------------------------------------------------------
module strap_arc(sx) {
    OVERLAP = 1.0;

    // Dimensiones del marco rectangular del arco
    arc_x_out = ARC_OUT + ARC_BAR_T + OVERLAP;  // largo en X
    arc_y_out = BODY_Y;                         // mismo ancho que el cuerpo
    arc_x_in  = ARC_OUT - ARC_BAR_T;            // hueco en X (paso de correa)
    arc_y_in  = BODY_Y - 2 * ARC_SIDE_T;        // hueco en Y (paso de correa)

    // Altura del arco: fraccion del alto del cuerpo (parametro ARC_Z_RATIO)
    arc_z = BODY_Z * ARC_Z_RATIO;
    // El chaflan superior/inferior debe ser menor que la mitad de la altura
    arc_ch = min(CHAMFER, arc_z/2 - 0.1);

    // Centro X del arco: la cara interior del arco solapa con la pared
    // exterior del cuerpo en OVERLAP/2, y desde ahi se extiende hacia fuera.
    cx = sx * (BODY_X/2 + arc_x_out/2 - OVERLAP);
    // Z: arco apoyado en el suelo (Z = 0). La correa queda por debajo del
    // cuerpo, contra la piel, como en un reloj convencional. Ademas, al
    // imprimirse desde la cama no necesita soportes.
    cz = 0;

    translate([cx, 0, cz])
        ring_frame(arc_x_out, arc_y_out,
                   arc_x_in,  arc_y_in,
                   arc_z,
                   ARC_OUT_R, ARC_IN_R,
                   arc_ch);
}

// ----------------------------------------------------------------------------
//  CUERPO  (caja hueca pura + 2 arcos)
// ----------------------------------------------------------------------------

module body() {
    union() {
        // Caja hueca (idéntica a v5)
        difference() {
            whoop_box(BODY_X, BODY_Y, BODY_Z, CORNER_R, CHAMFER);

            // Vaciado interior
            translate([0, 0, FLOOR])
                linear_extrude(height = INNER_Z + LID_LIP_H + 1)
                    rounded_rect(INNER_X, INNER_Y, max(1.0, CORNER_R - WALL/2));

            // Rebaje perimetral para el labio de la tapa
            translate([0, 0, BODY_Z - LID_LIP_H])
                linear_extrude(height = LID_LIP_H + 0.1)
                    difference() {
                        rounded_rect(INNER_X + 2*LID_LIP_T + TOL,
                                     INNER_Y + 2*LID_LIP_T + TOL,
                                     max(0.8, CORNER_R - WALL/2 + LID_LIP_T));
                        rounded_rect(INNER_X, INNER_Y,
                                     max(1.0, CORNER_R - WALL/2));
                    }
        }

        // Dos arcos rectangulares, uno en cada extremo corto
        for (sx = [-1, 1])
            strap_arc(sx);
    }
}

// ----------------------------------------------------------------------------
//  TAPA  (idéntica a v5)
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

        // Labio perimetral
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

        // Resaltes de presion (snap bumps) en lados largos
        long_y = (INNER_Y + 2*LID_LIP_T)/2 - LID_LIP_T/2;
        for (sy = [-1, 1])
            for (xpos = [-BODY_X/3, 0, BODY_X/3])
                translate([xpos, sy * long_y, -LID_LIP_H/2])
                    rotate([90, 0, 0])
                        scale([1, 1, 0.6])
                            sphere(r = 0.55);
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
    translate([0, BODY_Y + 25, 0])
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
echo(str("Arco: paso correa =", ARC_OUT - ARC_BAR_T, " x ", BODY_Y - 2 * ARC_SIDE_T, " mm"));
echo(str("Total con arcos X=", BODY_X + 2 * (ARC_OUT + ARC_BAR_T)));
