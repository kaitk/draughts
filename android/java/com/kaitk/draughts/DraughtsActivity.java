package com.kaitk.draughts;

import android.content.res.TypedArray;
import android.os.Build;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
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
// It also keeps the launch on the theme's background until the program's first frame is
// on screen (task 028). SDL draws into a SurfaceView, whose hole in the window shows
// black until SDL presents, and Android removes its splash at the window's first draw,
// before that. So a view in that colour covers the whole window, and on Android 12+ the
// splash, the icon on that colour, is held too; both go when the program calls
// firstFrame() (app/launch.c). Home's way out closes it, card and all, through
// closeApp().
//
// The system's back reaches the program as SDL's back key (AC Back), which goes back a
// screen (shell::back). Up to Android 12 the key comes through SDL's own key handling.
// From Android 13 the manifest opts into back callbacks, which Android 16 does anyway for
// an app targeting it, and the key is no longer dispatched; the callback below hands
// it to SDL instead. On home's menu the program gives it back through leaveApp().
public class DraughtsActivity extends SDLActivity {
    // Lifts them anyway if the program never reports a frame, rather than stay covered.
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
        if (Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    OnBackInvokedDispatcher.PRIORITY_DEFAULT, new OnBackInvokedCallback() {
                        @Override
                        public void onBackInvoked() {
                            SDLActivity.onNativeKeyDown(KeyEvent.KEYCODE_BACK);
                            SDLActivity.onNativeKeyUp(KeyEvent.KEYCODE_BACK);
                        }
                    });
        }
    }

    // From the program's thread, once, after its first frame is presented.
    public void firstFrame() {
        runOnUiThread(show);
    }

    // From the program's thread, as it returns after home's way out (app/launch.c): ends
    // the activity and takes its card out of recents, where SDL's own finish() would leave
    // a card showing home as if the app still ran. Called here rather than posted, as SDL
    // calls finish() from this thread too, so the activity is finishing by the time SDL
    // looks and SDL leaves it. The next start is a fresh process (SDLActivity.onCreate
    // exits one whose activity was created before), which restores the game.
    public void closeApp() {
        finishAndRemoveTask();
    }

    // From the program's thread, on the system's back at home's menu (app/launch.c): puts
    // the app in the background, the activity and the game kept, as the system's back
    // does for a launcher's root activity. onBackPressed, which SDL's own back would run,
    // finished the activity and removed its card on Android 17 (the Pixel 7a).
    public void leaveApp() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                moveTaskToBack(true);
            }
        });
    }
}
