// Who's playing and the player's sheet (shell/who.goose), headless. Home's chip, beside
// the way out, opens the card over the dimmed home; a face switches to that player and
// closes it, their look and game coming with them; + opens the sheet for a new player
// with the first free picture, and done adds them; the pencil puts a badge on each face,
// and a face then opens its sheet, where the name is typed (a name's characters, Erase,
// Return) and done saves it. Start again and remove are holds: let go at 0.5 s and
// nothing happens; held 1.5 s the ring fills and they act, the frames running only while
// held. The last player has no remove. Back goes from the sheet to the card and closes
// the card; a tap outside the card closes it. A fresh install's first run opens on the
// sheet of its one player, whose done and back both go home, with none of home's pieces
// (the wordmark's crown) drawn over it.
//
// Then the card and the sheet laid out at the tablet's and a 20:9 phone's proportions,
// both orientations, the phone at 480 dp, with one and four players and in English and
// Estonian: every tile of theirs inside the safe area, none overlapping another, every
// one 88 dp at least, and the sheet's pictures and holds; with the name typed, the card
// at the top.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn listed(sh: shell::Shell&) -> u8[>..] {
    var s: u8[>..] = [];
    for p, i in sh.players.list {
        format(s, if i == sh.players.playing { "*" } else { "" }, p.id, " ", players::ANIMALS[p.picture]);
        if p.name.len > 0 { format(s, " ", p.name[..]); }
        s.append(if i + 1 < sh.players.list.len { ", " } else { "" });
    }
    return s;
}

fn state(sh: shell::Shell&) -> u8[>..] {
    let states = ["closed", "who's playing", "the sheet", "the question"];
    return str(states[sh.who.state], if sh.who.editing { " (editing)" } else { "" }, if sh.who.typing { " (typing)" } else { "" },
               "; ", listed(sh), "; season ", sh.prefs.season, ", game ", rules::VARIANTS[sh.game.b.variant].size,
               " after ", sh.game.b.history.len);
}

// The tiles declared from the n-th on (the card's, home's being first).
fn card_tile(g: gui::Gui&, first: i64, k: i64) -> float2 { drive::tile(g, first + k) }

fn overlaps(a: float4, b: float4) -> bool {
    let e: f32 = 0.5;
    return a.x + e < b.x + b.z && b.x + e < a.x + a.z && a.y + e < b.y + b.w && b.y + e < a.y + a.w;
}

fn inside(r: float4, a: float4) -> bool {
    return r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

// The card's tiles from `first` on: how many, the smallest across and down in dp, the
// card's glass in dp, and anything out of place.
fn report(what: const u8[:], g: gui::Gui&, first: i64) {
    let u = g.scale;
    let safe = gui::safe(g, drive::size.x, drive::size.y);
    let n = drive::tiles(g);
    var narrow: f32     = 1.0e9;
    var low:    f32     = 1.0e9;
    var wrong:  u8[>..] = [];
    for i in first..n {
        let r = drive::rect(g, i);
        narrow = min(narrow, r.z);
        low = min(low, r.w);
        if !inside(r, safe) { format(wrong, " tile ", i - first, " off the safe area;"); }
        for j in first..i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j - first, " and ", i - first, " overlap;"); } }
    }
    // The card: the first glass after the veil.
    var card = float4 { 0.0, 0.0, 0.0, 0.0 };
    var veiled = false;
    for q in g.quads {
        if q.look.x == gui::FILL && q.color.w > 0.4 && q.color.w < 0.45 { veiled = true; }
        if veiled && q.look.x == gui::GLASS && card.z == 0.0 { card = q.rect; }
    }
    if narrow < gui::TAP * u - 0.5 || low < gui::TAP * u - 0.5 { wrong.append(" a tap under 88 dp;"); }
    print("  ", what, ": ", n - first, " tiles, smallest ", whole(narrow / u), " x ", whole(low / u), " dp, card at ",
          whole(card.y / u), " dp, ", whole(card.z / u), " x ", whole(card.w / u), " dp",
          if wrong.len > 0 { wrong[..] } else { ", all in place" });
}

