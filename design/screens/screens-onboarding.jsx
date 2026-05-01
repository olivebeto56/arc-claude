// ARC — Onboarding + Home screens

const SCREEN_W = 393; // iPhone 15 Pro
const SCREEN_H = 852;

// ─── 1. SPLASH ─────────────────────────────────────────────
function ScreenSplash() {
  const c = TOKENS.color;
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      position: 'relative',
    }}>
      {/* Center logo */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32 }}>
        <ARCLogo height={56}/>
        <div style={{
          fontSize: 13, color: c.text3, letterSpacing: '0.08em',
          textTransform: 'uppercase', fontWeight: 400,
        }}>Tu técnica, en tiempo real</div>
      </div>

      {/* Loading indicator */}
      <div style={{
        position: 'absolute', bottom: 100,
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14,
      }}>
        <div style={{
          width: 32, height: 1, background: c.border, position: 'relative', overflow: 'hidden',
        }}>
          <div style={{
            position: 'absolute', height: '100%', width: 12, background: c.accent,
            animation: 'arc-loader 1.4s infinite ease-in-out',
          }}/>
        </div>
      </div>

      {/* Version */}
      <div style={{
        position: 'absolute', bottom: 50,
        fontSize: 10, color: c.text3, letterSpacing: '0.08em',
        fontFamily: 'var(--font-mono)',
      }}>v1.0.0 · build 247</div>

      <style>{`
        @keyframes arc-loader {
          0% { left: -12px; } 50% { left: 50%; } 100% { left: 100%; }
        }
      `}</style>
    </div>
  );
}

