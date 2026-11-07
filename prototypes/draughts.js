// Shared parts of the draughts prototypes: the season's background and the glass that shows
// its blurred copy, the board in 2D (painted by a port of the native shaders) and 3D,
// icons, and a switcher for the season, board theme, view, king style, background, and
// move hints (?season=, ?theme=, ?view=3d, ?king=, ?bg=, ?assist=).
// Plain script, no build step.
'use strict';

const Draughts = (() => {
  const params = new URLSearchParams(location.search);

  // The app's face (docs/architecture/rendering.md, "Fonts").
  const FONT = { family: 'Libertinus Sans', pkg: 'libertinus-sans', weights: [400, 700] };
  const SEASONS = ['autumn', 'winter', 'spring', 'summer'];
  // The season picks the board: autumn wood, winter stone, spring birch, summer sea.
  const SEASON_THEME = { autumn: 'wood', winter: 'stone', spring: 'birch', summer: 'sea' };
  const THEMES = Object.values(SEASON_THEME);
  const KINGS = ['auto', 'crown', 'stack'];

  function seasonNow() {
    const m = new Date().getMonth();
    return m < 2 || m === 11 ? 'winter' : m < 5 ? 'spring' : m < 8 ? 'summer' : 'autumn';
  }

  const pick = (key, values, fallback) => values.includes(params.get(key)) ? params.get(key) : fallback;
  const season = pick('season', SEASONS, seasonNow());
  const settings = {
    season,
    theme: pick('theme', THEMES, SEASON_THEME[season]),
    view: pick('view', ['2d', '3d'], '2d'),
    king: pick('king', KINGS, 'auto'),
    bg: pick('bg', ['auto', 'blur', 'photo'], 'auto'),
    // Move hints: "mistakes" (the default) only marks a wrong move; "moves" shows the
    // selected piece's targets, on by default only in the first lessons (docs/product.md).
    assist: pick('assist', ['moves', 'mistakes'], 'mistakes'),
  };

  // Auto: a crown on the face top down, where a stack reads as a shadow; a stack of two
  // discs with the crown on top in 3D, as kings are in Estonian play.
  function kingStyle(view, king = settings.king) {
    return king === 'auto' ? (view === '3d' ? 'stack' : 'crown') : king;
  }

  function loadFont() {
    const f = FONT;
    for (const w of f.weights) {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = `https://cdn.jsdelivr.net/npm/@fontsource/${f.pkg}@5.3.0/${w}.css`;
      document.head.appendChild(link);
    }
    return `'${f.family}', sans-serif`;
  }

  // The background: the season's photograph from design/backgrounds/masters/ (local, out
  // of git; its README says how to make it), or a painted stand-in without it. Behind the
  // 2D board (pages with <body data-screen="board">) it is blurred, as on the design
  // boards, so the flat board reads cleanly; sharp everywhere else (home, puzzles) and
  // behind the 3D board.
  function useBlur() {
    return settings.bg === 'blur' ||
      (settings.bg === 'auto' && settings.view === '2d' && document.body.dataset.screen === 'board');
  }
  const SCENE_FILE = (s) => `../design/backgrounds/masters/${s}-01-2048.jpg`;
  let sceneAspect = 1;  // width / height of the scene image

  const PALETTES = {
    winter: { sky: ['#1b2a44', '#51698d', '#c9d4e2'], sun: '#ffe9c8', hills: ['#9fb0c8', '#d6e0ec', '#eef3f8'], trees: '#2e3f52' },
    spring: { sky: ['#294766', '#6f9bbf', '#e6efe0'], sun: '#fff4d2', hills: ['#6f8f6a', '#9fbf7f', '#c9dca2'], trees: '#3c5a3a' },
    summer: { sky: ['#1d4f7a', '#5d9cc7', '#f2e6c9'], sun: '#fff1c4', hills: ['#4f7a6a', '#7aa08a'], trees: '#2f4f45' },
    autumn: { sky: ['#2b2a44', '#8a6a7d', '#f0bf8a'], sun: '#ffd7a0', hills: ['#6b4a3a', '#a8643a', '#c98a45'], trees: '#3b2a25' },
  };

  function paintScene(s, w, h) {
    const p = PALETTES[s];
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const g = c.getContext('2d');
    const sky = g.createLinearGradient(0, 0, 0, h * 0.75);
    p.sky.forEach((col, i) => sky.addColorStop(i / (p.sky.length - 1), col));
    g.fillStyle = sky;
    g.fillRect(0, 0, w, h);
    const sun = g.createRadialGradient(w * 0.72, h * 0.42, 0, w * 0.72, h * 0.42, h * 0.45);
    sun.addColorStop(0, p.sun);
    sun.addColorStop(1, p.sun + '00');
    g.fillStyle = sun;
    g.fillRect(0, 0, w, h);
    p.hills.forEach((col, i) => {
      const base = h * (0.55 + i * 0.12);
      g.fillStyle = col;
      g.beginPath();
      g.moveTo(0, h);
      for (let x = 0; x <= w; x += w / 60) g.lineTo(x, base - Math.sin(x / w * (3 + i * 2) + i * 1.7) * h * 0.05);
      g.lineTo(w, h);
      g.fill();
    });
    return c.toDataURL('image/jpeg', 0.85);
  }

  function setScene(url, aspect) {
    sceneAspect = aspect;
    document.body.style.setProperty('--scene', `url("${url}")`);
    syncGlass();
  }

  function loadScene() {
    // Blurred in CSS (draughts.css, .scene-blur), since a canvas can't read a file:// image.
    document.body.classList.toggle('scene-blur', useBlur());
    const img = new Image();
    img.onload = () => setScene(img.src, img.naturalWidth / img.naturalHeight);
    img.onerror = () => setScene(paintScene(settings.season, 1280, 1280), 1);
    img.src = SCENE_FILE(settings.season);
  }

  // Each glass panel shows the blurred scene at its own screen position: the scene is
  // cover-cropped to the viewport, and the panel's copy is offset by the panel's place
  // (plus the 48 px the blur layer reaches past the panel).
  function syncGlass() {
    const vw = innerWidth, vh = innerHeight;
    const sw = Math.max(vw, vh * sceneAspect), sh = sw / sceneAspect;
    const ox = (vw - sw) / 2, oy = (vh - sh) / 2;
    document.body.style.setProperty('--scene-w', `${sw}px`);
    document.body.style.setProperty('--scene-h', `${sh}px`);
    for (const el of document.querySelectorAll('.glass')) {
      const r = el.getBoundingClientRect();
      el.style.setProperty('--gx', `${ox - r.left + 48}px`);
      el.style.setProperty('--gy', `${oy - r.top + 48}px`);
    }
  }

  const ICONS = {
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    hint: '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.3h6c0-1 .4-1.8 1-2.3A7 7 0 0 0 12 2z"/>',
    restart: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    back: '<path d="M19 12H5"/><path d="M11 18l-6-6 6-6"/>',
    next: '<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>',
    home: '<path d="M3.5 10.5 12 3.5l8.5 7"/><path d="M5.5 9v11.5h13V9"/><path d="M10 20.5v-6h4v6"/>',
    clock: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5"/><path d="M9.5 2.5h5"/>',
    // Home tiles: filled shapes, which read better large.
    friend: '<circle class="solid" cx="8.5" cy="7.5" r="3.6"/><path class="solid" d="M1.5 20.5a7 7 0 0 1 14 0z"/><circle class="solid" cx="16.5" cy="8.3" r="3.1"/><path class="solid" d="M15.6 13.7a6.3 6.3 0 0 1 6.9 6.8h-5.3a8.6 8.6 0 0 0-1.6-6.8z"/>',
    computer: '<rect x="4" y="6" width="16" height="10" rx="3.5"/><path d="M12 6V3.5"/><circle class="solid" cx="12" cy="2.6" r="1.3"/><circle class="solid" cx="9" cy="11" r="1.4"/><circle class="solid" cx="15" cy="11" r="1.4"/>',
    puzzle: '<path class="solid" d="M4 7h4.2a2.8 2.8 0 1 1 5.6 0H18v4.2a2.8 2.8 0 1 1 0 5.6V21H4v-4.5a2.6 2.6 0 1 0 0-5.2z"/>',
    star: '<path class="solid" d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    starOff: '<path d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    crown: '<path class="solid" d="M3 17 2 7l5 4 5-7 5 7 5-4-1 10z"/><path class="solid" d="M3 19h18v2H3z"/>',
    crownLine: '<path d="M3 17 2 7l5 4 5-7 5 7 5-4-1 10z"/><path d="M3 20.5h18"/>',
    dots: '<circle class="solid" cx="7" cy="7" r="2.2"/><circle class="solid" cx="17" cy="7" r="2.2"/><circle class="solid" cx="7" cy="17" r="2.2"/><circle class="solid" cx="17" cy="17" r="2.2"/>',
    target: '<circle cx="12" cy="12" r="7"/><circle class="solid" cx="12" cy="12" r="2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',
    shield: '<path d="M12 2.5 4 5.5v6c0 5 3.4 8.6 8 10 4.6-1.4 8-5 8-10v-6z"/>',
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/><circle cx="12" cy="12" r="6.5"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c2.6 2.7 3.8 5.7 3.8 9s-1.2 6.3-3.8 9c-2.6-2.7-3.8-5.7-3.8-9S9.4 5.7 12 3z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  };

  function icon(name, cls = '') {
    return `<svg class="icon ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;
  }

  // The 2D board and pieces are painted as the native shaders draw them: a port of
  // app/draw.goose's board and piece fragment shaders, run once per board and per kind
  // of piece at its size on screen, into images the CSS shows (--board-img, --sprite).
  // Keep it in step with draw.goose; the values are in docs/architecture/rendering.md
  // ("Board and pieces", "Light").
  const Paint = (() => {
    const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);
    const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
    const fract = (x) => x - Math.floor(x);
    const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    const WHITE = [1, 1, 1], BLACK = [0, 0, 0];
    const tint = (c, a) => (a > 0 ? mix(c, WHITE, a) : mix(c, BLACK, -a));
    // Light toward white, shade toward a deeper tone of the same color.
    const lit = (c, a) => (a > 0 ? mix(c, WHITE, a) : mix(c, [c[0] * c[0] * 0.85, c[1] * c[1] * 0.85, c[2] * c[2] * 0.85], -a));
    const hash = (x, y) => fract(Math.sin(x * 127.1 + y * 311.7) * 43758.5453);
    function noise(x, y) {
      const ix = Math.floor(x), iy = Math.floor(y);
      let fx = x - ix, fy = y - iy;
      fx = fx * fx * (3 - 2 * fx);
      fy = fy * fy * (3 - 2 * fy);
      const a = hash(ix, iy), b = hash(ix + 1, iy), c = hash(ix, iy + 1), d = hash(ix + 1, iy + 1);
      return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
    }
    const box = (px, py, cx, cy, h, r) => {
      const qx = Math.abs(px - cx) - h + r, qy = Math.abs(py - cy) - h + r;
      return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
    };
    const color = (s) => {
      s = s.trim();
      return [1, 3, 5].map((i) => parseInt(s.slice(i, i + 2), 16) / 255);
    };
    const KIND = { wood: 0, stone: 1, birch: 2, sea: 3 };

    function canvas(w, h) {
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      const g = c.getContext('2d');
      return { c, g, img: g.createImageData(w, h) };
    }
    function put(img, i, rgb, a) {
      img.data[i] = rgb[0] * 255;
      img.data[i + 1] = rgb[1] * 255;
      img.data[i + 2] = rgb[2] * 255;
      img.data[i + 3] = a * 255;
    }

    // The board B px wide with its soft shadow, on a canvas reaching 5% past it on every
    // side (draughts.css places it so). squaresOnly: just the squares, for the 3D board.
    function board(t, n, B, squaresOnly) {
      const u = B * 0.01;
      const lw = squaresOnly ? 0 : 1.1 * u;              // the lip
      const rad = 1.6 * u;
      const inner = B - 2 * lw, sqw = inner / n;
      const m = squaresOnly ? 0 : Math.round(0.05 * B);  // the margin round the board
      const W = Math.round(B) + 2 * m;
      const { c, g, img } = canvas(W, W);
      const light = color(t.light), dark = color(t.dark), kind = t.kind;
      const line = mix(light, WHITE, 0.25);
      const bh = B / 2;
      for (let j = 0; j < W; j++) {
        for (let i = 0; i < W; i++) {
          const px = i + 0.5 - m, py = j + 0.5 - m;
          const k = (j * W + i) * 4;
          const fd = squaresOnly ? -B : box(px, py, bh, bh, bh, rad);
          // A soft shadow under the board, a little down.
          const sd = box(px, py, bh, bh + 1.4 * u, bh - u, rad);
          const sh = squaresOnly ? 0 : 0.55 * (1 - smooth(-3.6 * u, 3.6 * u, sd));
          if (fd >= 1) { put(img, k, BLACK, sh); continue; }
          const id = squaresOnly ? -B : box(px, py, bh, bh, inner / 2, 0.5 * rad);
          let col = BLACK;
          if (id > -1) {
            // The lip: the dark square's color, a line of the light square's color on
            // its outer edge (brightest on top), a dark seam where the squares sit.
            const tt = clamp(-fd / lw, 0, 1);
            const ny = (py - bh) / bh;
            let lip = tint(dark, 0.06 - 0.1 * ny);
            lip = mix(lip, line, (0.75 - 0.25 * ny) * (1 - smooth(0.1, 0.26, tt)));
            col = tint(lip, -0.35 * smooth(0.7, 1, tt));
          }
          if (id < 1) {
            const qx = (px - lw) / sqw, qy = (py - lw) / sqw;
            const cx = clamp(Math.floor(qx), 0, n - 1), cy = clamp(Math.floor(qy), 0, n - 1);
            const x = cx, y = n - 1 - cy;
            const h = hash(cx, cy);
            let a = 0;
            if (kind === 0) {
              // Wood: fine irregular streaks along the board, a broad soft figure, and
              // each square's own tone, all barely there; no regular stripes.
              const mx = px / u + 41 * h, my = py / u + 41 * h;
              a += 0.022 * (noise(mx * 2.6, my * 0.08) - 0.5) + 0.03 * (noise(mx * 0.35, my * 0.06) - 0.5) + 0.02 * (h - 0.5);
            } else if (kind === 1) {
              const mx = px / u, my = py / u;
              a += 0.07 * (0.6 * noise(mx * 0.45 + 13 * h, my * 0.45 + 13 * h) + 0.4 * noise(mx * 1.3, my * 1.3) - 0.5);
            } else if (kind === 2) {
              a += 0.03 * (noise(px / (3 * u), py / (0.35 * u)) - 0.5);
            } else {
              a += 0.02 * (noise(px / (2 * u), py / (2 * u)) - 0.5);
            }
            // Where squares meet: a hair of light on each square's top edge.
            a += 0.04 * (1 - smooth(0, 0.18 * u, fract(qy) * sqw));
            const s = tint((x + y) % 2 === 0 ? dark : light, a);
            col = mix(col, s, clamp(0.5 - id, 0, 1));
          }
          const cov = clamp(0.5 - fd, 0, 1);
          const al = cov + sh * (1 - cov);
          put(img, k, al > 0 ? col.map((v) => (v * cov) / al) : col, al);
        }
      }
      g.putImageData(img, 0, 0);
      return c.toDataURL();
    }

    // The crown: five points over a band, in units where it spans -1..1.
    const CROWN = [[-0.72, 0.30], [-0.88, -0.42], [-0.40, 0.02], [0.0, -0.62], [0.40, 0.02], [0.88, -0.42], [0.72, 0.30]];
    function crown(px, py) {
      let d = (px - CROWN[0][0]) ** 2 + (py - CROWN[0][1]) ** 2, s = 1;
      for (let i = 0, j = 6; i < 7; j = i, i++) {
        const ex = CROWN[j][0] - CROWN[i][0], ey = CROWN[j][1] - CROWN[i][1];
        const wx = px - CROWN[i][0], wy = py - CROWN[i][1];
        const t = clamp((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1);
        d = Math.min(d, (wx - ex * t) ** 2 + (wy - ey * t) ** 2);
        const a = py >= CROWN[i][1], b = py < CROWN[j][1], c = ex * wy > ey * wx;
        if ((a && b && c) || (!a && !b && !c)) s = -s;
      }
      const qx = Math.abs(px) - 0.72, qy = Math.abs(py - 0.47) - 0.09;
      const band = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0);
      return Math.min(s * Math.sqrt(d), band);
    }
    const shoulder = (r, a, b, dy) => {
      const th = 1.45 * clamp((r - a) / (b - a), 0, 1);
      return 0.7071 * (-dy * Math.sin(th) + Math.cos(th) - 1);
    };
    const groove = (r, a, b, dy) => {
      const t = (r - a) / (b - a);
      return t <= 0 || t >= 1 ? 0 : -dy * Math.sin(2 * Math.PI * t);
    };
    const fill = (d, w) => clamp(0.5 - d / w, 0, 1);

    // One piece, R px in radius, in the units of the piece shader (its radius is 1),
    // over local x -1.9..1.9 and y top..2.1 + side. o: { face, crownW, glow, black,
    // king: '' | 'crown' | 'stack', sel, side, lift, stack }.
    function piece(o, R) {
      const top = -1.9 - o.lift - o.stack;
      const W = Math.ceil(3.8 * R), H = Math.ceil((2.1 + o.side - top) * R);
      const { c, g, img } = canvas(W, H);
      const face = color(o.face), glow = color(o.glow), crownW = color(o.crownW);
      const black = o.black, sel = o.sel ? 1 : 0;
      const lift = sel ? o.lift : 0, side = o.side;
      const scale = 1 + 0.05 * sel;
      const w = 1 / R / scale;
      const sidec = black ? mix(face, BLACK, 0.5) : face.map((v) => v * v * 0.92);
      const gold = [0.914, 0.769, 0.416];
      for (let j = 0; j < H; j++) {
        for (let i = 0; i < W; i++) {
          const x = -1.9 + (i + 0.5) / R, y = top + (j + 0.5) / R;
          let ar = 0, ag = 0, ab = 0, aa = 0;
          const over = (col, a) => {
            ar = col[0] * a + ar * (1 - a); ag = col[1] * a + ag * (1 - a);
            ab = col[2] * a + ab * (1 - a); aa = a + aa * (1 - a);
          };
          // A short soft shadow, straight down and a touch right, that spreads as the
          // piece lifts, and a tight one where it touches the board.
          const d0 = Math.hypot(x - 0.04, y - 0.25 - 0.6 * lift) - 1;
          const soft = 0.16 + 0.5 * lift;
          over(BLACK, (0.4 - 0.1 * sel) * (1 - smooth(-2 * soft, 2 * soft, d0)));
          const d1 = Math.hypot(x, y - 0.06 - side) - 1;
          over(BLACK, 0.3 * (1 - smooth(-0.08, 0.06, d1)) * (1 - smooth(0, 0.2, lift)));
          if (sel) {
            const r = Math.hypot(x / scale, (y + lift) / scale);
            over(glow, 0.4 * Math.exp(-Math.max(r - 1, 0) * 5));
          }
          // A stacked king: the lower disc, then the upper one a disc higher.
          const discs = o.king === 'stack' ? [[0, side], [o.stack, o.stack]] : [[0, side]];
          let fr = 9;
          for (const [up, depth] of discs) {
            const fx = x / scale, fy = (y + lift + up) / scale;
            const r = Math.hypot(fx, fy);
            fr = r;
            const dy = fy / Math.max(r, 0.001);
            // The thin side under the face, rounder in the middle, darkest at its foot.
            const dd = depth / scale;
            const sy = fy - clamp(fy, 0, dd);
            const arc = Math.sqrt(Math.max(1 - fx * fx, 0));
            const foot = clamp((fy - arc) / dd, 0, 1);
            const sc = sidec.map((v) => v * (0.8 + 0.25 * arc) * (1 - 0.25 * foot));
            over(sc, fill(Math.hypot(fx, sy) - 1, w));
            // The flat matte top, a groove at 70% of the radius, the rounded outer edge.
            let col = tint(face, -0.02 * fy);
            const l = shoulder(r, 0.86, 1, dy);
            col = lit(col, l > 0 ? (black ? 1 : 1.2) * l : (black ? 0.28 : 0.4) * l);
            const gr = groove(r, 0.63, 0.76, dy);
            col = lit(col, gr > 0 ? (black ? 0.4 : 0.5) * gr : (black ? 0.6 : 1.2) * gr);
            col = lit(col, -(black ? 0.3 : 0.45) * (1 - smooth(0, 0.05, Math.abs(r - 0.695))));
            if (o.king === 'crown' || (o.king === 'stack' && up > 0)) {
              col = mix(col, black ? gold : crownW, fill(0.56 * crown(fx / 0.56, fy / 0.56), w));
            }
            over(col, fill(r - 1, w));
          }
          // Selected: a ring in the glow color a little out from the piece.
          if (sel) {
            const rd = Math.abs(fr - 1.13) - 0.055;
            over(glow, 0.6 * Math.exp(-Math.max(rd, 0) * 7));
            over(mix(glow, WHITE, 0.25), fill(rd, w));
          }
          const k = (j * W + i) * 4;
          put(img, k, aa > 0 ? [ar / aa, ag / aa, ab / aa] : BLACK, aa);
        }
      }
      g.putImageData(img, 0, 0);
      return { url: c.toDataURL(), top };
    }

    // What a theme's colors are where an element sits.
    function theme(el) {
      const cs = getComputedStyle(el);
      const v = (k) => cs.getPropertyValue(k).trim();
      return { light: v('--light'), dark: v('--dark'), face: { white: v('--w-face'), black: v('--b-face') },
        crownW: v('--crown-w'), glow: v('--glow'), kind: KIND[v('--kind')] ?? 3 };
    }

    const cache = new Map();
    const once = (key, make) => {
      if (!cache.has(key)) cache.set(key, make());
      return cache.get(key);
    };
    const dpr = () => Math.min(devicePixelRatio || 1, 3);

    // Paints every board and piece under root that isn't painted at its present size.
    function all(root = document) {
      for (const el of root.querySelectorAll('.board')) {
        const B = Math.round(el.getBoundingClientRect().width * dpr());
        if (!B || el.dataset.painted === String(B)) continue;
        const t = theme(el), n = +getComputedStyle(el).getPropertyValue('--n') || 8;
        const flat = !el.classList.contains('view-3d');
        const key = `b${flat}${t.light}${t.dark}${t.kind}${n}${B}`;
        el.style.setProperty(flat ? '--board-img' : '--squares-img', `url(${once(key, () => board(t, n, flat ? B : 800, !flat))})`);
        el.dataset.painted = String(B);
        el.classList.add('painted');
      }
      for (const el of root.querySelectorAll('.piece')) {
        const R = Math.round(el.getBoundingClientRect().width / 2 * dpr());
        if (!R || el.dataset.painted === String(R)) continue;
        const t = theme(el);
        const black = el.classList.contains('black');
        const king = el.classList.contains('king') ? (el.closest('.stack') ? 'stack' : 'crown') : '';
        const sel = el.classList.contains('selected');
        // Depths in units of the radius, as on an 8 × 8 board: the side 0.55% of the
        // board, the lift 0.8%, a stacked disc 1.3%; a disc is 78% of a square of a board
        // whose squares are 97.8% of it.
        const r1 = 0.39 * 0.978 / 8;
        const o = { face: black ? t.face.black : t.face.white, crownW: t.crownW, glow: t.glow, black, king, sel,
          side: 0.0055 / r1, lift: 0.008 / r1, stack: king === 'stack' ? 0.013 / r1 : 0 };
        const key = `p${o.face}${o.glow}${o.crownW}${black}${king}${sel}${R}`;
        const s = once(key, () => piece(o, R));
        // The image covers x -1.9..1.9 and y top..2.1 + side, in radii; the element is
        // -1..1 both ways.
        el.style.setProperty('--sprite', `url(${s.url})`);
        el.style.setProperty('--sprite-top', `${((s.top + 1) / 2) * 100}%`);
        el.style.setProperty('--sprite-bottom', `${(-(1.1 + o.side) / 2) * 100}%`);
        el.dataset.painted = String(R);
      }
    }
    return { all };
  })();

  // A 3D disc: a soft shadow, layers for the side, and the face on top. A stacked king is
  // two discs; a king's crown is on the top face.
  function disc3d(color, discs, crown, cls) {
    const per = 6;
    let html = `<div class="p3 ${color} ${cls}"><div class="shadow"></div>`;
    for (let i = 0; i < discs * per; i++) {
      const z = (i + Math.floor(i / per) * 0.08 * per) / per;  // a hairline gap between discs
      html += `<div class="layer" style="--z:${z.toFixed(3)}"></div>`;
    }
    const top = discs + (discs - 1) * 0.08;
    html += `<div class="face" style="--z:${top}">${crown ? `<div class="crown">${icon('crown')}</div>` : ''}</div>`;
    return html + '</div>';
  }

  // Squares as a1..h8 (or a1..j10); a1 is dark, bottom left, as in rules/.
  // Draws a board into el. opts: { n, theme, view, king, white: [...], black: [...],
  // kings: [...], selected, forced: [...], targets: [...], via: [...], last: [...] }.
  function board(el, opts) {
    const n = opts.n || 8;
    const view = opts.view || settings.view;
    const style = kingStyle(view, opts.king || settings.king);
    const set = (list) => new Set(list || []);
    const white = set(opts.white), black = set(opts.black), kings = set(opts.kings);
    const forced = set(opts.forced), targets = set(opts.targets), via = set(opts.via);
    const last = set(opts.last), error = set(opts.error);
    const hints = (opts.assist || settings.assist) === 'moves';
    el.classList.add('board', `theme-${opts.theme || settings.theme}`);
    if (style === 'stack') el.classList.add('stack');
    if (view === '3d') el.classList.add('view-3d');
    el.style.setProperty('--n', n);
    let html = '<div class="squares">';
    for (let y = n - 1; y >= 0; y--) {
      for (let x = 0; x < n; x++) {
        const sq = String.fromCharCode(97 + x) + (y + 1);
        const dark = (x + y) % 2 === 0;
        let inner = '';
        if (white.has(sq) || black.has(sq)) {
          const color = white.has(sq) ? 'white' : 'black';
          const cls = [opts.selected === sq ? 'selected' : '', forced.has(sq) ? 'forced' : ''].join(' ');
          if (view === '3d') {
            inner = disc3d(color, kings.has(sq) && style === 'stack' ? 2 : 1, kings.has(sq), cls);
          } else {
            inner = `<div class="piece ${color} ${kings.has(sq) ? 'king' : ''} ${cls}"></div>`;
          }
        } else if (targets.has(sq) && hints) {
          inner = '<div class="target"></div>';
        } else if (via.has(sq) && hints) {
          inner = '<div class="target via"></div>';
        }
        if (error.has(sq)) inner += '<div class="error"></div>';
        html += `<div class="sq${dark ? ' dark' : ''}${last.has(sq) ? ' last' : ''}">${inner}</div>`;
      }
    }
    el.innerHTML = html + '</div>';
    Paint.all(el.parentNode || document);
  }

  // The prototype switcher, bottom right, faint until hovered. Theme "auto" follows the
  // season.
  function bar() {
    const el = document.createElement('div');
    el.className = 'proto-bar';
    const select = (key, values, current) => `<select data-key="${key}" aria-label="${key}">${values.map((v) =>
      `<option${current === v ? ' selected' : ''}>${v}</option>`).join('')}</select>`;
    el.innerHTML = select('season', SEASONS, settings.season) +
      select('theme', ['auto', ...THEMES], params.has('theme') ? settings.theme : 'auto') +
      select('view', ['2d', '3d'], settings.view) + select('king', KINGS, settings.king) +
      select('bg', ['auto', 'blur', 'photo'], settings.bg) +
      select('assist', ['moves', 'mistakes'], settings.assist);
    el.addEventListener('change', (e) => {
      const { key } = e.target.dataset;
      if (key === 'theme' && e.target.value === 'auto') params.delete('theme');
      else params.set(key, e.target.value);
      location.search = params.toString();
    });
    document.body.appendChild(el);
  }

  function init() {
    document.documentElement.style.setProperty('--font', loadFont());
    document.body.classList.add(`theme-${settings.theme}`);
    loadScene();
    let repaint = 0;
    addEventListener('resize', () => {
      syncGlass();
      clearTimeout(repaint);
      repaint = setTimeout(() => Paint.all(), 150);
    });
    requestAnimationFrame(() => Paint.all());
    addEventListener('load', () => Paint.all());
    addEventListener('scroll', syncGlass, true);
    addEventListener('load', syncGlass);
    document.fonts.ready.then(syncGlass);
    bar();
    document.querySelectorAll('[data-icon]').forEach((e) => {
      e.insertAdjacentHTML('afterbegin', icon(e.dataset.icon));
    });
  }

  return { settings, THEMES, SEASON_THEME, icon, board, init, loadFont, syncGlass, kingStyle, ICONS, paint: () => Paint.all() };
})();
