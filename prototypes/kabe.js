// Shared parts of the kabe prototypes: the season's background and the glass that shows
// its blurred copy, the board in 2D and 3D, icons, and a switcher for the season, board
// theme, view, king style, and font (?season=, ?theme=, ?view=3d, ?king=, ?font=).
// Plain script, no build step.
'use strict';

const Kabe = (() => {
  const params = new URLSearchParams(location.search);

  const FONTS = {
    tenor: { family: 'Tenor Sans', pkg: 'tenor-sans', weights: [400] },
    libertinus: { family: 'Libertinus Sans', pkg: 'libertinus-sans', weights: [400, 700] },
    belleza: { family: 'Belleza', pkg: 'belleza', weights: [400] },
    marcellus: { family: 'Marcellus', pkg: 'marcellus', weights: [400] },
  };
  const SEASONS = ['autumn', 'winter', 'spring', 'summer'];
  // The season picks the board: autumn wood, winter stone, spring birch, summer sea.
  // Tabletop pictures in design/tabletops/, by the switcher's name: <season>-<file>.png.
  const TOPS = { plain: '', real: 'real-02', felt: 'felt-01' };
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
    bg: pick('bg', ['auto', 'table', 'photo'], 'auto'),
    // The table's look: painted, or a generated tabletop picture (task 016; local only,
    // autumn so far).
    top: pick('top', Object.keys(TOPS), 'plain'),
    // Move hints: "mistakes" (the default) only marks a wrong move; "moves" shows the
    // selected piece's targets, on by default only in the first lessons (docs/product.md).
    assist: pick('assist', ['moves', 'mistakes'], 'mistakes'),
    font: FONTS[params.get('font')] ? params.get('font') : 'libertinus',
  };

  // Auto: a crown on the face top down, where a stack reads as a shadow; a stack of two
  // discs with the crown on top in 3D, as kings are in Estonian play.
  function kingStyle(view, king = settings.king) {
    return king === 'auto' ? (view === '3d' ? 'stack' : 'crown') : king;
  }

  function loadFont(key) {
    const f = FONTS[key];
    for (const w of f.weights) {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = `https://cdn.jsdelivr.net/npm/@fontsource/${f.pkg}@5.3.0/${w}.css`;
      document.head.appendChild(link);
    }
    return `'${f.family}', sans-serif`;
  }

  // The background. Behind the 2D board (pages with <body data-screen="board">), a flat
  // tabletop in the theme's color: the board reads cleanest on a calm surface. Everywhere
  // else (home, puzzles) and behind the 3D board, the season's photograph from design/backgrounds/masters/ (local, out of git; its README says how
  // to make it), or a painted stand-in without it.
  const TABLES = { wood: '#3a2c22', stone: '#25313e', birch: '#2a382f', sea: '#1e3838' };

  // A tabletop: the color, a little lighter under the board, darker toward the edges,
  // with a faint fine texture like matte cloth. Natively: one full-screen shader.
  function paintTable(theme, w, h) {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const g = c.getContext('2d');
    g.fillStyle = TABLES[theme];
    g.fillRect(0, 0, w, h);
    const r = Math.hypot(w, h) / 2;
    const v = g.createRadialGradient(w * 0.45, h * 0.45, 0, w * 0.5, h * 0.5, r);
    v.addColorStop(0, 'rgb(255 255 255 / 0.07)');
    v.addColorStop(0.55, 'rgb(255 255 255 / 0)');
    v.addColorStop(1, 'rgb(0 0 0 / 0.35)');
    g.fillStyle = v;
    g.fillRect(0, 0, w, h);
    const img = g.getImageData(0, 0, w, h);
    let seed = 11;
    for (let i = 0; i < img.data.length; i += 4) {
      seed = (seed * 16807) % 2147483647;
      const n = ((seed / 2147483647) - 0.5) * 7;
      img.data[i] += n; img.data[i + 1] += n; img.data[i + 2] += n;
    }
    g.putImageData(img, 0, 0);
    return c.toDataURL('image/jpeg', 0.9);
  }

  function useTable() {
    return settings.bg === 'table' ||
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
    if (useTable()) {
      const painted = () =>
        setScene(paintTable(settings.theme, 1280, Math.round(1280 * innerHeight / innerWidth)), innerWidth / innerHeight);
      if (settings.top === 'plain') return painted();
      const img = new Image();
      img.onload = () => setScene(img.src, img.naturalWidth / img.naturalHeight);
      img.onerror = painted;
      img.src = `../design/tabletops/${settings.season}-${TOPS[settings.top]}.png`;
      return;
    }
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
            inner = `<div class="piece ${color} ${kings.has(sq) ? 'king' : ''} ${cls}">${kings.has(sq) ? `<div class="crown">${icon('crown')}</div>` : ''}</div>`;
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
      select('bg', ['auto', 'table', 'photo'], settings.bg) +
      select('assist', ['moves', 'mistakes'], settings.assist) +
      select('top', Object.keys(TOPS), settings.top) +
      select('font', Object.keys(FONTS), settings.font);
    el.addEventListener('change', (e) => {
      const { key } = e.target.dataset;
      if (key === 'theme' && e.target.value === 'auto') params.delete('theme');
      else params.set(key, e.target.value);
      location.search = params.toString();
    });
    document.body.appendChild(el);
  }

  function init() {
    document.documentElement.style.setProperty('--font', loadFont(settings.font));
    document.body.classList.add(`theme-${settings.theme}`);
    loadScene();
    addEventListener('resize', () => (useTable() && settings.top === 'plain' ? loadScene() : syncGlass()));
    addEventListener('scroll', syncGlass, true);
    addEventListener('load', syncGlass);
    document.fonts.ready.then(syncGlass);
    bar();
    document.querySelectorAll('[data-icon]').forEach((e) => {
      e.insertAdjacentHTML('afterbegin', icon(e.dataset.icon));
    });
  }

  return { settings, FONTS, THEMES, SEASON_THEME, icon, board, init, loadFont, syncGlass, kingStyle, ICONS };
})();
