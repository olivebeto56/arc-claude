/**
 * bno085_i2c_diagnostico.ino
 *
 * Sketch de diagnostico I2C para BNO085 en XIAO nRF52840 Sense
 * Cubre: scan de bus, verificacion de direccion, tensiones logicas,
 *        pull-ups, velocidad de bus y comunicacion basica.
 *
 * Dependencias:
 *   - SparkFun BNO08x Arduino Library (SparkFun_BNO08x_Arduino_Library)
 *   - Wire (incluida en el core de Arduino / Mbed OS nRF52)
 *
 * Uso:
 *   1. Compilar y subir al XIAO nRF52840 Sense.
 *   2. Abrir Serial Monitor a 115200 baud.
 *   3. Leer cada seccion del informe y seguir las recomendaciones.
 */

#include <Wire.h>
#include <SparkFun_BNO08x_Arduino_Library.h>

// ============================================================
// CONFIGURACION
// ============================================================

// Pines I2C del XIAO nRF52840 Sense (puede forzarlos si el core los ignora)
// SDA = P0.04 (pin 4), SCL = P0.05 (pin 5)  <-- defaults del core
// Si usas pines alternativos, cambia aqui:
#define I2C_SDA   4
#define I2C_SCL   5

// Direcciones posibles del BNO085 segun nivel de AD0/PS1
#define ADDR_BNO085_LOW   0x4A   // AD0 = GND (default)
#define ADDR_BNO085_HIGH  0x4B   // AD0 = VCC

// Velocidades de bus a probar (Hz)
const uint32_t I2C_SPEEDS[] = {100000UL, 400000UL};
const uint8_t  N_SPEEDS = 2;

// Numero de intentos de scan por velocidad
#define SCAN_ATTEMPTS  3

// ============================================================
// OBJETOS
// ============================================================
BNO08x imu;

// ============================================================
// UTILIDADES
// ============================================================

void separador(char c = '-', uint8_t n = 50) {
  for (uint8_t i = 0; i < n; i++) Serial.print(c);
  Serial.println();
}

void titulo(const char* texto) {
  Serial.println();
  separador('=');
  Serial.println(texto);
  separador('=');
}

// Retorna true si el dispositivo ACK en esa direccion
bool probeAddress(uint8_t addr) {
  Wire.beginTransmission(addr);
  return (Wire.endTransmission() == 0);
}

// ============================================================
// MODULO 1 — SCAN COMPLETO DEL BUS I2C
// ============================================================

void scanBus(uint32_t speed) {
  Wire.setClock(speed);
  Serial.print("  Bus clock: ");
  Serial.print(speed / 1000);
  Serial.println(" kHz");

  uint8_t found = 0;
  Serial.print("  Dispositivos encontrados: ");

  for (uint8_t addr = 1; addr < 127; addr++) {
    if (probeAddress(addr)) {
      Serial.print("0x");
      if (addr < 16) Serial.print("0");
      Serial.print(addr, HEX);
      Serial.print(" ");
      found++;
    }
  }

  if (found == 0) {
    Serial.print("[NINGUNO]");
  }
  Serial.println();
  Serial.print("  Total: ");
  Serial.println(found);
}

void moduloScanBus() {
  titulo("MODULO 1: SCAN COMPLETO DEL BUS I2C");
  Serial.println("Buscando dispositivos en el bus a diferentes velocidades...");

  for (uint8_t s = 0; s < N_SPEEDS; s++) {
    Serial.println();
    scanBus(I2C_SPEEDS[s]);
  }

  Serial.println();
  Serial.println("INTERPRETACION:");
  Serial.println("  - Si no aparece ninguna direccion: problema de cableado o pull-ups.");
  Serial.println("  - Si aparece 0x4A o 0x4B: BNO085 detectado en bus.");
  Serial.println("  - Si aparece solo a 100kHz pero no a 400kHz: problema de calidad de senial.");
}

// ============================================================
// MODULO 2 — VERIFICACION DE DIRECCION BNO085
// ============================================================

