// Draughts on gfx alone, the build every platform ships: the app (src/app/) on gfx's
// backend (src/gfx/backend.goose). scripts/mac.py builds it, scripts/ngfx.py builds
// draughts_ngfx.goose beside it, the same program holding goose-ngfx too
// (docs/development.md).

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
