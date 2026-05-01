// ARC — Stylized GPS map (dark sport)
// Mapbox/Google-style dark map with custom route overlay.
// Renders a believable urban grid with parks + the runner's route.

// Generate a deterministic pseudo-random urban grid
function buildMapPaths(seed = 1) {
  // Major roads — slight curves + intersections
  const major = [
    'M0,180 Q120,170 240,185 T420,200',
    'M0,330 Q150,340 300,330 T420,335',
    'M80,0 Q90,160 100,330 T130,640',
    'M280,0 Q270,140 285,290 T310,640',
  ];
  // Minor streets — denser grid
  const minor = [];
  for (let i = 0; i < 14; i++) {
    const y = 30 + i * 45 + (i % 3) * 5;
    minor.push(`M0,${y} L420,${y + (i%2 === 0 ? 4 : -3)}`);
  }
  for (let i = 0; i < 9; i++) {
    const x = 20 + i * 48 + (i % 3) * 4;
    minor.push(`M${x},0 L${x + (i%2 === 0 ? 5 : -4)},640`);
  }
  return { major, minor };
}

// A park / green space polygon
const parks = [
  // Central park-ish blob
  'M165,210 Q200,200 230,215 Q255,235 250,275 Q240,300 210,305 Q175,300 162,275 Q150,240 165,210 Z',
];

// Water — a river curve
const water = 'M0,440 Q80,460 160,450 Q260,435 340,470 Q400,490 420,485 L420,640 L0,640 Z';

// Sample running route — a loop through the city
const ROUTES = {
  loop_5k: 'M210,420 L210,378 Q205,365 218,355 L260,325 Q278,318 282,300 L290,250 Q288,232 272,225 L228,212 Q210,212 200,228 L168,275 Q160,290 170,302 L195,335 Q200,348 192,358 L155,392 Q145,405 152,420 L188,448 Q205,455 210,440 Z',
  outback_3k: 'M210,420 L218,380 L240,355 L260,310 L255,265 L230,245 L195,260 L185,310 L210,355 L195,400 L210,420',
};

function ARCMap({
  width = '100%', height = 280, route = 'loop_5k',
  showCurrent = true, showStart = true, currentT = 0.65,
  zoom = 1, label,
}) {
  const c = TOKENS.color;
  const { major, minor } = buildMapPaths();

  // Find the (approximate) point at currentT along the path
  const routeRef = React.useRef();
  const [currentPoint, setCurrentPoint] = React.useState(null);
  const [startPoint, setStartPoint] = React.useState(null);
  const [routeLen, setRouteLen] = React.useState(0);

  React.useEffect(() => {
    if (!routeRef.current) return;
    const path = routeRef.current;
    const total = path.getTotalLength();
    setRouteLen(total);
    setCurrentPoint(path.getPointAtLength(total * currentT));
    setStartPoint(path.getPointAtLength(0));
  }, [currentT, route]);

  return (
    <div style={{
      width, height, position: 'relative', overflow: 'hidden',
      background: c.surfaceMap, borderRadius: 0,
    }}>
      <svg width="100%" height="100%" viewBox="0 0 420 640" preserveAspectRatio="xMidYMid slice"
           style={{ display: 'block', transform: `scale(${zoom})`, transformOrigin: 'center' }}>
        {/* Base */}
        <rect x="0" y="0" width="420" height="640" fill={c.surfaceMap}/>

        {/* Subtle grid pattern */}
        <defs>
          <pattern id="mapgrid" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M40 0 L0 0 0 40" fill="none" stroke="rgba(255,255,255,0.014)" strokeWidth="0.5"/>
          </pattern>
          <linearGradient id="routeGlow" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#00E5FF" stopOpacity="0.9"/>
            <stop offset="100%" stopColor="#00E5FF" stopOpacity="0.6"/>
          </linearGradient>
          <filter id="routeBlur" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3"/>
          </filter>
        </defs>
        <rect x="0" y="0" width="420" height="640" fill="url(#mapgrid)"/>

        {/* Park */}
        {parks.map((d, i) => (
          <path key={i} d={d} fill="rgba(61,220,132,0.06)" stroke="rgba(61,220,132,0.12)" strokeWidth="0.5"/>
        ))}

        {/* Water */}
        <path d={water} fill="rgba(0,80,120,0.18)" stroke="rgba(0,140,180,0.15)" strokeWidth="0.5"/>

        {/* Minor streets */}
        {minor.map((d, i) => (
          <path key={`min-${i}`} d={d} fill="none" stroke="rgba(255,255,255,0.025)" strokeWidth="1"/>
        ))}
        {/* Major roads */}
        {major.map((d, i) => (
          <path key={`maj-${i}`} d={d} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="2.5" strokeLinecap="round"/>
        ))}

        {/* Route — glow underlay */}
        <path d={ROUTES[route]} fill="none" stroke="#00E5FF" strokeOpacity="0.25"
              strokeWidth="10" strokeLinecap="round" strokeLinejoin="round" filter="url(#routeBlur)"/>
        {/* Route — main line */}
        <path ref={routeRef} d={ROUTES[route]} fill="none" stroke="#00E5FF"
              strokeWidth="3.2" strokeLinecap="round" strokeLinejoin="round"/>

        {/* Start point */}
        {showStart && startPoint && (
          <g>
            <circle cx={startPoint.x} cy={startPoint.y} r="6" fill="#00E5FF" stroke="#0A0A0A" strokeWidth="2"/>
          </g>
        )}

        {/* Current position with halo */}
        {showCurrent && currentPoint && (
          <g>
            <circle cx={currentPoint.x} cy={currentPoint.y} r="14" fill="rgba(0,229,255,0.25)"/>
            <circle cx={currentPoint.x} cy={currentPoint.y} r="8" fill="rgba(0,229,255,0.5)"/>
            <circle cx={currentPoint.x} cy={currentPoint.y} r="4" fill="#FFFFFF" stroke="#00E5FF" strokeWidth="2"/>
          </g>
        )}
      </svg>

      {/* Optional label overlay */}
      {label && (
        <div style={{
          position: 'absolute', top: 12, left: 12,
          padding: '6px 10px', borderRadius: 8, fontSize: 10, letterSpacing: '0.12em',
          textTransform: 'uppercase', color: c.text2,
          background: 'rgba(15,26,31,0.85)', backdropFilter: 'blur(8px)',
          border: `1px solid ${c.border}`,
        }}>{label}</div>
      )}
    </div>
  );
}

// Smaller version for the History list cards
function ARCMapMini({ size = 48, route = 'loop_5k' }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 8, overflow: 'hidden',
      background: TOKENS.color.surfaceMap, position: 'relative',
    }}>
      <svg width="100%" height="100%" viewBox="120 200 220 240" preserveAspectRatio="xMidYMid slice">
        <rect x="0" y="0" width="420" height="640" fill={TOKENS.color.surfaceMap}/>
        <path d={ROUTES[route]} fill="none" stroke="#00E5FF" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </div>
  );
}

Object.assign(window, { ARCMap, ARCMapMini, ROUTES });
