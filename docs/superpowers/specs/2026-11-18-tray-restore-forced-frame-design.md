# Tray-restore blank: forced frame (Cach 2)

Date: 2026-11-18
Status: approved by Ponta 2026-11-18 16:51
Base: a017518 (immediate + 250ms deferred scheduleFrame, VERIFIED FAILED)
Context: docs/superpowers/specs/2026-11-18-tray-restore-blank-fallback-design.md

## Intent

The deferred scheduleFrame() in a017518 did not fix the tray-restore blank. The log from the failed verification (2026-11-18 16:45, two restores) shows all three diagnostic lines per restore, including 'Tray restore: frame ran after show'. A framework frame ran and the window still stayed blank, so the failure is at the engine/surface layer, not framework scheduling. This design tries the one remaining Dart-side lever that targets the engine: scheduleForcedFrame().

## SDK facts (Flutter 3.50.0, packages/flutter/lib/src/scheduler/binding.dart, read 2026-11-18)

- scheduleFrame() returns early if a frame is already scheduled OR framesEnabled is false. framesEnabled is false when the app lifecycle is not resumed.
- scheduleForcedFrame() returns early only if a frame is already scheduled. It ignores framesEnabled and the lifecycle state. Otherwise it does exactly what scheduleFrame() does: ensureFrameCallbacksRegistered(), platformDispatcher.scheduleFrame(), set the scheduled flag.
- scheduleWarmUpFrame() may never actually render, because the engine did not request it and therefore has no valid context to paint in. Not used.
- So scheduleForcedFrame() differs from scheduleFrame() ONLY by the framesEnabled gate. There is no other mechanical difference.

## What the failed verification proves, and what it does not

- Proves: the immediate frame ran (the post-frame callback fired) on both restores, so the framesEnabled gate was OPEN at show time.
- Does not prove: whether the deferred frame at 250ms ran. No callback was registered on it, and its log line prints at request time, not at run time.
- Consequence: if the gate is open at 250ms too, a forced frame there is mechanically identical to the deferred scheduleFrame() that already failed. This change is therefore an experiment with a decisive read-out, not a guaranteed fix: if a forced deferred frame still blanks, the gate was never the blocker, and the new deferred-ran log line will show whether the deferred frame ran at all.

## Approach (picked by Ponta 2026-11-18 16:47: Cach 2)

- Keep the immediate scheduleFrame() with its post-frame callback and its log line, unchanged.
- In the 250ms Timer, call scheduleForcedFrame() instead of scheduleFrame(). Before requesting it, register an addPostFrameCallback logging 'Tray restore: deferred frame ran after show', so the log proves whether the deferred frame ran, not only that it was requested.
- Change the deferred request log line to 'Tray restore: deferred forced frame requested after 250ms', so the log distinguishes this build from a017518.
- Keep the Timer field, cancel-on-re-entry, and dispose handling, unchanged. No new imports. No geometry change.

## Goals

- Restoring from the tray shows content on the first try.
- The log proves, per restore, whether each frame was requested AND ran (four lines per restore).

## Non-goals

- The second-launch (existing-window) branch: same bug class, separate follow-up.
- The first-launch blank: already fixed by the runner geometry work.
- Tuning the 250ms delay.
- Any native runner change.

## Anti-goals

- A retry loop.
- A resize or size nudge in this change: resizing is the one action known to clear a blank window, because it forces a surface reconfigure rather than just a frame. It is held as the step after ForcedFrame and Focused if both fail, not smuggled into this change.
- Calling scheduleForcedFrame() anywhere except the deferred Timer in _showWindow: it fires once per restore, so the battery note in its doc does not apply in practice.

## Alternatives considered

- Cach 1 deferred scheduleFrame() (a017518): failed, log-proven.
- Cach 3 frame-on-Focused-event: unverified whether Focused fires on the tray-restore path on Wayland, and it would still need a Timer backup. Next step if ForcedFrame fails.
- Resize or 1px size nudge after show: the only action known to force a present, because it reconfigures the surface. Visible flicker risk, untested on this path. Held as the step after ForcedFrame and Focused.
- scheduleWarmUpFrame(): may never render. Wrong tool.

## Verification

Same round as the fallback plan, stricter: CI build on the new commit, Ponta installs after quitting the running app, hide to tray + restore 10 times (including one --minimized launch + restore), second-launch-from-desktop-icon result recorded, two restores under 250ms apart + one tray click while the window is open. The day log must show four lines per restore: shown, frame ran after show, deferred forced frame requested after 250ms, deferred frame ran after show. If any restore blanks, STOP and record which lines appeared: a missing deferred-ran line means the deferred frame never ran (engine vsync or surface problem, not scheduling); a present deferred-ran line with a blank window means the engine produced frames the surface never presented, and the next step is the resize-nudge design.
