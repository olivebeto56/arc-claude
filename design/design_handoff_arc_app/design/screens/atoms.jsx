// ARC — Shared UI atoms & icons

// ─── Icons (24px viewBox unless noted) ───────────────────────
const Icon = {
  settings: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <circle cx="12" cy="12" r="3"/>
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
    </svg>
  ),
  bluetooth: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <path d="m7 7 10 10-5 5V2l5 5-10 10"/>
    </svg>
  ),
  location: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/>
      <circle cx="12" cy="10" r="3"/>
    </svg>
  ),
  check: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <polyline points="20 6 9 17 4 12"/>
    </svg>
  ),
  chevR: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <polyline points="9 18 15 12 9 6"/>
    </svg>
  ),
  chevL: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <polyline points="15 18 9 12 15 6"/>
    </svg>
  ),
  pause: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
      <rect x="6" y="5" width="4" height="14" rx="1"/>
      <rect x="14" y="5" width="4" height="14" rx="1"/>
    </svg>
  ),
  play: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
      <path d="M8 5v14l11-7z"/>
    </svg>
  ),
  stop: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...p}>
      <rect x="6" y="6" width="12" height="12" rx="2"/>
    </svg>
  ),
  share: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <path d="M12 16V4m0 0L8 8m4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/>
    </svg>
  ),
  search: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <circle cx="11" cy="11" r="7"/>
      <line x1="21" y1="21" x2="16.65" y2="16.65"/>
    </svg>
  ),
  trend: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <polyline points="3 17 9 11 13 15 21 7"/>
      <polyline points="14 7 21 7 21 14"/>
    </svg>
  ),
  filter: (p = {}) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}>
      <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/>
    </svg>
  ),
  battery: (level, color, p = {}) => (
    <svg viewBox="0 0 28 12" fill="none" {...p}>
      <rect x="0.5" y="0.5" width="23" height="11" rx="2" stroke={color} strokeOpacity="0.5" fill="none"/>
      <rect x="2.5" y="2.5" width={Math.max(0, 19 * level / 100)} height="7" rx="1" fill={color}/>
      <rect x="24.5" y="3" width="2" height="6" rx="0.5" fill={color} fillOpacity="0.5"/>
    </svg>
  ),
  // Brand symbol — ARC arc + dot
  arcSym: (p = {}) => (
    <svg viewBox="0 0 75 100" fill="none" {...p}>
      <path d="M8 70 Q37.5 -10 67 70" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
      <circle cx="37.5" cy="58" r="3" fill="currentColor"/>
    </svg>
  ),
};

// ─── Atoms ───────────────────────────────────────────────────

// CTA button (primary cyan)
function ARCButton({ children, kind = 'primary', size = 'lg', icon, full, style = {}, onClick }) {
  const c = TOKENS.color;
  const styles = {
    primary: { background: c.accent, color: '#0A0A0A' },
    secondary: { background: 'transparent', color: c.text, border: `1px solid ${c.border}` },
    ghost: { background: c.surface, color: c.text, border: `1px solid ${c.border}` },
    destructive: { background: 'rgba(255,77,79,0.10)', color: c.crit, border: `1px solid ${c.crit}` },
    danger: { background: c.crit, color: '#FFF' },
  };
  const sizes = {
    lg: { padding: '18px 24px', fontSize: 16, borderRadius: 14, fontWeight: 600, letterSpacing: '0.02em' },
    md: { padding: '12px 20px', fontSize: 14, borderRadius: 12, fontWeight: 500 },
    sm: { padding: '8px 14px', fontSize: 13, borderRadius: 10, fontWeight: 500 },
  };
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      width: full ? '100%' : 'auto', cursor: 'pointer', border: 'none',
      ...styles[kind], ...sizes[size], ...style,
    }}>
      {icon && <span style={{ display: 'flex' }}>{icon}</span>}
      {children}
    </button>
  );
}

// Card
function ARCCard({ children, style = {}, padding = 16, accent }) {
  const c = TOKENS.color;
  return (
    <div style={{
      background: c.surface,
      border: `1px solid ${c.border}`,
      borderRadius: 14,
      padding,
      position: 'relative',
      ...(accent ? { borderLeft: `2px solid ${c.accent}` } : {}),
      ...style,
    }}>
      {children}
    </div>
  );
}

// Caption / eyebrow label
function Caption({ children, color, style = {} }) {
  return (
    <div style={{
      fontSize: 10, fontWeight: 500, letterSpacing: '0.14em',
      textTransform: 'uppercase', color: color || TOKENS.color.text3,
      ...style,
    }}>{children}</div>
  );
}

// Status dot
function Dot({ color = TOKENS.color.ok, size = 6, glow = false, style = {} }) {
  return (
    <span style={{
      display: 'inline-block', width: size, height: size, borderRadius: '50%',
      background: color,
      boxShadow: glow ? `0 0 ${size*2}px ${color}` : 'none',
      ...style,
    }} />
  );
}

// Sparkline — accepts array of values, normalizes to height
function Sparkline({ data, w = 60, h = 18, color = TOKENS.color.accent, dot = true }) {
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = h - ((v - min) / range) * h;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  const last = pts[pts.length - 1].split(',').map(parseFloat);
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', overflow: 'visible' }}>
      <polyline points={pts.join(' ')} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      {dot && <circle cx={last[0]} cy={last[1]} r="2" fill={color}/>}
    </svg>
  );
}

// Wordmark "RC" logo (Inter ExtraLight) — uses brand SVG
function ARCLogo({ height = 22, color = '#FFF' }) {
  // The integrated SVG. We render via inline SVG so color is controllable
  // without having to load files. This keeps it self-contained.
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 0, height,
      color, lineHeight: 1,
    }}>
      <Icon.arcSym style={{ width: height * 1.45 * 0.75, height: height * 1.45, color }}/>
      <span style={{
        fontSize: height, fontWeight: 200, letterSpacing: '0.04em',
        lineHeight: 0.9, marginLeft: 2,
      }}>RC</span>
    </div>
  );
}

// Battery + label
function BatteryReading({ pct, color }) {
  const c = TOKENS.color;
  const fc = color || (pct < 15 ? c.warn : pct < 30 ? c.warn : c.text2);
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
      {Icon.battery(pct, fc, { width: 22, height: 10 })}
      <span style={{ fontSize: 11, color: fc, fontVariantNumeric: 'tabular-nums' }}>{pct}%</span>
    </span>
  );
}

// Status bar inside the app (top)
function ARCTopBar({ left, center, right, style = {} }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '8px 20px 12px', height: 44, ...style,
    }}>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8 }}>{left}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>{center}</div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'flex-end' }}>{right}</div>
    </div>
  );
}

// Segmented control
function Segmented({ options, value, onChange }) {
  const c = TOKENS.color;
  return (
    <div style={{
      display: 'flex', gap: 2, padding: 3, background: c.surfaceHi,
      borderRadius: 10, border: `1px solid ${c.border}`,
    }}>
      {options.map(opt => {
        const active = opt.value === value;
        return (
          <button key={opt.value} onClick={() => onChange?.(opt.value)} style={{
            flex: 1, padding: '8px 12px', border: 'none', cursor: 'pointer',
            background: active ? c.bg : 'transparent',
            color: active ? c.text : c.text2,
            borderRadius: 8, fontSize: 12, fontWeight: 500,
            letterSpacing: '0.02em',
          }}>{opt.label}</button>
        );
      })}
    </div>
  );
}

Object.assign(window, {
  Icon, ARCButton, ARCCard, Caption, Dot, Sparkline,
  ARCLogo, BatteryReading, ARCTopBar, Segmented,
});
