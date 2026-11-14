// Draughts on gfx alone, the build every platform ships (app.goose is the program). The
// thread needs a build: on the Mac, from src/app/, `goose build -o ../../build/draughts
// draughts.goose`, or scripts/mac.py src/app/draughts.goose, then
//
//   ../../build/draughts                          at home
//   ../../build/draughts --screen game            the game screen; --fen and --tap open it too
//   ../../build/draughts --fen W:Wc3,Kh6:Be5 --tap c3 --frames 30   taps, then saves draughts.png
//   scripts/android.py src/app/draughts.goose --run   on a device over USB (docs/development.md)
//   scripts/ios.py src/app/draughts.goose --run   in the iOS simulator
//
// scripts/ngfx.py builds src/ngfx/draughts_ngfx.goose, the same program holding goose-ngfx
// too.

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
import .app;
import .backend;

fn main() { run(); }
