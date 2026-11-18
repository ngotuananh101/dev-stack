# Tray restore deferred-frame fallback Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

Goal: After a tray restore, Flutter presents a fresh frame even when the first frame requested after show() is dropped, and one verification round produces diagnostic evidence if it still fails.

Architecture: One Dart change in WindowService._showWindow: keep the immediate scheduleFrame(), add exactly one deferred scheduleFrame() via a 250ms Timer (stored in a field, cancelled on re-entry and on dispose), plus AppLogger.info diagnostic lines and a post-frame callback that logs when a framework frame runs. Verification is Ponta manual hide/restore on the Linux release bundle plus a log check.

Tech Stack: Flutter 3.50.0 / Dart 3.14.0, nativeapi 0.6.1, Riverpod.

Spec: docs/superpowers/specs/2026-11-18-tray-restore-blank-fallback-design.md

## Global Constraints

- Windows and Linux only, no macOS.
- No widget-tree, theme, page, or runner changes.
- No geometry change, no size nudge, no retry loop: exactly one deferred frame request.
- Diagnostic logging via AppLogger.info only (no debug level exists); the three log lines are pinned in Task 1.
- Full suite baseline: 1213 passed / 3 skipped / 0 failed. flutter analyze baseline: exactly 1 info, the documented implementation_imports at lib/main.dart:18:8.
- A widget test cannot cover this (native/framework boundary; Window is a native FFI object that cannot be faked). Same TDD exception as the earlier plans.
- Do not launch the app: Ponta running instance hosts many services. Verification is hers, on the Linux release bundle (CI artifact or local bundle) after quitting the running app.
- BASE for this plan: 26c3ed0 (main, pushed). Work lands on main, no worktree (BVPD is project-scoped to this checkout).

## Review Focus

- Rapid repeated restores before the 250ms Timer fires: the pending Timer must be cancelled and a fresh one scheduled, never stacked. A reasonable person restoring twice in quick succession expects one deferred frame per restore and no crash or log spam. Pinned by Task 2 manual check (two quick restores, confirm the log shows one deferred line per restore).
- _showWindow while the window is already visible (tray click with the window open): the extra frame and log lines must be harmless. Pinned by Task 2 manual check (tray click with window open, nothing odd).
- Restore after a --minimized launch: same _showWindow path, must also get a frame. Pinned by Task 2 manual check (one --minimized launch + restore).
- App quit while the deferred Timer is pending: the Timer must not fire after dispose. Pinned by Task 1 dispose step (cancel on dispose) and code review.
- Second-launch activation (desktop icon while hidden): same bug class, different trigger, NOT fixed here; if it blanks, record it as a follow-up, not a failure of this fix. Pinned by Task 2 manual check (record the result).

---

## Setup

- Create the plan workspace directory .superpowers/sdd/2026-11-18-tray-restore-blank-fallback/ and its ledger progress.md with the first line: # SDD ledger - plan: docs/superpowers/plans/2026-11-18-tray-restore-blank-fallback.md, then BASE = 26c3ed0, then a Setup line naming the execution method once Ponta chooses it, then the pre-flight line below.
- Pre-flight: Task 1 produces the deferred frame + logs in _showWindow; Task 2 consumes the Linux bundle; Task 3 consumes the docs. Interfaces match - _showWindow is the only show path in Dart; no conflict found.

### Task 1: Deferred frame + diagnostic logging in _showWindow

Files:
- Modify: lib/core/services/window_service.dart (_showWindow, one new field, dispose)
- Test: none (TDD exception, see Global Constraints)

Interfaces:
- Consumes: currentWindow() from lib/core/services/window_api.dart; SchedulerBinding.instance.scheduleFrame() and addPostFrameCallback from package:flutter/scheduler.dart (already imported); AppLogger.info from package:dev_stack/core/services/log_service.dart (already imported); Timer from dart:async (already imported). No new imports.
- Produces: _showWindow shows the window, requests an immediate frame, registers a post-frame callback, and schedules exactly one deferred frame 250ms later; the three pinned log lines.

- [ ] Step 1: Read the current _showWindow and the field + dispose regions of lib/core/services/window_service.dart
  Expected: _showWindow matches the text in Step 3 apart from the new lines; the field Timer? _updateTimer; exists near the top of the class; ref.onDispose starts with _updateTimer?.cancel();

- [ ] Step 2: Add the field Timer? _deferredFrameTimer; directly after Timer? _updateTimer;
  Expected: the field sits next to _updateTimer; analyze stays clean (checked in Step 5)

