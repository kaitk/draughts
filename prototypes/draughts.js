// The prototypes' shared parts: the screen (?device=), the season's scene and the glass
// over it, the board flat and raised (?board=3d), icons, and one game's moves. Plain
// script, no build step. URL parameters, all optional: ?season=winter|spring|summer|autumn
// (else by the date), ?bg=plain (the plain fade in place of the photograph), ?board=3d,
// ?device=tablet|pixel|iphone, with -portrait for its portrait (else the window).
'use strict';

const Draughts = (() => {
  const params = new URLSearchParams(location.search);
  const SEASON_THEME = { autumn: 'wood', winter: 'stone', spring: 'birch', summer: 'sunset' };
  const pick = (key, values, fallback) => (values.includes(params.get(key)) ? params.get(key) : fallback);
  const m = new Date().getMonth();
  const season = pick('season', Object.keys(SEASON_THEME), m < 2 || m === 11 ? 'winter' : m < 5 ? 'spring' : m < 8 ? 'summer' : 'autumn');
  const settings = { season, theme: SEASON_THEME[season], board: pick('board', ['flat', '3d'], 'flat'), bg: pick('bg', ['photo', 'plain'], 'photo') };

  // Devices in dp, landscape, with the safe area's insets (top, right, bottom, left); a
  // portrait turns them. The Pixel 7a: its cutout and gesture bar; the iPhone 13 mini at
  // its points. Without ?device= the window is the screen, with no insets.
  const DEVICES = {
    tablet: [1280, 800, [0, 0, 0, 0], [0, 0, 0, 0]],
    pixel: [1066, 480, [0, 0, 37, 52], [52, 0, 37, 0]],
    iphone: [812, 375, [0, 50, 21, 50], [50, 0, 34, 0]],
  };
  const device = (() => {
    const [name, turn] = (params.get('device') || '').split('-');
    const d = DEVICES[name];
    if (!d) return null;
    return turn === 'portrait' ? { w: d[1], h: d[0], insets: d[3] } : { w: d[0], h: d[1], insets: d[2] };
  })();

  // The body is the screen: with a device, its size in dp, scaled down to fit the window.
  function fit() {
    if (!device) return;
    const b = document.body, s = Math.min(1, (innerWidth - 16) / device.w, (innerHeight - 16) / device.h);
    Object.assign(b.style, { position: 'absolute', width: `${device.w}px`, height: `${device.h}px`, transformOrigin: '0 0',
      left: `${(innerWidth - device.w * s) / 2}px`, top: `${(innerHeight - device.h * s) / 2}px`, transform: `scale(${s})` });
    ['--it', '--ir', '--ib', '--il'].forEach((k, i) => b.style.setProperty(k, `${device.insets[i]}px`));
  }

  // The scene: the season's photograph (design/backgrounds/masters/, in git), or the plain
  // fade. As natively (src/app/scene.goose), glass and the flat game's backdrop show
  // copies blurred once when the page loads, at a fixed size (a file:// image can be
  // drawn, not read back): the image is cover-cropped by the screen, so the same blur
  // serves every size. A glass copies its part into its own small canvas: a blit, no
  // filter, and only when it moved or changed size.
  let scene = null, copies = null;
  const dims = () => [scene.naturalWidth || scene.width, scene.naturalHeight || scene.height];
  function blurred(N, px, filter) {
    // The image N across with a margin, the margin its edges stretched, then blurred.
    const [iw, ih] = dims(), M = Math.ceil(2 * px);
    const t = Object.assign(document.createElement('canvas'), { width: N + 2 * M, height: Math.round(ih * N / iw) + 2 * M });
    const tg = t.getContext('2d');
    tg.drawImage(scene, 0, 0, t.width, t.height);
    tg.drawImage(scene, M, M, N, t.height - 2 * M);
    const c = Object.assign(document.createElement('canvas'), { width: t.width, height: t.height });
    const g = c.getContext('2d');
    g.filter = `blur(${px}px) ${filter}`;
    g.drawImage(t, 0, 0);
    return { c, M, k: N / iw };
  }
  // A copy's scale to the screen's W x H, and where the screen's top left is in it.
  function map(cp, W, H) {
    const [iw, ih] = dims(), s = Math.max(W / iw, H / ih), f = cp.k / s;
    return { f, x0: cp.M + ((iw * s - W) / 2) * f, y0: cp.M + ((ih * s - H) / 2) * f };
  }
  function sync() {
    if (!scene) return;
    const b = document.body, W = b.offsetWidth, H = b.offsetHeight, br = b.getBoundingClientRect(), s = br.width / W;
    if (!copies) {
      const cs = getComputedStyle(b);
      // The blurs a 24 and a 14 px one are at 1280 px across, as the native copies have them.
      copies = { tint: cs.getPropertyValue('--glass-tint'),
        glass: blurred(256, 24 * 256 / 1280, `saturate(1.3) brightness(${cs.getPropertyValue('--glass-dim')})`),
        back: blurred(512, 14 * 512 / 1280, 'brightness(0.8)') };
    }
    if (b.dataset.screen === 'board' && settings.board === 'flat') {
      let bg = b.querySelector(':scope > canvas.scene-blur');
      if (!bg) b.prepend(bg = Object.assign(document.createElement('canvas'), { className: 'scene-blur' }));
      const m = map(copies.back, W, H), w = Math.ceil(W * m.f), h = Math.ceil(H * m.f);
      if (bg.width !== w || bg.height !== h) {
        Object.assign(bg, { width: w, height: h });
        bg.getContext('2d').drawImage(copies.back.c, -m.x0, -m.y0);
      }
    }
    const m = map(copies.glass, W, H);
    for (const el of document.querySelectorAll('.glass')) {
      let cv = el.firstElementChild;
      if (!cv || cv.className !== 'copy') el.prepend(cv = Object.assign(document.createElement('canvas'), { className: 'copy' }));
      const r = el.getBoundingClientRect(), x = (r.left - br.left) / s, y = (r.top - br.top) / s;
      const at = `${x} ${y} ${el.offsetWidth} ${el.offsetHeight} ${W} ${H}`;
      if (cv.dataset.at === at) continue;
      cv.dataset.at = at;
      const w = Math.max(1, Math.ceil(el.offsetWidth * m.f)), h = Math.max(1, Math.ceil(el.offsetHeight * m.f));
      Object.assign(cv, { width: w, height: h });
      const g = cv.getContext('2d');
      g.drawImage(copies.glass.c, m.x0 + x * m.f, m.y0 + y * m.f, w, h, 0, 0, w, h);
      g.fillStyle = copies.tint;
      g.fillRect(0, 0, w, h);
    }
  }
  let queued = false;
  const later = () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; sync(); }); } };

  // The plain fade (fade b, src/render3d/shaders.goose's FADE_FN): the page color at the
  // top to a deep tone of the frame at the foot, a faint light of the dark square behind
  // the middle, the corners darker; in linear light, painted at most 480 px across.
  const PLAIN = { wood: ['#1e1510', '#4a2c1a', '#7a4626'], stone: ['#0c1724', '#2c3a4c', '#5a6777'],
    birch: ['#101b15', '#2f3d30', '#6b7f6a'], sunset: ['#21150f', '#4f2e28', '#9a6655'] };
  function plain(w, h) {
    const lin = (s) => [1, 3, 5].map((i) => ((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))(parseInt(s.slice(i, i + 2), 16) / 255));
    const [top, foot, light] = PLAIN[settings.theme].map(lin);
    const step = (a, b, x) => { const t = Math.min(Math.max((x - a) / (b - a), 0), 1); return t * t * (3 - 2 * t); };
    const k = Math.min(1, 480 / Math.max(w, h)), W = Math.round(w * k), H = Math.round(h * k), L = Math.max(w, h);
    const c = Object.assign(document.createElement('canvas'), { width: W, height: H });
    const g = c.getContext('2d'), img = g.createImageData(W, H);
    for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
      const qx = (i + 0.5) / W - 0.5, qy = (j + 0.5) / H - 0.5;
      const a = 0.22 * (1 - step(0, 1, Math.hypot(qx * (w / L) / 0.62, (qy - 0.04) * (h / L) / 0.5)));
      const v = 1 - 0.3 * step(0.15, 0.6, qx * qx + qy * qy), f = step(0, 1, qy + 0.5);
      for (let n = 0; n < 3; n++) {
        const col = (top[n] + (foot[n] - top[n]) * f) * (1 - a) + light[n] * a;
        img.data[(j * W + i) * 4 + n] = 255 * (col * v) ** (1 / 2.2);
      }
      img.data[(j * W + i) * 4 + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    return c;
  }
  function loadScene() {
    if (settings.bg === 'plain') {
      scene = plain(document.body.offsetWidth, document.body.offsetHeight);
      document.body.style.backgroundImage = `url(${scene.toDataURL()})`;
      return sync();
    }
    const img = new Image();
    img.onload = () => { scene = img; sync(); };
    img.src = `../design/backgrounds/masters/${settings.season}-01-2048.jpg`;
    document.body.style.backgroundImage = `url("${img.src}")`;
  }

  // Icons: Lucide-style lines on a 24-unit grid; home's are filled shapes.
  const ICONS = {
    back: '<path d="M19 12H5"/><path d="M11 18l-6-6 6-6"/>',
    next: '<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>',
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    restart: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    hint: '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.3h6c0-1 .4-1.8 1-2.3A7 7 0 0 0 12 2z"/>',
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/><circle cx="12" cy="12" r="6.5"/>',
    eyeOff: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/><path d="M3 3l18 18"/>',
    x: '<path d="M5 5l14 14M19 5 5 19"/>',
    friend: '<circle class="solid" cx="8.5" cy="7.5" r="3.6"/><path class="solid" d="M1.5 20.5a7 7 0 0 1 14 0z"/><circle class="solid" cx="16.5" cy="8.3" r="3.1"/><path class="solid" d="M15.6 13.7a6.3 6.3 0 0 1 6.9 6.8h-5.3a8.6 8.6 0 0 0-1.6-6.8z"/>',
    computer: '<rect x="4" y="6" width="16" height="10" rx="3.5"/><path d="M12 6V3.5"/><circle class="solid" cx="12" cy="2.6" r="1.3"/><circle class="solid" cx="9" cy="11" r="1.4"/><circle class="solid" cx="15" cy="11" r="1.4"/>',
    puzzle: '<path class="solid" d="M4 7h4.2a2.8 2.8 0 1 1 5.6 0H18v4.2a2.8 2.8 0 1 1 0 5.6V21H4v-4.5a2.6 2.6 0 1 0 0-5.2z"/>',
    bars: '<path d="M5 20v-5M12 20V10M19 20V4"/>',
    star: '<path class="solid" d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    starOff: '<path d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    crown: '<path d="M3 17 2 7l5 4 5-7 5 7 5-4-1 10z"/><path d="M3 20.5h18"/>',
    book: '<path d="M2 5h6a4 4 0 0 1 4 4v11a3 3 0 0 0-3-3H2z"/><path d="M22 5h-6a4 4 0 0 0-4 4v11a3 3 0 0 1 3-3h7z"/>',
    captures: '<circle cx="6" cy="16" r="3.5"/><circle cx="18" cy="16" r="3.5"/><path d="M6 11c1-5 11-5 12 0"/><path d="M15.5 9.5 18 11l1-3"/>',
    target: '<circle cx="12" cy="12" r="7"/><circle class="solid" cx="12" cy="12" r="2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',
    shield: '<path d="M12 2.5 4 5.5v6c0 5 3.4 8.6 8 10 4.6-1.4 8-5 8-10v-6z"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c2.6 2.7 3.8 5.7 3.8 9s-1.2 6.3-3.8 9c-2.6-2.7-3.8-5.7-3.8-9S9.4 5.7 12 3z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/>',
    clock: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5"/><path d="M9.5 2.5h5"/>',
    pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    // New game's icon, its takes (home.html ?newgame=): as built, a plus in a ring; a, a
    // light and a dark piece side by side; b, a piece with a plus at its
    // shoulder; c, a small board, its dark squares filled; d, the app icon's board with
    // its dark piece, no arc or king; e, two pieces seen from the side, one behind the other; f, the app
    // icon's board as c is, its dark squares filled, no piece or arc; g, f with a light piece;
    // h, a solid piece on the board and an outlined one over it, higher, an arc behind it;
    // i, an outlined piece mid-jump in front of a solid one, overlapping it, the solid
    // running under the outline so the two merge, an arc from behind (N2, 2026-11-13); j, i
    // with a gap cut round the outlined piece (M2).
    newNow: '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
    newPair: '<circle cx="6.5" cy="12" r="5.5"/><circle cx="6.5" cy="12" r="2.4"/><path class="solid" fill-rule="evenodd" d="M12 12a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0 -11 0M14.5 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0M15.7 12a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"/>',
    newBadge: '<circle cx="10" cy="14" r="7.5"/><circle cx="10" cy="14" r="3.5"/><path d="M19.5 1.5v6M16.5 4.5h6"/>',
    newPieces: '<mask id="ng-e"><rect x="0" y="0" width="24" height="24" fill="white"/><ellipse cx="8.2" cy="14.6" rx="8.7" ry="5.2" fill="black"/><rect x="-0.5" y="14.6" width="17.4" height="3.2" fill="black"/><ellipse cx="8.2" cy="17.8" rx="8.7" ry="5.2" fill="black"/></mask><g mask="url(#ng-e)"><ellipse cx="15.8" cy="8.2" rx="7" ry="3.5"/><ellipse cx="15.8" cy="8.2" rx="3.5" ry="1.75"/><path d="M8.8 8.2v3.2a7 3.5 0 0 0 14 0v-3.2"/></g><ellipse cx="8.2" cy="14.6" rx="7" ry="3.5"/><ellipse cx="8.2" cy="14.6" rx="3.5" ry="1.75"/><path d="M1.2 14.6v3.2a7 3.5 0 0 0 14 0v-3.2"/>',
    newIso: '<path d="M1 13.5 12 7.5 23 13.5 12 19.5z"/><path d="M1 13.5v2.3l11 6 11-6v-2.3"/><ellipse class="solid" cx="12" cy="11.6" rx="4.6" ry="2.4"/><path class="solid" d="M7.4 11.6v1.6a4.6 2.4 0 0 0 9.2 0v-1.6a4.6 2.4 0 0 1-9.2 0z"/>',
    newIsoBoard: '<path d="M1.5 12L12 6L22.5 12L12 18z"/><path class="solid" d="M1.5 12L5 10L8.5 12L5 14zM8.5 16L12 14L15.5 16L12 18zM8.5 12L12 10L15.5 12L12 14zM8.5 8L12 6L15.5 8L12 10zM15.5 12L19 10L22.5 12L19 14z"/><path d="M1.5 12v2.6L12 20.6L22.5 14.6V12M12 18v2.6"/>',
    newIsoPiece: '<mask id="ng-g"><rect x="0" y="0" width="24" height="24" fill="white"/><ellipse cx="15.5" cy="8.8" rx="4.4" ry="2.6" fill="black"/><rect x="11.1" y="8.8" width="8.8" height="2.4" fill="black"/><ellipse cx="15.5" cy="11.2" rx="4.4" ry="2.6" fill="black"/></mask><g mask="url(#ng-g)"><path d="M1.5 12L12 6L22.5 12L12 18z"/><path class="solid" d="M1.5 12L5 10L8.5 12L5 14zM8.5 16L12 14L15.5 16L12 18zM8.5 12L12 10L15.5 12L12 14zM8.5 8L12 6L15.5 8L12 10zM15.5 12L19 10L22.5 12L19 14z"/><path d="M1.5 12v2.6L12 20.6L22.5 14.6V12M12 18v2.6"/></g><ellipse cx="15.5" cy="8.8" rx="3.2" ry="1.6"/><path d="M12.3 8.8v1.8a3.2 1.6 0 0 0 6.4 0v-1.8"/>',
    newOver: '<mask id="ng-i" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><path d="M9 9a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z" fill="black" stroke="none"/></mask><path class="solid" mask="url(#ng-i)" d="M4.5 15a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z"/><ellipse cx="15" cy="9" rx="6" ry="2.5"/><path d="M9 9v3a6 2.5 0 0 0 12 0v-3"/><path d="M1.5 12C2.3 11.3 3.8 9.3 6.8 9.3"/>',
    newOverGap: '<mask id="ng-j" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><path d="M9 9a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z" fill="black" stroke="black" stroke-width="5.2"/></mask><path class="solid" mask="url(#ng-j)" d="M4.5 15a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z"/><ellipse cx="15" cy="9" rx="6" ry="2.5"/><path d="M9 9v3a6 2.5 0 0 0 12 0v-3"/><path d="M1.5 12C2.3 11.3 3.8 9.3 6.8 9.3"/>',
    newJump: '<mask id="ng-h1" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><path d="M1.6 16.6a6.6 3.3 0 0 0 13.2 0" fill="none" stroke="black" stroke-width="1.4"/><ellipse cx="8.2" cy="16.6" rx="3.168" ry="1.584" fill="none" stroke="black" stroke-width="1.4"/></mask><mask id="ng-h2" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><ellipse cx="16.4" cy="6.6" rx="7.5" ry="4.5" fill="black"/><rect x="8.9" y="6.6" width="15" height="2.8" fill="black"/><ellipse cx="16.4" cy="9.4" rx="7.5" ry="4.5" fill="black"/></mask><g mask="url(#ng-h1)" class="solid"><ellipse cx="8.2" cy="16.6" rx="6.6" ry="3.3" fill="currentColor"/><rect x="1.6" y="16.6" width="13.2" height="3.2" fill="currentColor"/><ellipse cx="8.2" cy="19.8" rx="6.6" ry="3.3" fill="currentColor"/></g><path mask="url(#ng-h2)" d="M3 12C3.5 5 8 2.5 12 4.8"/><ellipse cx="16.4" cy="6.6" rx="6" ry="3"/><path d="M10.4 6.6v2.8a6 3 0 0 0 12 0v-2.8"/>',
    newBoard: '<rect x="3" y="3" width="18" height="18" rx="2"/><rect class="solid" x="7.5" y="3" width="4.5" height="4.5"/><rect class="solid" x="16.5" y="3" width="4.5" height="4.5"/><rect class="solid" x="3" y="7.5" width="4.5" height="4.5"/><rect class="solid" x="12" y="7.5" width="4.5" height="4.5"/><rect class="solid" x="7.5" y="12" width="4.5" height="4.5"/><rect class="solid" x="16.5" y="12" width="4.5" height="4.5"/><rect class="solid" x="3" y="16.5" width="4.5" height="4.5"/><rect class="solid" x="12" y="16.5" width="4.5" height="4.5"/>',
    up: '<path d="M6 15l6-6 6 6"/>',
    left: '<path d="M15 6l-6 6 6 6"/>',
    right: '<path d="M9 6l6 6-6 6"/>',
    first: '<path d="M17 6l-6 6 6 6"/><path d="M7 6v12"/>',
    last: '<path d="M7 6l6 6-6 6"/><path d="M17 6v12"/>',
    view: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M12 4v16M4 12h16"/>',
    zoom: '<circle cx="11" cy="11" r="7"/><path d="M16 16l5 5M11 8v6M8 11h6"/>',
    orbit: '<ellipse cx="12" cy="15" rx="9" ry="4"/><path d="M7 13.5V9a5 5 0 0 1 10 0v4.5"/>',
  };
  const icon = (name) => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;

  // The flat board and its pieces as the native shaders draw them: a port of
  // src/app/draw.goose's board and piece shaders, run once per board and kind of piece,
  // into images. Sizes are rounded up to steps of 19%, so a resize repaints only past a
  // step. Keep it in step with draw.goose (docs/architecture/rendering.md, "Board and pieces").
  const Paint = (() => {
    const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);
    const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
    const fract = (x) => x - Math.floor(x);
    const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
    const WHITE = [1, 1, 1], BLACK = [0, 0, 0];
    const tint = (c, a) => (a > 0 ? mix(c, WHITE, a) : mix(c, BLACK, -a));
    const lit = (c, a) => (a > 0 ? mix(c, WHITE, a) : mix(c, c.map((v) => v * v * 0.85), -a));
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
    const color = (s) => [1, 3, 5].map((i) => parseInt(s.trim().slice(i, i + 2), 16) / 255);
    const KIND = { wood: 0, stone: 1, birch: 2, sunset: 3 };
    function canvas(w, h) {
      const c = Object.assign(document.createElement('canvas'), { width: w, height: h });
      const g = c.getContext('2d');
      return { c, g, img: g.createImageData(w, h) };
    }
    const put = (img, i, rgb, a) => {
      img.data[i] = rgb[0] * 255; img.data[i + 1] = rgb[1] * 255; img.data[i + 2] = rgb[2] * 255; img.data[i + 3] = a * 255;
    };

    // The board B px wide with its lip and soft shadow, on a canvas reaching 5% past it.
    // squaresOnly: just the squares, for the raised board.
    function board(t, n, B, squaresOnly) {
      const u = B * 0.01, lw = squaresOnly ? 0 : 1.1 * u, rad = 1.6 * u;
      const inner = B - 2 * lw, sqw = inner / n;
      const m = squaresOnly ? 0 : Math.round(0.05 * B), W = Math.round(B) + 2 * m;
      const { c, g, img } = canvas(W, W);
      const light = color(t.light), dark = color(t.dark), kind = t.kind, line = mix(light, WHITE, 0.25), bh = B / 2;
      for (let j = 0; j < W; j++) for (let i = 0; i < W; i++) {
        const px = i + 0.5 - m, py = j + 0.5 - m, k = (j * W + i) * 4;
        const fd = squaresOnly ? -B : box(px, py, bh, bh, bh, rad);
        const sh = squaresOnly ? 0 : 0.55 * (1 - smooth(-3.6 * u, 3.6 * u, box(px, py, bh, bh + 1.4 * u, bh - u, rad)));
        if (fd >= 1) { put(img, k, BLACK, sh); continue; }
        const id = squaresOnly ? -B : box(px, py, bh, bh, inner / 2, 0.5 * rad);
        let col = BLACK;
        if (id > -1) {
          // The lip: the dark square's color, a line of the light one on its outer edge.
          const tt = clamp(-fd / lw, 0, 1), ny = (py - bh) / bh;
          col = tint(mix(tint(dark, 0.06 - 0.1 * ny), line, (0.75 - 0.25 * ny) * (1 - smooth(0.1, 0.26, tt))), -0.35 * smooth(0.7, 1, tt));
        }
        if (id < 1) {
          const qx = (px - lw) / sqw, qy = (py - lw) / sqw;
          const cx = clamp(Math.floor(qx), 0, n - 1), cy = clamp(Math.floor(qy), 0, n - 1), h = hash(cx, cy);
          let a = 0;
          if (kind === 0) {
            const mx = px / u + 41 * h, my = py / u + 41 * h;
            a += 0.022 * (noise(mx * 2.6, my * 0.08) - 0.5) + 0.03 * (noise(mx * 0.35, my * 0.06) - 0.5) + 0.02 * (h - 0.5);
          } else if (kind === 1) {
            a += 0.07 * (0.6 * noise(px / u * 0.45 + 13 * h, py / u * 0.45 + 13 * h) + 0.4 * noise(px / u * 1.3, py / u * 1.3) - 0.5);
          } else if (kind === 2) {
            a += 0.03 * (noise(px / (3 * u), py / (0.35 * u)) - 0.5);
          } else {
            a += 0.02 * (noise(px / (2 * u), py / (2 * u)) - 0.5);
          }
          a += 0.04 * (1 - smooth(0, 0.18 * u, fract(qy) * sqw));
          col = mix(col, tint((cx + n - 1 - cy) % 2 === 0 ? dark : light, a), clamp(0.5 - id, 0, 1));
        }
        const cov = clamp(0.5 - fd, 0, 1), al = cov + sh * (1 - cov);
        put(img, k, al > 0 ? col.map((v) => (v * cov) / al) : col, al);
      }
      g.putImageData(img, 0, 0);
      return c.toDataURL();
    }

    // The crown: five points over a band, in units where it spans -1..1.
    const CROWN = [[-0.72, 0.30], [-0.88, -0.42], [-0.40, 0.02], [0.0, -0.62], [0.40, 0.02], [0.88, -0.42], [0.72, 0.30]];
    function crown(px, py) {
      let d = (px - CROWN[0][0]) ** 2 + (py - CROWN[0][1]) ** 2, s = 1;
      for (let i = 0, j = 6; i < 7; j = i, i++) {
        const ex = CROWN[j][0] - CROWN[i][0], ey = CROWN[j][1] - CROWN[i][1], wx = px - CROWN[i][0], wy = py - CROWN[i][1];
        const t = clamp((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1);
        d = Math.min(d, (wx - ex * t) ** 2 + (wy - ey * t) ** 2);
        const a = py >= CROWN[i][1], b = py < CROWN[j][1], c = ex * wy > ey * wx;
        if ((a && b && c) || (!a && !b && !c)) s = -s;
      }
      const qx = Math.abs(px) - 0.72, qy = Math.abs(py - 0.47) - 0.09;
      return Math.min(s * Math.sqrt(d), Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0));
    }
    const shoulder = (r, a, b, dy) => { const th = 1.45 * clamp((r - a) / (b - a), 0, 1); return 0.7071 * (-dy * Math.sin(th) + Math.cos(th) - 1); };
    const groove = (r, a, b, dy) => { const t = (r - a) / (b - a); return t <= 0 || t >= 1 ? 0 : -dy * Math.sin(2 * Math.PI * t); };
    const fill = (d, w) => clamp(0.5 - d / w, 0, 1);

    // One piece, R px in radius, over x -1.9..1.9 and y top..2.1 + side radii. o: { face,
    // crownW, glow, black, king: '' | 'crown' | 'stack', sel, side, lift, stack, bare }; bare
    // leaves out the shadow, the side, and the glow, for the raised board's sprites.
    function piece(o, R) {
      const top = -1.9 - o.lift - o.stack;
      const W = Math.ceil(3.8 * R), H = Math.ceil((2.1 + o.side - top) * R);
      const { c, g, img } = canvas(W, H);
      const face = color(o.face), glow = color(o.glow), crownW = color(o.crownW), black = o.black, sel = o.sel ? 1 : 0;
      const lift = sel ? o.lift : 0, side = o.side, scale = 1 + 0.05 * sel, w = 1 / R / scale;
      const sidec = black ? mix(face, BLACK, 0.5) : face.map((v) => v * v * 0.92), gold = [0.914, 0.769, 0.416];
      for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
        const x = -1.9 + (i + 0.5) / R, y = top + (j + 0.5) / R;
        let ar = 0, ag = 0, ab = 0, aa = 0;
        const over = (col, a) => {
          ar = col[0] * a + ar * (1 - a); ag = col[1] * a + ag * (1 - a); ab = col[2] * a + ab * (1 - a); aa = a + aa * (1 - a);
        };
        if (!o.bare) {
          const soft = 0.16 + 0.5 * lift;
          over(BLACK, (0.4 - 0.1 * sel) * (1 - smooth(-2 * soft, 2 * soft, Math.hypot(x - 0.04, y - 0.25 - 0.6 * lift) - 1)));
          over(BLACK, 0.3 * (1 - smooth(-0.08, 0.06, Math.hypot(x, y - 0.06 - side) - 1)) * (1 - smooth(0, 0.2, lift)));
          if (sel) over(glow, 0.4 * Math.exp(-Math.max(Math.hypot(x / scale, (y + lift) / scale) - 1, 0) * 5));
        }
        const discs = o.king === 'stack' ? [[0, side], [o.stack, o.stack]] : [[0, side]];
        let fr = 9;
        for (const [up, depth] of discs) {
          const fx = x / scale, fy = (y + lift + up) / scale, r = Math.hypot(fx, fy), dy = fy / Math.max(r, 0.001);
          fr = r;
          if (!o.bare) {
            const dd = depth / scale, arc = Math.sqrt(Math.max(1 - fx * fx, 0)), foot = clamp((fy - arc) / dd, 0, 1);
            over(sidec.map((v) => v * (0.8 + 0.25 * arc) * (1 - 0.25 * foot)), fill(Math.hypot(fx, fy - clamp(fy, 0, dd)) - 1, w));
          }
          let col = tint(face, -0.02 * fy);
          const l = shoulder(r, 0.86, 1, dy);
          col = lit(col, l > 0 ? (black ? 1 : 1.2) * l : (black ? 0.28 : 0.4) * l);
          const gr = groove(r, 0.63, 0.76, dy);
          col = lit(col, gr > 0 ? (black ? 0.4 : 0.5) * gr : (black ? 0.6 : 1.2) * gr);
          col = lit(col, -(black ? 0.3 : 0.45) * (1 - smooth(0, 0.05, Math.abs(r - 0.695))));
          if (o.king === 'crown') col = mix(col, black ? gold : crownW, fill(0.56 * crown(fx / 0.56, fy / 0.56), w));
          over(col, fill(r - 1, w));
        }
        if (sel && !o.bare) {
          const rd = Math.abs(fr - 1.13) - 0.055;
          over(glow, 0.6 * Math.exp(-Math.max(rd, 0) * 7));
          over(mix(glow, WHITE, 0.25), fill(rd, w));
        }
        put(img, (j * W + i) * 4, aa > 0 ? [ar / aa, ag / aa, ab / aa] : BLACK, aa);
      }
      g.putImageData(img, 0, 0);
      return { c, top };
    }

    // A raised piece's sprite, R px in radius: the face above, squashed by the tilt, over
    // its side (two discs for a stacked king), over a soft shadow on the board. In units of
    // the radius the sprite is 2.6 wide, and the piece's foot is at (1.3, UP).
    const TILT = 37.5 * Math.PI / 180, COS = Math.cos(TILT), SIN = Math.sin(TILT), T = 0.3, GAP = 0.04, UP = 1.35, DOWN = 1.15;
    function raised(o, R) {
      const W = Math.ceil(2.6 * R), H = Math.ceil((UP + DOWN) * R), ox = 1.3 * R, oy = UP * R;
      const c = Object.assign(document.createElement('canvas'), { width: W, height: H });
      const g = c.getContext('2d');
      const sh = g.createRadialGradient(0, 0, 0, 0, 0, 1.3 * R);
      sh.addColorStop(0, 'rgb(0 0 0 / 0.5)');
      sh.addColorStop(0.7, 'rgb(0 0 0 / 0.3)');
      sh.addColorStop(1, 'rgb(0 0 0 / 0)');
      g.save();
      g.translate(ox + 0.08 * R, oy + 0.12 * R);
      g.scale(1, COS);
      g.fillStyle = sh;
      g.fillRect(-1.4 * R, -1.4 * R, 2.8 * R, 2.8 * R);
      g.restore();
      const f = color(o.face), sc = o.black ? f.map((v) => v * 0.5) : f.map((v) => v * v * 0.92);
      const css = (v, k) => `rgb(${v.map((x) => Math.round(255 * Math.min(1, x * k))).join(' ')})`;
      const side = g.createLinearGradient(ox - R, 0, ox + R, 0);
      side.addColorStop(0, css(sc, 1.15));
      side.addColorStop(0.4, css(sc, 1));
      side.addColorStop(1, css(sc, 0.6));
      const ry = R * COS, t = T * R * SIN, lift = o.sel ? 0.25 * R : 0;
      let y = oy - lift;
      const discs = o.king === 'stack' ? 2 : 1;
      for (let k = 0; k < discs; k++) {
        g.fillStyle = side;
        g.beginPath();
        g.ellipse(ox, y, R, ry, 0, 0, Math.PI);
        g.lineTo(ox - R, y - t);
        g.ellipse(ox, y - t, R, ry, 0, Math.PI, 0, true);
        g.closePath();
        g.fill();
        y -= t + (k + 1 < discs ? GAP * R : 0);
      }
      const p = piece({ ...o, king: o.king === 'crown' ? 'crown' : '', bare: true, side: 0, lift: 0, stack: 0, sel: false }, R);
      g.drawImage(p.c, ox - 1.9 * R, y - 1.9 * ry, 3.8 * R, p.c.height * COS);
      if (o.sel) {
        g.strokeStyle = o.glow;
        g.lineWidth = 0.1 * R;
        g.shadowColor = o.glow;
        g.shadowBlur = 0.4 * R;
        g.beginPath();
        g.ellipse(ox, y, 1.12 * R, 1.12 * ry, 0, 0, 2 * Math.PI);
        g.stroke();
      }
      return c.toDataURL();
    }

    function theme(el) {
      const cs = getComputedStyle(el), v = (k) => cs.getPropertyValue(k).trim();
      return { light: v('--light'), dark: v('--dark'), white: v('--w-face'), black: v('--b-face'), crownW: v('--crown-w'),
        glow: v('--glow'), kind: KIND[v('--kind')] ?? 3 };
    }
    const cache = new Map();
    const once = (key, make) => { if (!cache.has(key)) cache.set(key, make()); return cache.get(key); };
    const step = (x) => Math.round(2 ** (Math.ceil(Math.log2(Math.max(x, 8)) * 4) / 4));
    const dpr = () => Math.min(devicePixelRatio || 1, 2) * (document.body.getBoundingClientRect().width / document.body.offsetWidth || 1);
    // What a piece element is: its color, king, and selection.
    const kind = (el, t) => {
      const black = el.classList.contains('black');
      return { face: black ? t.black : t.white, crownW: t.crownW, glow: t.glow, black, sel: el.classList.contains('selected'),
        king: el.classList.contains('king') ? (el.closest('.raised, .stack') ? 'stack' : 'crown') : '' };
    };

    // Paints every board and piece under root not painted at its present size's step.
    function all(root = document) {
      for (const el of root.querySelectorAll('.board')) {
        const B = step(el.offsetWidth * dpr()), flat = !el.classList.contains('raised');
        if (!el.offsetWidth || el.dataset.painted === String(B)) continue;
        const t = theme(el), n = +getComputedStyle(el).getPropertyValue('--n') || 8;
        el.querySelector(flat ? '.lip' : '.squares').style.backgroundImage = (
          `url(${once(`b${flat}${t.light}${t.kind}${n}${flat ? B : 0}`, () => board(t, n, flat ? B : 1024, !flat))})`);
        el.dataset.painted = String(B);
        el.classList.add('painted');
        if (!flat) place(el, t);
      }
      for (const el of root.querySelectorAll('.piece')) {
        const R = step(el.offsetWidth / 2 * dpr());
        if (!el.offsetWidth || el.dataset.painted === String(R)) continue;
        const o = kind(el, theme(el));
        // Depths in radii, as on an 8 × 8 board: the side 0.55% of it, the lift 0.8%, a
        // stacked disc 1.3%.
        const r1 = 0.39 * 0.978 / 8;
        Object.assign(o, { side: 0.0055 / r1, lift: 0.008 / r1, stack: o.king === 'stack' ? 0.013 / r1 : 0 });
        const s = once(`p${o.face}${o.glow}${o.king}${o.sel}${R}`, () => { const p = piece(o, R); return { url: p.c.toDataURL(), top: p.top }; });
        // The image covers x -1.9..1.9 and y top..2.1 + side radii; the element is -1..1.
        const img = el.firstElementChild || el.appendChild(document.createElement('i'));
        Object.assign(img.style, { backgroundImage: `url(${s.url})`, top: `${((s.top + 1) / 2) * 100}%`,
          bottom: `${(-(1.1 + o.side) / 2) * 100}%` });
        el.dataset.painted = String(R);
      }
    }

    // The raised board's pieces and front edge, where the tilted plane puts them: the
    // plane is perspective(1.7 S) rotateX(37.5°) about its center, S its width.
    function place(el, t = theme(el)) {
      const S = el.offsetWidth, P = 1.7 * S, n = +el.style.getPropertyValue('--n') || 8, sq = (S * 0.952) / n;
      const at = (x, y) => { const f = P / (P - y * SIN); return [S / 2 + x * f, S / 2 + y * COS * f, f]; };
      const R = step(0.39 * sq * at(0, S / 2)[2] * dpr());
      for (const p of el.querySelectorAll('.p3')) {
        const [X, Y, f] = at(-S * 0.476 + (+p.dataset.x + 0.5) * sq, -S * 0.476 + (+p.dataset.y + 0.5) * sq);
        const r = 0.39 * sq * f;
        Object.assign(p.style, { left: `${X - 1.3 * r}px`, top: `${Y - UP * r}px`, width: `${2.6 * r}px`, height: `${(UP + DOWN) * r}px` });
        if (p.dataset.painted === String(R)) continue;
        const o = kind(p, t);
        p.style.backgroundImage = `url(${once(`r${o.face}${o.king}${o.sel}${R}`, () => raised(o, R))})`;
        p.dataset.painted = String(R);
      }
      const [, Y, f] = at(0, S / 2), front = el.querySelector('.front');
      front.style.cssText = `left:${S / 2 - (S / 2) * f}px;width:${S * f}px;top:${Y - 0.022 * S}px;height:${0.022 * S + 0.035 * S * SIN * f}px`;
    }
    return { all, place };
  })();

  // Draws a board into el. Squares are a1..h8 (a1..j10), a1 dark at the bottom left.
  // opts: { n, view: 'flat' | '3d', white, black, kings, selected, forced, targets, via,
  // last, error, marks: { sq: html } }.
  function board(el, opts) {
    const n = opts.n || 8, raised = (opts.view || settings.board) === '3d';
    const has = (k, sq) => (opts[k] || []).includes(sq);
    el.className = `board${raised ? ' raised' : ''} ${el.className.replace(/\b(board|raised|painted)\b/g, '')}`.trim();
    el.style.setProperty('--n', n);
    delete el.dataset.painted;
    let html = '', pieces = '';
    for (let y = n - 1; y >= 0; y--) for (let x = 0; x < n; x++) {
      const sq = String.fromCharCode(97 + x) + (y + 1), dark = (x + y) % 2 === 0;
      const color = has('white', sq) ? 'white' : has('black', sq) ? 'black' : '';
      const cls = `${color} ${has('kings', sq) ? 'king' : ''} ${opts.selected === sq ? 'selected' : ''}`;
      let inner = '';
      if (color && !raised) inner = `<div class="piece ${cls}${has('forced', sq) ? ' forced' : ''}"></div>`;
      if (color && raised) {
        pieces += `<div class="p3 ${cls}" data-x="${x}" data-y="${n - 1 - y}"></div>`;
        if (has('forced', sq)) inner = '<div class="spot forced"></div>';
      }
      if (has('targets', sq)) inner += '<div class="target"></div>';
      if (has('via', sq)) inner += '<div class="target via"></div>';
      if (has('error', sq)) inner += '<div class="error"></div>';
      if (opts.marks && opts.marks[sq]) inner += opts.marks[sq];
      html += `<div class="sq${dark ? ' dark' : ''}${has('last', sq) ? ' last' : ''}">${inner}</div>`;
    }
    el.innerHTML = raised ? `<div class="plane"><div class="squares">${html}</div></div><div class="front"></div>${pieces}`
      : `<i class="lip"></i><div class="squares">${html}</div>`;
    if (document.readyState !== 'loading') Paint.all(el.parentNode);
  }

  // The start on a size × size board: men on the dark squares of the first three rows,
  // four on 10 × 10.
  function start(size) {
    const rows = size === 10 ? 4 : 3, white = [], black = [];
    for (let y = 0; y < size; y++) for (let x = (y % 2); x < size; x += 2) {
      const sq = String.fromCharCode(97 + x) + (y + 1);
      if (y < rows) white.push(sq); else if (y >= size - rows) black.push(sq);
    }
    return { n: size, white, black };
  }

  // One International game, the child (white) against Medium: each ply in PDN with its
  // mark after a slash (* best, ?!, ?, ??, = an only move), and the positions after plies
  // 24 and 39 (white's men, black's men, white's kings, black's kings).
  const PLIES = ('31-27 17-22 36-31 19-24 34-30/?! 14-19 40-34 20-25/* 41-36 15-20/?! 32-28/?! 11-17 45-40 10-15 ' +
    '50-45 6-11/* 47-41 5-10 37-32 1-6 41-37/* 10-14 46-41/* 4-10/* 34-29/? 25x23/= 39-34 20-25/* 43-39 15-20 48-43/?! ' +
    '10-15/* 35-30 24x35/= 34-30 35x24/* 40-34 24-30/* 33-29/?? 22x24/= 31-26 30-35/?! 36-31 24-30 41-36/?! 20-24 ' +
    '45-40 14-20 38-33/* 17-22 43-38 11-17 49-43/* 6-11 33-28 22x33/= 38x29/* 24x33/= 39x28/= 30x50 40-34 50x22/=')
    .split(' ').map((s) => { const [m, k = ''] = s.split('/'); return { m, k }; });
  const POS = {
    24: '27,28,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,48,49|2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,22,24,25||',
    39: '27,28,29,31,32,34,36,37,38,39,41,42,43,44,45,49|2,3,6,7,8,9,11,12,13,14,15,16,17,18,19,20,22,23,25,30||',
  };
  // PDN square n (1..50) on 10 × 10: 1 is b10, 46 is a1.
  const alg = (n) => { const r = Math.floor((n - 1) / 5), k = (n - 1) % 5; return String.fromCharCode(97 + (r % 2 ? 2 * k : 2 * k + 1)) + (10 - r); };
  function game(ply) {
    const [w, b, W, B] = POS[ply].split('|').map((s) => (s ? s.split(',').map(Number) : []));
    const last = PLIES[ply - 1].m.split(/[-x]/).map(Number).map(alg);
    return { n: 10, white: [...w, ...W].map(alg), black: [...b, ...B].map(alg), kings: [...W, ...B].map(alg), last };
  }
  // A mark's glyph after its move, and its color for a disc.
  const MARKS = { '*': ['best', ''], '?!': ['q0', '?!'], '?': ['q1', '?'], '??': ['q2', '??'] };
  const mark = (k) => (MARKS[k] ? `<i class="mk ${MARKS[k][0]}">${MARKS[k][1] || icon('star')}</i>` : '');

  function init() {
    for (const w of [400, 700]) {
      document.head.insertAdjacentHTML('beforeend',
        `<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fontsource/libertinus-sans@5.3.0/${w}.css">`);
    }
    document.body.classList.add(`theme-${settings.theme}`);
    document.querySelectorAll('[data-icon]').forEach((e) => e.insertAdjacentHTML('afterbegin', icon(e.dataset.icon)));
    fit();
    loadScene();
    Paint.all();
    // While a size changes, the images scale; they are painted again at the new size's
    // step once it has held for 0.2 s.
    let repaint = 0;
    const ro = new ResizeObserver(() => {
      clearTimeout(repaint);
      repaint = setTimeout(() => Paint.all(), 200);
      document.querySelectorAll('.board.raised.painted').forEach((el) => Paint.place(el));
      later();
    });
    ro.observe(document.body);
    document.querySelectorAll('.board, .glass').forEach((el) => ro.observe(el));
    addEventListener('resize', () => { fit(); later(); });
    document.fonts.ready.then(later);
  }

  return { settings, icon, board, start, init, sync: later, paint: () => Paint.all(), game, PLIES, mark };
})();
