// Draughts holding both renderers, gfx and goose-ngfx, one chosen when it starts
// (backend.goose, in place of src/app/backend.goose). Built by scripts/ngfx.py, which
// makes what build/ngfx/ holds.

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
