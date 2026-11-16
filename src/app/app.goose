// Draughts, the program both roots run: the gfx build's src/app/draughts.goose and the
// one holding goose-ngfx too, src/ngfx/draughts_ngfx.goose. It draws only when something
// changed (docs/architecture/rendering.md). Every flag is a field of flags::Flags.

import std;
import vec;
import os;
import audio;
import rules from "../rules";
import board from "../board";
import strings from "../../strings";
import gui from "../gui";
import .theme;
import .draw;
import .draw_gpu;
import .gpu;
import .scene;
import .scene_gpu;
import .widgets;
import .widgets_gpu;
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import puzzles from "../puzzles";
import badges from "../badges";
import model3d from "../model3d";
import render3d from "../render3d";
import .text;
import .host;
import .host_gpu;
import .think;
import .draw3d;
import .render;
import .flags;
import .dev;
import .bench;

// Seconds between looks for the hint's answer while it is on its way (think::frame).
let HINT_POLL = 0.02;

// What the loop carries from one frame to the next.
struct Loop {
    size:         int2 = int2 { 0, 0 },
    scale:        f32  = 0.0,
    dirty:        bool = true,
    focused:      bool = true,
    season_in:    i64  = 0,     // frames until a new season's photograph loads
    wake_at:      f64  = -1.0,  // when the timer set last wakes the loop
    released:     bool = false, // the launch's memory given back
    most_dropped: i64  = 0,
    day:          i64  = 0,     // the local date for the daily puzzles
    zone:         i64  = 0,     // the local zone's offset from UTC in seconds, the games' dates in it
    day_read:     f64  = 0.0,
    level:        f32  = -1.0,  // the volume the sounds were last set to, and muted
    muted:        bool = false,
}

// The sound each sound event plays (board/sound_event.goose): a capture's stop is the move a step up.
let SOUND_OF = [sound::MOVE, sound::MOVE, sound::TAKE, sound::CROWN, sound::WRONG, sound::MUST, sound::GOLD, sound::RED,
                sound::SOLVED, sound::WON, sound::LOST, sound::DRAWN, sound::CROWN_COMPUTER];

// The sounds (docs/architecture/sound.md): the volume followed, the device opened and the
// sounds built once it is above zero and closed at zero, then this frame's sound events played.
fn play_sounds(lp: Loop&, bk: sound::Bank&, out: shell::Frame&, s: settings::Settings&) {
    let level = settings::volume_of(s);
    if level != lp.level || s.muted != lp.muted {
        lp.level = level;
        lp.muted = s.muted;
        if !sound::set_level(bk, level, s.muted) { print("sound: ", audio::error()); }
    }
    for c in out.sound_events { sound::play(bk, SOUND_OF[c.kind], c.step); }
}

// The theme a season setting picks: its own, or by the date.
fn theme_for(season: i64) -> i64 {
    return if season >= 0 { season } else { theme::for_month(theme::month(time())) };
}

fn season_changed(rd: render::Renderer&, sh: shell::Shell&) -> bool {
    return !render::shows_theme(rd, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs));
}

// Android may kill the app once it is paused, and SDL runs the loop once more after focus
// is lost, so the game is written then. On a phone the clocks count only while the app
// has focus; a Mac window started from a terminal never has it, so desktops leave it out.
fn follow_focus(lp: Loop&, sh: shell::Shell&, mobile: bool) {
    if lp.focused && !host::focused() { shell::write_game(sh); }
    if mobile && (!lp.focused || !host::focused()) { shell::pause(sh); }
    lp.focused = host::focused();
}

// A new season loads two frames after the tap, so the tile shows lit before the load
// holds the thread.
fn load_season(lp: Loop&, rd: render::Renderer&, sh: shell::Shell&) {
    guard lp.season_in > 0 else { return; }
    lp.season_in--;
    if lp.season_in == 0 && season_changed(rd, sh) {
        render::reload(rd, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs));
        lp.dirty = true;
    }
}

