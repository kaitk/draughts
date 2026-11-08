package com.kaitk.draughts;

import android.content.res.TypedArray;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.window.SplashScreen;
import android.window.SplashScreenView;

import org.libsdl.app.SDLActivity;

// SDL's activity, with development flags for the program: the intent's "args" extra,
// split at spaces, as the Mac's command line would give them (docs/development.md).
//
//   adb shell am start -S -n com.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"
//
// -S stops it first: a start that finds it running (singleInstance) only brings it back,
// with the flags it started with.
//
// It also keeps the launch on the theme's navy until the program's first frame is on
// screen (task 028). SDL draws into a SurfaceView, whose hole in the window shows black
// until SDL presents, and Android removes its splash at the window's first draw, before
// that. So a navy view covers the whole window, and on Android 12+ the splash, the icon
// on navy, is held too; both go when the program calls firstFrame() (app/launch.c).
public class DraughtsActivity extends SDLActivity {
    // Lifts them anyway if the program never reports a frame, rather than stay navy.
    private static final long COVER_MAX_MS = 3000;

    private View cover;
    private View splash;            // a SplashScreenView, API 31+
    private boolean shown;          // the first frame is on screen
    private final Runnable show = new Runnable() {
        @Override
        public void run() {
            shown = true;
            if (splash != null) {
                ((SplashScreenView) splash).remove();
                splash = null;
            }
            if (cover != null) {
                cover.setVisibility(View.GONE);
                cover = null;
            }
        }
    };

    @Override
    protected String[] getArguments() {
        String args = getIntent() != null ? getIntent().getStringExtra("args") : null;
        if (args == null || args.trim().isEmpty()) {
            return new String[0];
        }
        return args.trim().split("\\s+");
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (mLayout == null) {
            return;                 // SDL's libraries didn't load; it shows an error
        }
        cover = new View(this);
        TypedArray a = getTheme().obtainStyledAttributes(
                new int[] { android.R.attr.windowBackground });
        cover.setBackground(a.getDrawable(0));
        a.recycle();
        // On the decor rather than SDL's layout, so it spans the bars' area as well.
        ViewGroup decor = (ViewGroup) getWindow().getDecorView();
        int fill = FrameLayout.LayoutParams.MATCH_PARENT;
        decor.addView(cover, new FrameLayout.LayoutParams(fill, fill));
        if (Build.VERSION.SDK_INT >= 31) {
            // Android hands its splash over at the window's first draw instead of fading
            // it out; it stays until shown.
            SplashScreen screen = getSplashScreen();
            screen.setOnExitAnimationListener(new SplashScreen.OnExitAnimationListener() {
                @Override
                public void onSplashScreenExit(SplashScreenView view) {
                    splash = view;
                    if (shown) {
                        show.run();
                    }
                }
            });
        }
        mLayout.postDelayed(show, COVER_MAX_MS);
    }

    // From the program's thread, once, after its first frame is presented.
    public void firstFrame() {
        runOnUiThread(show);
    }
}