// ─── 2. PERMISOS ───────────────────────────────────────────
function ScreenPermisos() {
  const c = TOKENS.color;
  const Permission = ({ icon, title, desc, status }) => {
    const stColor = status === 'granted' ? c.ok : status === 'denied' ? c.crit : c.text3;
    return (
      <div style={{
        display: 'flex', alignItems: 'flex-start', gap: 14, padding: 18,
        background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
      }}>
        <div style={{
          width: 40, height: 40, borderRadius: 10, background: c.surfaceHi,
          border: `1px solid ${c.border}`, color: c.accent,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          {icon({ width: 20, height: 20 })}
        </div>
        <div style={{ flex: 1, paddingTop: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
            <div style={{ fontSize: 15, fontWeight: 500, color: c.text }}>{title}</div>
            <Caption color={stColor}>
              {status === 'granted' ? 'Concedido' : status === 'denied' ? 'Denegado' : 'Pendiente'}
            </Caption>
          </div>
          <div style={{ fontSize: 12.5, color: c.text2, lineHeight: 1.5 }}>{desc}</div>
        </div>
      </div>
    );
  };

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <div style={{ padding: '32px 24px 0', flex: 1 }}>
        <Caption style={{ marginBottom: 8 }}>Paso 1 de 2</Caption>
        <h1 style={{
          fontSize: 26, fontWeight: 500, letterSpacing: '-0.02em', margin: '0 0 10px',
          lineHeight: 1.15, maxWidth: 280,
        }}>Necesitamos algunos permisos</h1>
        <p style={{ fontSize: 14, color: c.text2, lineHeight: 1.55, margin: '0 0 32px', maxWidth: 320 }}>
          ARC necesita conectarse a tus bandas y conocer tu ubicación para registrar la sesión.
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <Permission icon={Icon.bluetooth} title="Bluetooth"
            desc="Para conectar las bandas SportBand-L y SportBand-R en tus tobillos."
            status="granted"/>
          <Permission icon={Icon.location} title="Ubicación"
            desc="Para registrar tu ruta y calcular distancia y ritmo reales con GPS."
            status="pending"/>
        </div>

        <button style={{
          marginTop: 20, background: 'transparent', border: 'none', color: c.text2,
          fontSize: 13, padding: 0, cursor: 'pointer', textDecoration: 'underline',
          textDecorationColor: c.border, textUnderlineOffset: 4,
        }}>¿Por qué los necesitamos?</button>
      </div>

      <div style={{ padding: '20px 24px 40px' }}>
        <ARCButton kind="primary" full>CONTINUAR</ARCButton>
      </div>
    </div>
  );
}

// ─── 3. SCAN & CONNECT ────────────────────────────────────
function ScreenScan() {
  const c = TOKENS.color;
  const NodeCard = ({ side, name, rssi, battery, status }) => {
    const stColor = status === 'connected' ? c.ok : status === 'searching' ? c.accent : c.text3;
    const stLabel = status === 'connected' ? 'Conectado' : status === 'searching' ? 'Buscando…' : 'Esperando';
    return (
      <div style={{
        background: c.surface, border: `1px solid ${status === 'connected' ? c.accent : c.border}`,
        borderRadius: 14, padding: 16,
        boxShadow: status === 'connected' ? `0 0 0 3px ${c.accentDim}` : 'none',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18, background: c.surfaceHi,
              border: `1px solid ${c.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: c.accent, fontSize: 13, fontWeight: 500,
            }}>{side}</div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>SportBand-{side}</div>
              <div style={{ fontSize: 11, color: c.text3, fontFamily: 'var(--font-mono)' }}>{name}</div>
            </div>
          </div>
          {status === 'searching' ? (
            <div style={{
              width: 14, height: 14, border: `2px solid ${c.border}`,
              borderTopColor: c.accent, borderRadius: '50%',
              animation: 'arc-spin 0.8s linear infinite',
            }}/>
          ) : status === 'connected' ? (
            <Dot color={c.ok} size={8} glow/>
          ) : <Dot color={c.text3} size={8}/>}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 11, color: c.text2 }}>
          <span>RSSI {rssi} dBm</span>
          {battery !== null ? <BatteryReading pct={battery}/> : <span style={{ color: c.text3 }}>—</span>}
          <span style={{ color: stColor, fontWeight: 500 }}>{stLabel}</span>
        </div>
      </div>
    );
  };

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <div style={{ padding: '32px 24px 0', flex: 1 }}>
        <Caption style={{ marginBottom: 8 }}>Paso 2 de 2</Caption>
        <h1 style={{
          fontSize: 26, fontWeight: 500, letterSpacing: '-0.02em', margin: '0 0 10px',
          lineHeight: 1.15,
        }}>Conecta tus bandas</h1>
        <p style={{ fontSize: 14, color: c.text2, lineHeight: 1.55, margin: '0 0 28px', maxWidth: 320 }}>
          Coloca SportBand-L en tu tobillo izquierdo y SportBand-R en el derecho.
          Mantén el celular cerca durante el escaneo.
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 24 }}>
          <NodeCard side="L" name="A4:C1:38:7B:21" rssi={-58} battery={87} status="connected"/>
          <NodeCard side="R" name="A4:C1:38:7B:9F" rssi={-65} battery={null} status="searching"/>
        </div>

        {/* Discarded list (collapsed) */}
        <div style={{
          padding: '12px 14px', background: c.surfaceHi, border: `1px solid ${c.border}`,
          borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          fontSize: 12, color: c.text2,
        }}>
          <span>3 dispositivos descartados</span>
          <span style={{ color: c.text3 }}>{Icon.chevR({ width: 14, height: 14 })}</span>
        </div>
      </div>

      <div style={{ padding: '20px 24px 40px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <ARCButton kind="secondary" full>REESCANEAR</ARCButton>
        <ARCButton kind="primary" full disabled style={{ opacity: 0.4 }}>CONTINUAR</ARCButton>
      </div>

      <style>{`@keyframes arc-spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

// ─── 0. HOME — Variation A: Atlético / energético (default) ────
function ScreenHomeA() {
  const c = TOKENS.color;
  const scoreData = [68, 71, 65, 74, 78, 82];
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      {/* Top bar */}
      <ARCTopBar
        left={<ARCLogo height={18}/>}
        right={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer' }}>
            {Icon.settings({ width: 22, height: 22 })}
          </button>
        }
      />

      <div style={{ padding: '8px 20px 20px', flex: 1, overflow: 'auto' }}>
        {/* Greeting */}
        <div style={{ marginBottom: 22 }}>
          <Caption style={{ marginBottom: 6 }}>Lunes · 16:42</Caption>
          <h1 style={{ fontSize: 28, fontWeight: 500, letterSpacing: '-0.02em', margin: 0, lineHeight: 1.1 }}>
            Hola, Alberto
          </h1>
        </div>

        {/* Stats line */}
        <div style={{ display: 'flex', gap: 0, marginBottom: 18 }}>
          {[
            { v: '47', l: 'sesiones' },
            { v: '218', l: 'km totales' },
            { v: '12', l: 'racha días' },
          ].map((s, i) => (
            <div key={i} style={{
              flex: 1, paddingLeft: i === 0 ? 0 : 14,
              borderLeft: i > 0 ? `1px solid ${c.border}` : 'none',
            }}>
              <div style={{ fontSize: 22, fontWeight: 500, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{s.v}</div>
              <Caption style={{ marginTop: 4 }}>{s.l}</Caption>
            </div>
          ))}
        </div>

        {/* Promedios card */}
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
          padding: 16, marginBottom: 12,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <Caption>Promedios — últimas 10</Caption>
            <Sparkline data={scoreData} w={50} h={16}/>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {[
              { v: '178', u: 'spm', l: 'Cadencia' },
              { v: '49 / 51', u: '%', l: 'Simetría L / R' },
              { v: '232', u: 'ms', l: 'GCT' },
              { v: '78', u: '/100', l: 'Score técnico' },
            ].map((m, i) => (
              <div key={i}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                  <span style={{ fontSize: 22, fontWeight: 500, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em' }}>{m.v}</span>
                  <span style={{ fontSize: 11, color: c.text3 }}>{m.u}</span>
                </div>
                <Caption style={{ marginTop: 4 }}>{m.l}</Caption>
              </div>
            ))}
          </div>
        </div>

        {/* Recommendation card */}
        <div style={{
          background: c.surface, border: `1px solid ${c.accent}`,
          borderLeft: `3px solid ${c.accent}`, borderRadius: 14,
          padding: 16, marginBottom: 12,
          boxShadow: `0 0 0 3px ${c.accentDim}`,
        }}>
          <Caption color={c.accent} style={{ marginBottom: 8 }}>Recomendación · histórico</Caption>
          <div style={{ fontSize: 14.5, color: c.text, lineHeight: 1.45, fontWeight: 400 }}>
            Tu pierna izquierda carga 3% más que la derecha en las últimas 6 sesiones.
            Hoy enfócate en mantener simetría sobre los 50/50.
          </div>
        </div>

        {/* Bands */}
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
          padding: 14, marginBottom: 14,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <Caption>Bandas conectadas</Caption>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: c.ok }}>
              <Dot color={c.ok} glow size={6}/> Listo para correr
            </span>
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            {[{ s: 'L', b: 87 }, { s: 'R', b: 92 }].map(({ s, b }) => (
              <div key={s} style={{
                flex: 1, padding: 10, background: c.surfaceHi, borderRadius: 10,
                border: `1px solid ${c.border}`,
                display: 'flex', alignItems: 'center', gap: 10,
              }}>
                <div style={{
                  width: 30, height: 30, borderRadius: 15, background: c.bg,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: c.accent, fontSize: 13, fontWeight: 500,
                  border: `1px solid ${c.border}`,
                }}>{s}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12, fontWeight: 500 }}>SportBand-{s}</div>
                  <BatteryReading pct={b}/>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Session type selector */}
        <Segmented
          options={[
            { value: 'libre', label: 'Libre' },
            { value: 'tiempo', label: 'Tiempo' },
            { value: 'distancia', label: 'Distancia' },
          ]}
          value="libre"
        />
      </div>

      {/* Bottom bar */}
      <div style={{ padding: '12px 20px 38px', display: 'flex', gap: 10, alignItems: 'stretch' }}>
        <ARCButton kind="secondary" style={{ width: 100 }}>HISTORIAL</ARCButton>
        <ARCButton kind="primary" full style={{
          boxShadow: `0 0 32px ${c.accentDim2}`,
          letterSpacing: '0.06em',
        }}>INICIAR SESIÓN</ARCButton>
      </div>
    </div>
  );
}

// ─── 0. HOME — Variation B: Hero score ────────────────────
function ScreenHomeB() {
  const c = TOKENS.color;
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={<ARCLogo height={18}/>}
        right={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer' }}>
            {Icon.settings({ width: 22, height: 22 })}
          </button>
        }
      />

      <div style={{ padding: '8px 20px 20px', flex: 1, overflow: 'auto' }}>
        <div style={{ marginBottom: 18 }}>
          <Caption style={{ marginBottom: 6 }}>Hola, Alberto</Caption>
          <div style={{ fontSize: 13, color: c.text2 }}>
            Llevas <span style={{ color: c.text }}>12 días</span> de racha.
          </div>
        </div>

        {/* Hero score */}
        <div style={{
          background: `radial-gradient(ellipse at 50% 0%, ${c.accentDim} 0%, transparent 70%), ${c.surface}`,
          border: `1px solid ${c.border}`, borderRadius: 18,
          padding: '32px 20px 24px', marginBottom: 12,
          textAlign: 'center', position: 'relative', overflow: 'hidden',
        }}>
          <Caption style={{ marginBottom: 14 }}>Score técnico · promedio</Caption>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6 }}>
            <span style={{
              fontSize: 88, fontWeight: 300, lineHeight: 1, letterSpacing: '-0.04em',
              color: c.accent, fontVariantNumeric: 'tabular-nums',
              textShadow: `0 0 40px ${c.accentDim2}`,
            }}>78</span>
            <span style={{ fontSize: 22, color: c.text3, fontWeight: 300 }}>/100</span>
          </div>
          <div style={{ marginTop: 6, fontSize: 12, color: c.ok, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5 }}>
            {Icon.trend({ width: 12, height: 12 })} +4 esta semana
          </div>
          <div style={{ marginTop: 18 }}>
            <Sparkline data={[68,71,65,74,78,82]} w={120} h={28} color={c.accent}/>
          </div>
        </div>

        {/* Quick metrics row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 12 }}>
          {[
            { v: '178', u: 'spm', l: 'Cadencia' },
            { v: '49/51', u: '', l: 'Simetría' },
            { v: '232', u: 'ms', l: 'GCT' },
          ].map((m, i) => (
            <div key={i} style={{
              background: c.surface, border: `1px solid ${c.border}`, borderRadius: 12,
              padding: 12, textAlign: 'center',
            }}>
              <div style={{ fontSize: 18, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{m.v}</div>
              <div style={{ fontSize: 9.5, color: c.text3, marginTop: 2 }}>{m.u}</div>
              <Caption style={{ marginTop: 4, fontSize: 9 }}>{m.l}</Caption>
            </div>
          ))}
        </div>

        {/* Recommendation */}
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`,
          borderLeft: `3px solid ${c.accent}`, borderRadius: 12,
          padding: 14, marginBottom: 12,
        }}>
          <Caption color={c.accent} style={{ marginBottom: 6 }}>Hoy</Caption>
          <div style={{ fontSize: 13.5, color: c.text, lineHeight: 1.5 }}>
            Carga 3% mayor en pierna izquierda. Enfócate en simetría 50/50.
          </div>
        </div>

        {/* Bands compact */}
        <div style={{
          display: 'flex', gap: 8, padding: 12,
          background: c.surface, border: `1px solid ${c.border}`, borderRadius: 12,
          marginBottom: 12, alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Dot color={c.ok} glow size={7}/>
            <span style={{ fontSize: 12.5, fontWeight: 500 }}>Bandas listas</span>
          </div>
          <div style={{ display: 'flex', gap: 12, fontSize: 11, color: c.text2 }}>
            <span>L 87%</span><span>R 92%</span>
          </div>
        </div>

        <Segmented
          options={[
            { value: 'libre', label: 'Libre' },
            { value: 'tiempo', label: 'Tiempo' },
            { value: 'distancia', label: 'Distancia' },
          ]}
          value="libre"
        />
      </div>

      <div style={{ padding: '12px 20px 38px', display: 'flex', gap: 10 }}>
        <ARCButton kind="secondary" style={{ width: 100 }}>HISTORIAL</ARCButton>
        <ARCButton kind="primary" full style={{ boxShadow: `0 0 32px ${c.accentDim2}` }}>INICIAR SESIÓN</ARCButton>
      </div>
    </div>
  );
}

// ─── 0. HOME — Variation C: Editorial / minimal ────────────
function ScreenHomeC() {
  const c = TOKENS.color;
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={<ARCLogo height={18}/>}
        right={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer' }}>
            {Icon.settings({ width: 22, height: 22 })}
          </button>
        }
      />

      <div style={{ padding: '24px 28px 20px', flex: 1, overflow: 'auto' }}>
        {/* Big editorial greeting */}
        <div style={{ marginBottom: 36 }}>
          <Caption style={{ marginBottom: 12 }}>16 · Junio · 2025</Caption>
          <h1 style={{
            fontSize: 38, fontWeight: 200, letterSpacing: '-0.03em', margin: 0,
            lineHeight: 1.05, color: c.text,
          }}>
            Hola,<br/>
            <span style={{ fontStyle: 'italic', fontWeight: 300 }}>Alberto.</span>
          </h1>
        </div>

        {/* Number strip */}
        <div style={{ marginBottom: 32 }}>
          <Caption color={c.text3} style={{ marginBottom: 10 }}>Tu última sesión</Caption>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 16 }}>
            <span style={{ fontSize: 56, fontWeight: 200, color: c.accent, lineHeight: 1, letterSpacing: '-0.04em', fontVariantNumeric: 'tabular-nums' }}>82</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 11, color: c.text2 }}>Score · sábado</div>
              <div style={{ fontSize: 11, color: c.ok, marginTop: 2 }}>+4 vs media</div>
            </div>
            <Sparkline data={[68,71,65,74,78,82]} w={50} h={22} color={c.accent}/>
          </div>
        </div>

        {/* Editorial recommendation */}
        <div style={{
          padding: '20px 0', borderTop: `1px solid ${c.border}`, borderBottom: `1px solid ${c.border}`,
          marginBottom: 28,
        }}>
          <Caption color={c.accent} style={{ marginBottom: 10 }}>Para hoy</Caption>
          <div style={{ fontSize: 18, fontWeight: 300, lineHeight: 1.4, letterSpacing: '-0.01em', color: c.text }}>
            Tu pierna izquierda carga <span style={{ color: c.accent, fontWeight: 400 }}>3% más</span>.
            Mantén simetría 50/50 hoy.
          </div>
        </div>

        {/* Stats — minimal table */}
        <div style={{ marginBottom: 24 }}>
          <Caption color={c.text3} style={{ marginBottom: 10 }}>Promedios · últimas 10</Caption>
          {[
            { l: 'Cadencia', v: '178', u: 'spm' },
            { l: 'Simetría', v: '49/51', u: '%' },
            { l: 'GCT', v: '232', u: 'ms' },
          ].map((m, i, arr) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
              padding: '12px 0',
              borderBottom: i < arr.length - 1 ? `1px solid ${c.border}` : 'none',
            }}>
              <span style={{ fontSize: 13, color: c.text2 }}>{m.l}</span>
              <span>
                <span style={{ fontSize: 18, fontWeight: 400, fontVariantNumeric: 'tabular-nums' }}>{m.v}</span>
                <span style={{ fontSize: 10, color: c.text3, marginLeft: 4 }}>{m.u}</span>
              </span>
            </div>
          ))}
        </div>

        {/* Bands — minimal */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 12, color: c.text2 }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Dot color={c.ok} glow size={6}/> Bandas listas
          </span>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 10 }}>L 87% · R 92%</span>
        </div>
      </div>

      <div style={{ padding: '16px 28px 38px' }}>
        <ARCButton kind="primary" full style={{ boxShadow: `0 0 32px ${c.accentDim2}`, letterSpacing: '0.08em' }}>
          INICIAR SESIÓN →
        </ARCButton>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenSplash, ScreenPermisos, ScreenScan,
  ScreenHomeA, ScreenHomeB, ScreenHomeC,
  SCREEN_W, SCREEN_H,
});
