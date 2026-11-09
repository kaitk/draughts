// The faces baked with only the characters they draw (shell::face_chars, rendering.md
// "Fonts"): the title holds the app's name in every language, as home's wordmark reads it
// through strings::use and get, and the figures hold every time a clock shows, up to 100
// minutes, and every digit (a tabular cell is the widest digit's). A character drawn in
// either face that the face doesn't hold would show as '?' on screen, so it fails here:
// a translation whose name has a new letter needs nothing more than its file. A word
// with letters the title lacks shows the check finds them; the other faces hold all.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";

// The characters of s the set lacks, as drawn: one a face never holds is drawn as '?'.
fn missing(set: gui::Chars&, s: const u8[:], out: u8[>..]&) -> i64 {
    var n = 0;
    var i = 0;
    while i < s.len {
        let c, next = gui::next_char(s, i);
        let drawn = if gui::glyph_index(c) >= 0 { c } else { '?' };
        if !gui::holds(set, drawn) {
            out.append(s[i..next]);
            n++;
        }
        i = next;
    }
    return n;
}

fn chars(set: gui::Chars&) -> u8[>..] {
    var out: u8[>..] = [];
    for c in set {
        if c < 0x80 { out.push(c as u8); } else { format(out, "U+", c); }
    }
    return out;
}

fn main() {
    var bad = 0;
    var title: gui::Chars = [];
    assert(shell::face_chars(gui::TITLE, title));
    print("title: ", chars(title));
    for code, lang in strings::LANGUAGES {
        strings::use(lang);
        let name = strings::get(strings::APP_NAME);
        var out: u8[>..] = [];
        let n = missing(title, name, out);
        print(code, ": ", name, ", ", n, " missing ", out);
        bad += n;
    }
    strings::use(strings::EN);

    var figures: gui::Chars = [];
    assert(shell::face_chars(gui::FIGURES, figures));
    print("figures: ", chars(figures));
    var times = 0;
    var lacking = 0;
    for seconds in 6000 {
        var t: u8[..8] = [];
        clock::text(seconds, t);
        var out: u8[>..] = [];
        let n = missing(figures, t, out);
        if n > 0 && lacking < 3 { print("  ", t, " lacks ", out); }
        lacking += n;
        times++;
    }
    var out: u8[>..] = [];
    lacking += missing(figures, "0123456789", out);
    print(times, " clock times and every digit, ", lacking, " missing");
    bad += lacking;

    var shown: u8[>..] = [];
    print("Dame in the title: ", missing(title, "Dame", shown), " missing ", shown);

    var set: gui::Chars = [];
    for face in [gui::LABEL, gui::HEADING, gui::BODY, gui::SMALL] {
        if shell::face_chars(face, set) {
            print("face ", face, " holds only some");
            bad++;
        }
    }
    print(if bad == 0 { "ok" } else { "FAILED" });
    if bad > 0 { exit(1); }
}
