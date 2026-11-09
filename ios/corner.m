/* The window control's corner on iPadOS 26 (its three dots at a window's top left), for
   the layout to keep clear of (gui::Gui's corner; task 050). UIKit's safe area doesn't
   leave it out; its corner-adapted safe area does, the left inset grown by the control
   when adapting across and the top inset when adapting down. The difference from the
   plain safe area says whether there is a control at all: none full screen without
   windowing, on an iPhone, or before iOS 26, whose windows had no corner control.
   Called from display.c each frame, on the main thread, where the program runs. */
#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>

/* Writes how far the control reaches right and down from the window's top left, in
   points, into out[0] and out[1]; 0 and 0 with none. */
void draughts_ios_corner(SDL_Window *window, float *out) {
    out[0] = 0.0f;
    out[1] = 0.0f;
    if (@available(iOS 26.0, *)) {
        UIWindow *w = (__bridge UIWindow *)SDL_GetPointerProperty(SDL_GetWindowProperties(window),
                                                                  SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, NULL);
        UIView *v = w.rootViewController.view ? w.rootViewController.view : w;
        if (!v) return;
        UIEdgeInsets plain = v.safeAreaInsets;
        UIEdgeInsets across = [v edgeInsetsForLayoutRegion:
            [UIViewLayoutRegion safeAreaLayoutRegionWithCornerAdaptation:UIViewLayoutRegionAdaptivityAxisHorizontal]];
        UIEdgeInsets down = [v edgeInsetsForLayoutRegion:
            [UIViewLayoutRegion safeAreaLayoutRegionWithCornerAdaptation:UIViewLayoutRegionAdaptivityAxisVertical]];
        if (across.left <= plain.left + 0.5 && down.top <= plain.top + 0.5) return;
        out[0] = (float)(across.left > plain.left ? across.left : plain.left);
        out[1] = (float)(down.top > plain.top ? down.top : plain.top);
    }
}
