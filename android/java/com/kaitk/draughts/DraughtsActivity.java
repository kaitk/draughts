package com.kaitk.draughts;

import org.libsdl.app.SDLActivity;

// SDL's activity, with development flags for the program: the intent's "args" extra,
// split at spaces, as the Mac's command line would give them (docs/development.md).
//
//   adb shell am start -n com.kaitk.draughts/.DraughtsActivity --es args "--theme sea"
public class DraughtsActivity extends SDLActivity {
    @Override
    protected String[] getArguments() {
        String args = getIntent() != null ? getIntent().getStringExtra("args") : null;
        if (args == null || args.trim().isEmpty()) {
            return new String[0];
        }
        return args.trim().split("\\s+");
    }
}
