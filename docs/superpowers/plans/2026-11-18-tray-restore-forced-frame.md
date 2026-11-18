# Tray-Restore Forced Frame Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

Goal: Make restoring from the tray show content on the first try by requesting a forced frame 250ms after show, and prove per restore whether each frame was requested and ran.

Architecture: One change in WindowService._showWindow: keep the immediate scheduleFrame() and its callback, and change only the deferred Timer to call scheduleForcedFrame() with a post-frame callback that logs when the deferred frame runs. No new imports, no geometry change, no runner change.

Tech Stack: Flutter 3.50.0 / Dart 3.14.0, window_manager 0.7.0 (nativeapi 0.6.1), Riverpod, AppLogger.

Spec: docs/superpowers/specs/2026-11-18-tray-restore-forced-frame-design.md

## Global Constraints

- Windows and Linux only, no macOS.
- Do not launch the app: Ponta's running instance hosts many services.
- Push only when Ponta says so.
- Suite baseline: 1213 passed / 3 skipped / 0 failed. Analyze baseline: exactly 1 info, the documented implementation_imports in lib/main.dart.
- The 250ms Timer delay is not to be tuned.
- Log lines are exact copy: 'Tray restore: window shown, immediate frame requested', 'Tray restore: frame ran after show', 'Tray restore: deferred forced frame requested after 250ms', 'Tray restore: deferred frame ran after show'.

## Review Focus

- A restore while a frame is already scheduled: scheduleForcedFrame() returns early, but the registered callback attaches to the pending frame and still fires, so the deferred-ran line still appears and content shows. Pinned by Task 2: the quick-restores check (two restores under 250ms apart) must show the deferred-ran line.
- Two restores under 250ms apart: the second _showWindow cancels the first Timer, so only one deferred forced frame is requested. Pinned by Task 2: the quick-restores check must show exactly one set of deferred lines for the second restore.
- A tray click while the window is open: _showWindow runs again on an already-visible window and requests another forced frame. Pinned by Task 2: the open-click check, content stays visible, no Timer leak.
- A --minimized launch followed by restore: the same _showWindow path. Pinned by Task 2: the --minimized check must show all four lines.
- The deferred frame never runs: no deferred-ran line appears, which proves the failure is engine-side and the STOP rule applies. Pinned by Task 2: the log check records exactly which lines appeared per restore.

---

## Setup

- [ ] Create the plan workspace .superpowers/sdd/2026-11-18-tray-restore-forced-frame/ and its ledger progress.md. First line: the plan path. BASE = 31ac9ad. Setup line naming the execution method. Pre-flight line: Task 1 produces the forced frame + logs in _showWindow; Task 2 consumes the Linux bundle; Task 3 consumes the docs. Interfaces match - _showWindow is the only show path in Dart; no conflict found.

### Task 1: Forced frame in _showWindow

Files:
- Modify: lib/core/services/window_service.dart

Interfaces:
- Consumes: _deferredFrameTimer (Timer field, added in a017518), AppLogger.info, SchedulerBinding.instance (already imported: package:flutter/scheduler.dart).
- Produces: the deferred Timer requests scheduleForcedFrame() and logs when the deferred frame runs; the four log lines per restore that Task 2 checks.

- [ ] Step 1: Read the current _showWindow and the _deferredFrameTimer field and dispose lines in lib/core/services/window_service.dart.
- [ ] Step 2: Replace the body of the deferred Timer callback with the exact text below. Nothing else in _showWindow changes: the immediate scheduleFrame(), its callback and its log line stay exactly as they are.

    _deferredFrameTimer?.cancel();
    _deferredFrameTimer = Timer(const Duration(milliseconds: 250), () {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        AppLogger.info('Tray restore: deferred frame ran after show');
      });
      SchedulerBinding.instance.scheduleForcedFrame();
      AppLogger.info('Tray restore: deferred forced frame requested after 250ms');
    });

- [ ] Step 3: Run flutter analyze on lib/core/services/window_service.dart. Expected: No issues found.
- [ ] Step 4: Run the full flutter test suite. Expected: 1213 passed / 3 skipped / 0 failed.
- [ ] Step 5: Commit with message fix(window): request a forced frame when restoring from the tray. Push only when Ponta says so.

TDD note: no new widget test is possible for _showWindow. Window is a native FFI object that cannot be faked in a widget test, so the log-based verification in Task 2 is the test for this task, as it was for the two previous attempts.

### Task 2: Build and verify

Files:
- Consumes: the Task 1 commit; produces the Linux bundle and the verification verdict.

Interfaces:
- Consumes: build/linux/x64/release/bundle/lib/libapp.so (the Dart code lives here, not in bundle/dev_stack, which is the C++ runner and holds no Dart strings).
- Produces: Ponta's hide/restore verdict and the per-restore log lines.

- [ ] Step 1: Run flutter build linux --release.
- [ ] Step 2: Read build/linux/x64/release/bundle/lib/libapp.so as bytes and check all four log strings are present. If any is missing, STOP: the build is stale and must be investigated before relying on the bundle; prefer the CI artifact.
- [ ] Step 3: Ponta verifies (she must quit the running app first): hide to tray + restore 10 times (including one --minimized launch + restore), second-launch-from-desktop-icon result recorded (follow-up, not a failure), two restores under 250ms apart + one tray click while the window is open, and she checks the day app log for the four diagnostic lines per restore.
- [ ] Step 4: If any restore blanks, STOP and record which log lines appeared. Do NOT tune the Timer delay. Next step is a new design (Focused event or resize-nudge) from that evidence.

### Task 3: Close out

Files:
- Modify: docs/superpowers/specs/2026-11-18-tray-restore-forced-frame-design.md (status line already updated on approval), docs/superpowers/plans/2026-11-18-tray-restore-forced-frame.md (this plan).

Interfaces:
- Consumes: the Task 1 commit, the Task 2 verdict, the two docs.
- Produces: the docs commit, the updated MEMORY.md, the deleted workspace.

- [ ] Step 1: Re-verify the suite + analyze baseline (1213/3/0, 1 accepted info).
- [ ] Step 2: Commit the two docs with message docs: design and plan for tray-restore forced-frame fix.
- [ ] Step 3: Append completion lines to the ledger, delete the workspace dir .superpowers/sdd/2026-11-18-tray-restore-forced-frame/, update ~/MEMORY.md, report. The FIRST plan workspace (.superpowers/sdd/2026-11-18-tray-restore-blank/) STAYS as the record of the failed first fix; the fallback workspace was already deleted in its Task 3.
