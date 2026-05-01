// ARC Sport Monitor — Design tokens (v1)
// Aligned with the brand guidelines + product doc

const TOKENS = {
  // ─── Color — dark sport ──────────────────────────────────
  color: {
    bg:        '#0A0A0A',  // App background
    surface:   '#13131F',  // Cards, modals (slightly tweaked from doc for warmth)
    surfaceHi: '#0F0F1A',  // Nested cards, banners
    surfaceMap:'#0F1A1F',  // Map background
    border:    '#2B2D3F',  // Sutil
    borderHi:  '#3A3D52',  // More visible borders

    text:      '#FFFFFF',
    text2:     '#9AA0AB',
    text3:     '#7A7E88',
    text4:     '#52555E',  // Disabled / placeholders

    accent:    '#00E5FF',  // Cyan — primary
    accentDim: 'rgba(0,229,255,0.15)',
    accentDim2:'rgba(0,229,255,0.33)',
    accentGlow:'rgba(0,229,255,0.5)',

    ok:        '#3DDC84',
    okDim:     'rgba(61,220,132,0.18)',
    warn:      '#FFB020',
    warnDim:   'rgba(255,176,32,0.18)',
    crit:      '#FF4D4F',
    critDim:   'rgba(255,77,79,0.15)',

    lime:      '#D6FF00',  // From brand — alt accent for special highlights
  },

  // ─── Typography ──────────────────────────────────────────
  font: {
    sans: '"Inter", -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif',
    mono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace',
  },

  // ─── Spacing (4px grid) ──────────────────────────────────
  s: {
    1:  4, 2:  8, 3: 12, 4: 16, 5: 20,
    6: 24, 7: 32, 8: 40, 9: 48, 10: 64,
  },

  // ─── Radii ──────────────────────────────────────────────
  r: {
    sm: 8, md: 12, lg: 16, xl: 18, full: 9999,
  },
};

// CSS custom properties — inject once
function injectTokens() {
  if (document.getElementById('arc-tokens')) return;
  const s = document.createElement('style');
  s.id = 'arc-tokens';
  s.textContent = `
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@200;300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
    :root {
      --bg: ${TOKENS.color.bg};
      --surface: ${TOKENS.color.surface};
      --surface-hi: ${TOKENS.color.surfaceHi};
      --surface-map: ${TOKENS.color.surfaceMap};
      --border: ${TOKENS.color.border};
      --text: ${TOKENS.color.text};
      --text2: ${TOKENS.color.text2};
      --text3: ${TOKENS.color.text3};
      --accent: ${TOKENS.color.accent};
      --ok: ${TOKENS.color.ok};
      --warn: ${TOKENS.color.warn};
      --crit: ${TOKENS.color.crit};
      --font-sans: ${TOKENS.font.sans};
      --font-mono: ${TOKENS.font.mono};
    }
    .arc-app, .arc-app * {
      font-family: var(--font-sans);
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      font-feature-settings: "ss01", "cv11", "tnum";
      box-sizing: border-box;
    }
    .arc-mono { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
    .arc-tnum { font-variant-numeric: tabular-nums; }
  `;
  document.head.appendChild(s);
}
injectTokens();

window.TOKENS = TOKENS;