void moduloDireccion() {
  titulo("MODULO 2: VERIFICACION DE DIRECCION BNO085");
  Wire.setClock(100000UL);

  bool encontrado4A = false;
  bool encontrado4B = false;

  // Varios intentos para descartar errores transitorios
  for (uint8_t intento = 0; intento < SCAN_ATTEMPTS; intento++) {
    if (probeAddress(ADDR_BNO085_LOW))  encontrado4A = true;
    if (probeAddress(ADDR_BNO085_HIGH)) encontrado4B = true;
    delay(10);
  }

  Serial.print("  0x4A (AD0/PS1 = GND): ");
  Serial.println(encontrado4A ? "ENCONTRADO" : "no encontrado");
  Serial.print("  0x4B (AD0/PS1 = VCC): ");
  Serial.println(encontrado4B ? "ENCONTRADO" : "no encontrado");

  Serial.println();
  Serial.println("INTERPRETACION:");
  if (!encontrado4A && !encontrado4B) {
    Serial.println("  [ERROR] BNO085 no responde en ninguna direccion.");
    Serial.println("  Causas probables:");
    Serial.println("    1. Cable SDA o SCL desconectado o en mal contacto.");
    Serial.println("    2. VCC/3.3V del sensor no presente (mide con multimetro).");
    Serial.println("    3. Pull-ups faltantes o demasiado debiles (>10k ohm).");
    Serial.println("    4. Pin NRST del BNO085 en bajo — necesita al menos 10ms en alto.");
    Serial.println("    5. Interfaz I2C no habilitada en el sensor (PS0/PS1 mal configurados).");
    Serial.println("    6. Sensor danado.");
  } else if (encontrado4A && !encontrado4B) {
    Serial.println("  [OK] BNO085 responde en 0x4A. AD0/PS1 = GND (correcto por defecto).");
    Serial.println("  Si el sketch principal usa 0x4B, cambia la direccion en el codigo.");
  } else if (!encontrado4A && encontrado4B) {
    Serial.println("  [OK] BNO085 responde en 0x4B. AD0/PS1 = VCC.");
    Serial.println("  Si el sketch principal usa 0x4A, cambia la direccion en el codigo.");
  } else {
    Serial.println("  [INFO] Responde en ambas direcciones (poco probable; verifica parasitos).");
  }
}

// ============================================================
// MODULO 3 — VERIFICACION DE CONFIGURACION PS0/PS1
// ============================================================

void moduloPS0PS1() {
  titulo("MODULO 3: CONFIGURACION DE INTERFAZ (PS0 / PS1)");
  Serial.println("El BNO085 selecciona el protocolo segun PS0 y PS1:");
  Serial.println();
  Serial.println("  PS1=0, PS0=0  => I2C   (AD0=GND => 0x4A)");
  Serial.println("  PS1=0, PS0=1  => UART-RVC");
  Serial.println("  PS1=1, PS0=0  => SPI");
  Serial.println("  PS1=1, PS0=1  => I2C   (AD0=VCC => 0x4B)");
  Serial.println();
  Serial.println("ACCION: Verifica con multimetro que PS0 este en 0 (GND) y PS1 en 0 (GND)");
  Serial.println("para usar I2C con direccion 0x4A.");
  Serial.println("Muchos modulos breakout tienen PS0/PS1 controlados por jumpers o resistencias.");
  Serial.println("En el modulo Adafruit BNO085: SA0 controla AD0 (la LSB de la direccion).");
}

// ============================================================
// MODULO 4 — PRUEBA DE RESET Y TIEMPO DE ARRANQUE
// ============================================================

void moduloReset() {
  titulo("MODULO 4: PRUEBA DE RESET Y TIEMPO DE ARRANQUE");
  Serial.println("El BNO085 necesita ~400ms tras el reset para estar listo.");
  Serial.println("Probando con delays de 100ms, 300ms y 600ms...");

  const uint16_t delays[] = {100, 300, 600};
  for (uint8_t i = 0; i < 3; i++) {
    Wire.setClock(100000UL);
    // Simula un ciclo de encendido esperando el tiempo indicado
    delay(delays[i]);
    bool ok = probeAddress(ADDR_BNO085_LOW) || probeAddress(ADDR_BNO085_HIGH);
    Serial.print("  Delay ");
    Serial.print(delays[i]);
    Serial.print("ms => BNO085 accesible: ");
    Serial.println(ok ? "SI" : "NO");
  }

  Serial.println();
  Serial.println("INTERPRETACION:");
  Serial.println("  Si responde con 600ms pero no con 100ms: aumenta el delay de inicio");
  Serial.println("  en tu sketch principal (agregar delay(600) antes de imu.begin()).");
}

