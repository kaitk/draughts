# The iOS native part: one executable for the app bundle, holding a Goose program's C
# (GOOSE_PROGRAM_C, from `goose -o`), the Goose runtime (GOOSE_RUNTIME_C, from `goose
# --emit-runtime`), goose_gfx's gfx, ui, and audio layers, and SDL, linked statically as
# goose_gfx's own CMakeLists links it. scripts/ios.py configures this for the simulator
# or a device and makes the bundle around the executable.

cmake_minimum_required(VERSION 3.20)
project(draughts_ios C OBJC)

set(GOOSE_PROGRAM_C "" CACHE FILEPATH "The program's C, from goose -o")
set(GOOSE_RUNTIME_C "" CACHE FILEPATH "The Goose runtime's C, from goose --emit-runtime")
# The program's own C and its include directories, from its .build sidecar.
set(GOOSE_PROGRAM_SOURCES "" CACHE STRING "The sidecar's c_sources")
set(GOOSE_PROGRAM_INCLUDE "" CACHE STRING "The sidecar's c_include")
set(GOOSE_GFX "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/goose_gfx")
# goose_gfx's src/ with patches/goose_gfx applied (scripts/ios.py makes the copy).
set(GOOSE_GFX_SRC "${GOOSE_GFX}/src" CACHE PATH "goose_gfx's C layers")
# SDL with patches/SDL applied (scripts/ios.py makes the copy).
set(SDL_SRC "${GOOSE_GFX}/third_party/SDL" CACHE PATH "SDL's sources")

# --- SDL, static, configured as goose_gfx configures it ----------------------------------
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_CAMERA OFF CACHE BOOL "" FORCE)
set(SDL_RENDER OFF CACHE BOOL "" FORCE)
set(SDL_OPENGL OFF CACHE BOOL "" FORCE)
set(SDL_OPENGLES OFF CACHE BOOL "" FORCE)
# No HIDAPI: on iOS it links CoreBluetooth, and App Store Connect refuses a binary that
# references Bluetooth without a purpose string (NSBluetoothAlwaysUsageDescription). The
# app opens no joystick, and a Kids app asks for no Bluetooth (task 046).
set(SDL_HIDAPI OFF CACHE BOOL "" FORCE)
add_subdirectory("${SDL_SRC}" SDL EXCLUDE_FROM_ALL)

# --- the program -------------------------------------------------------------------------
add_executable(main
    ${GOOSE_PROGRAM_C}
    ${GOOSE_RUNTIME_C}
    ${GOOSE_PROGRAM_SOURCES}
    main.c
    ${GOOSE_GFX_SRC}/gfx/gfx_device.c
    ${GOOSE_GFX_SRC}/gfx/gfx_resources.c
    ${GOOSE_GFX_SRC}/gfx/gfx_pipeline.c
    ${GOOSE_GFX_SRC}/gfx/gfx_draw.c
    ${GOOSE_GFX_SRC}/audio/audio.c
    ${GOOSE_GFX_SRC}/ui/ui_nuklear.c
    ${GOOSE_GFX_SRC}/ui/ui_core.c
    ${GOOSE_GFX_SRC}/ui/ui_font.c
    ${GOOSE_GFX_SRC}/ui/ui_window.c
    ${GOOSE_GFX_SRC}/ui/ui_widget.c
    ${GOOSE_GFX_SRC}/ui/ui_style.c
    ${GOOSE_GFX_SRC}/ui/ui_draw.c
)
set_target_properties(main PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED ON MACOSX_BUNDLE OFF)
target_include_directories(main PRIVATE "${GOOSE_GFX}/third_party/nuklear" ${GOOSE_PROGRAM_INCLUDE})
target_link_libraries(main PRIVATE SDL3::SDL3-static)
# main.c's main hands UIKit the thread and SDL calls the program back as SDL_main; the
# Goose program's C defines main.
set_source_files_properties(${GOOSE_PROGRAM_C} PROPERTIES COMPILE_DEFINITIONS "main=SDL_main"
                            COMPILE_OPTIONS "-w")
# The generated C warns of what Goose has checked already, as goose build compiles it.
set_source_files_properties(${GOOSE_RUNTIME_C} PROPERTIES COMPILE_OPTIONS "-w")
set_source_files_properties(${GOOSE_GFX_SRC}/ui/ui_nuklear.c PROPERTIES COMPILE_OPTIONS "-w")
