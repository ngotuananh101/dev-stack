# Tray restore shows a blank window - Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

Goal: Restoring the app from the tray presents a fresh frame, so the window never comes back blank.

Architecture: One Dart change: WindowService._showWindow schedules a Flutter frame after showing the window. No runner, widget, or service changes. Verification is Ponta's manual hide/restore on the Linux release bundle, because the defect lives at the native/framework boundary and no widget test can observe it.

Tech Stack: Dart/Flutter 3.50.0, nativeapi 0.6.1 (window_manager 0.7.0 re-export), Riverpod.

Spec: docs/superpowers/specs/2026-11-18-tray-restore-blank-design.md

## Global Constraints

- Windows + Linux only, no macOS.
- No geometry change: no setSize, no size nudge, no center/move call.
- No new dependencies.
- No // ignore: suppressions, no analysis_options exclusions, no weakening a test.
- Commit messages must not contain ;.
- Patch-script technique for edits.
- TDD exception (spec-pinned): no unit test - the defect is a missing frame after a native show, unobservable in a widget test; verification is analyze + suite + Ponta's manual hide/restore.
- Analyze baseline: exactly the 1 documented implementation_imports info at lib/main.dart:18:8; zero new issues.
- Full suite must stay green (1213 passed / 3 skipped / 0 failed).

## Review Focus

1. The scheduled frame renders before the new surface exists (map still in flight) - the window still blanks sometimes. Task 2's 10x hide/restore catches it; the fallback is a deferred schedule, decided then, not now.
2. _showWindow runs while the window is already visible (tray click with the window open) - the extra frame must be harmless, and the null-window early return must stay.
3. Restore after a --minimized launch: the first show after an auto-start launch must also get a frame - same _showWindow path; Task 2 includes one such launch.
4. Second launch while hidden (runner activation branch) shows the window with no Dart frame request - it may still blank; Task 2 records the result, a blank there is a follow-up, not a failure of this fix.
5. The Windows restore path runs the same Dart code but the bug was never reported there - Task 2's Windows check is opportunistic; no Windows-specific code in this plan.

---

### Task 1: Schedule a frame after showing the window

Files:
- Modify: lib/core/services/window_service.dart (_showWindow)
- Test: none (TDD exception - see Global Constraints)

Interfaces:
- Consumes: currentWindow() from lib/core/services/window_api.dart; SchedulerBinding.instance.scheduleFrame() from package:flutter/scheduler.dart.
- Produces: _showWindow shows the window and requests a fresh frame.

- [ ] Step 1: Read the current _showWindow and its imports

- [ ] Step 2: Add the frame request

  After window.show() (and focus()), call SchedulerBinding.instance.scheduleFrame(), with a comment stating why (a hidden window's surface is gone on Wayland; without a fresh frame the window shows the runner's #020617 background until something else - e.g. a resize - forces a frame). Import package:flutter/scheduler.dart if not already imported. Keep the existing null-window early return and the isMinimized restore.

- [ ] Step 3: Run flutter analyze on the file

  Run: flutter analyze lib/core/services/window_service.dart
  Expected: No issues found!

- [ ] Step 4: Run the full suite

  Run: flutter test (via the summary script that prints only failures and the last line)
  Expected: +1213 ~3 -0, All tests passed!

- [ ] Step 5: Commit

  git add lib/core/services/window_service.dart
  git commit -m "fix(window): request a frame when restoring from the tray so the window never comes back blank"

### Task 2: Build + Ponta verifies the restore

Files:
- None (verification only)

- [ ] Step 1: Build the Linux release bundle

  Run: flutter build linux --release
  Expected: exit 0, bundle at build/linux/x64/release/bundle/dev_stack.

- [ ] Step 2: Ponta launches the bundle and hides/restores 10 times from the tray icon (including one --minimized launch + restore); expect no blank in any of them. She also hides to tray, then launches the app again from the desktop icon, and records whether that restore blanks (follow-up if so, not a failure of this fix).

- [ ] Step 3: Record the per-item results in the ledger - if any restore blanks, stop: the fallback (deferred schedule) is designed then, not shipped now.

### Task 3: Docs + finish

- [ ] Step 1: Verify the full suite + analyze match baseline (same expectations as Task 1 Steps 3-4).

- [ ] Step 2: Commit the design + plan docs

  git add docs/superpowers/specs/2026-11-18-tray-restore-blank-design.md docs/superpowers/plans/2026-11-18-tray-restore-blank.md
  git commit -m "docs: design and plan for tray restore blank window"

- [ ] Step 3: Append the completion lines to the ledger and delete the plan workspace dir.
