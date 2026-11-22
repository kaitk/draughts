// The prototypes' shared parts: the screen (?device=), the season's scene and the glass
// over it, the board, icons, and one game's moves. Plain script, no build step. URL
// parameters, all optional: ?season=winter|spring|summer|autumn (else by the date),
// ?device=tablet|pixel|iphone, with -portrait for its portrait, or a desktop's window
// full screen: mac|desktop|ultrawide (else the window).
'use strict';

const Draughts = (() => {
  const params = new URLSearchParams(location.search);
  const SEASON_THEME = { autumn: 'wood', winter: 'stone', spring: 'birch', summer: 'sunset' };
  const pick = (key, values, fallback) => (values.includes(params.get(key)) ? params.get(key) : fallback);
  const m = new Date().getMonth();
  const season = pick('season', Object.keys(SEASON_THEME), m < 2 || m === 11 ? 'winter' : m < 5 ? 'spring' : m < 8 ? 'summer' : 'autumn');
  const settings = { season, theme: SEASON_THEME[season] };


  // Devices in dp, landscape, with the safe area's insets (top, right, bottom, left); a
  // portrait turns them. The Pixel 7a: its cutout and gesture bar; the iPhone 13 mini at
  // its points. A desktop in dp (gui::DESKTOP_DP, 0.75 points a dp, up to 0.9 on a
  // 1440-point screen): a MacBook's 1512 × 982 points, a 27" 2560 × 1440, and a 34"
  // ultrawide's 3440 × 1440. Without ?device= the window is the screen, with no insets.
  const DEVICES = {
    tablet: [1280, 800, [0, 0, 0, 0], [0, 0, 0, 0]],
    pixel: [1066, 480, [0, 0, 37, 52], [52, 0, 37, 0]],
    iphone: [812, 375, [0, 50, 21, 50], [50, 0, 34, 0]],
    mac: [2016, 1309, [0, 0, 0, 0], [0, 0, 0, 0]],
    desktop: [2844, 1600, [0, 0, 0, 0], [0, 0, 0, 0]],
    ultrawide: [3822, 1600, [0, 0, 0, 0], [0, 0, 0, 0]],
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

  // The scene: the season's photograph (design/backgrounds/masters/, in git). As natively
  // (src/app/scene.goose), glass and the game's blurred backdrop show
  // copies blurred once when the page loads, at a fixed size (a file:// image can be
  // drawn, not read back): the image is cover-cropped by the screen, so the same blur
  // serves every size. A glass copies its part into its own small canvas: a blit, no
  // filter, and only when it moved or changed size.
  let scene = null, copies = null;
  const dims = () => [scene.naturalWidth, scene.naturalHeight];
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
    if (b.dataset.screen === 'board') {
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

  function loadScene() {
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
    check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
    moon: '<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z"/>',
    today: '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/><circle class="solid" cx="12" cy="15" r="2.2"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c2.6 2.7 3.8 5.7 3.8 9s-1.2 6.3-3.8 9c-2.6-2.7-3.8-5.7-3.8-9S9.4 5.7 12 3z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/>',
    clock: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5"/><path d="M9.5 2.5h5"/>',
    pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    // New game's icon: a light piece mid-jump over a dark one, cut clear of it (task 082).
    newGame: '<mask id="ng-new" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="white"/><path d="M9 9a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z" fill="black" stroke="black" stroke-width="5.2"/></mask><path class="solid" mask="url(#ng-new)" d="M4.5 15a6 2.5 0 0 1 12 0v3a6 2.5 0 0 1 -12 0z"/><ellipse cx="15" cy="9" rx="6" ry="2.5"/><path d="M9 9v3a6 2.5 0 0 0 12 0v-3"/><path d="M1.5 12C2.3 11.3 3.8 9.3 6.8 9.3"/>',
    // Lucide's handshake (ISC), and a flag for giving up.
    handshake: '<path d="m11 17 2 2a1 1 0 1 0 3-3"/><path d="m14 14 2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4"/><path d="m21 3 1 11h-2"/><path d="M3 3 2 14l6.47 6.47a1 1 0 1 0 3-3"/><path d="M3 4h8"/>',
    thumbDown: '<path d="M17 14V2"/><path d="M9 18.12 10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88Z"/>',
    hand: '<path d="M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2"/><path d="M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2"/><path d="M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
    handshakeOff: '<path d="m11 17 2 2a1 1 0 1 0 3-3"/><path d="m14 14 2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4"/><path d="m21 3 1 11h-2"/><path d="M3 3 2 14l6.47 6.47a1 1 0 1 0 3-3"/><path d="M3 4h8"/><path d="M2.5 21.5 21.5 2.5"/>',
    flag: '<path d="M5 22V3"/><path class="solid" d="M5 3.5h13l-2.8 4.5 2.8 4.5H5z"/>',
    up: '<path d="M6 15l6-6 6 6"/>',
    left: '<path d="M15 6l-6 6 6 6"/>',
    right: '<path d="M9 6l6 6-6 6"/>',
    first: '<path d="M17 6l-6 6 6 6"/><path d="M7 6v12"/>',
    last: '<path d="M7 6l6 6-6 6"/><path d="M17 6v12"/>',
  };
  const icon = (name) => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;

  // Draws a board into el. Squares are a1..h8 (a1..j10), a1 dark at the bottom left.
  // opts: { n, white, black, kings, selected, forced, targets, via, last, error,
  // marks: { sq: html } }. The board and pieces are plain CSS (draughts.css).
  function board(el, opts) {
    const n = opts.n || 8;
    const has = (k, sq) => (opts[k] || []).includes(sq);
    el.classList.add('board');
    el.style.setProperty('--n', n);
    let html = '';
    for (let y = n - 1; y >= 0; y--) for (let x = 0; x < n; x++) {
      const sq = String.fromCharCode(97 + x) + (y + 1), dark = (x + y) % 2 === 0;
      const color = has('white', sq) ? 'white' : has('black', sq) ? 'black' : '';
      let inner = '';
      if (color) inner = `<div class="piece ${color}${has('kings', sq) ? ' king' : ''}${opts.selected === sq ? ' selected' : ''}` +
        `${has('forced', sq) ? ' forced' : ''}"></div>`;
      if (has('targets', sq)) inner += '<div class="target"></div>';
      if (has('via', sq)) inner += '<div class="target via"></div>';
      if (has('error', sq)) inner += '<div class="error"></div>';
      if (opts.marks && opts.marks[sq]) inner += opts.marks[sq];
      html += `<div class="sq${dark ? ' dark' : ''}${has('last', sq) ? ' last' : ''}">${inner}</div>`;
    }
    el.innerHTML = `<div class="squares">${html}</div>`;
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

  // Today's puzzles as dots, the solved ones filled in the glow; a check once all are.
  const dots = (done, n, now = -1) => (done >= n ? `<span class="dots all">${icon('check')}</span>`
    : `<span class="dots">${Array.from({ length: n }, (_, i) => `<i class="${i < done ? 'on' : i === now ? 'now' : ''}"></i>`).join('')}</span>`);

  function init() {
    for (const w of [400, 700]) {
      document.head.insertAdjacentHTML('beforeend',
        `<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@fontsource/libertinus-sans@5.3.0/${w}.css">`);
    }
    document.body.classList.add(`theme-${settings.theme}`);
    document.querySelectorAll('[data-icon]').forEach((e) => e.insertAdjacentHTML('afterbegin', icon(e.dataset.icon)));
    fit();
    loadScene();
    const ro = new ResizeObserver(later);
    ro.observe(document.body);
    document.querySelectorAll('.glass').forEach((el) => ro.observe(el));
    addEventListener('resize', () => { fit(); later(); });
    document.fonts.ready.then(later);
  }

  return { settings, params, dots, icon, board, start, init, sync: later, game, PLIES, mark };
})();
