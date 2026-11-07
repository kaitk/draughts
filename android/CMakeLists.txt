# The Android native part: libSDL3.so and libmain.so, which SDL's stock SDLActivity loads
# in that order and enters at SDL_main. libmain holds a Goose program's C (GOOSE_PROGRAM_C,
# from `goose -o`), the Goose runtime (GOOSE_RUNTIME_C, from `goose --emit-runtime`), and
# goose_gfx's gfx, ui, and audio layers.
#
# goose_gfx's own CMakeLists links SDL statically. That works on the desktop, but SDL's
# Java glue loads libSDL3.so by name, so here SDL is shared and the layers are compiled
# with the same settings as goose_gfx's CMakeLists. scripts/android.py configures this.

cmake_minimum_required(VERSION 3.20)
project(kabe_android C)

set(GOOSE_PROGRAM_C "" CACHE FILEPATH "The program's C, from goose -o")
set(GOOSE_RUNTIME_C "" CACHE FILEPATH "The Goose runtime's C, from goose --emit-runtime")
set(GOOSE_GFX "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/goose_gfx")
# goose_gfx's src/ with patches/goose_gfx applied (scripts/android.py makes the copy).
set(GOOSE_GFX_SRC "${GOOSE_GFX}/src" CACHE PATH "goose_gfx's C layers")
# SDL with patches/SDL applied (scripts/android.py makes the copy).
set(SDL_SRC "${GOOSE_GFX}/third_party/SDL" CACHE PATH "SDL's sources")

# --- SDL, shared, configured as goose_gfx configures it ---------------------------------
set(SDL_SHARED ON CACHE BOOL "" FORCE)
set(SDL_STATIC OFF CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_CAMERA OFF CACHE BOOL "" FORCE)
set(SDL_RENDER OFF CACHE BOOL "" FORCE)
set(SDL_OPENGL OFF CACHE BOOL "" FORCE)
set(SDL_OPENGLES OFF CACHE BOOL "" FORCE)
add_subdirectory("${SDL_SRC}" SDL EXCLUDE_FROM_ALL)

# --- libmain -----------------------------------------------------------------------------
set(ui_layer_sources
    ${GOOSE_GFX_SRC}/ui/ui_core.c
    ${GOOSE_GFX_SRC}/ui/ui_font.c
    ${GOOSE_GFX_SRC}/ui/ui_window.c
    ${GOOSE_GFX_SRC}/ui/ui_widget.c
    ${GOOSE_GFX_SRC}/ui/ui_style.c
    ${GOOSE_GFX_SRC}/ui/ui_draw.c
)
add_library(main SHARED
    ${GOOSE_PROGRAM_C}
    ${GOOSE_RUNTIME_C}
    stdio_to_logcat.c
    ${GOOSE_GFX_SRC}/gfx/gfx_device.c
    ${GOOSE_GFX_SRC}/gfx/gfx_resources.c
    ${GOOSE_GFX_SRC}/gfx/gfx_pipeline.c
    ${GOOSE_GFX_SRC}/gfx/gfx_draw.c
    ${GOOSE_GFX_SRC}/audio/audio.c
    ${GOOSE_GFX_SRC}/ui/ui_nuklear.c
    ${ui_layer_sources}
)
set_target_properties(main PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED ON)
target_include_directories(main PRIVATE "${GOOSE_GFX}/third_party/nuklear")
target_link_libraries(main PRIVATE SDL3::SDL3-shared android log m)
# SDLActivity calls SDL_main; the Goose program's C defines main.
set_source_files_properties(${GOOSE_PROGRAM_C} PROPERTIES COMPILE_DEFINITIONS "main=SDL_main")
set_source_files_properties(${GOOSE_GFX_SRC}/ui/ui_nuklear.c PROPERTIES COMPILE_OPTIONS "-w")
# 16 KB pages, which Android 15 devices may use and Play requires.
target_link_options(main PRIVATE "-Wl,-z,max-page-size=16384")
