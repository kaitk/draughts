// Draughts on gfx alone, the build Android and Linux ship: the app (src/app/) on gfx's
// backend (src/gfx/backend.goose). The other platforms ship draughts_ngfx.goose beside it,
// the same program holding goose-ngfx too, and build this one with --gfx-only.

import rules from "../rules";
import board from "../board";
import strings from "../../strings";
import gui from "../gui";
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import puzzles from "../puzzles";
import badges from "../badges";
import model3d from "../model3d";
import render3d from "../render3d";
import sound from "../sound";
import app from "../app";
import gpu from "../gfx";
import gpu.backend;

fn main() { run(); }
