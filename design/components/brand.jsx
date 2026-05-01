// ARC — Brand Guidelines
// AI Sport Monitor · Movement Analytics

// ─── Core symbol (refined "tall" version — the chosen one) ────
function ArcMarkTall({ size = 60, color = '#000', strokeWidth = 3 }) {
  const w = Math.round(size * 0.75);
  return (
    <svg width={w} height={size} viewBox="0 0 75 100" fill="none" style={{ display: 'block' }}>
      <path d="M8 70 Q37.5 -10 67 70" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" />
      <circle cx="37.5" cy="58" r="3" fill={color} />
    </svg>
  );
}

// Outline version — stroke only, no filled dot
function ArcMarkOutline({ size = 60, color = '#000' }) {
  const w = Math.round(size * 0.75);
  return (
    <svg width={w} height={size} viewBox="0 0 75 100" fill="none" style={{ display: 'block' }}>
      <path d="M8 70 Q37.5 -10 67 70" stroke={color} strokeWidth="3" strokeLinecap="round" />
      <circle cx="37.5" cy="58" r="2.5" stroke={color} strokeWidth="1.5" fill="none" />
    </svg>
  );
}

// ─── Wordmark lockups ──────────────────────────────────────────

// Integrated: arc replaces the "A"
function ArcLockupIntegrated({ height = 64, color = '#000' }) {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, height }}>
      <ArcMarkTall size={height * 1.45} color={color} />
      <span style={{ fontSize: height, fontWeight: 200, letterSpacing: '0.04em', lineHeight: 0.9, color, fontFamily: '"Inter", sans-serif' }}>RC</span>
    </div>
  );
}

// Symbol only
function ArcLockupSymbol({ height = 64, color = '#000' }) {
  return <ArcMarkTall size={height} color={color} />;
}

// Wordmark only (no symbol)
function ArcLockupWordmark({ height = 64, color = '#000' }) {
  return (
    <span style={{ fontSize: height, fontWeight: 200, letterSpacing: '0.18em', lineHeight: 0.9, color, fontFamily: '"Inter", sans-serif' }}>
      ARC
    </span>
  );
}

// ─── Page wrapper — every artboard is a 794x1123 (A4 @ 96dpi) page ────
const PAGE_W = 794;
const PAGE_H = 1123;
const INK = '#0a0a0a';
const PAPER = '#ffffff';
const MUTED = '#9a9a9a';
const LINE = '#e5e5e5';
const LIME = '#d6ff00'; // accent

