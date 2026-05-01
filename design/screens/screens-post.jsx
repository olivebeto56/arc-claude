// ARC — Post-session + auxiliary screens

// ─── 7. SESSION SUMMARY ───────────────────────────────────
function ScreenSummary() {
  const c = TOKENS.color;
  // Score circle: 82
  const score = 82;
  const circumference = 2 * Math.PI * 56;
  const dash = (score / 100) * circumference;

  // Cadencia time series
  const cadenceData = [172, 175, 178, 180, 182, 178, 176, 179, 181, 178, 175, 178];
  const buildSparkPath = (data, w, h, pad = 0) => {
    const min = Math.min(...data), max = Math.max(...data);
    const range = max - min || 1;
    return data.map((v, i) => {
      const x = pad + (i / (data.length - 1)) * (w - pad * 2);
      const y = h - pad - ((v - min) / range) * (h - pad * 2);
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');
  };

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer', display: 'flex' }}>
            {Icon.chevL({ width: 22, height: 22 })}
          </button>
        }
        right={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer', display: 'flex' }}>
            {Icon.share({ width: 20, height: 20 })}
          </button>
        }
      />

      <div style={{ flex: 1, overflow: 'auto', padding: '8px 20px 20px' }}>
        {/* Header */}
        <div style={{ marginBottom: 20 }}>
          <Caption style={{ marginBottom: 6 }}>Sábado 14 · junio · 17:34</Caption>
          <h1 style={{
            fontSize: 26, fontWeight: 500, letterSpacing: '-0.02em', margin: '0 0 12px',
            lineHeight: 1.1,
          }}>Sesión completada</h1>
          <div style={{ display: 'flex', gap: 18, fontSize: 13, color: c.text2 }}>
            <span><span style={{ color: c.text, fontWeight: 500 }}>32:18</span> tiempo</span>
            <span style={{ color: c.border }}>·</span>
            <span><span style={{ color: c.text, fontWeight: 500 }}>5.78</span> km</span>
            <span style={{ color: c.border }}>·</span>
            <span><span style={{ color: c.text, fontWeight: 500 }}>5:35</span> /km</span>
          </div>
        </div>

        {/* Score circle */}
        <div style={{
          background: `radial-gradient(ellipse at 50% 50%, ${c.accentDim} 0%, transparent 65%), ${c.surface}`,
          border: `1px solid ${c.border}`, borderRadius: 18,
          padding: 24, marginBottom: 12, display: 'flex', alignItems: 'center', gap: 24,
        }}>
          <div style={{ position: 'relative', width: 130, height: 130, flexShrink: 0 }}>
            <svg width="130" height="130" viewBox="0 0 130 130" style={{ transform: 'rotate(-90deg)' }}>
              <circle cx="65" cy="65" r="56" stroke={c.surfaceHi} strokeWidth="6" fill="none"/>
              <circle cx="65" cy="65" r="56" stroke={c.accent} strokeWidth="6" fill="none"
                strokeLinecap="round"
                strokeDasharray={`${dash} ${circumference}`}
                style={{ filter: `drop-shadow(0 0 8px ${c.accent})` }}/>
            </svg>
            <div style={{
              position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{
                fontSize: 44, fontWeight: 300, color: c.accent, lineHeight: 1, letterSpacing: '-0.03em',
                fontVariantNumeric: 'tabular-nums',
              }}>{score}</div>
              <div style={{ fontSize: 10, color: c.text3, marginTop: 2 }}>/ 100</div>
            </div>
          </div>
          <div style={{ flex: 1 }}>
            <Caption color={c.accent} style={{ marginBottom: 6 }}>Score técnico</Caption>
            <div style={{ fontSize: 14, color: c.text, lineHeight: 1.4, marginBottom: 8, fontWeight: 400 }}>
              Excelente sesión. Cadencia y GCT en óptimo.
            </div>
            <div style={{ fontSize: 11, color: c.ok, display: 'flex', alignItems: 'center', gap: 5 }}>
              {Icon.trend({ width: 12, height: 12 })} +4 vs media histórica
            </div>
          </div>
        </div>

        {/* Map preview */}
        <div style={{
          borderRadius: 14, overflow: 'hidden', border: `1px solid ${c.border}`,
          marginBottom: 12, position: 'relative',
        }}>
          <ARCMap height={180} currentT={1.0} showCurrent={false}/>
          {/* Pace legend */}
          <div style={{
            position: 'absolute', top: 10, left: 10, right: 10,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <div style={{
              padding: '5px 9px', borderRadius: 6, fontSize: 9.5, color: c.text2,
              background: 'rgba(15,26,31,0.85)', backdropFilter: 'blur(8px)',
              border: `1px solid ${c.border}`, letterSpacing: '0.08em',
            }}>RUTA · 5.78 KM</div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '5px 9px', borderRadius: 6,
              background: 'rgba(15,26,31,0.85)', backdropFilter: 'blur(8px)',
              border: `1px solid ${c.border}`,
            }}>
              <span style={{ fontSize: 9.5, color: c.text3 }}>5:00</span>
              <div style={{
                width: 50, height: 4, borderRadius: 2,
                background: 'linear-gradient(to right, #00E5FF 0%, #3DDC84 50%, #FFB020 100%)',
              }}/>
              <span style={{ fontSize: 9.5, color: c.text3 }}>6:30</span>
            </div>
          </div>
        </div>

        {/* Cadence chart */}
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
          padding: 16, marginBottom: 12,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 10 }}>
            <Caption>Cadencia · sesión completa</Caption>
            <span style={{ fontSize: 11, color: c.text2, fontFamily: 'var(--font-mono)' }}>
              <span style={{ color: c.text }}>178</span> spm avg
            </span>
          </div>
          <svg width="100%" height="80" viewBox="0 0 320 80" preserveAspectRatio="none">
            {/* Optimal band 175-185 */}
            <rect x="0" y="22" width="320" height="20" fill={c.okDim}/>
            {/* Grid */}
            <line x1="0" y1="22" x2="320" y2="22" stroke={c.border} strokeWidth="0.5" strokeDasharray="2 2"/>
            <line x1="0" y1="42" x2="320" y2="42" stroke={c.border} strokeWidth="0.5" strokeDasharray="2 2"/>
            {/* Cadence line */}
            <path d={buildSparkPath(cadenceData, 320, 80, 4)} fill="none" stroke={c.accent} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 9, color: c.text3, marginTop: 6, fontFamily: 'var(--font-mono)' }}>
            <span>0:00</span><span>16:00</span><span>32:18</span>
          </div>
        </div>

        {/* Symmetry bar */}
        <div style={{
          background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14,
          padding: 16, marginBottom: 12,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <Caption>Simetría L / R</Caption>
            <span style={{ fontSize: 11, color: c.ok }}>● En rango</span>
          </div>
          <div style={{
            display: 'flex', height: 36, borderRadius: 8, overflow: 'hidden',
            border: `1px solid ${c.border}`,
          }}>
            <div style={{
              flex: 49, background: c.accent, color: c.bg, display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 13, fontWeight: 600, fontVariantNumeric: 'tabular-nums',
            }}>49%</div>
            <div style={{
              flex: 51, background: 'rgba(0,229,255,0.25)', color: c.text, display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 13, fontWeight: 500, fontVariantNumeric: 'tabular-nums',
            }}>51%</div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, color: c.text3, marginTop: 6, letterSpacing: '0.08em' }}>
            <span>IZQUIERDA</span><span>DERECHA</span>
          </div>
        </div>

        {/* Trio cards */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 16 }}>
          {[
            { v: '231', u: 'ms', l: 'GCT avg' },
            { v: '13.2', u: 'm/s²', l: 'Impacto pico' },
            { v: '4.8', u: '%', l: 'Variabilidad' },
          ].map((m, i) => (
            <div key={i} style={{
              background: c.surface, border: `1px solid ${c.border}`, borderRadius: 12,
              padding: 12,
            }}>
              <Caption style={{ marginBottom: 4, fontSize: 9 }}>{m.l}</Caption>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
                <span style={{ fontSize: 18, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{m.v}</span>
                <span style={{ fontSize: 10, color: c.text3 }}>{m.u}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Próxima sesión */}
        <div style={{ marginBottom: 12 }}>
          <Caption color={c.text2} style={{ marginBottom: 10 }}>Próxima sesión</Caption>
          {[
            'Mantén la cadencia 175-185 spm. Vas en óptimo.',
            'Trabaja simetría: 1% más en derecha cierra el gap.',
            'Tu variabilidad bajó: estás más estable.',
          ].map((rec, i) => (
            <div key={i} style={{
              display: 'flex', gap: 12, padding: '12px 14px',
              background: c.surface, border: `1px solid ${c.border}`,
              borderRadius: 10, marginBottom: 6,
            }}>
              <div style={{
                width: 22, height: 22, borderRadius: '50%', background: c.accentDim,
                color: c.accent, display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 11, fontWeight: 600, flexShrink: 0,
              }}>{i + 1}</div>
              <div style={{ fontSize: 13, color: c.text, lineHeight: 1.45 }}>{rec}</div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '12px 20px 38px', display: 'flex', gap: 10 }}>
        <ARCButton kind="ghost" icon={Icon.share({ width: 16, height: 16 })} style={{ width: 110 }}>COMPARTIR</ARCButton>
        <ARCButton kind="primary" full>LISTO</ARCButton>
      </div>
    </div>
  );
}

// ─── 8. HISTORY ────────────────────────────────────────────
function ScreenHistory() {
  const c = TOKENS.color;
  const sessions = [
    { date: 'Hoy · 17:34', dur: '32:18', km: '5.78', score: 82, cad: [175,178,182,178,175,178], type: 'Libre' },
    { date: 'Mié · 06:42', dur: '24:51', km: '4.12', score: 75, cad: [170,172,168,175,178,176], type: 'Tiempo · 25min' },
    { date: 'Lun · 18:10', dur: '38:42', km: '7.20', score: 79, cad: [172,176,180,178,176,175], type: 'Distancia · 7km' },
    { date: '8 jun · 17:00', dur: '28:30', km: '5.00', score: 71, cad: [165,170,172,168,170,172], type: 'Libre' },
    { date: '6 jun · 06:30', dur: '22:15', km: '3.85', score: 80, cad: [178,180,182,178,176,178], type: 'Libre' },
  ];

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer', display: 'flex' }}>
            {Icon.chevL({ width: 22, height: 22 })}
          </button>
        }
        center={<span style={{ fontSize: 15, fontWeight: 500 }}>Historial</span>}
        right={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer', display: 'flex' }}>
            {Icon.search({ width: 20, height: 20 })}
          </button>
        }
      />

      <div style={{ padding: '8px 20px 16px' }}>
        {/* Filter */}
        <Segmented
          options={[
            { value: 'week', label: 'Semana' },
            { value: 'month', label: 'Mes' },
            { value: 'all', label: 'Todo' },
          ]}
          value="month"
        />

        {/* Aggregate stats */}
        <div style={{ display: 'flex', gap: 0, marginTop: 16, padding: '14px 0', borderBottom: `1px solid ${c.border}` }}>
          {[
            { v: '12', l: 'sesiones' },
            { v: '52.4', l: 'km' },
            { v: '7:42', l: 'h totales' },
            { v: '78', l: 'score avg' },
          ].map((s, i) => (
            <div key={i} style={{
              flex: 1,
              borderLeft: i ? `1px solid ${c.border}` : 'none',
              paddingLeft: i ? 12 : 0,
            }}>
              <div style={{ fontSize: 18, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{s.v}</div>
              <Caption style={{ marginTop: 3, fontSize: 9 }}>{s.l}</Caption>
            </div>
          ))}
        </div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 20px' }}>
        {sessions.map((s, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            padding: '14px 12px',
            background: c.surface, border: `1px solid ${c.border}`,
            borderRadius: 12, marginBottom: 8,
          }}>
            <ARCMapMini route={i % 2 ? 'outback_3k' : 'loop_5k'}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 3 }}>
                <span style={{ fontSize: 13, fontWeight: 500 }}>{s.date}</span>
                <span style={{ fontSize: 10, color: c.text3 }}>{s.type}</span>
              </div>
              <div style={{ display: 'flex', gap: 10, fontSize: 11, color: c.text2, fontVariantNumeric: 'tabular-nums', marginBottom: 8 }}>
                <span>{s.dur}</span>
                <span style={{ color: c.border }}>·</span>
                <span>{s.km} km</span>
              </div>
              <Sparkline data={s.cad} w={80} h={14} dot={false}/>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{
                fontSize: 22, fontWeight: 500, color: c.accent, lineHeight: 1,
                fontVariantNumeric: 'tabular-nums',
              }}>{s.score}</div>
              <Caption style={{ marginTop: 3, fontSize: 8 }}>SCORE</Caption>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── 9. SETTINGS ───────────────────────────────────────────
function ScreenSettings() {
  const c = TOKENS.color;
  const Section = ({ title, children }) => (
    <div style={{ marginBottom: 18 }}>
      <Caption color={c.text2} style={{ marginBottom: 10, paddingLeft: 4 }}>{title}</Caption>
      <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 12, overflow: 'hidden' }}>
        {children}
      </div>
    </div>
  );
  const Row = ({ left, right, divider = true }) => (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 14px',
      borderBottom: divider ? `1px solid ${c.border}` : 'none',
      gap: 12,
    }}>
      <span style={{ fontSize: 13, color: c.text }}>{left}</span>
      <span style={{ fontSize: 12, color: c.text2, display: 'flex', alignItems: 'center', gap: 6 }}>{right}</span>
    </div>
  );
  const Slider = ({ label, value, min, max, unit }) => {
    const pct = ((value - min) / (max - min)) * 100;
    return (
      <div style={{ padding: '14px', borderBottom: `1px solid ${c.border}` }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
          <span style={{ fontSize: 13, color: c.text }}>{label}</span>
          <span style={{ fontSize: 12, color: c.accent, fontFamily: 'var(--font-mono)' }}>{value} {unit}</span>
        </div>
        <div style={{ height: 4, background: c.surfaceHi, borderRadius: 2, position: 'relative' }}>
          <div style={{
            position: 'absolute', left: 0, top: 0, height: '100%', width: `${pct}%`,
            background: c.accent, borderRadius: 2,
          }}/>
          <div style={{
            position: 'absolute', left: `calc(${pct}% - 7px)`, top: -5, width: 14, height: 14,
            borderRadius: '50%', background: c.accent,
            boxShadow: `0 0 0 4px ${c.accentDim}`,
          }}/>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 9, color: c.text3, marginTop: 5, fontFamily: 'var(--font-mono)' }}>
          <span>{min}</span><span>{max}</span>
        </div>
      </div>
    );
  };

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={
          <button style={{ background: 'transparent', border: 'none', color: c.text2, padding: 4, cursor: 'pointer', display: 'flex' }}>
            {Icon.chevL({ width: 22, height: 22 })}
          </button>
        }
        center={<span style={{ fontSize: 15, fontWeight: 500 }}>Ajustes</span>}
      />

      <div style={{ flex: 1, overflow: 'auto', padding: '8px 20px 20px' }}>
        <Section title="Bandas">
          <Row
            left={<><span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <span style={{
                width: 22, height: 22, borderRadius: 11, background: c.surfaceHi, color: c.accent,
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 600,
                border: `1px solid ${c.border}`,
              }}>L</span>
              SportBand-L
            </span></>}
            right={<><BatteryReading pct={87}/> {Icon.chevR({ width: 14, height: 14 })}</>}
          />
          <Row
            left={<><span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <span style={{
                width: 22, height: 22, borderRadius: 11, background: c.surfaceHi, color: c.accent,
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 600,
                border: `1px solid ${c.border}`,
              }}>R</span>
              SportBand-R
            </span></>}
            right={<><BatteryReading pct={92}/> {Icon.chevR({ width: 14, height: 14 })}</>}
            divider={false}
          />
        </Section>

        <Section title="Calibración de detección">
          <Slider label="Impact threshold" value={12} min={8} max={18} unit="m/s²"/>
          <Slider label="Takeoff threshold" value={3} min={1} max={5} unit="m/s²"/>
          <Slider label="Min step duration" value={180} min={100} max={300} unit="ms"/>
          <div style={{ padding: '12px 14px' }}>
            <button style={{
              background: 'transparent', border: `1px solid ${c.border}`, color: c.text2,
              padding: '8px 14px', borderRadius: 8, fontSize: 12, cursor: 'pointer',
            }}>Restaurar defaults</button>
          </div>
        </Section>

        <Section title="Personal">
          <Row left="Altura" right={<>176 cm {Icon.chevR({ width: 14, height: 14 })}</>}/>
          <Row left="Peso" right={<>72 kg {Icon.chevR({ width: 14, height: 14 })}</>}/>
          <Row left="Longitud zancada" right={<>1.18 m {Icon.chevR({ width: 14, height: 14 })}</>} divider={false}/>
        </Section>

        <Section title="Unidades">
          <Row left="Sistema" right={<>Métrico {Icon.chevR({ width: 14, height: 14 })}</>}/>
          <Row left="Idioma" right={<>Español {Icon.chevR({ width: 14, height: 14 })}</>} divider={false}/>
        </Section>

        <Section title="Datos">
          <Row left="Exportar CSV" right={Icon.chevR({ width: 14, height: 14 })}/>
          <Row left={<span style={{ color: c.crit }}>Borrar historial</span>} right={null} divider={false}/>
        </Section>

        <Section title="Acerca de">
          <Row left="Versión" right={<span style={{ fontFamily: 'var(--font-mono)' }}>1.0.0 · 247</span>}/>
          <Row left="Política de privacidad" right={Icon.chevR({ width: 14, height: 14 })} divider={false}/>
        </Section>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenSummary, ScreenHistory, ScreenSettings,
});
