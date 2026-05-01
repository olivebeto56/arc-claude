// ARC — Live session screens (Dashboard, Recommendation, Pause)

// ─── 4. DASHBOARD LIVE — Variation A: Map prominent ───────
function ScreenDashboardA() {
  const c = TOKENS.color;
  const Metric = ({ v, u, l, status = 'ok' }) => {
    const borderColor = status === 'crit' ? c.crit : status === 'warn' ? c.warn : c.accent;
    return (
      <div style={{
        background: c.surface, border: `1px solid ${c.border}`,
        borderLeft: `2px solid ${borderColor}`, borderRadius: 10,
        padding: '10px 12px',
      }}>
        <Caption style={{ marginBottom: 4, fontSize: 9 }}>{l}</Caption>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
          <span style={{ fontSize: 20, fontWeight: 500, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.01em' }}>{v}</span>
          <span style={{ fontSize: 10, color: c.text3 }}>{u}</span>
        </div>
      </div>
    );
  };

  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      {/* Top status bar */}
      <ARCTopBar
        left={<>
          <Dot color={c.ok} glow size={6}/>
          <span style={{ fontSize: 11, color: c.text2 }}>Conectado</span>
        </>}
        center={
          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 10, color: c.ok, fontFamily: 'var(--font-mono)' }}>
            <Dot color={c.ok} size={5}/> GPS ±4m
          </span>
        }
        right={<>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>L 84%</span>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>R 89%</span>
        </>}
      />

      {/* Time + distance hero */}
      <div style={{ padding: '4px 20px 12px', textAlign: 'center' }}>
        <div style={{
          fontSize: 56, fontWeight: 300, letterSpacing: '-0.04em', lineHeight: 1,
          fontVariantNumeric: 'tabular-nums', color: c.text,
        }}>28:43</div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginTop: 8, fontSize: 13, color: c.text2 }}>
          <span><span style={{ color: c.text, fontWeight: 500 }}>5.2</span> km</span>
          <span style={{ color: c.border }}>·</span>
          <span><span style={{ color: c.text, fontWeight: 500 }}>5:32</span> /km</span>
        </div>
      </div>

      {/* Map */}
      <div style={{ position: 'relative', margin: '4px 16px 12px', borderRadius: 14, overflow: 'hidden', border: `1px solid ${c.border}` }}>
        <ARCMap height={220} currentT={0.62}/>
        {/* View toggle */}
        <div style={{
          position: 'absolute', top: 10, right: 10,
          background: 'rgba(15,26,31,0.85)', backdropFilter: 'blur(12px)',
          border: `1px solid ${c.border}`, borderRadius: 8, padding: 3, display: 'flex', gap: 2,
        }}>
          <button style={{
            background: c.accent, color: c.bg, border: 'none', padding: '5px 10px',
            borderRadius: 6, fontSize: 10, fontWeight: 600, cursor: 'pointer', letterSpacing: '0.06em',
          }}>MAPA</button>
          <button style={{
            background: 'transparent', color: c.text2, border: 'none', padding: '5px 10px',
            borderRadius: 6, fontSize: 10, fontWeight: 500, cursor: 'pointer', letterSpacing: '0.06em',
          }}>CARDS</button>
        </div>
      </div>

      {/* Metrics grid */}
      <div style={{ flex: 1, padding: '0 16px', overflow: 'auto' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <Metric v="178" u="spm" l="Cadencia"/>
          <Metric v="48/52" u="%" l="Simetría" status="warn"/>
          <Metric v="231" u="ms" l="GCT"/>
          <Metric v="12.4" u="m/s²" l="Impacto"/>
          <Metric v="6.2" u="°" l="Strike"/>
          <Metric v="4.8" u="%" l="Variabilidad"/>
        </div>
      </div>

      {/* Bottom action bar */}
      <div style={{ padding: '14px 16px 38px', display: 'flex', gap: 10 }}>
        <ARCButton kind="ghost" icon={Icon.pause({ width: 18, height: 18 })} full>PAUSA</ARCButton>
        <ARCButton kind="destructive" icon={Icon.stop({ width: 16, height: 16 })} full>TERMINAR</ARCButton>
      </div>
    </div>
  );
}

