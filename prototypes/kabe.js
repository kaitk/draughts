// Shared parts of the kabe prototypes: the scene and its pre-blurred copy for glass, the
// board, icons, and a switcher for the board theme, font, and season (?theme=, ?font=,
// ?season=, ?king=stack). Plain script, no build step.
'use strict';

const Kabe = (() => {
  const params = new URLSearchParams(location.search);

  const FONTS = {
    tenor: { family: 'Tenor Sans', pkg: 'tenor-sans', weights: [400] },
    libertinus: { family: 'Libertinus Sans', pkg: 'libertinus-sans', weights: [400, 700] },
    belleza: { family: 'Belleza', pkg: 'belleza', weights: [400] },
    marcellus: { family: 'Marcellus', pkg: 'marcellus', weights: [400] },
  };
  const THEMES = ['wood', 'stone', 'flat'];
  const SEASONS = ['winter', 'spring', 'summer', 'autumn'];

  function seasonNow() {
    const m = new Date().getMonth();
    return m < 2 || m === 11 ? 'winter' : m < 5 ? 'spring' : m < 8 ? 'summer' : 'autumn';
  }

  const settings = {
    theme: THEMES.includes(params.get('theme')) ? params.get('theme') : 'wood',
    font: FONTS[params.get('font')] ? params.get('font') : 'libertinus',
    season: SEASONS.includes(params.get('season')) ? params.get('season') : seasonNow(),
    king: params.get('king') === 'stack' ? 'stack' : 'crown',
  };

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

  // The scene: a calm Nordic landscape for the season, painted once per size. The page
  // shows it softened; glass shows a small copy blurred hard, as the app will (one
  // texture, blurred when the background changes).
  const PALETTES = {
    winter: { sky: ['#1b2a44', '#51698d', '#c9d4e2'], sun: '#ffe9c8', hills: ['#9fb0c8', '#d6e0ec', '#eef3f8'], trees: '#2e3f52', water: null },
    spring: { sky: ['#294766', '#6f9bbf', '#e6efe0'], sun: '#fff4d2', hills: ['#6f8f6a', '#9fbf7f', '#c9dca2'], trees: '#3c5a3a', water: null },
    summer: { sky: ['#1d4f7a', '#5d9cc7', '#f2e6c9'], sun: '#fff1c4', hills: ['#4f7a6a', '#7aa08a'], trees: '#2f4f45', water: '#3f7fa8' },
    autumn: { sky: ['#2b2a44', '#8a6a7d', '#f0bf8a'], sun: '#ffd7a0', hills: ['#6b4a3a', '#a8643a', '#c98a45'], trees: '#3b2a25', water: null },
  };

  function paintScene(season, w, h) {
    const p = PALETTES[season];
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
    sun.addColorStop(0.12, p.sun + 'cc');
    sun.addColorStop(1, p.sun + '00');
    g.fillStyle = sun;
    g.fillRect(0, 0, w, h);
    let seed = 7;
    const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    p.hills.forEach((col, i) => {
      const base = h * (0.55 + i * 0.12);
      g.fillStyle = col;
      g.beginPath();
      g.moveTo(0, h);
      for (let x = 0; x <= w; x += w / 60) {
        const y = base - Math.sin(x / w * (3 + i * 2) + i * 1.7) * h * 0.05 - Math.sin(x / w * 11 + i) * h * 0.012;
        g.lineTo(x, y);
      }
      g.lineTo(w, h);
      g.fill();
      if (i === 0 || (i === 1 && p.hills.length > 2)) {
        g.fillStyle = p.trees;
        for (let k = 0; k < 40; k++) {
          const x = rnd() * w;
          const y = base - Math.sin(x / w * (3 + i * 2) + i * 1.7) * h * 0.05 + h * 0.01;
          const th = h * (0.04 + rnd() * 0.05) * (i === 0 ? 0.8 : 1.2);
          g.beginPath();
          g.moveTo(x, y - th);
          g.lineTo(x - th * 0.28, y);
          g.lineTo(x + th * 0.28, y);
          g.fill();
        }
      }
    });
    if (p.water) {
      const sea = g.createLinearGradient(0, h * 0.68, 0, h);
      sea.addColorStop(0, p.water);
      sea.addColorStop(1, '#173a55');
      g.fillStyle = sea;
      g.fillRect(0, h * 0.72, w, h * 0.28);
      g.fillStyle = 'rgb(255 241 196 / 0.35)';
      for (let k = 0; k < 30; k++) g.fillRect(w * 0.62 + rnd() * w * 0.2, h * (0.73 + rnd() * 0.2), w * 0.03 * rnd(), 2);
    }
    if (season === 'winter') {
      g.fillStyle = 'rgb(255 255 255 / 0.7)';
      for (let k = 0; k < 120; k++) {
        g.beginPath();
        g.arc(rnd() * w, rnd() * h * 0.8, 1 + rnd() * 2.5, 0, 7);
        g.fill();
      }
    }
    return c;
  }

  function blurred(src, width, blurPx, extra = '') {
    const c = document.createElement('canvas');
    c.width = width;
    c.height = Math.round(src.height * width / src.width);
    const g = c.getContext('2d');
    g.filter = `blur(${blurPx * width / innerWidth}px) ${extra}`;
    // Draw a little past the edges so the blur doesn't darken them.
    const m = c.width * 0.08;
    g.drawImage(src, -m, -m, c.width + 2 * m, c.height + 2 * m);
    return c.toDataURL('image/jpeg', 0.85);
  }

  function applyScene() {
    const w = Math.min(1600, innerWidth), h = Math.round(w * innerHeight / innerWidth);
    const scene = paintScene(settings.season, w, h);
    document.body.style.setProperty('--scene', `url(${blurred(scene, w, 6)})`);
    document.body.style.setProperty('--glass-copy', `url(${blurred(scene, 240, 24, 'saturate(1.3)')})`);
  }

  const ICONS = {
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    hint: '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.3h6c0-1 .4-1.8 1-2.3A7 7 0 0 0 12 2z"/>',
    restart: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    back: '<path d="M15 18l-6-6 6-6"/>',
    next: '<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>',
    friend: '<circle cx="9" cy="7" r="4"/><path d="M2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/><path d="M22 21v-1a6 6 0 0 0-4-5.6"/>',
    computer: '<rect x="3" y="8" width="18" height="12" rx="3"/><path d="M12 8V5"/><circle cx="12" cy="4" r="1"/><circle class="solid" cx="9" cy="14" r="1.3"/><circle class="solid" cx="15" cy="14" r="1.3"/>',
    puzzle: '<path d="M4 7h5a3 3 0 0 1 6 0h5v4a3 3 0 0 1 0 6v4H4z"/>',
    star: '<path class="solid" d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    starOff: '<path d="M12 2l3.1 6.3 6.9 1-5 4.8 1.2 6.9-6.2-3.2-6.2 3.2 1.2-6.9-5-4.8 6.9-1z"/>',
    crown: '<path class="solid" d="M3 17 2 7l5 4 5-7 5 7 5-4-1 10z"/><path class="solid" d="M3 19h18v2H3z"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  };

  function icon(name, cls = '') {
    return `<svg class="icon ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;
  }

  // Squares as a1..h8 (or a1..j10); a1 is dark, bottom left, as in rules/.
  function at(sq) {
    return { x: sq.charCodeAt(0) - 97, y: parseInt(sq.slice(1), 10) - 1 };
  }

  // Draws a board into el. opts: { n, white: [...], black: [...], kings: [...],
  // selected, forced: [...], targets: [...], via: [...], last: [...] }.
  function board(el, opts) {
    const n = opts.n || 8;
    const set = (list) => new Set(list || []);
    const white = set(opts.white), black = set(opts.black), kings = set(opts.kings);
    const forced = set(opts.forced), targets = set(opts.targets), via = set(opts.via);
    const last = set(opts.last);
    el.classList.add('board', `theme-${opts.theme || settings.theme}`);
    if ((opts.king || settings.king) === 'stack') el.classList.add('stack');
    el.style.setProperty('--n', n);
    let html = '<div class="squares">';
    for (let y = n - 1; y >= 0; y--) {
      for (let x = 0; x < n; x++) {
        const sq = String.fromCharCode(97 + x) + (y + 1);
        const dark = (x + y) % 2 === 0;
        let inner = '';
        if (white.has(sq) || black.has(sq)) {
          const cls = [white.has(sq) ? 'white' : 'black', kings.has(sq) ? 'king' : '',
            opts.selected === sq ? 'selected' : '', forced.has(sq) ? 'forced' : ''].join(' ');
          inner = `<div class="piece ${cls}">${kings.has(sq) ? `<div class="crown">${icon('crown')}</div>` : ''}</div>`;
        } else if (targets.has(sq)) {
          inner = '<div class="target"></div>';
        } else if (via.has(sq)) {
          inner = '<div class="target via"></div>';
        }
        html += `<div class="sq${dark ? ' dark' : ''}${last.has(sq) ? ' last' : ''}">${inner}</div>`;
      }
    }
    el.innerHTML = html + '</div>';
  }

  // The prototype switcher, bottom right, faint until hovered.
  function bar() {
    const el = document.createElement('div');
    el.className = 'proto-bar';
    const select = (key, values) => `<select data-key="${key}">${values.map((v) =>
      `<option${settings[key] === v ? ' selected' : ''}>${v}</option>`).join('')}</select>`;
    el.innerHTML = select('theme', THEMES) + select('font', Object.keys(FONTS)) +
      select('season', SEASONS) + select('king', ['crown', 'stack']);
    el.addEventListener('change', (e) => {
      params.set(e.target.dataset.key, e.target.value);
      location.search = params.toString();
    });
    document.body.appendChild(el);
  }

  function init() {
    document.documentElement.style.setProperty('--font', loadFont(settings.font));
    applyScene();
    let pending;
    addEventListener('resize', () => {
      clearTimeout(pending);
      pending = setTimeout(applyScene, 200);
    });
    bar();
    document.querySelectorAll('[data-icon]').forEach((e) => {
      e.insertAdjacentHTML('afterbegin', icon(e.dataset.icon));
    });
  }

  return { settings, FONTS, THEMES, icon, board, init, loadFont, paintScene, blurred };
})();