// The screen's size, scale, and safe area, read each frame: turning a phone moves its
// cutout and gesture bar, and a window moved to another display lays out again.
fn follow_screen(lp: Loop&, h: host::Host&, f: flags::Flags&, g: gui::Gui&, rd: render::Renderer&,
                 mobile: bool, on_android: bool) -> f32 {
    let s = host::screen_size();
    if s.x != lp.size.x || s.y != lp.size.y {
        lp.size = s;
        lp.dirty = true;
    }
    if host::exposed() { lp.dirty = true; }
    host::read_display(h);
    let display = h.display;
    if mobile && f.display_scale < 0.0 { gui::display_scale = display[4]; }
    // A desktop's controls stay the size a mouse wants however large the window, unless
    // --touch lays it out as a touch screen.
    if !mobile && f.touch != 1 { gui::desktop_scale = if f.display_scale >= 0.0 { f.display_scale } else { display[4] }; }
    let scale = gui::scale_of(lp.size.x, lp.size.y);
    // The 3D board's shadow taps: 16 on a desktop and iOS; on Android 4 on a phone, 9 on a
    // tablet. A phone's screen bakes its surfaces at a quarter of the texels.
    let phone = gui::phone(float4 { 0.0, 0.0, lp.size.x, lp.size.y }, scale);
    render::screen_shadow(rd, if !on_android { render3d::SHADOW_16 } else if phone { render3d::SHADOW_4 }
                              else { render3d::SHADOW_9 });
    render::screen_bake(rd, phone);
    let e = if f.inset.x < 0.0 { float4 { display[0], display[1], display[2], display[3] } }
            else { float4 { floor(f.inset.x * scale + 0.5), floor(f.inset.y * scale + 0.5),
                            floor(f.inset.z * scale + 0.5), floor(f.inset.w * scale + 0.5) } };
    if scale != lp.scale || e.x != g.insets.x || e.y != g.insets.y || e.z != g.insets.z || e.w != g.insets.w {
        lp.scale = scale;
        g.insets = e;
        lp.dirty = true;
    }
    if render::upload_text(rd, g, scale) { trim_memory(); }
    return scale;
}

// The 3D board gets ready a step a frame as it is drawn (draw3d::prepare), so frames go on
// until it shows and has faded in, and while its image eases grey or back. Back to flat,
// it is given back only once settings is left, so switching there doesn't prepare it
// again each time. Returns whether it is ready and whether it shows.
fn follow_3d(lp: Loop&, rd: render::Renderer&, sh: shell::Shell&, now: f64) -> bool, bool {
    let want = shell::board3d(sh);
    render::material(rd, sh.prefs.material);
    let ready = want != shell::WANTED || render::ready3d(rd, shell::board_n(sh));
    let shown = render::shown3d(rd);
    // Only a screen showing the board prepares it, so only there is it waited for.
    if want == shell::WANTED && sh.out.raised && (!ready || !shown || render::appearing3d(rd, now)) { lp.dirty = true; }
    if sh.out.raised && render::moving3d(rd) { lp.dirty = true; }
    if want == shell::DROPPED { render::drop3d(rd); }
    return ready, shown;
}

// The UI's quads past gui::MAX_QUADS are dropped unseen, so each new most is printed.
fn report_dropped(lp: Loop&, g: gui::Gui&, sh: shell::Shell&) {
    guard g.dropped > lp.most_dropped else { return; }
    lp.most_dropped = g.dropped;
    print("gui: ", g.dropped, " quads dropped past gui::MAX_QUADS (", gui::MAX_QUADS, ") on screen ", sh.screen);
}

// A switches the 3D board between MSAA and SMAA; Alt and Enter, or F11, a desktop's window
// to fullscreen and back; neither while a name is typed, which keeps the keyboard up.
fn follow_keys(lp: Loop&, h: host::Host&, rd: render::Renderer&, out: shell::Frame&) {
    if !out.typing && host::aa_key() {
        render::toggle_aa(rd);
        lp.dirty = true;
    }
    if !out.typing && host::fullscreen_key() {
        host::toggle_fullscreen();
        lp.dirty = true;
    }
    host::keyboard(h, out.typing, out.keyboard);
}