// ============================================================
// MODULO 5 — PRUEBA DE INICIALIZACION CON LIBRERIA SPARKFUN
// ============================================================

void moduloInicializacion() {
  titulo("MODULO 5: INICIALIZACION CON LIBRERIA SPARKFUN BNO08x");
  Wire.setClock(400000UL);
  delay(600);

  Serial.println("Intentando imu.begin() en 0x4A ...");
  bool ok4A = imu.begin(ADDR_BNO085_LOW, Wire);
  Serial.print("  begin(0x4A): ");
  Serial.println(ok4A ? "EXITO" : "FALLO");

  if (!ok4A) {
    Serial.println("Intentando imu.begin() en 0x4B ...");
    bool ok4B = imu.begin(ADDR_BNO085_HIGH, Wire);
    Serial.print("  begin(0x4B): ");
    Serial.println(ok4B ? "EXITO" : "FALLO");

    if (!ok4B) {
      Serial.println();
      Serial.println("  [ERROR] La libreria no pudo inicializar el sensor.");
      Serial.println("  Verifica los modulos anteriores antes de continuar.");
    } else {
      Serial.println();
      Serial.println("  [OK] Sensor inicializado en 0x4B.");
      Serial.println("  Cambia la direccion en tu sketch principal a 0x4B.");
    }
  } else {
    Serial.println();
    Serial.println("  [OK] Sensor inicializado correctamente en 0x4A.");

    // Lectura rapida de version de producto
    Serial.println("  Habilitando reporte de acelerometro por 5 lecturas...");
    imu.enableAccelerometer(50);  // 50ms de reporte

    uint8_t lecturas = 0;
    uint32_t t0 = millis();
    while (lecturas < 5 && millis() - t0 < 3000) {
      if (imu.wasReset()) {
        imu.enableAccelerometer(50);
      }
      if (imu.getSensorEvent()) {
        if (imu.getSensorEventID() == SENSOR_REPORTID_ACCELEROMETER) {
          Serial.print("  Acel [");
          Serial.print(lecturas + 1);
          Serial.print("] x=");
          Serial.print(imu.getAccelX(), 3);
          Serial.print(" y=");
          Serial.print(imu.getAccelY(), 3);
          Serial.print(" z=");
          Serial.print(imu.getAccelZ(), 3);
          Serial.println(" m/s2");
          lecturas++;
        }
      }
    }
    if (lecturas == 0) {
      Serial.println("  [AVISO] No se recibieron datos de acelerometro en 3 segundos.");
    }
  }
}

// ============================================================
// MODULO 6 — LECTURA RAW I2C DEL REGISTRO PRODUCT ID
// ============================================================