// Home's tiles with the card closed; the card's tiles follow them when it is open.
fn home_tiles(sh: shell::Shell&, g: gui::Gui&, now: f64) -> i64 {
    let was = sh.who.state;
    sh.who.state = who::CLOSED;
    drive::idle(sh, g, now);
    let n = drive::tiles(g);
    sh.who.state = was;
    drive::idle(sh, g, now);
    return n;
}

// Holds the pointer down on p from `now` for `seconds`, a frame each 0.1 s, then lets go;
// prints what the frames said.
fn hold(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64, seconds: f64) {
    drive::frame(sh, g, p, true, true, false, now);
    var t = 0.1;
    var animating = true;
    while t <= seconds + 0.001 {
        drive::frame(sh, g, p, true, false, false, now + t);
        animating = animating && (shell::animating(sh, g, now + t) || sh.who.state != who::SHEET);
        t += 0.1;
    }
    drive::frame(sh, g, p, false, false, true, now + seconds + 0.05);
    drive::idle(sh, g, now + seconds + 0.1);
    print("  held ", seconds, " s: animating while held ", animating, ", after ", shell::animating(sh, g, now + seconds + 0.5));
}

fn type_text(sh: shell::Shell&, g: gui::Gui&, chars: const u32[:], now: f64) {
    var input = gui::Input { at: drive::AWAY, .. };
    for c in chars { input.typed.push(c); }
    gui::begin(g, input, gui::scale_of(drive::size.x, drive::size.y), now);
    shell::frame(sh, g, drive::size.x, drive::size.y, now);
    drive::idle(sh, g, now + 0.02);
}

// The card and a sheet (the player at `index`, or -1 for a new one) of shell s.
fn layouts(s: shell::Shell&, g: gui::Gui&, name: const u8[:], index: i64, now: f64) {
    s.who = who::Who {};
    who::open(s.who);
    report(str(name, ", ", s.players.list.len, " players, who's playing"), g, home_tiles(s, g, now));
    who::sheet_for(s.who, s.players, index);
    drive::idle(s, g, now);
    report(str(name, ", ", if index < 0 { "a new player" } else { "a sheet" }), g, home_tiles(s, g, now));
    s.who.typing = true;
    drive::idle(s, g, now);
    report(str(name, ", typing"), g, home_tiles(s, g, now));
    s.who = who::Who {};
}