// A tap in settings applies at once and is written (shell::Frame.save).
fn save_settings(lp: Loop&, rd: render::Renderer&, sh: shell::Shell&, system_lang: i64) {
    players::write(sh.players, sh.prefs);
    shell::wrote(sh);
    let next = if sh.prefs.language >= 0 { sh.prefs.language } else { system_lang };
    if next != strings::current { strings::use(next); }
    if season_changed(rd, sh) { lp.season_in = 2; }
    lp.dirty = true;
}

fn draw(dv: dev::Dev&, f: flags::Flags&, rd: render::Renderer&, sh: shell::Shell&, g: gui::Gui&,
        out: shell::Frame&, size: int2, now: f64) {
    var frame = render::Frame { board: shell::build_frame_pieces(sh, now), layout: out.layout, ui_pieces: out.ui_pieces[..], quads: g.quads[..],
                                clip:  g.scroll.view, raised: out.raised, view: out.view,
                                which: shell::which(out.board_screen), hold: out.hold, place: out.place,
                                fade:  out.fade, blur: out.blur, hole: out.hole, tall: out.tall, now: now,
                                size: size };
    if f.bench > 0 { bench::frame(dv.bench, f, rd, frame); } else { render::frame(rd, frame); }
}

// A timer wakes the idle loop when a clock's shown time changes, the computer's move is
// due, or a held arrow repeats.
fn set_wake(lp: Loop&, h: host::Host&, sh: shell::Shell&, now: f64) {
    var next = shell::wake_in(sh, now, HINT_POLL);
    let repeat = host::repeat_in(h.repeat, now);
    if repeat >= 0.0 && (next < 0.0 || repeat < next) { next = repeat; }
    if next >= 0.0 && (lp.wake_at < now || now + next < lp.wake_at - 0.005) {
        host::wake_in((1000.0 * next) as i64 + 2);
        lp.wake_at = now + next;
    }
}

