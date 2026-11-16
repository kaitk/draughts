// Switching through home's card to a player whose draughts is another size (shell::
// who_card, change_player): every frame lays the board out for the pieces it draws, the
// old player's to the tap's end and the new one's from the next frame, so no frame's
// board shows one size's pieces on the other's squares (the 3D board keeps that image
// while it is prepared for the new size). International to Russian and back.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/switch-size-files/") } else { str("switch-size-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

var t: f64 = 0.0;
fn tick() -> f64 {
    t += 1.0;
    return t;
}

// Whether the last frame's layout is for the board it draws.
fn agrees(sh: shell::Shell&) -> bool {
    let b .= shell::board_of(sh, sh.out.board_screen);
    return rules::VARIANTS[b.variant].size == sh.out.layout.n;
}

// A frame with the pointer at p, and whether it agreed; `wrong` counts the frames that didn't.
fn step(sh: shell::Shell&, g: gui::Gui&, p: float2, down: bool, pressed: bool, released: bool, wrong: i64&) {
    drive::frame(sh, g, p, down, pressed, released, tick());
    if !agrees(sh) { wrong++; }
}

// Opens the card from home's chip and taps the face of the player at `index`, a frame
// at a time; prints the board's size after and the frames that didn't agree.
fn switch_to(sh: shell::Shell&, g: gui::Gui&, index: i64, what: const u8[:]) {
    var wrong = 0;
    step(sh, g, drive::AWAY, false, false, false, wrong);
    let home = drive::tiles(g);
    let chip = drive::tile(g, home - 2);
    step(sh, g, chip, true, true, false, wrong);
    step(sh, g, chip, false, false, true, wrong);
    step(sh, g, drive::AWAY, false, false, false, wrong);
    // The card's tiles follow home's: back, the pencil, then the faces.
    let face = drive::tile(g, home + 2 + index);
    step(sh, g, face, true, true, false, wrong);
    step(sh, g, face, false, false, true, wrong);
    for k in 4 { step(sh, g, drive::AWAY, false, false, false, wrong); }
    print(what, ": playing ", sh.players.playing, ", the board ", sh.out.layout.n, " squares a side, frames out of step ", wrong);
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    var ps = players::Players {};
    sh.prefs = players::load(ps, folder(), true);
    sh.players = ps;
    sh.prefs.first_start_done = true;
    var none: players::Name = [];
    shell::add_player(sh, 2, none);
    sh.prefs.first_start_done = true;
    sh.prefs.variant = rules::RUSSIAN;
    sh.game = game::new(rules::RUSSIAN);
    sh.player_card = player_card::PlayerCard {};
    drive::idle(sh, g, tick());
    print("the second player: the board ", sh.out.layout.n, " squares a side");
    switch_to(sh, g, 0, "to the first");
    switch_to(sh, g, 1, "back to the second");
}