// ─── 4. DASHBOARD LIVE — Variation B: Cards prominent (no map) ────
function ScreenDashboardB() {
  const c = TOKENS.color;
  const BigMetric = ({ v, u, l, status = 'ok', sub }) => {
    const borderColor = status === 'crit' ? c.crit : status === 'warn' ? c.warn : c.accent;
    return (
      <div style={{
        background: c.surface, border: `1px solid ${c.border}`,
        borderLeft: `2px solid ${borderColor}`, borderRadius: 12,
        padding: 14, display: 'flex', flexDirection: 'column', gap: 6,
      }}>
        <Caption>{l}</Caption>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span style={{ fontSize: 26, fontWeight: 500, fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em' }}>{v}</span>
          <span style={{ fontSize: 11, color: c.text3 }}>{u}</span>
        </div>
        {sub && <div style={{ fontSize: 10, color: c.text3 }}>{sub}</div>}
      </div>
    );
  };
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={<><Dot color={c.ok} glow size={6}/><span style={{ fontSize: 11, color: c.text2 }}>Conectado</span></>}
        center={<span style={{ fontSize: 10, color: c.ok, fontFamily: 'var(--font-mono)' }}>GPS ±4m</span>}
        right={<>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>L 84%</span>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>R 89%</span>
        </>}
      />

      {/* Big timer */}
      <div style={{
        padding: '12px 20px 20px', textAlign: 'center',
        background: `radial-gradient(ellipse at 50% 0%, ${c.accentDim} 0%, transparent 60%)`,
      }}>
        <div style={{
          fontSize: 72, fontWeight: 300, letterSpacing: '-0.05em', lineHeight: 1,
          fontVariantNumeric: 'tabular-nums', color: c.text,
        }}>28:43</div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 32, marginTop: 12 }}>
          <div>
            <div style={{ fontSize: 24, fontWeight: 500, color: c.accent, fontVariantNumeric: 'tabular-nums' }}>5.2</div>
            <Caption>km</Caption>
          </div>
          <div style={{ width: 1, background: c.border }}/>
          <div>
            <div style={{ fontSize: 24, fontWeight: 500, color: c.accent, fontVariantNumeric: 'tabular-nums' }}>5:32</div>
            <Caption>min/km</Caption>
          </div>
        </div>
      </div>

      {/* Toggle pill */}
      <div style={{ padding: '0 20px 12px', display: 'flex', justifyContent: 'center' }}>
        <div style={{ display: 'flex', gap: 4, padding: 3, background: c.surfaceHi, border: `1px solid ${c.border}`, borderRadius: 8 }}>
          <button style={{ background: 'transparent', color: c.text2, border: 'none', padding: '5px 12px', fontSize: 10, letterSpacing: '0.08em', borderRadius: 6, cursor: 'pointer', fontWeight: 500 }}>MAPA</button>
          <button style={{ background: c.bg, color: c.text, border: 'none', padding: '5px 12px', fontSize: 10, letterSpacing: '0.08em', borderRadius: 6, cursor: 'pointer', fontWeight: 600 }}>CARDS</button>
        </div>
      </div>

      <div style={{ flex: 1, padding: '0 16px', overflow: 'auto' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <BigMetric v="178" u="spm" l="Cadencia" sub="Óptima 175-185"/>
          <BigMetric v="48/52" u="%" l="Simetría" status="warn" sub="Fuera de rango"/>
          <BigMetric v="231" u="ms" l="GCT" sub="Óptimo"/>
          <BigMetric v="12.4" u="m/s²" l="Impacto" sub="En rango"/>
          <BigMetric v="6.2" u="°" l="Strike angle" sub="Mid-foot"/>
          <BigMetric v="4.8" u="%" l="Variabilidad" sub="Estable"/>
        </div>
      </div>

      <div style={{ padding: '14px 16px 38px', display: 'flex', gap: 10 }}>
        <ARCButton kind="ghost" icon={Icon.pause({ width: 18, height: 18 })} full>PAUSA</ARCButton>
        <ARCButton kind="destructive" icon={Icon.stop({ width: 16, height: 16 })} full>TERMINAR</ARCButton>
      </div>
    </div>
  );
}

// ─── 4. DASHBOARD LIVE — Variation C: Hero metric (single focus) ────
function ScreenDashboardC() {
  const c = TOKENS.color;
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={<><Dot color={c.ok} glow size={6}/><span style={{ fontSize: 11, color: c.text2 }}>Live</span></>}
        center={<span style={{ fontSize: 10, color: c.ok, fontFamily: 'var(--font-mono)' }}>GPS ±4m</span>}
        right={<>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>L 84%</span>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>R 89%</span>
        </>}
      />

      {/* Hero — Cadencia o métrica focal */}
      <div style={{ padding: '20px 24px 12px', textAlign: 'center', flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div>
          <Caption style={{ marginBottom: 8 }}>Tiempo</Caption>
          <div style={{
            fontSize: 64, fontWeight: 300, letterSpacing: '-0.04em', lineHeight: 1,
            fontVariantNumeric: 'tabular-nums',
          }}>28:43</div>

          <div style={{ marginTop: 32, padding: '16px 0', borderTop: `1px solid ${c.border}`, borderBottom: `1px solid ${c.border}` }}>
            <Caption style={{ marginBottom: 4 }}>Cadencia · ahora</Caption>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6 }}>
              <span style={{
                fontSize: 96, fontWeight: 200, color: c.accent, lineHeight: 0.9,
                letterSpacing: '-0.05em', fontVariantNumeric: 'tabular-nums',
                textShadow: `0 0 60px ${c.accentDim2}`,
              }}>178</span>
              <span style={{ fontSize: 18, color: c.text3, fontWeight: 300 }}>spm</span>
            </div>
            <div style={{ fontSize: 11, color: c.ok, marginTop: 4 }}>● Óptima · rango 175-185</div>
          </div>

          {/* Distance + pace */}
          <div style={{ display: 'flex', gap: 0, marginTop: 18 }}>
            {[{ v: '5.2', u: 'km', l: 'Distancia' }, { v: '5:32', u: '/km', l: 'Ritmo' }].map((m, i) => (
              <div key={i} style={{ flex: 1, borderLeft: i ? `1px solid ${c.border}` : 'none', paddingLeft: i ? 16 : 0 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 4 }}>
                  <span style={{ fontSize: 24, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{m.v}</span>
                  <span style={{ fontSize: 11, color: c.text3 }}>{m.u}</span>
                </div>
                <Caption style={{ marginTop: 4 }}>{m.l}</Caption>
              </div>
            ))}
          </div>

          {/* Mini metrics row */}
          <div style={{ display: 'flex', gap: 8, marginTop: 16, justifyContent: 'space-between', flexWrap: 'wrap' }}>
            {[
              { v: '49/51', l: 'Sym' },
              { v: '231ms', l: 'GCT' },
              { v: '12.4', l: 'Impacto' },
              { v: '4.8%', l: 'CV' },
            ].map((m, i) => (
              <div key={i} style={{ flex: 1, textAlign: 'center', padding: 8, background: c.surface, borderRadius: 8 }}>
                <div style={{ fontSize: 13, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{m.v}</div>
                <Caption style={{ marginTop: 2, fontSize: 8 }}>{m.l}</Caption>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div style={{ padding: '14px 16px 38px', display: 'flex', gap: 10 }}>
        <ARCButton kind="ghost" icon={Icon.pause({ width: 18, height: 18 })} full>PAUSA</ARCButton>
        <ARCButton kind="destructive" icon={Icon.stop({ width: 16, height: 16 })} full>TERMINAR</ARCButton>
      </div>
    </div>
  );
}

// ─── Static dashboard backdrop (cheap — for overlay screens) ───
function DashboardBackdrop() {
  const c = TOKENS.color;
  return (
    <div className="arc-app" style={{
      width: '100%', height: '100%', background: c.bg, color: c.text,
      display: 'flex', flexDirection: 'column', paddingTop: 56,
    }}>
      <ARCTopBar
        left={<><Dot color={c.ok} glow size={6}/><span style={{ fontSize: 11, color: c.text2 }}>Conectado</span></>}
        center={<span style={{ fontSize: 10, color: c.ok, fontFamily: 'var(--font-mono)' }}>GPS ±4m</span>}
        right={<>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>L 84%</span>
          <span style={{ fontSize: 10, color: c.text2, fontFamily: 'var(--font-mono)' }}>R 89%</span>
        </>}
      />
      <div style={{ padding: '4px 20px 12px', textAlign: 'center' }}>
        <div style={{ fontSize: 56, fontWeight: 300, letterSpacing: '-0.04em', lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>28:43</div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginTop: 8, fontSize: 13, color: c.text2 }}>
          <span><span style={{ color: c.text, fontWeight: 500 }}>5.2</span> km</span>
          <span style={{ color: c.border }}>·</span>
          <span><span style={{ color: c.text, fontWeight: 500 }}>5:32</span> /km</span>
        </div>
      </div>
      <div style={{ margin: '4px 16px 12px', borderRadius: 14, overflow: 'hidden', border: `1px solid ${c.border}`, height: 220, background: c.surfaceMap }}/>
      <div style={{ flex: 1, padding: '0 16px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {['178 spm','48/52 %','231 ms','12.4 m/s²','6.2 °','4.8 %'].map((v,i) => (
            <div key={i} style={{ background: c.surface, border: `1px solid ${c.border}`, borderLeft: `2px solid ${c.accent}`, borderRadius: 10, padding: '10px 12px', height: 50 }}/>
          ))}
        </div>
      </div>
      <div style={{ padding: '14px 16px 38px', height: 70 }}/>
    </div>
  );
}

// ─── 5. RECOMMENDATION OVERLAY ───
function ScreenRecommendation() {
  const c = TOKENS.color;
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      <DashboardBackdrop/>
      {/* Card flotante */}
      <div style={{
        position: 'absolute', left: 16, right: 16, bottom: 110,
        background: c.surface,
        border: `1px solid ${c.accent}`,
        borderRadius: 14, padding: 16,
        boxShadow: `0 12px 40px rgba(0,0,0,0.6), 0 0 0 4px ${c.accentDim}`,
        backdropFilter: 'blur(8px)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
          <Caption color={c.accent}>Simetría · fuera de rango</Caption>
          <button style={{
            background: 'transparent', border: 'none', color: c.text3, cursor: 'pointer',
            padding: 0, fontSize: 18, lineHeight: 1, marginTop: -4,
          }}>×</button>
        </div>
        <div style={{ fontSize: 14.5, color: c.text, lineHeight: 1.5, marginBottom: 10, fontWeight: 400 }}>
          Estás cargando más en la pierna izquierda. Relaja el hombro derecho y busca llegar parejo al suelo.
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11, color: c.text2, fontFamily: 'var(--font-mono)' }}>
          <span>Actual <span style={{ color: c.warn }}>48/52</span></span>
          <span style={{ color: c.border }}>→</span>
          <span>Óptimo <span style={{ color: c.ok }}>50/50</span></span>
        </div>
      </div>
    </div>
  );
}

// ─── 6. PAUSE MODAL ────────────────────────────────────────
function ScreenPause() {
  const c = TOKENS.color;
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      <DashboardBackdrop/>
      {/* Overlay */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'rgba(10,10,10,0.85)', backdropFilter: 'blur(12px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: 24, paddingTop: 56,
      }}>
        <div style={{
          width: '100%', background: c.surface, border: `1px solid ${c.border}`,
          borderRadius: 18, padding: 24, textAlign: 'center',
        }}>
          <Caption color={c.warn} style={{ marginBottom: 14 }}>● Sesión pausada</Caption>
          <div style={{
            fontSize: 64, fontWeight: 300, letterSpacing: '-0.04em', lineHeight: 1,
            fontVariantNumeric: 'tabular-nums', marginBottom: 8,
          }}>28:43</div>
          <div style={{ fontSize: 13, color: c.text2, marginBottom: 24 }}>
            5.2 km · Ritmo medio 5:32/km
          </div>

          {/* Snapshot */}
          <div style={{
            background: c.surfaceHi, border: `1px solid ${c.border}`, borderRadius: 12,
            padding: 14, marginBottom: 20, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12,
          }}>
            {[
              { v: '178', l: 'spm' },
              { v: '49/51', l: 'sym' },
              { v: '231', l: 'gct' },
            ].map((m, i) => (
              <div key={i}>
                <div style={{ fontSize: 16, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>{m.v}</div>
                <Caption style={{ marginTop: 2, fontSize: 9 }}>{m.l}</Caption>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <ARCButton kind="primary" full icon={Icon.play({ width: 18, height: 18 })}>REANUDAR</ARCButton>
            <ARCButton kind="destructive" full>TERMINAR SESIÓN</ARCButton>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenDashboardA, ScreenDashboardB, ScreenDashboardC,
  ScreenRecommendation, ScreenPause,
});