fn run() {
    let f = flags::parse(args());
    if f.dp > 0 { gui::short_dp = f.dp; }
    if f.density_floor >= 0.0 { gui::density_floor = f.density_floor; }
    if f.display_scale >= 0.0 { gui::display_scale = f.display_scale; }
    // --dp says how many dp the shorter side has, so the floor stays off unless asked.
    if f.dp > 0 && f.density_floor < 0.0 { gui::density_floor = 0.0; }
    var kind = f.theme;
    var lang = f.lang;
    // A run with flags that set up a game or take a screenshot neither reads nor writes
    // the player's saved game.
    let keep = f.screen < 0 && f.puzzle < 0 && f.library < 0 && f.go < 0 && f.win < 0.0 && f.fen.len == 0 && f.taps.len == 0 && f.frames < 0 && f.variant < 0 && f.clock < 0 && f.computer < 0;
    var folder: u8[512] = [0; 512];
    let dir = host::storage(folder);
    var players_read = players::Players {};
    // A new player starts on the 3D board on a desktop, on the flat one elsewhere; the
    // device's sound starts at half on a desktop and off on a phone or a tablet.
    if host::platform() == host::DESKTOP {
        settings::default_board = settings::RAISED;
        settings::default_volume = 50;
    }
    host::sound_session();
    let prefs = players::load(players_read, dir, keep);
    if kind < 0 { kind = theme_for(prefs.season); }
    var locales: u8[256] = [0; 256];
    let system_lang = strings::pick(host::locales(locales));
    if lang < 0 { lang = if prefs.language >= 0 { prefs.language } else { system_lang }; }
    strings::use(lang);
    puzzles::load((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);

    let platform = host::platform();
    let on_android = platform == host::ANDROID;
    let on_ios = platform == host::IOS;
    let mobile = platform != host::DESKTOP;
    // An iOS app never closes itself, so home has no way out there.
    if on_ios { home::closable = false; }
    var h = host::open(strings::get(strings::APP_NAME), f.width, f.height, f.full, f.no_vsync);
    defer host::close();

    var sh = shell::new((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);
    shell::launch(sh, prefs, players_read);
    dev::setup(f, sh, prefs);
    shell::open(sh, keep);
    var rd = render::new(kind, !settings::photo_shown(sh.prefs), f);
    var dv = dev::new(f);
    var g = gui::Gui {};
    var thinker = think::Thinker {};
    var lp = Loop { day: host::local_day(), zone: host::utc_offset(), day_read: host::time(), .. };
    var bank = sound::Bank {};
    while host::frame() {
        // frame() presents what the pass before it drew, and the first pass draws.
        if host::frame_count() == 2 { host::first_frame(); }
        follow_focus(lp, sh, mobile);
        load_season(lp, rd, sh);
        let now = host::time();
        if now >= lp.day_read + 1.0 {
            lp.day = host::local_day();
            lp.zone = host::utc_offset();
            lp.day_read = now;
        }
        let scale = follow_screen(lp, h, f, g, rd, mobile, on_android);
        // The screens give the pointer to the UI first; a press on it never reaches the board.
        let input = dev::pointer(dv, f, host::input(h, now));
        gui::begin(g, input, scale, now);
        if input.wheel != 0.0 { lp.dirty = true; }
        // Back goes back a screen. From home's menu Android goes to the background, and a
        // desktop quits where home doesn't ask first (home::ask_quit).
        if host::back(h) {
            if shell::put_down(sh, g) || shell::back(sh, now) { lp.dirty = true; }
            else if on_android { host::leave(); }
            else { break; }
        }
        dev::before(dv, f, sh, now);
        let ready3d, shown3d = follow_3d(lp, rd, sh, now);
        let out .= shell::frame(sh, g, lp.size.x, lp.size.y, now, ready3d, shown3d, lp.day, lp.zone);
        if out.changed { lp.dirty = true; }
        report_dropped(lp, g, sh);
        follow_keys(lp, h, rd, out);
        if out.quit { break; }
        // After shell::frame, so a game started over this frame is asked at its new skill.
        let moved = think::frame(thinker, sh.game);
        if moved {
            lp.dirty = true;
            g.acted = true;
        }
        host::keep_screen(h, moved || host::touched(input), now);
        if out.save { save_settings(lp, rd, sh, system_lang); }
        play_sounds(lp, bank, out, sh.prefs);
        if out.screen == shell::SETTINGS { render::thumbs(rd); }
        if dev::after_shell(dv, f, sh, g, rd, now) { lp.dirty = true; }
        // iOS ends an app that uses the GPU in the background, and SDL doesn't block the
        // loop there: nothing draws while the app hasn't focus, which it loses first.
        let hidden = on_ios && !host::focused();
        if hidden { lp.dirty = true; }
        let drew = !hidden && (lp.dirty || shell::animating(sh, g, now));
        if drew {
            draw(dv, f, rd, sh, g, out, lp.size, now);
            lp.dirty = false;
        }
        // A 3D board too slow for an Android display draws fewer samples, then drops the
        // display to 60 Hz (display.c). The 3D bench's waiting frames are left out.
        let paced = drew && out.raised && ready3d && shown3d && !dev::waited3d(dv);
        if on_android && host::pace_3d(paced, now) { render::fewer_samples(rd); }
        // The first idle frame after the launch's first frame shows loads settings'
        // thumbnails and gives what the launch's loads freed back to the system (memory.c).
        if !drew && !hidden && !lp.released && host::frame_count() >= 2 {
            render::thumbs(rd);
            host::release_memory();
            lp.released = true;
        }
        // The 3D pass keeps its targets while the board shows, and gives them back for a
        // screen without it or a phone's app losing focus on its way to the background.
        render::release_targets_unless_shown(rd, out.raised && !(mobile && !host::focused()));
        set_wake(lp, h, sh, now);
        // A widget declared before a click changed it draws again next frame.
        if g.acted { lp.dirty = true; }
        if dev::after(dv, f, rd, drew, lp.size, now) { break; }
    }
    dev::end(f, rd);
    sound::close(bank);
    shell::write_game(sh);
    if sh.out.quit { host::close_app(); }
}