function Page({ children, no, title, total = '01' }) {
  return (
    <div style={{
      width: PAGE_W, height: PAGE_H, background: PAPER, color: INK,
      fontFamily: '"Inter", -apple-system, BlinkMacSystemFont, sans-serif',
      position: 'relative', boxSizing: 'border-box',
      padding: '64px 72px 56px',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Top header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 56, paddingBottom: 16, borderBottom: `1px solid ${LINE}` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <ArcMarkTall size={20} />
          <span style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.16em', textTransform: 'uppercase' }}>ARC · Brand Guidelines</span>
        </div>
        <div style={{ fontSize: 10, color: MUTED, fontFamily: 'ui-monospace, SFMono-Regular, monospace', letterSpacing: '0.08em' }}>
          {no} / {total}
        </div>
      </div>
      {/* Page title */}
      <div style={{ marginBottom: 40 }}>
        <div style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.32em', color: MUTED, textTransform: 'uppercase', marginBottom: 10 }}>
          Section {no}
        </div>
        <h1 style={{ fontSize: 40, fontWeight: 300, letterSpacing: '-0.02em', lineHeight: 1.05, margin: 0, color: INK }}>
          {title}
        </h1>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>{children}</div>
      {/* Footer */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 24, paddingTop: 16, borderTop: `1px solid ${LINE}`, fontSize: 10, color: MUTED, letterSpacing: '0.06em' }}>
        <span style={{ fontFamily: 'ui-monospace, monospace' }}>arc.ai</span>
        <span>Movement Analytics · v1.0</span>
        <span style={{ fontFamily: 'ui-monospace, monospace' }}>©  2026</span>
      </div>
    </div>
  );
}

// Generic small caption
const Caption = ({ children, style }) => (
  <div style={{ fontSize: 10, color: MUTED, letterSpacing: '0.08em', textTransform: 'uppercase', fontWeight: 500, ...style }}>{children}</div>
);

const Mono = ({ children, style }) => (
  <span style={{ fontFamily: 'ui-monospace, SFMono-Regular, monospace', fontSize: 11, color: MUTED, letterSpacing: '0.04em', ...style }}>{children}</span>
);

// Cell with a tile + label below — used in lockup grids
function Cell({ children, label, code, dark = false, span = 1, height = 220 }) {
  return (
    <div style={{ gridColumn: `span ${span}`, display: 'flex', flexDirection: 'column' }}>
      <div style={{
        background: dark ? INK : PAPER,
        border: dark ? 'none' : `1px solid ${LINE}`,
        height,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
      }}>
        {children}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', paddingTop: 10 }}>
        <div style={{ fontSize: 12, fontWeight: 500, color: INK }}>{label}</div>
        <Mono>{code}</Mono>
      </div>
    </div>
  );
}

// ─── PAGE 01 — Cover ──────────────────────────────────────────
function CoverPage() {
  return (
    <div style={{
      width: PAGE_W, height: PAGE_H, background: PAPER, color: INK,
      fontFamily: '"Inter", sans-serif',
      position: 'relative', boxSizing: 'border-box',
      padding: '72px',
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: MUTED, letterSpacing: '0.16em', textTransform: 'uppercase' }}>
        <span>Brand Guidelines</span>
        <span style={{ fontFamily: 'ui-monospace, monospace' }}>v1.0 · 2026</span>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 48 }}>
        <ArcLockupIntegrated height={140} />
        <div>
          <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.32em', color: MUTED, textTransform: 'uppercase', marginBottom: 12 }}>
            Movement Analytics
          </div>
          <h1 style={{ fontSize: 56, fontWeight: 200, letterSpacing: '-0.03em', lineHeight: 1, margin: 0 }}>
            The shape of <br/>
            <span style={{ fontStyle: 'italic', fontWeight: 300 }}>elite performance.</span>
          </h1>
          <p style={{ marginTop: 24, fontSize: 14, color: '#444', lineHeight: 1.6, maxWidth: 460, fontWeight: 400 }}>
            ARC is the AI sport monitoring system that captures the trajectory
            of every movement — through sensors on your hands and feet —
            translating raw biomechanics into actionable performance insight.
          </p>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', borderTop: `1px solid ${LINE}`, paddingTop: 20 }}>
        <div>
          <Caption>Issued by</Caption>
          <div style={{ fontSize: 13, marginTop: 4 }}>ARC Performance Labs</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <Caption>Document</Caption>
          <Mono style={{ fontSize: 12, color: INK, display: 'block', marginTop: 4 }}>ARC-BG-001</Mono>
        </div>
      </div>
    </div>
  );
}

// ─── PAGE 02 — Logo Lockups ───────────────────────────────────
function LogoLockupsPage() {
  return (
    <Page no="02" title={<>Lockups <br/><span style={{ color: MUTED }}>The three official forms</span></>} total="08">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 24 }}>
        <Cell label="Wordmark integrado" code="ARC-01"><ArcLockupIntegrated height={56} /></Cell>
        <Cell label="Símbolo solo" code="ARC-02"><ArcLockupSymbol height={80} /></Cell>
        <Cell label="Wordmark sin símbolo" code="ARC-03"><ArcLockupWordmark height={56} /></Cell>
      </div>

      <div style={{ marginTop: 40, display: 'grid', gridTemplateColumns: '120px 1fr', gap: 32, fontSize: 12, lineHeight: 1.7, color: '#333' }}>
        <Caption>Primario</Caption>
        <div><strong style={{ fontWeight: 500 }}>ARC-01</strong> — Wordmark integrado. La forma principal. Úsalo siempre que sea posible (web, app, packaging, marketing).</div>
        <Caption>Display</Caption>
        <div><strong style={{ fontWeight: 500 }}>ARC-02</strong> — Símbolo aislado. Para espacios reducidos (favicon, app icon, sensor físico) y para usos de display: hero shots, animaciones, splash screens.</div>
        <Caption>Editorial</Caption>
        <div><strong style={{ fontWeight: 500 }}>ARC-03</strong> — Wordmark sin símbolo. En contextos donde la marca ya está establecida: títulos largos, body copy, prensa.</div>
      </div>
    </Page>
  );
}

