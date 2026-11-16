// Draughts on gfx alone, the build every platform ships; app.goose is the program.
// scripts/mac.py builds it, scripts/ngfx.py builds src/ngfx/draughts_ngfx.goose, the same
// program holding goose-ngfx too (docs/development.md).

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
import .app;
import .backend;

fn main() { run(); }
