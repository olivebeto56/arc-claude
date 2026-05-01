// ============================================================================
//  AI Sport Monitor — Carcasa wearable v3
//
//  ALCANCE DE ESTA VERSION:
//      Solo CUERPO RECTANGULAR + TAPA. Sin correa ni pasadores.
//      La fijacion al brazo / tobillo se resolvera en una iteracion posterior.
//
//  Lenguaje formal:
//      - Caja rectangular con esquinas redondeadas suaves (R = 3 mm)
//      - Chaflan ligero arriba y abajo (0.8 mm)
//      - Cierre snap-fit con labio perimetral (sin tornillos)
//      - Marca L / R grabada en la tapa
//      - Acceso USB-C lateral abierto
//
//  Componentes alojados (apilamiento vertical, abajo -> arriba):
//      1) Bateria LiPo 602030  ........ 30 x 20 x 6 mm
//      2) Seeed XIAO nRF52840 Sense ... 21 x 17.5 x 5 mm   (USB-C lateral)
//      3) Adafruit BNO085 #4754 ....... 25.4 x 20.3 x 3 mm
//
//  Convenciones:
//      Eje X = largo
//      Eje Y = ancho
//      Eje Z = alto (apilado de componentes, alejado de la piel)
// ============================================================================

// ----------------------------------------------------------------------------
//  PARAMETROS
// ----------------------------------------------------------------------------

// Que pieza renderizar: " ", "lid", "both", "exploded"
PART = "both";

TOL       = 0.30;
WALL      = 1.8;
FLOOR     = 1.6;
LID_TOP   = 1.6;
LID_LIP_H = 2.5;
LID_LIP_T = 1.0;

CORNER_R  = 3.0;
CHAMFER   = 0.8;

NODE_LABEL = "L";    // "L" o "R"

$fa = 2;
$fs = 0.3;

// ----------------------------------------------------------------------------
//  COMPONENTES
// ----------------------------------------------------------------------------

BAT_X = 30.0;  BAT_Y = 20.0;  BAT_Z = 6.5;
BAT_CABLE_DIAM = 2.5;

XIAO_X = 21.0; XIAO_Y = 17.5; XIAO_Z = 5.0;
XIAO_USB_W = 9.0;  XIAO_USB_H = 3.5;

BNO_X = 25.4;  BNO_Y = 20.3;  BNO_Z = 3.5;
BNO_HOLE_DIAM  = 2.5;
BNO_HOLE_INSET = 2.0;

// ----------------------------------------------------------------------------
//  HUELLA INTERIOR / EXTERIOR
// ----------------------------------------------------------------------------

MARGIN_X = 1.5;
MARGIN_Y = 1.5;

INNER_X = max(BAT_X, BNO_X, XIAO_X) + 2 * MARGIN_X;   // 33.0
INNER_Y = max(BAT_Y, BNO_Y, XIAO_Y) + 2 * MARGIN_Y;   // 23.3

SEP_BAT_XIAO = 1.0;
SEP_XIAO_BNO = 1.5;
AIR_TOP      = 1.0;

INNER_Z = BAT_Z + SEP_BAT_XIAO + XIAO_Z + SEP_XIAO_BNO + BNO_Z + AIR_TOP;
// = 18.5

BODY_X = INNER_X + 2 * WALL;    // 36.6
BODY_Y = INNER_Y + 2 * WALL;    // 26.9
BODY_Z = FLOOR + INNER_Z;       // 20.1

// Z (cara inferior) de cada componente
Z_BAT  = FLOOR;
Z_XIAO = Z_BAT  + BAT_Z  + SEP_BAT_XIAO;
Z_BNO  = Z_XIAO + XIAO_Z + SEP_XIAO_BNO;

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

// Caja con esquinas redondeadas en planta y chaflanes arriba/abajo
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
//  CUERPO
// ----------------------------------------------------------------------------

module body() {
    difference() {
        whoop_box(BODY_X, BODY_Y, BODY_Z, CORNER_R, CHAMFER);

        // Vaciado interior
        translate([0, 0, FLOOR])
            linear_extrude(height = INNER_Z + LID_LIP_H + 1)
                rounded_rect(INNER_X, INNER_Y, max(1.0, CORNER_R - WALL/2));

        // Rebaje para el labio de la tapa
        translate([0, 0, BODY_Z - LID_LIP_H])
            linear_extrude(height = LID_LIP_H + 0.1)
                difference() {
                    rounded_rect(INNER_X + 2*LID_LIP_T + TOL,
                                 INNER_Y + 2*LID_LIP_T + TOL,
                                 max(0.8, CORNER_R - WALL/2 + LID_LIP_T));
                    rounded_rect(INNER_X, INNER_Y,
                                 max(1.0, CORNER_R - WALL/2));
                }

        // Canal USB-C lateral (lado +X)
        usb_z = Z_XIAO + XIAO_USB_H/2 + 0.3;
        translate([BODY_X/2 - WALL - 0.5, 0, usb_z])
            cube([WALL + 4, XIAO_USB_W + 1.0, XIAO_USB_H + 1.5], center = true);

        // Hueco para los cables JST de la bateria
        translate([BODY_X/2 - WALL - 0.5,
                   -INNER_Y/2 + 4,
                   Z_BAT + BAT_Z/2])
            rotate([0, 90, 0])
                cylinder(h = WALL + 4, r = BAT_CABLE_DIAM, center = true);

        // Pestana de apertura de la tapa (lado +Y)
        translate([0, BODY_Y/2 - 0.5, BODY_Z - LID_LIP_H/2])
            cube([8, 2, LID_LIP_H + 0.6], center = true);
    }