// ─── PAGE 03 — Color Variants ─────────────────────────────────
function ColorVariantsPage() {
  return (
    <Page no="03" title={<>Versiones de color <br/><span style={{ color: MUTED }}>Black, white, outline, lime</span></>} total="08">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <Cell label="Black on white" code="#0A0A0A" height={200}>
          <ArcLockupIntegrated height={64} />
        </Cell>
        <Cell label="White on black" code="#FFFFFF" dark height={200}>
          <ArcLockupIntegrated height={64} color="#fff" />
        </Cell>
        <Cell label="Outline" code="STROKE 1.5" height={200}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}>
            <ArcMarkOutline size={92} />
            <span style={{ fontSize: 64, fontWeight: 200, letterSpacing: '0.04em', color: 'transparent', WebkitTextStroke: '1.2px #0a0a0a', fontFamily: '"Inter", sans-serif', lineHeight: 0.9 }}>RC</span>
          </div>
        </Cell>
        <Cell label="Performance lime" code="#D6FF00" dark height={200}>
          <ArcLockupIntegrated height={64} color={LIME} />
        </Cell>
      </div>

      <div style={{ marginTop: 36, padding: 20, background: '#fafafa', border: `1px solid ${LINE}` }}>
        <Caption style={{ marginBottom: 10 }}>Reglas de uso</Caption>
        <ul style={{ margin: 0, padding: 0, listStyle: 'none', fontSize: 12, lineHeight: 1.8, color: '#333' }}>
          <li>· <strong style={{ fontWeight: 500 }}>Black on white</strong> es la versión por defecto. Úsala siempre que el fondo sea claro.</li>
          <li>· <strong style={{ fontWeight: 500 }}>White on black</strong> requiere un fondo de #0A0A0A o más oscuro.</li>
          <li>· <strong style={{ fontWeight: 500 }}>Outline</strong> solo para grabados, bordados o vinilo cortado. Nunca en pantalla.</li>
          <li>· <strong style={{ fontWeight: 500 }}>Lime</strong> reservado para producto físico (sensor) y acentos puntuales.</li>
        </ul>
      </div>
    </Page>
  );
}

// ─── PAGE 04 — Sizing & Scale ─────────────────────────────────
function SizingPage() {
  const sizes = [
    { px: 16, label: 'Favicon', use: 'Browser tab' },
    { px: 24, label: 'UI mínimo', use: 'App nav, buttons' },
    { px: 32, label: 'Pequeño', use: 'Email signature' },
    { px: 48, label: 'Medio', use: 'App icon' },
    { px: 96, label: 'Grande', use: 'Hero, splash' },
  ];
  return (
    <Page no="04" title={<>Tamaños mínimos <br/><span style={{ color: MUTED }}>Escala y legibilidad</span></>} total="08">
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '40px 0', borderBottom: `1px solid ${LINE}` }}>
        {sizes.map((s) => (
          <div key={s.px} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, flex: 1 }}>
            <ArcMarkTall size={s.px} />
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 11, fontWeight: 500 }}>{s.label}</div>
              <Mono style={{ fontSize: 10 }}>{s.px}px</Mono>
            </div>
          </div>
        ))}
      </div>

      <div style={{ marginTop: 28, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div style={{ padding: 20, background: '#fafafa', border: `1px solid ${LINE}` }}>
          <Caption style={{ marginBottom: 10 }}>Tamaño mínimo digital</Caption>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8 }}>
            <span style={{ fontSize: 36, fontWeight: 200 }}>16</span>
            <span style={{ fontSize: 14, color: MUTED }}>px</span>
          </div>
          <p style={{ fontSize: 12, color: '#444', lineHeight: 1.6, margin: 0 }}>
            Bajo este tamaño, el punto del símbolo se pierde. Usa una versión simplificada del símbolo (sin punto) optimizada para favicon.
          </p>
        </div>
        <div style={{ padding: 20, background: '#fafafa', border: `1px solid ${LINE}` }}>
          <Caption style={{ marginBottom: 10 }}>Tamaño mínimo impreso</Caption>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8 }}>
            <span style={{ fontSize: 36, fontWeight: 200 }}>8</span>
            <span style={{ fontSize: 14, color: MUTED }}>mm</span>
          </div>
          <p style={{ fontSize: 12, color: '#444', lineHeight: 1.6, margin: 0 }}>
            En tinta o serigrafía, el grosor de línea debe mantenerse a 0.4mm o más para evitar quiebres.
          </p>
        </div>
      </div>
    </Page>
  );
}

