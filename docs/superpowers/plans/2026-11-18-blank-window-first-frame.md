# Blank Window on Launch — First-Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The window is created at its final size, position, and frameless style on both Linux and Windows, and only becomes visible with the first frame already rendered, so the app never opens blank.

**Architecture:** Move all startup window geometry and visibility out of Dart into the two runners, and leave Dart setting only the versioned title, the taskbar icon, and the transparent background colour. Linux: `my_application.cc` owns size, minimum size, centering, and first-frame show. Windows: `main.cpp` owns centered size at creation, `win32_window.cpp` owns the frameless style and the minimum size, first-frame show stays.

**Tech Stack:** Dart/Flutter 3.50.0, nativeapi/window_manager 0.6/0.7 (Dart side only), GTK3 C++ (Linux runner), Win32 C++ (Windows runner).

**Spec:** `docs/superpowers/specs/2026-11-18-blank-window-first-frame-design.md`

## Global Constraints

- The app runs on Windows and Linux only. There is no macOS path to preserve.
- Initial size is 1024x640, minimum size is 720x520, on both platforms. Copy these values exactly.
- No `// ignore:` suppressions, no analysis_options exclusions, no weakening a test.
- Git commit messages must not contain `;` (the BVPD command filter rejects it).
- Edits go through the patch-script technique (stage a Python script in /tmp, upload it into the project root via BVPD `write_file`, run it with `run_command` `python3`, delete it afterwards). Never re-run a patch script that aborted mid-run; write a second script with only the remaining edits.
- No new unit tests: the defect is a startup race between the runners and the engine's first frame; no widget test can observe it (the spec says so). Verification is `flutter analyze` + the existing suite + repeated launches + the CI Windows build.
- Tasks 1-3 are one atomic behaviour change: commit per task, but ship only together. Task 1 alone would leave the Linux window at the runner's 1200x800 default and the Windows window with a native title bar.
- `flutter analyze` baseline: the only accepted output on touched Dart files is the pre-existing `deprecated_member_use` info for the `package:flutter/material.dart` import. Zero new issues.
- Verification is split by platform: Linux (`flutter analyze`, `flutter build linux`, repeated launches) runs on Ponta's Fedora machine once Flutter 3.50.0 is reinstalled; Windows is verified by the CI `build-windows` job plus Ponta launching the artifact, because this VM has no Windows toolchain.

## Review Focus

- A Windows launch where dragging the header, resizing by the edges, maximizing, minimizing, or closing misbehaves after the frameless style moves into the runner — Task 3's manual check must exercise every one of these, because the frameless style is what makes them work.
- A Windows HiDPI monitor where the 720x520 minimum comes out the wrong size — Task 3 must scale the minimum by the window's DPI, and the manual check must include a scaled display if one is available.
- A Linux multi-monitor setup where the window centers on the wrong monitor — Task 2's manual check must confirm the window opens centered on the monitor Ponta expects.
- A launch where the title bar shows the unversioned `Ponta DevStack` instead of `Ponta DevStack v<version>` — Dart still sets the versioned title, and the manual check on both platforms must confirm it.
- An auto-start launch (`--minimized`) that pops the window over the user's work — Tasks 2 and 3 must keep the minimized behaviour owned by the runners, and the manual check must include one minimized launch.

---

### Task 1: Dart — strip the startup window block to title, icon, background only

**Files:**
- Modify: `lib/main.dart` (the `whenCurrentWindow` callback in `main()`, currently ~lines 76-111)
- Test: none new (see Global Constraints); the existing suite is the regression check

**Interfaces:**
- Consumes: `whenCurrentWindow` from `core/services/window_api.dart`, `Window` from `package:window_manager/window_manager.dart`, `Application` from `package:nativeapi/nativeapi.dart`
- Produces: the startup callback contract the runners rely on — Dart sets nothing that changes size, position, style, or visibility

- [ ] **Step 1: Rewrite the `whenCurrentWindow` callback in `lib/main.dart`**

Delete from the callback: `window.titleBarStyle`, `window.isWindowControlButtonsVisible`, `window.setSize`, `window.minimumSize`, `window.center`, `window.show`, `window.focus`, and the `if (!isMinimized)` guard around them. Keep exactly: `window.title = title;`, `window.backgroundColor = Colors.transparent.toNative();`, `Application.instance.setIcon(_resolveIconPath());`. Delete the now-unused `final isMinimized = args.contains('--minimized');` local. Rewrite the callback's comment block to state the division: the runners own geometry, style, and visibility; Dart sets title, background colour, and icon only. Keep `whenCurrentWindow` itself and the Linux comment about the runner creating the window undecorated where it still applies.

- [ ] **Step 2: Run `flutter analyze` on the touched file**

Run: `flutter analyze lib/main.dart`
Expected: only the pre-existing `deprecated_member_use` info for the `package:flutter/material.dart` import. No new issues, no unused-import hints.

- [ ] **Step 3: Run the existing suite**