    // Postes y nervios internos
    color("DimGray") translate([0, 0, FLOOR])  battery_cradle();
    color("DimGray") translate([0, 0, Z_XIAO]) xiao_supports();
    color("DimGray") translate([0, 0, Z_BNO])  bno_posts();
}

// ----------------------------------------------------------------------------
//  Cuna para la bateria
// ----------------------------------------------------------------------------
module battery_cradle() {
    rib_h = 1.0;
    rib_t = 1.2;
    for (sy = [-1, 1])
        translate([-BAT_X/2 - 1,
                   sy * (BAT_Y/2 + 0.4) - rib_t/2,
                   0])
            cube([BAT_X + 2, rib_t, rib_h]);
    translate([-BAT_X/2 - 1.6, -BAT_Y/2 - 0.5, 0])
        cube([1.2, BAT_Y + 1, rib_h + 0.5]);
}

// 4 columnas para apoyar el XIAO
module xiao_supports() {
    col_h = 0.8;
    col_r = 1.4;
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * (XIAO_X/2 - col_r/2),
                   sy * (XIAO_Y/2 - col_r/2),
                   0])
            cylinder(h = col_h, r = col_r);
}

// 4 postes con agujero pasante para sujetar el BNO085
module bno_posts() {
    post_h = SEP_XIAO_BNO + 0.5;
    post_r = 2.2;
    hole_r = BNO_HOLE_DIAM / 2;
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * (BNO_X/2 - BNO_HOLE_INSET),
                   sy * (BNO_Y/2 - BNO_HOLE_INSET),
                   -SEP_XIAO_BNO])
            difference() {
                cylinder(h = post_h + SEP_XIAO_BNO, r = post_r);
                translate([0, 0, -0.1])
                    cylinder(h = post_h + SEP_XIAO_BNO + 0.5, r = hole_r);
            }
}

// ----------------------------------------------------------------------------
//  TAPA
// ----------------------------------------------------------------------------

module lid() {
    union() {
        difference() {
            whoop_box(BODY_X - 0.4, BODY_Y - 0.4, LID_TOP, CORNER_R - 0.2, CHAMFER);

            // Grabado del label
            translate([0, 0, LID_TOP - 0.6])
                linear_extrude(height = 0.8)
                    text(NODE_LABEL, size = 8, halign = "center",
                         valign = "center",
                         font = "Liberation Sans:style=Bold");

            // Flecha de orientacion hacia +X (lado del USB)
            translate([BODY_X/2 - 6, 0, LID_TOP - 0.4])
                linear_extrude(height = 0.6)
                    polygon(points = [[0,-1.5],[2.5,0],[0,1.5]]);
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

        // Resaltes de presion (snap bumps) en los lados largos
        for (sy = [-1, 1])
            for (xpos = [-BODY_X/4, BODY_X/4])
                translate([xpos,
                           sy * (INNER_Y/2 + LID_LIP_T/2),
                           -LID_LIP_H/2])
                    rotate([90, 0, 0])
                        scale([1, 1, 0.6])
                            sphere(r = 0.55);
    }
}

// ----------------------------------------------------------------------------
//  VISTA EXPLODED
// ----------------------------------------------------------------------------

module ghost_battery() {
    color("Gold", 0.7)
    translate([-BAT_X/2, -BAT_Y/2, Z_BAT])
        cube([BAT_X, BAT_Y, BAT_Z]);
}
module ghost_xiao() {
    color("DodgerBlue", 0.7)
    translate([-XIAO_X/2, -XIAO_Y/2, Z_XIAO])
        cube([XIAO_X, XIAO_Y, XIAO_Z]);
}
module ghost_bno() {
    color("Crimson", 0.7)
    translate([-BNO_X/2, -BNO_Y/2, Z_BNO])
        cube([BNO_X, BNO_Y, BNO_Z]);
}

module exploded_view() {
    body();
    translate([0, 0, 4])  ghost_battery();
    translate([0, 0, 18]) ghost_xiao();
    translate([0, 0, 32]) ghost_bno();
    translate([0, 0, 55]) lid();
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
    translate([BODY_X + 20, 0, 0])
        rotate([180, 0, 0])
            lid();
} else if (PART == "exploded") {
    exploded_view();
}

// ----------------------------------------------------------------------------
//  ECHO
// ----------------------------------------------------------------------------
echo(str("BODY  X=", BODY_X, "  Y=", BODY_Y, "  Z=", BODY_Z, "  mm"));
echo(str("INNER X=", INNER_X, "  Y=", INNER_Y, "  Z=", INNER_Z, "  mm"));
echo(str("Z_BAT=", Z_BAT, "  Z_XIAO=", Z_XIAO, "  Z_BNO=", Z_BNO));