// ─── PAGE 05 — Clear space & construction ─────────────────────
function ClearSpacePage() {
  // X is the height of the dot (~3 in viewBox 100, scaled). We render the
  // logo with overlay markers showing the X-units around it.
  const X = 18; // px of the safety unit (scaled for visualization)
  return (
    <Page no="05" title={<>Espacio de protección <br/><span style={{ color: MUTED }}>Clear space &amp; construction</span></>} total="08">
      <div style={{ position: 'relative', padding: 48, background: '#fafafa', border: `1px solid ${LINE}`, display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: 320 }}>
        {/* Dotted clear-space rectangle */}
        <div style={{ position: 'relative', padding: X * 2 }}>
          <div style={{ position: 'absolute', inset: 0, border: `1px dashed ${LIME}`, pointerEvents: 'none' }} />
          {/* X markers on each edge */}
          <div style={{ position: 'absolute', top: -10, left: '50%', transform: 'translateX(-50%)', background: PAPER, padding: '0 6px' }}>
            <Mono style={{ color: '#444' }}>2X</Mono>
          </div>
          <div style={{ position: 'absolute', bottom: -10, left: '50%', transform: 'translateX(-50%)', background: PAPER, padding: '0 6px' }}>
            <Mono style={{ color: '#444' }}>2X</Mono>
          </div>
          <div style={{ position: 'absolute', left: -14, top: '50%', transform: 'translateY(-50%) rotate(-90deg)', background: PAPER, padding: '0 6px' }}>
            <Mono style={{ color: '#444' }}>2X</Mono>
          </div>
          <div style={{ position: 'absolute', right: -14, top: '50%', transform: 'translateY(-50%) rotate(90deg)', background: PAPER, padding: '0 6px' }}>
            <Mono style={{ color: '#444' }}>2X</Mono>
          </div>
          <ArcLockupIntegrated height={56} />
        </div>
      </div>

      <div style={{ marginTop: 32, display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: 32 }}>
        <div>
          <Caption style={{ marginBottom: 12 }}>Unidad X</Caption>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 16 }}>
            <div style={{ width: 18, height: 18, background: LIME, border: `1px solid ${INK}` }} />
            <span style={{ fontSize: 12 }}>= altura del punto del símbolo</span>
          </div>
          <p style={{ fontSize: 12, color: '#444', lineHeight: 1.6, margin: 0 }}>
            Mantén un mínimo de <strong>2X</strong> de aire alrededor del logo en todas las direcciones. Ningún elemento gráfico, texto o borde puede invadir esta zona.
          </p>
        </div>
        <div style={{ borderLeft: `1px solid ${LINE}`, paddingLeft: 32 }}>
          <Caption style={{ marginBottom: 12 }}>Construcción del símbolo</Caption>
          <div style={{ display: 'flex', alignItems: 'center', gap: 24, marginBottom: 16 }}>
            <svg width="90" height="120" viewBox="0 0 75 100" fill="none">
              <rect x="0" y="0" width="75" height="100" stroke={LIME} strokeWidth="0.5" strokeDasharray="2 2" fill="none" />
              <line x1="0" y1="50" x2="75" y2="50" stroke={LIME} strokeWidth="0.5" strokeDasharray="2 2" />
              <line x1="37.5" y1="0" x2="37.5" y2="100" stroke={LIME} strokeWidth="0.5" strokeDasharray="2 2" />
              <path d="M8 70 Q37.5 -10 67 70" stroke={INK} strokeWidth="3" strokeLinecap="round" />
              <circle cx="37.5" cy="58" r="3" fill={INK} />
            </svg>
            <div style={{ fontSize: 11, lineHeight: 1.7, color: '#444' }}>
              Proporción: <Mono style={{ fontSize: 11 }}>3:4</Mono> (W:H)<br/>
              Stroke: <Mono style={{ fontSize: 11 }}>3 / 100</Mono> de viewBox<br/>
              Punto: <Mono style={{ fontSize: 11 }}>r = 3</Mono>, centrado en X
            </div>
          </div>
        </div>
      </div>
    </Page>
  );
}