var t: f64 = 0.0;
fn tick() -> f64 {
    t += 1.0;
    return t;
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);

    drive::idle(sh, g, t);
    let home = drive::tiles(g);
    // The chip: the last tile but one, beside the way out.
    print("home's chip at ", drive::rect(g, home - 2), ", the way out at ", drive::rect(g, home - 1));
    drive::tap(sh, g, drive::tile(g, home - 2), tick());
    print("chip tapped: ", state(sh));
    let first = home_tiles(sh, g, t);
    // back, pencil, then the faces and +.
    print("the card's tiles: ", drive::tiles(g) - first);
    drive::tap(sh, g, card_tile(g, first, 3), tick());
    print("+ tapped: ", state(sh), ", picture ", players::ANIMALS[sh.who.picture]);
    // The sheet: back, done, the six pictures, the name. Owl, a name, done.
    let sheet = home_tiles(sh, g, t);
    drive::tap(sh, g, card_tile(g, sheet, 2 + 3), tick());
    drive::tap(sh, g, card_tile(g, sheet, 8), tick());
    print("the name tapped: ", state(sh), ", keyboard asked ", sh.who.keyboard);
    type_text(sh, g, [0x4D, 0x69, 0x61, 0x78, gui::ERASE], tick());
    type_text(sh, g, [gui::ENTER], tick());
    print("typed: '", sh.who.name[..], "', ", state(sh));
    drive::tap(sh, g, card_tile(g, sheet, 1), tick());
    print("done: ", state(sh), ", changed ", sh.changed);
    // The question (task 026): asked once it shows; I know how closes it.
    let asked = home_tiles(sh, g, t);
    print("  asked ", sh.prefs.first_start_done, ", the question's tiles ", drive::tiles(g) - asked);
    drive::tap(sh, g, card_tile(g, asked, 1), tick());
    print("I know how: ", state(sh), ", knows ", sh.prefs.knows, ", home's first row how to play ", shell::resume(sh).learn);
    sh.changed = false;
    // A tap on the player's game, then back to the fox through the card.
    drive::tap(sh, g, drive::tile(g, home - 2), tick());
    let card = home_tiles(sh, g, t);
    drive::tap(sh, g, card_tile(g, card, 2), tick());
    print("the fox's face: ", state(sh), ", changed ", sh.changed);
    // The pencil, then Mia's face: her sheet.
    drive::tap(sh, g, drive::tile(g, home - 2), tick());
    drive::tap(sh, g, card_tile(g, card, 1), tick());
    print("the pencil: ", state(sh));
    drive::tap(sh, g, card_tile(g, card, 3), tick());
    print("Mia's face: ", state(sh), ", the sheet's tiles ", drive::tiles(g) - home_tiles(sh, g, t));
    let mine = home_tiles(sh, g, t);
    // The holds: start again, then remove (Mia is not playing).
    let again = card_tile(g, mine, 9);
    let remove = card_tile(g, mine, 10);
    print("start again, let go early:");
    hold(sh, g, again, tick(), 0.5);
    print("  ", state(sh));
    print("start again, held:");
    hold(sh, g, again, tick(), 1.6);
    print("  ", state(sh));
    print("remove, let go early:");
    hold(sh, g, remove, tick(), 0.5);
    print("  ", state(sh));
    print("remove, held:");
    hold(sh, g, remove, tick(), 1.6);
    print("  ", state(sh));
    // The fox's own sheet, now the last player: no remove.
    drive::tap(sh, g, card_tile(g, card, 2), tick());
    print("the last player's sheet: ", state(sh), ", tiles ", drive::tiles(g) - home_tiles(sh, g, t));
    // Back: to the card, then closed.
    shell::back(sh, tick());
    print("back: ", state(sh));
    shell::back(sh, tick());
    print("back: ", state(sh));
    // Outside the card.
    drive::tap(sh, g, drive::tile(g, home - 2), tick());
    drive::tap(sh, g, float2 { 4.0, drive::size.y - 4.0 }, tick());
    print("a tap outside the card: ", state(sh));

    // A fresh install's first run.
    var fresh = shell::new(rules::INTERNATIONAL);
    fresh.unset = true;         // no game kept, as on a fresh install (shell::read_game)
    who::first_run(fresh.who, fresh.players);
    drive::idle(fresh, g, tick());
    let at = home_tiles(fresh, g, t);
    print("first run: ", state(fresh), ", tiles ", drive::tiles(g) - at);
    // Home's pieces over its UI (the wordmark's crown) would draw on the sheet: none.
    print("home's pieces over the sheet: ", fresh.out.over.len);
    drive::tap(fresh, g, card_tile(g, at, 2 + 4), tick());
    drive::tap(fresh, g, card_tile(g, at, 1), tick());
    print("a frog, done: ", state(fresh), ", changed ", fresh.changed);
    // Show me: how to play in the player's draughts, from its first step; its back goes home,
    // where How to play is the first row.
    let q = home_tiles(fresh, g, t);
    drive::tap(fresh, g, card_tile(g, q, 0), tick());
    print("show me: screen ", fresh.screen, " (how to play ", shell::TUTORIAL, "), step ", fresh.lesson.step, " of ",
          tutorial::count(fresh.lesson.variant), ", knows ", fresh.prefs.knows);
    shell::back(fresh, tick());
    drive::idle(fresh, g, tick());
    print("back: screen ", fresh.screen, ", home's first row how to play ", shell::resume(fresh).learn);

    // The layouts.
    var many = shell::new(rules::INTERNATIONAL);
    var none: players::Name = [];
    var name: players::Name = [];
    players::set_name(name, "Aleksandra M");
    for k in 3 { shell::add_player(many, k + 1, if k == 0 { name } else { none }); }
    let sizes = [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }, float2 { 1066.0, 480.0 }, float2 { 480.0, 1066.0 }];
    let names = ["tablet landscape", "tablet portrait", "phone landscape", "phone portrait"];
    for lang in strings::LANGUAGES.len {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ":");
        for size, k in sizes {
            drive::size = size;
            gui::short_dp = if k < 2 { 800.0 } else { 480.0 };
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            layouts(sh, g, names[k], -1, t);
            layouts(many, g, names[k], 1, t);
        }
    }
}
