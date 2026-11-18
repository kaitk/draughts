// Draughts holding both renderers, gfx and goose-ngfx, one chosen when it starts
// (src/ngfx/backend.goose, in place of src/gfx/backend.goose). Built by scripts/ngfx.py,
// which makes what build/ngfx/ holds.

import ngfx from "../../build/ngfx/goose-ngfx";
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
import gpu_ngfx from "../ngfx";
import gpu_ngfx.backend;

fn main() { run(); }