// ─── PAGE 06 — Misuse / Don'ts ────────────────────────────────
function MisusePage() {
  const Bad = ({ label, children }) => (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <div style={{
        height: 140, background: '#fafafa', border: `1px solid ${LINE}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
      }}>
        {children}
        <svg width="20" height="20" viewBox="0 0 20 20" style={{ position: 'absolute', top: 8, right: 8 }}>
          <circle cx="10" cy="10" r="9" fill="#e63b3b" />
          <line x1="6" y1="6" x2="14" y2="14" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
          <line x1="14" y1="6" x2="6" y2="14" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </div>
      <div style={{ fontSize: 11, color: '#444', marginTop: 8 }}>{label}</div>
    </div>
  );

  return (
    <Page no="06" title={<>Mal uso <br/><span style={{ color: MUTED }}>What not to do</span></>} total="08">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
        <Bad label="No estires ni distorsiones la proporción.">
          <div style={{ transform: 'scaleX(1.6)' }}><ArcLockupIntegrated height={40} /></div>
        </Bad>
        <Bad label="No rotes el logo.">
          <div style={{ transform: 'rotate(-12deg)' }}><ArcLockupIntegrated height={40} /></div>
        </Bad>
        <Bad label="No alteres el espaciado entre símbolo y letras.">
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 24 }}>
            <ArcMarkTall size={56} />
            <span style={{ fontSize: 40, fontWeight: 200, letterSpacing: '0.04em', fontFamily: '"Inter", sans-serif', color: INK }}>RC</span>
          </div>
        </Bad>
        <Bad label="No cambies a colores no autorizados.">
          <ArcLockupIntegrated height={40} color="#ff5b9b" />
        </Bad>
        <Bad label="No uses sobre fondos con bajo contraste.">
          <div style={{ background: '#444', padding: 14 }}>
            <ArcLockupIntegrated height={40} />
          </div>
        </Bad>
        <Bad label="No añadas sombras, gradientes o efectos.">
          <div style={{ filter: 'drop-shadow(0 4px 8px rgba(0,0,0,.4))' }}>
            <ArcLockupIntegrated height={40} />
          </div>
        </Bad>
        <Bad label="No engrueses el trazo del símbolo.">
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}>
            <ArcMarkTall size={60} strokeWidth={9} />
            <span style={{ fontSize: 40, fontWeight: 200, letterSpacing: '0.04em', fontFamily: '"Inter", sans-serif', color: INK }}>RC</span>
          </div>
        </Bad>
        <Bad label="No uses el wordmark sin el símbolo en aplicaciones primarias.">
          <span style={{ fontSize: 40, fontWeight: 200, letterSpacing: '0.18em', fontFamily: '"Inter", sans-serif', color: INK }}>ARC</span>
        </Bad>
        <Bad label="No reemplaces la tipografía.">
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}>
            <ArcMarkTall size={56} />
            <span style={{ fontSize: 40, fontFamily: 'Times New Roman, serif', letterSpacing: '0.04em', color: INK, fontStyle: 'italic' }}>RC</span>
          </div>
        </Bad>
      </div>
    </Page>
  );
}

// ─── PAGE 07 — Color & Typography ─────────────────────────────
function ColorTypeSystemPage() {
  const Swatch = ({ name, hex, rgb, role, dark, lime }) => (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <div style={{
        height: 140, background: hex,
        border: hex.toLowerCase() === '#ffffff' ? `1px solid ${LINE}` : 'none',
        position: 'relative',
      }}>
        <span style={{ position: 'absolute', bottom: 12, left: 12, fontSize: 10, color: dark ? PAPER : (lime ? INK : INK), letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 500 }}>
          {role}
        </span>
      </div>
      <div style={{ paddingTop: 10 }}>
        <div style={{ fontSize: 13, fontWeight: 500 }}>{name}</div>
        <Mono style={{ display: 'block', marginTop: 2 }}>{hex.toUpperCase()}</Mono>
        <Mono style={{ display: 'block' }}>{rgb}</Mono>
      </div>
    </div>
  );

  const TypeRow = ({ weight, name, sample, sampleSize = 28, role }) => (
    <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr 140px', gap: 24, alignItems: 'baseline', padding: '16px 0', borderBottom: `1px solid ${LINE}` }}>
      <div>
        <Mono>{weight}</Mono>
        <div style={{ fontSize: 11, marginTop: 2, color: '#666' }}>{name}</div>
      </div>
      <div style={{ fontFamily: '"Inter", sans-serif', fontSize: sampleSize, fontWeight: weight, lineHeight: 1, color: INK, letterSpacing: weight <= 300 ? '-0.01em' : '0' }}>
        {sample}
      </div>
      <div style={{ fontSize: 10, color: MUTED, letterSpacing: '0.06em', textTransform: 'uppercase' }}>{role}</div>
    </div>
  );

  return (
    <Page no="07" title={<>Color &amp; tipografía <br/><span style={{ color: MUTED }}>The visual system</span></>} total="08">
      <Caption style={{ marginBottom: 14 }}>Paleta primaria</Caption>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginBottom: 32 }}>
        <Swatch name="Ink" hex="#0A0A0A" rgb="10 / 10 / 10" role="Primary" dark />
        <Swatch name="Paper" hex="#FFFFFF" rgb="255 / 255 / 255" role="Background" />
        <Swatch name="Performance Lime" hex="#D6FF00" rgb="214 / 255 / 0" role="Accent" lime />
      </div>

      <Caption style={{ marginBottom: 14 }}>Neutros</Caption>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 8, marginBottom: 36 }}>
        {[
          ['Ash 900', '#1a1a1a'],
          ['Ash 700', '#444444'],
          ['Ash 500', '#9a9a9a'],
          ['Ash 300', '#e5e5e5'],
          ['Ash 100', '#fafafa'],
        ].map(([n, h]) => (
          <div key={n}>
            <div style={{ height: 64, background: h, border: h === '#fafafa' ? `1px solid ${LINE}` : 'none' }} />
            <div style={{ fontSize: 11, fontWeight: 500, marginTop: 6 }}>{n}</div>
            <Mono style={{ fontSize: 10 }}>{h.toUpperCase()}</Mono>
          </div>
        ))}
      </div>

      <Caption style={{ marginBottom: 4 }}>Tipografía · Inter</Caption>
      <div style={{ fontSize: 11, color: MUTED, marginBottom: 8 }}>Una sola familia. Pesos definidos por función.</div>
      <div>
        <TypeRow weight={200} name="ExtraLight" sample="Aa Bb Cc 1234" sampleSize={32} role="Hero · Wordmark" />
        <TypeRow weight={300} name="Light" sample="Headline display" sampleSize={28} role="Page titles" />
        <TypeRow weight={400} name="Regular" sample="Body copy that flows naturally." sampleSize={16} role="Body text" />
        <TypeRow weight={500} name="Medium" sample="LABEL · CAPTION" sampleSize={11} role="Eyebrows · UI labels" />
        <TypeRow weight={600} name="SemiBold" sample="Emphasis &amp; metrics" sampleSize={14} role="Data callouts" />
      </div>
    </Page>
  );
}

// ─── PAGE 08 — Voice & Tagline ────────────────────────────────
function VoicePage() {
  const Pair = ({ doIt, dont }) => (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 0, borderBottom: `1px solid ${LINE}` }}>
      <div style={{ padding: '16px 20px 16px 0', borderRight: `1px solid ${LINE}` }}>
        <div style={{ fontSize: 9, fontWeight: 500, letterSpacing: '0.32em', color: '#1f9e5a', textTransform: 'uppercase', marginBottom: 6 }}>Sí</div>
        <div style={{ fontSize: 14, color: INK, fontWeight: 400, lineHeight: 1.4 }}>{doIt}</div>
      </div>
      <div style={{ padding: '16px 0 16px 20px' }}>
        <div style={{ fontSize: 9, fontWeight: 500, letterSpacing: '0.32em', color: '#c93a3a', textTransform: 'uppercase', marginBottom: 6 }}>No</div>
        <div style={{ fontSize: 14, color: '#888', fontWeight: 400, lineHeight: 1.4, textDecoration: 'line-through', textDecorationColor: '#c93a3a' }}>{dont}</div>
      </div>
    </div>
  );

  return (
    <Page no="08" title={<>Tono &amp; tagline <br/><span style={{ color: MUTED }}>The voice of ARC</span></>} total="08">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, marginBottom: 32 }}>
        <div>
          <Caption style={{ marginBottom: 12 }}>Lockup oficial</Caption>
          <div style={{ padding: 28, background: '#fafafa', border: `1px solid ${LINE}`, display: 'flex', flexDirection: 'column', gap: 14 }}>
            <ArcLockupIntegrated height={48} />
            <div style={{ height: 1, background: LINE }} />
            <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.32em', textTransform: 'uppercase', color: '#444' }}>
              Movement Analytics
            </div>
          </div>
        </div>
        <div>
          <Caption style={{ marginBottom: 12 }}>Taglines</Caption>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[
              ['ES', 'Mide cada movimiento.'],
              ['EN', 'Measure every move.'],
              ['ES', 'La forma del rendimiento.'],
              ['EN', 'The shape of performance.'],
              ['ES', 'De la trayectoria al podio.'],
            ].map(([lang, line], i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'baseline', gap: 12, padding: '8px 0', borderBottom: `1px solid ${LINE}` }}>
                <Mono style={{ fontSize: 9 }}>{lang}</Mono>
                <span style={{ fontSize: 14, fontWeight: 300, fontStyle: 'italic' }}>{line}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <Caption style={{ marginBottom: 8 }}>Personalidad</Caption>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 28 }}>
        {['Preciso', 'Silencioso', 'Atlético', 'Inteligente', 'Premium', 'Directo', 'Sin adornos'].map((t) => (
          <span key={t} style={{ padding: '6px 12px', border: `1px solid ${INK}`, fontSize: 11, fontWeight: 500, letterSpacing: '0.06em' }}>{t}</span>
        ))}
      </div>

      <Caption style={{ marginBottom: 4 }}>Cómo escribimos</Caption>
      <div>
        <Pair
          doIt="“Tu zancada perdió 4° de eficiencia en el km 12.”"
          dont="“¡Wow! Mira qué interesante lo que pasó en tu carrera 🔥”"
        />
        <Pair
          doIt="“Datos en tiempo real. Decisiones inmediatas.”"
          dont="“La revolucionaria plataforma que cambiará tu vida deportiva.”"
        />
        <Pair
          doIt="“ARC no opina. Mide.”"
          dont="“ARC es tu mejor amigo en el entrenamiento.”"
        />
      </div>
    </Page>
  );
}

// ─── App ──────────────────────────────────────────────────────
function App() {
  return (
    <DesignCanvas>
      <DCSection id="brand" title="ARC · Brand Guidelines"
        subtitle="8 páginas · click cualquiera para verla en pantalla completa">
        <DCArtboard id="p01" label="01 · Cover" width={PAGE_W} height={PAGE_H}>
          <CoverPage />
        </DCArtboard>
        <DCArtboard id="p02" label="02 · Lockups" width={PAGE_W} height={PAGE_H}>
          <LogoLockupsPage />
        </DCArtboard>
        <DCArtboard id="p03" label="03 · Color Variants" width={PAGE_W} height={PAGE_H}>
          <ColorVariantsPage />
        </DCArtboard>
        <DCArtboard id="p04" label="04 · Sizing" width={PAGE_W} height={PAGE_H}>
          <SizingPage />
        </DCArtboard>
        <DCArtboard id="p05" label="05 · Clear Space" width={PAGE_W} height={PAGE_H}>
          <ClearSpacePage />
        </DCArtboard>
        <DCArtboard id="p06" label="06 · Misuse" width={PAGE_W} height={PAGE_H}>
          <MisusePage />
        </DCArtboard>
        <DCArtboard id="p07" label="07 · Color & Type" width={PAGE_W} height={PAGE_H}>
          <ColorTypeSystemPage />
        </DCArtboard>
        <DCArtboard id="p08" label="08 · Voice & Tagline" width={PAGE_W} height={PAGE_H}>
          <VoicePage />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
