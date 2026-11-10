// The 3D board's camera as data (src/board/rig.goose, task 015's camera buttons): the
// view button cycling the rest angle and the top view, eased over 0.6 s; the showcase's
// drags turning and tipping the camera within their range, its mode off keeping the
// angle, the view button's dot while the board is off its rest angle and its tap easing
// back to rest first; the zoom toggling; and the hot-seat turn, 180° more each time the
// side to move changes, over 0.7 s, the showcase's angle easing back with it, put at once
// the first time. Each line gives the camera at a moment: its angle down, its turn round
// (the showcase's), the board's turn, and the zoom's share.
import std;
import vec;
import math;
import rules from "../../src/rules";
import gui from "../../src/gui";
import board from "../../src/board";

fn r1(x: f32) -> f64 { floor((x as f64) * 10.0 + 0.5) / 10.0 }

fn show(what: const u8[:], r: rig::Rig&, rest: f32, now: f64) {
    let c = rig::camera(r, rest, now);
    print("  ", what, " at ", now, " s: ", r1(c.pitch), "° down, swung ", r1(c.yaw), "°, board turned ", r1(c.turn),
          "°, zoom ", r1(rig::value(r.zoom, now)), if rig::off_rest(r) { ", dot" } else { "" },
          if r.showcase { ", showcase on" } else { "" }, if rig::moving(r, now) { ", moving" } else { "" });
}

// The board faced to `side`, saying when that turned it.
fn face_to(r: rig::Rig&, side: i64, now: f64) {
    if rig::face(r, side, now) { print("  (turns)"); }
}

fn main() {
    let rest: f32 = 52.5;
    var r = rig::Rig {};
    print("the view button, landscape (rest 52.5°):");
    show("at rest", r, rest, 0.0);
    rig::view_tap(r, 1.0);
    show("tapped", r, rest, 1.0);
    show("halfway", r, rest, 1.3);
    show("eased", r, rest, 1.6);
    show("after", r, rest, 5.0);
    rig::view_tap(r, 5.0);
    show("tapped again", r, rest, 5.3);
    show("back at rest", r, rest, 5.6);
    print("portrait's rest 65°, the top view the same 74°:");
    rig::view_tap(r, 6.0);
    show("top", r, 65.0, 7.0);
    rig::view_tap(r, 7.0);
    show("rest", r, 65.0, 8.0);

    print("the showcase:");
    rig::showcase_tap(r);
    show("on", r, rest, 10.0);
    // A drag of 50 dp left and 40 dp down, then far past the range both ways.
    rig::drag(r, float2 { -50.0, 40.0 }, rest, 10.0);
    show("dragged left and down", r, rest, 10.0);
    rig::drag(r, float2 { -500.0, 500.0 }, rest, 10.1);
    show("dragged far left and down", r, rest, 10.1);
    rig::drag(r, float2 { 1000.0, -1000.0 }, rest, 10.2);
    show("dragged far right and up", r, rest, 10.2);
    rig::drag(r, float2 { -60.0, 50.0 }, rest, 10.3);
    show("and back a little", r, rest, 10.3);
    // Through the pointer at 2 pixels a dp: a press, a drag of 20 px right, a release.
    rig::drive(r, float2 { 100.0, 100.0 }, true, true, false, 2.0, rest, 10.4);
    rig::drive(r, float2 { 120.0, 100.0 }, true, false, false, 2.0, rest, 10.45);
    rig::drive(r, float2 { 120.0, 100.0 }, false, false, true, 2.0, rest, 10.5);
    show("dragged 10 dp right by the pointer", r, rest, 10.5);
    rig::showcase_tap(r);
    show("off, the angle kept", r, rest, 11.0);
    show("still kept", r, rest, 20.0);
    rig::view_tap(r, 20.0);
    show("the view tapped: back to rest first", r, rest, 20.3);
    show("at rest", r, rest, 20.6);
    rig::view_tap(r, 21.0);
    show("then the top view", r, rest, 21.6);
    rig::showcase_tap(r);
    rig::drag(r, float2 { 0.0, 100.0 }, rest, 22.0);
    show("in the top view, tipped further", r, rest, 22.0);
    rig::view_tap(r, 22.0);
    show("the view tapped: back to the rest angle", r, rest, 22.6);
    rig::showcase_tap(r);

    print("the zoom:");
    rig::zoom_tap(r, 30.0);
    show("tapped", r, rest, 30.3);
    show("in", r, rest, 30.6);
    rig::zoom_tap(r, 31.0);
    show("out", r, rest, 31.6);

    print("the hot-seat turn:");
    var h = rig::Rig {};
    face_to(h, 1, 0.0);
    show("first frame, black to move: put at once", h, rest, 0.0);
    rig::reset(h);
    face_to(h, 0, 1.0);
    show("a new game, white to move", h, rest, 1.0);
    face_to(h, 0, 2.0);
    show("still white", h, rest, 2.0);
    rig::showcase_tap(h);
    rig::drag(h, float2 { 40.0, -30.0 }, rest, 2.5);
    show("the showcase swung", h, rest, 2.5);
    face_to(h, 1, 3.0);
    show("black to move", h, rest, 3.0);
    show("halfway", h, rest, 3.35);
    show("turned", h, rest, 3.7);
    face_to(h, 1, 4.0);
    show("still black", h, rest, 4.0);
    face_to(h, 0, 5.0);
    show("white again: on round", h, rest, 5.35);
    show("turned", h, rest, 5.7);
    face_to(h, 1, 6.0);
    show("black again, from 0", h, rest, 6.35);
    show("turned", h, rest, 6.7);
}