void moduloProductID() {
  titulo("MODULO 6: LECTURA RAW DEL PRODUCT ID (SHTP)");
  Serial.println("Enviando comando SHTP para obtener Product ID del BNO085...");

  Wire.setClock(100000UL);
  delay(100);

  // El BNO085 usa SHTP sobre I2C. El primer paquete tras encendido
  // es el Product ID response en el canal 2 (executable).
  // Aqui leemos los primeros bytes disponibles como sanity check.

  uint8_t buf[16];
  uint8_t addr = ADDR_BNO085_LOW;

  // Si 0x4A no responde, prueba con 0x4B
  if (!probeAddress(addr)) {
    addr = ADDR_BNO085_HIGH;
  }

  if (!probeAddress(addr)) {
    Serial.println("  [ERROR] No hay ACK del sensor. Omitiendo lectura raw.");
    return;
  }

  // Pedir Product ID: enviar header SHTP (longitud 4, canal 2, seq 0) + cmd 0xF9
  uint8_t cmd[] = {0x05, 0x00, 0x02, 0x00, 0xF9};
  Wire.beginTransmission(addr);
  for (uint8_t i = 0; i < 5; i++) Wire.write(cmd[i]);
  uint8_t err = Wire.endTransmission(false);  // repeated start

  Serial.print("  endTransmission (0=OK): ");
  Serial.println(err);

  delay(50);

  // Leer respuesta
  Wire.requestFrom((uint8_t)addr, (uint8_t)16);
  uint8_t n = 0;
  while (Wire.available() && n < 16) {
    buf[n++] = Wire.read();
  }

  Serial.print("  Bytes recibidos: ");
  Serial.println(n);
  Serial.print("  Datos (hex): ");
  for (uint8_t i = 0; i < n; i++) {
    if (buf[i] < 16) Serial.print("0");
    Serial.print(buf[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  if (n >= 4) {
    uint16_t longitud = (uint16_t)buf[0] | ((uint16_t)(buf[1] & 0x7F) << 8);
    Serial.print("  SHTP longitud de paquete declarada: ");
    Serial.println(longitud);
  }

  Serial.println();
  Serial.println("INTERPRETACION:");
  Serial.println("  - endTransmission != 0: el sensor no acusa recibo (sin pull-ups, sin VCC).");
  Serial.println("  - Bytes recibidos = 0:  el sensor no envio datos (fallo SHTP o reset).");
  Serial.println("  - Datos con patron 0x28: Product ID del BNO085 confirmado.");
}

// ============================================================
// MODULO 7 — RESUMEN DE CHECKLIST DE HARDWARE
// ============================================================

void moduloChecklist() {
  titulo("MODULO 7: CHECKLIST DE HARDWARE");
  Serial.println("Verifica manualmente los siguientes puntos:");
  Serial.println();
  Serial.println("  [ ] VCC del BNO085 conectado a 3.3V del XIAO (NO a 5V).");
  Serial.println("  [ ] GND del BNO085 conectado al GND del XIAO.");
  Serial.println("  [ ] SDA del BNO085 conectado al pin SDA del XIAO (D4/P0.04).");
  Serial.println("  [ ] SCL del BNO085 conectado al pin SCL del XIAO (D5/P0.05).");
  Serial.println("  [ ] Pull-up de 4.7k ohm entre SDA y 3.3V.");
  Serial.println("  [ ] Pull-up de 4.7k ohm entre SCL y 3.3V.");
  Serial.println("      (algunos breakouts las incluyen internamente; verifica el esquematico).");
  Serial.println("  [ ] Pin NRST del BNO085 en alto (3.3V) o sin conectar.");
  Serial.println("  [ ] PS0 = GND y PS1 = GND para seleccionar modo I2C.");
  Serial.println("  [ ] Longitud de cables < 20cm para evitar degradacion de senial.");
  Serial.println("  [ ] No hay otros dispositivos I2C que compartan la misma direccion.");
  Serial.println();
  Serial.println("Para el XIAO nRF52840 Sense especificamente:");
  Serial.println("  [ ] Asegurate de llamar Wire.begin() ANTES de setClock().");
  Serial.println("  [ ] El core Mbed OS puede requerir Wire.begin(SDA, SCL) con pines explicitos.");
  Serial.println("  [ ] Si usas el conector Qwiic (JST-SH 4-pin), el orden es: GND-VCC-SDA-SCL.");
}

// ============================================================
// SETUP & LOOP
// ============================================================

void setup() {
  Serial.begin(115200);
  // Esperar hasta 5 segundos a que abra el Serial Monitor
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 5000);

  Serial.println();
  Serial.println("***********************************************");
  Serial.println("  DIAGNOSTICO I2C - BNO085 + XIAO nRF52840   ");
  Serial.println("***********************************************");
  Serial.println("Fecha de compilacion: " __DATE__ " " __TIME__);

  // Inicializar bus I2C con pines explicitos
  Wire.begin();          // usa pines por defecto del core
  // Si los pines por defecto no funcionan, descomenta la siguiente linea:
  // Wire.begin(I2C_SDA, I2C_SCL);

  Wire.setClock(100000UL);
  delay(600);  // Tiempo de arranque del BNO085

  // Ejecutar todos los modulos de diagnostico
  moduloScanBus();
  moduloDireccion();
  moduloPS0PS1();
  moduloReset();
  moduloInicializacion();
  moduloProductID();
  moduloChecklist();

  titulo("DIAGNOSTICO COMPLETADO");
  Serial.println("Revisa cada seccion arriba y sigue las indicaciones.");
  Serial.println("Si el problema persiste tras verificar el hardware,");
  Serial.println("considera probar con otro BNO085 o con un logic analyzer.");
}

void loop() {
  // No hace nada; el diagnostico se ejecuta una sola vez en setup()
  delay(1000);
}