- [ ] Step 3: Replace _showWindow with the new version below, exact text (the existing comment and scheduleFrame() call stay, the new lines follow them):

  void _showWindow() {
    final window = currentWindow();
    if (window == null) return;
    if (window.isMinimized) window.restore();
    window.show();
    window.focus();
    // A hidden window's surface is gone on Wayland: showing it without
    // asking for a new frame leaves the runner's #020617 background
    // showing through the transparent view until something else (e.g.
    // a resize) forces a frame. Requesting one here covers every
    // Dart-initiated show (tray click, tray menu, restore after a
    // --minimized launch).
    SchedulerBinding.instance.scheduleFrame();
    AppLogger.info('Tray restore: window shown, immediate frame requested');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      AppLogger.info('Tray restore: frame ran after show');
    });
    // The immediate request alone proved not enough (26c3ed0): the frame
    // can fire before the Wayland surface is configured and get dropped,
    // with nothing scheduling another. One deferred request, 250ms later,
    // lands after the surface exists.
    _deferredFrameTimer?.cancel();
    _deferredFrameTimer = Timer(const Duration(milliseconds: 250), () {
      SchedulerBinding.instance.scheduleFrame();
      AppLogger.info('Tray restore: deferred frame requested after 250ms');
    });
  }

  Expected: the method matches the text above exactly.

- [ ] Step 4: Cancel the Timer on dispose: in ref.onDispose, directly after _updateTimer?.cancel(); add _deferredFrameTimer?.cancel(); and _deferredFrameTimer = null;
  Expected: the dispose block cancels both timers.

- [ ] Step 5: Run flutter analyze lib/core/services/window_service.dart
  Expected: No issues found!

- [ ] Step 6: Run the full suite (flutter test)
  Expected: 1213 passed / 3 skipped / 0 failed (All tests passed!)

- [ ] Step 7: Commit
  git add lib/core/services/window_service.dart
  git commit with message: fix(window): request a deferred frame when restoring from the tray
  Push only when Ponta says so, as before.

### Task 2: Build the Linux bundle, Ponta verifies

Files:
- Consumes: the Task 1 commit.
- Produces: a Linux release bundle proven to contain the fix, plus Ponta per-item verification results in the ledger.

- [ ] Step 1: Run flutter build linux --release
  Expected: Built build/linux/x64/release/bundle/dev_stack

- [ ] Step 2: Prove the bundle contains the fix: read build/linux/x64/release/bundle/dev_stack as bytes and check it contains the three log strings (Tray restore: window shown, immediate frame requested / Tray restore: deferred frame requested after 250ms / Tray restore: frame ran after show). If any is missing, STOP - the build is stale (a local-bundle mtime anomaly was seen on 2026-11-18: mtime 11:32:26 after a 15:39 build) and must be investigated before relying on the bundle; prefer the CI artifact in that case.
  Expected: all three strings present.

- [ ] Step 3: Ponta verifies on the Linux release bundle (CI artifact or the local bundle from Step 1, after quitting the running app): hide to tray and restore from the tray icon 10 times (including one launch with --minimized followed by a restore); no blank in any of them. Also: hide to tray, then launch the app again from the desktop icon, and record whether that restore blanks (follow-up, not a failure of this fix). Also: two restores in quick succession (under 250ms apart) and one tray click while the window is already open; confirm nothing odd and the log shows one deferred line per restore.
  Expected: 10/10 restores show content; second-launch result recorded; quick-restore + open-click checks clean.

- [ ] Step 4: Ponta checks the day app log (under the app logs dir, file named by date) for the diagnostic lines: one shown line, one deferred line, and one frame-ran line per restore. Record in the ledger which lines appeared.
  Expected: all three lines per restore.
  If any restore blanks, STOP: record which diagnostic lines appeared for that restore and do NOT tune the Timer delay and retry - the next step is a new design (ForcedFrame or Focused event) from that evidence.

### Task 3: Verify baseline, commit docs, close out

Files:
- Modify: none in lib. Commit the docs: docs/superpowers/specs/2026-11-18-tray-restore-blank-design.md, docs/superpowers/plans/2026-11-18-tray-restore-blank.md, docs/superpowers/specs/2026-11-18-tray-restore-blank-fallback-design.md, docs/superpowers/plans/2026-11-18-tray-restore-blank-fallback.md (the first two are still untracked; they document the failed first fix).

- [ ] Step 1: Run the full suite and flutter analyze (whole project)
  Expected: suite 1213 passed / 3 skipped / 0 failed; analyze exactly the 1 documented info at lib/main.dart:18:8.

- [ ] Step 2: Commit the four docs
  git add the four paths above
  git commit with message: docs: design and plans for tray-restore blank fix and deferred-frame fallback

- [ ] Step 3: Append completion lines to .superpowers/sdd/2026-11-18-tray-restore-blank-fallback/progress.md, delete that workspace directory, update ~/MEMORY.md with the outcome, report to Ponta.
  Note: the first plan workspace (.superpowers/sdd/2026-11-18-tray-restore-blank/) stays as the record of the failed first fix; do not delete it in this plan.
