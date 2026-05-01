// ARC — AI Sport Monitor
// Logo wordmark exploration: arc symbol replaces the "A"

// ─── Arc symbol variants ─────────────────────────────────────

// Original — proportional 1:1 arc with dot at the base
function ArcMark({ size = 60, color = '#000' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" fill="none" style={{ display: 'block' }}>
      <path d="M18 72 Q50 14 82 72" stroke={color} strokeWidth="3" strokeLinecap="round" />
      <circle cx="50" cy="78" r="3" fill={color} />
    </svg>
  );
}

// Centered — arc tightened vertically, dot closer
function ArcMarkCentered({ size = 60, color = '#000' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" fill="none" style={{ display: 'block' }}>
      <path d="M18 76 Q50 22 82 76" stroke={color} strokeWidth="3.4" strokeLinecap="round" />
      <circle cx="50" cy="82" r="3.2" fill={color} />
    </svg>
  );
}

// Tall — stretched vertically (0.75:1) to match cap-height of R + C
function ArcMarkTall({ size = 60, color = '#000' }) {
  const w = Math.round(size * 0.75);
  return (
    <svg width={w} height={size} viewBox="0 0 75 100" fill="none" style={{ display: 'block' }}>
      <path d="M8 70 Q37.5 -10 67 70" stroke={color} strokeWidth="3" strokeLinecap="round" />
      <circle cx="37.5" cy="58" r="3" fill={color} />
    </svg>
  );
}

// ─── Single-symbol logo card (the "trajectory arc" reference) ───
function ArcSymbolArtboard() {
  return (
    <div style={{
      width: 320, height: 420, background: '#fff',
      display: 'flex', flexDirection: 'column',
      fontFamily: '"Inter", -apple-system, BlinkMacSystemFont, sans-serif',
    }}>
      {/* Hero symbol */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '32px 20px 16px' }}>
        <ArcMarkTall size={140} />
      </div>

      {/* Wordmark */}
      <div style={{ textAlign: 'center', padding: '0 20px 8px' }}>
        <div style={{ fontSize: 32, fontWeight: 700, letterSpacing: '0.18em', color: '#000', lineHeight: 1 }}>
          ARC
        </div>
        <div style={{ fontSize: 9, fontWeight: 500, letterSpacing: '0.32em', color: '#999', marginTop: 8, textTransform: 'uppercase' }}>
          Movement Analytics
        </div>
      </div>

      {/* Size variants */}
      <div style={{
        borderTop: '1px solid #f0f0f0',
        padding: '16px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: '#fafafa',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <ArcMarkTall size={16} />
          <ArcMarkTall size={24} />
          <ArcMarkTall size={36} />
          <ArcMarkTall size={48} />
        </div>
        <div style={{ fontSize: 9, color: '#bbb', fontFamily: 'ui-monospace, monospace', letterSpacing: '0.05em' }}>
          16 / 24 / 36 / 48
        </div>
      </div>

      {/* Negative variant */}
      <div style={{ background: '#000', padding: '20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <ArcMarkTall size={32} color="#fff" />
        <div style={{ color: '#fff', fontSize: 14, fontWeight: 700, letterSpacing: '0.18em' }}>ARC</div>
        <div style={{ fontSize: 9, color: '#666', fontFamily: 'ui-monospace, monospace' }}>NEG</div>
      </div>
    </div>
  );
}

// ─── Integrated wordmark — arc symbol replaces the "A" ──────
function ArcIntegratedArtboard({ Mark = ArcMark, markSize = 110, markGap = 4, smallMarkScale = 1.15, smallMarkGap = 1, negMarkSize = 44, negGap = 3 }) {
  return (
    <div style={{
      width: 320, height: 420, background: '#fff',
      display: 'flex', flexDirection: 'column',
      fontFamily: '"Inter", -apple-system, BlinkMacSystemFont, sans-serif',
    }}>
      {/* Hero: integrated wordmark */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '32px 20px 8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: markGap }}>
          <Mark size={markSize} />
          <span style={{ fontSize: 88, letterSpacing: '0.04em', lineHeight: 0.9, color: '#000', fontWeight: 200 }}>RC</span>
        </div>
      </div>

      {/* Tagline */}
      <div style={{ textAlign: 'center', padding: '0 20px 12px' }}>
        <div style={{ fontSize: 9, fontWeight: 500, letterSpacing: '0.32em', color: '#999', textTransform: 'uppercase' }}>
          Movement Analytics
        </div>
      </div>

      {/* Size variants */}
      <div style={{
        borderTop: '1px solid #f0f0f0',
        padding: '14px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: '#fafafa',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          {[16, 24, 34, 46].map((s) => (
            <div key={s} style={{ display: 'flex', alignItems: 'center', gap: smallMarkGap }}>
              <Mark size={s * smallMarkScale} />
              <span style={{ fontSize: s * 0.95, fontWeight: 200, letterSpacing: '0.04em', lineHeight: 1, color: '#000' }}>RC</span>
            </div>
          ))}
        </div>
      </div>

      {/* Negative variant */}
      <div style={{ background: '#000', padding: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: negGap }}>
        <Mark size={negMarkSize} color="#fff" />
        <span style={{ fontSize: 36, fontWeight: 200, letterSpacing: '0.04em', lineHeight: 0.9, color: '#fff' }}>RC</span>
      </div>
    </div>
  );
}

// ─── App ──────────────────────────────────────────────────────
function App() {
  return (
    <DesignCanvas>
      <DCSection id="arc-wordmark" title="ARC — Wordmark integrado"
        subtitle="El símbolo del arco reemplaza la &quot;A&quot;">
        <DCArtboard id="arc-tall" label="ARC · más alto" width={320} height={420}>
          <ArcIntegratedArtboard Mark={ArcMarkTall} markSize={120} markGap={2} smallMarkScale={1.3} smallMarkGap={0} negMarkSize={50} negGap={2} />
        </DCArtboard>
      </DCSection>

      <DCSection id="arc-symbol" title="ARC — Símbolo solo"
        subtitle="El arco como logotipo, con el wordmark debajo">
        <DCArtboard id="arc-symbol-card" label="ARC · símbolo + wordmark" width={320} height={420}>
          <ArcSymbolArtboard />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
