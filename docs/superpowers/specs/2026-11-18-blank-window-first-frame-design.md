# Blank window on launch — first-frame design

Date: 2026-11-18. Status: awaiting Ponta's approval.
Fixes: the app sometimes opens as an empty window and only shows content
after the window is resized. Picked approach: Cách 1 (runner owns the
window on both platforms). Ponta corrected 2026-11-18: the app runs on
Windows and Linux only, no macOS — so there is no macOS path to preserve.

## Why

Before the window_manager 0.6 migration (commit 2a64f55, 2026-11-09),
startup used `windowManager.waitUntilReadyToShow`: the window was only
shown after the first frame was ready. The migration replaced it with
`whenCurrentWindow`, which fires as soon as the window is discoverable —
on Linux immediately in `main()`, before `runApp` and before the first
frame. Its callback then resizes the window (Linux 1200x800 -> 1024x640,
Windows 1280x720 -> 1024x640), centers it, and shows it, all before the
first frame is presented. A resize between surface creation and first
present can make the embedder drop the first frame, so the window stays
blank (only the runner's background) until a manual resize forces a fresh
frame. It is a timing race, which is why it only happens sometimes.
Evidence: `git show 2a64f55 -- lib/main.dart`; `Window.show()` maps to
native `native_window_show` (nativeapi 0.6.1); the Linux runner already
shows only on first frame (`first_frame_cb`) and the Windows runner only
on first frame (`SetNextFrameCallback` -> `Show()`); the tray
`_showWindow` is post-startup only; `VirtualWindowFrameInit` is a widget
builder and never shows the window. The same failure mode on Windows is
documented by RustDesk's white-window fix (a resize between surface
creation and first present rejects the first frame).

## Goals

- The window is created at its final size, position, and style, and only
  becomes visible with the first frame already rendered — on both Linux
  and Windows.
- No visible jump, flash, or title-bar flash at startup on either
  platform.
- `--minimized` (auto-start to tray) keeps working on both platforms.
- The tray restore path (`window_service.dart` `_showWindow`) is untouched.

## Non-goals

- No change to the Flutter widget tree, the theme, or any page.
- No change to window behaviour after startup (drag, resize, maximize,
  minimize, close, tray).
- No macOS work: the app does not target macOS.

## Anti-goals

- Do not "fix" it by forcing a repaint, nudging the size, or retrying
  show after a delay. Those treat the symptom; the race stays.
- Do not keep any Dart-side size/show call at startup "just in case".

## Approaches

- **Cách 1 (picked): runner owns geometry + visibility on both
  platforms.** Linux: `my_application.cc` creates the window at
  1024x640, centered, with a 720x520 minimum size, and shows it on the
  first frame (already). Windows: `main.cpp` creates the window at
  1024x640 centered on the primary monitor; `win32_window.cpp` creates
  it frameless from the start and enforces the 720x520 minimum via
  `WM_GETMINMAXINFO`; first-frame show stays. Dart (`lib/main.dart`)
  keeps only what is not geometry or visibility: the versioned title
  and the taskbar icon, plus the transparent background colour (a paint
  property, not a resize). The `whenCurrentWindow` startup block loses
  `setSize`, `minimumSize`, `center`, `show`, `focus`, and (Windows)
  `titleBarStyle` / `isWindowControlButtonsVisible`.
- **Cách 2 (not picked): defer Dart's setup until after the first
  frame.** Keeps the setup in Dart but runs it from a post-frame
  callback. The window would appear at the runner's default size and
  then jump to 1024x640, and there would still be two places showing
  the window.
- **Cách 3 (dropped): only remove the early `show()`.** The resize
  before the first frame stays, so the frame can still be dropped; and
  on Windows the caption removal after creation is itself a client-area
  resize. Partial fix.

## What the builder decides

- The exact frameless style flags and `WM_NCCALCSIZE` handling in
  `win32_window.cpp` (must keep resize borders, maximize, and the
  `VirtualWindowFrame` drag/resize behaviour working), and the exact
  DPI-aware minimum-size math in `WM_GETMINMAXINFO`.
- The exact centered-origin computation in `main.cpp` (primary monitor
  work area, logical pixels, letting `Win32Window::Create` apply its
  DPI scaling as today).
- The exact geometry-hint calls in `my_application.cc`.
- Test/verification split: Linux (`flutter analyze`, `flutter build
  linux`, repeated launches) runs on Ponta's Fedora machine once
  Flutter 3.50.0 is reinstalled; Windows is verified by the CI
  `build-windows` job plus Ponta launching the artifact, because this
  VM has no Windows toolchain. A widget test cannot cover this: the
  race lives in the runners, not the widget tree.
