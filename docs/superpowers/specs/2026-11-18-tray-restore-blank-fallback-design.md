# Tray restore blank window - deferred-frame fallback design

## Intent

The first fix (commit 26c3ed0: SchedulerBinding.instance.scheduleFrame() immediately after show() in WindowService._showWindow) was verified FAILED on the fixed build: Ponta dispatched CI run 44269274380 on 26c3ed0 (success), installed the artifact to /opt at 15:47, restarted the app at 16:22, and hide-to-tray + Show still blanks. The frame requested synchronously after show() evidently fires before the Wayland surface is configured and gets dropped, and nothing schedules another frame afterwards. This design adds one deferred frame request so a frame lands after the surface exists, and adds diagnostic logging so a single verification round both tests the fix and produces evidence if it fails again.

## Evidence

- First fix verified failed 2026-11-18 16:23 on the fixed build (CI run 44269274380, /opt installed 15:47, app restarted 16:22).
- Flutter 3.50.0 SDK, SchedulerBinding.scheduleFrame(): if no frame is already scheduled it calls platformDispatcher.scheduleFrame() and sets the flag; the engine then calls handleBeginFrame at the next vsync. Nothing in that path waits for the native surface to be configured, and nothing re-requests if the frame is dropped.
- The window event listener (window.addListener in WindowService.build) already exists, and addPostFrameCallback is used elsewhere in the codebase (main.dart, pages); both are available without new plumbing.
- AppLogger has info, error and warning only (no debug level); logs go to daily files under the app logs dir and to debugPrint.

## Goals

- After any Dart-initiated show of the window, Flutter presents a fresh frame: hide-to-tray then tray-click restore, tray-menu Show App, and restore after a --minimized (auto-start) launch.
- One verification round answers both whether the fix works and, if not, whether framework frames ran at all after show().
- No geometry change, no visible jump or flash, no size nudge.
- Windows and Linux (shared Dart in _showWindow).

## Non-goals

- No widget-tree, theme, or page changes. No runner changes.
- No retry loop: exactly one deferred request, not repeated attempts. The first design ruled out a delayed-retry loop; this is a single deferred request, which that same design named as the fallback decided by verification - verification has now decided it.
- The runner second-launch activation branch stays a follow-up, not part of this fix.
- No ForcedFrame and no Focused-event trigger in this fix (see Alternatives).

## Approach (Ponta picked Cach 1, 2026-11-18)

_showWindow keeps the immediate SchedulerBinding.instance.scheduleFrame() after show() and focus(), and also schedules exactly one deferred scheduleFrame() via Timer(Duration(milliseconds: 250)). 250ms is several vsync periods plus compositor configure time, and the window itself shows immediately, so the delay is not felt as a wait - it only bounds how long a dropped first frame can leave the window blank.

The deferred request is a single Timer stored in a field on WindowService (same pattern as _updateTimer): if _showWindow runs again before it fires, the pending Timer is cancelled and a fresh one scheduled, so rapid restores never stack timers; it is cancelled on dispose.

Diagnostic logging (AppLogger.info, the file already imports log_service):
- in _showWindow: one line when the window is shown and the immediate frame is requested, one line when the deferred Timer fires and requests its frame.
- one SchedulerBinding.instance.addPostFrameCallback registered in _showWindow that logs when a framework frame runs after the show. The callback proves the framework produced a frame; it does NOT prove the surface presented it. If the window still blanks with the callback logged, the failure is at the engine/surface layer, not the framework - that distinction is the evidence the next step needs.

## Alternatives considered

- scheduleForcedFrame (Cach 2): the Flutter API for forcing a render while the display is off, a closer match to this shape than scheduleFrame, and needs no guessed delay - but it is not certain the engine keeps that frame until the surface exists, so it can fail the same way. Kept as the next step if this fallback fails.
- Frame on the Focused window event (Cach 3): an event-driven trigger instead of a guessed delay, using the existing window.addListener - but it is unverified whether Focused fires on the tray-restore path on Wayland, and it would still need a Timer backup. Kept as the next step if this fallback fails.
- Size nudge: the known cure, but the symptom fix the launch-race plan forbids.

## Verification

- flutter analyze on the touched file: no new issues.
- Full suite stays green (1213 passed / 3 skipped / 0 failed).
- Ponta, on the Linux release bundle: hide to tray and restore from the tray icon 10 times (including one launch with --minimized followed by a restore); no blank in any of them. Also: hide to tray, then launch the app again from the desktop icon, and record whether that restore blanks (follow-up, not a failure of this fix).
- After the restores, check the day app log for the diagnostic lines per restore (shown, deferred frame requested, frame ran). If any restore blanks, STOP: record which diagnostic lines appeared for that restore and design the next step (ForcedFrame or Focused event) from that evidence - do not tune the Timer delay and retry.
- A widget test cannot cover this: the defect lives at the native/framework boundary, and Window is a native FFI object that cannot be faked in a widget test. Same TDD exception as the earlier plans.