Run: `flutter test`
Expected: the suite result is identical to the pre-change baseline (same passing count, same pre-existing failures from the stale-tests cleanup, no new failures).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "fix(window): Dart no longer sizes or shows the window at startup"
```

### Task 2: Linux runner — final geometry at creation, show on first frame

**Files:**
- Modify: `linux/runner/my_application.cc` (`my_application_activate`, currently `gtk_window_set_default_size(window, 1200, 800)`)

**Interfaces:**
- Consumes: nothing from Task 1 (the runners and Dart change independently; they land together per Global Constraints)
- Produces: a Linux window created at 1024x640, centered, minimum 720x520, shown only on the first frame

- [ ] **Step 1: Set the final geometry in `my_application_activate`**

Change `gtk_window_set_default_size(window, 1200, 800)` to `(window, 1024, 640)`. Add `gtk_window_set_position(window, GTK_WIN_POS_CENTER);`. Add a minimum size via geometry hints: a `GdkGeometry` with `min_width = 720` and `min_height = 520`, applied with `gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);`. Leave untouched: the undecorated window, the RGBA visual and `window_draw_cb`, the transparent `FlView` background, and `first_frame_cb` showing the window on the first frame.

- [ ] **Step 2: Build the Linux bundle**

Run: `flutter build linux --release`
Expected: exit 0.

- [ ] **Step 3: Launch the built app repeatedly and check**

Run the built binary several times in a row (at least 5 launches, including at least one while the machine is busy). Expected: every launch shows content immediately with no blank window; the window opens at 1024x640 centered; the title reads `Ponta DevStack v<version>`; the window cannot be resized below 720x520. One launch with `--minimized` must stay hidden in the tray.

- [ ] **Step 4: Commit**

```bash
git add linux/runner/my_application.cc
git commit -m "fix(linux): runner creates the window at its final size and shows it on the first frame"
```

### Task 3: Windows runner — centered final size, frameless from creation, minimum size

**Files:**
- Modify: `windows/runner/main.cpp` (currently `Win32Window::Point origin(10, 10); Win32Window::Size size(1280, 720);`)
- Modify: `windows/runner/win32_window.cpp` (`Win32Window::Create`, `Win32Window::MessageHandler`)

**Interfaces:**
- Consumes: nothing from Tasks 1-2 (independent runner change; lands together per Global Constraints)
- Produces: a Windows window created at 1024x640 centered and frameless, minimum 720x520, shown only on the first frame

- [ ] **Step 1: Create the window centered at 1024x640 in `main.cpp`**

Change the size to 1024x640. Compute the origin so the window is centered on the primary monitor's work area, in logical pixels (so `Win32Window::Create` applies its DPI scaling exactly as today). Leave untouched: the single-instance mutex block, the `--minimized` handling (`set_show_on_first_frame(false)`), and `SetQuitOnClose(true)`.

- [ ] **Step 2: Make the window frameless from creation in `win32_window.cpp`**

In `Win32Window::Create`, replace the `WS_OVERLAPPEDWINDOW` style with a frameless style that keeps resize borders and minimize/maximize boxes (the builder picks the exact flags). Add a `WM_NCCALCSIZE` case in `MessageHandler` so the client area covers the whole window.

- [ ] **Step 3: Enforce the minimum size in `win32_window.cpp`**

Add a `WM_GETMINMAXINFO` case in `MessageHandler` enforcing a 720x520 minimum, scaled by the window's DPI (`GetDpiForWindow`, divided by 96.0). Leave untouched: `FlutterWindow::OnCreate` (the `FlutterViewController` sizing comment still applies — the client area is final at creation now), `SetNextFrameCallback` showing the window on the first frame, and `ForceRedraw()`.

- [ ] **Step 4: Verify via the CI Windows build**

Push the commit and watch the CI `build-windows` job. Expected: green. (There is no Windows toolchain on this VM, so the build itself is the compile check.)

- [ ] **Step 5: Launch the Windows artifact and check every window behaviour**

Ponta launches the built Windows app several times (at least 5, including one while the machine is busy). Expected: no blank window on any launch; the window opens at 1024x640 centered with no native title bar; the title reads `Ponta DevStack v<version>`; dragging the header moves the window; all four edges and corners resize it; maximize fills the work area without covering the taskbar; minimize, close, and the tray restore all work; the window cannot be resized below 720x520. One launch with `--minimized` must stay hidden in the tray.

- [ ] **Step 6: Commit**

```bash
git add windows/runner/main.cpp windows/runner/win32_window.cpp
git commit -m "fix(windows): runner creates the window centered, frameless, at its final size"
```

### Task 4: Final verification and commit the docs

**Files:**
- Modify: none
- Test: the whole suite plus analyze, as below

**Interfaces:**
- Consumes: Tasks 1-3 committed
- Produces: a green suite, a clean analyze, and the committed design + plan docs

- [ ] **Step 1: Run the full suite and analyze**

Run: `flutter test` then `flutter analyze`
Expected: the suite result matches the pre-change baseline (same passing count, same pre-existing stale-test failures, no new failures); analyze reports only the pre-existing infos.

- [ ] **Step 2: Confirm the manual launch checks from Tasks 2 and 3 are recorded**

Both platforms' launch checklists (no blank window, correct size and centering, versioned title, minimum size, minimized launch, and on Windows the drag/resize/maximize checks) must have passed and be noted in the ledger before this commit.

- [ ] **Step 3: Commit the design and plan docs**

```bash
git add docs/superpowers/specs/2026-11-18-blank-window-first-frame-design.md docs/superpowers/plans/2026-11-18-blank-window-first-frame.md
git commit -m "docs: design and plan for blank window on launch"
```
