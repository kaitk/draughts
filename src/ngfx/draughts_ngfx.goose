// Draughts holding both renderers, gfx and goose-ngfx (NoGraphicsAPI), one chosen when it
// starts (backend.goose, task 073): the program (src/app/app.goose) and gfx's backend as
// the gfx build has them, goose-ngfx's backend beside gfx's, and this build's backend.goose
// in place of src/app/backend.goose. Built by scripts/ngfx.py, which first links goose-ngfx
// at build/ngfx/goose-ngfx, writes build/ngfx/draughts_version.h, and compiles the shaders
// into build/ngfx/blobs/.

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
import app from "../app";
import .nx;
import .gpu_ngfx;
import .draw_ngfx;
import .scene_ngfx;
import .widgets_ngfx;
import .host_ngfx;
import .render3d_ngfx;
import .backend;

fn main() { run(); }
