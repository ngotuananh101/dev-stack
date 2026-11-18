# Tray restore shows a blank window - design

## Intent

Hiding the app to the tray and restoring it shows a uniformly dark,
empty window. The launch-time blank (first frame dropped by Dart's
pre-first-frame resize/show) was fixed by making the runners own
geometry and visibility, but that gate only protects the initial
launch: restoring a hidden window goes through a different path that
never produces a fresh frame.

## Evidence

- Ponta reproduced it 2026-11-18 15:23: hide to tray, click the tray
  icon, window comes back blank. Resizing brings the content back.
- WindowService._showWindow (lib/core/services/window_service.dart)
  does restore() (if minimized), show(), focus() - and nothing
  that asks Flutter for a new frame.
- nativeapi 0.6.1 has no WindowShownEvent (events: Focused, Blurred,
  Minimized, Maximized, Restored, Moved, Resized, Created, Closed,
  full-screen, CloseRequested, PropertyChanged, OcclusionChanged,
  Docked, Undocked) and no redraw/frame method on Window (all
  methods are thin FFI calls: native_window_show etc.).
- The dark in the screenshot is the runner's own window background
  (kWindowBackground = "#020617" in linux/runner/my_application.cc,
  painted by window_draw_cb) showing through the transparent
  FlView: the view has no presented frame, so the window background
  is all there is.
- A resize cures it, which is what a missing frame looks like: the
  resize forces the engine to render at the new size. The content,
  the widget tree and the engine are all fine; only the presentation
  of a fresh frame is missing.

## Goals

- After any Dart-initiated show of the window, Flutter presents a
  fresh frame: hide-to-tray then tray-click restore, tray-menu
  "Show App", and restore after a --minimized (auto-start) launch.
- No geometry change, no visible jump or flash, no size nudge.
- Windows and Linux (the fix is shared Dart in _showWindow).

## Non-goals

- No widget-tree, theme, or page changes.
- No runner changes in this fix.
- The runner's second-launch activation branch
  (my_application_activate's existing-window branch: show +
  deiconify + present with no frame request) is the same bug class but
  a different trigger (launching the app again while it is hidden);
  it is a verification item, not part of this fix. If it still blanks,
  that is a follow-up design.
- No size nudge, no delayed-retry loop: the fix is one frame request,
  not a workaround that fights the symptom.

## Approach

_showWindow schedules a Flutter frame after showing the window
(SchedulerBinding.instance.scheduleFrame()). scheduleFrame defers
to the next vsync, by which time the GTK map has been processed on
the platform thread, so the frame lands on the new surface. If the
manual verification still shows an occasional blank, the fallback is
a deferred schedule (a short Timer before the request) - decided by
verification, not upfront.

## Alternatives considered

- Size nudge (setSize to the current size): the known cure, but it
  is the symptom fix the launch-race plan forbids, and it costs a
  window-configure roundtrip.
- Scheduling the frame from a window event (Focused/Restored/
  OcclusionChanged): no event reliably means "just shown" on Linux,
  and it needs hidden-state tracking for the --minimized case;
  _showWindow already knows when it shows, so no event is needed.
- Runner gtk_widget_queue_draw: redraws the GTK background, not
  the Flutter content; only the engine can produce a frame.

## Verification

- flutter analyze on the touched file: no new issues.
- Full suite stays green (1213 passed / 3 skipped / 0 failed).
- Ponta, on the Linux release bundle: hide to tray and restore from
  the tray icon 10 times (including one launch with --minimized
  followed by a restore); no blank in any of them. Also: hide to
  tray, then launch the app again from the desktop icon, and record
  whether that restore blanks (follow-up, not a failure of this fix).
- A widget test cannot cover this: the defect lives at the
  native/framework boundary (a hidden window's surface and the
  engine's frame scheduling), and Window is a native FFI object
  that cannot be faked in a widget test. Same TDD exception as the
  launch-race plan.
