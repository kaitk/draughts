/* The app's entry on iOS. UIKit must own the main thread, so main hands it to
   SDL_RunApp, which starts UIApplicationMain and, once the app has launched, calls the
   Goose program's main (compiled as SDL_main, ios/CMakeLists.txt) on the same thread.
   SDL runs UIKit's run loop from inside the program's event polling. */
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

int SDL_main(int argc, char *argv[]);

int main(int argc, char *argv[]) { return SDL_RunApp(argc, argv, SDL_main, NULL); }
