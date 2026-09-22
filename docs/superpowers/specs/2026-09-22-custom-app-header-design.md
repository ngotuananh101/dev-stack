# Custom App Header & Frameless Window Design

## Context & Motivation

The window frame differs across operating systems, so the app cannot present a
consistent chrome. Today `WindowOptions.titleBarStyle` is `TitleBarStyle.normal`:
the OS draws the title bar. On Windows that is the Win32 caption; on Linux the
Flutter runner (`linux/runner/my_application.cc`) builds a `GtkHeaderBar` and
attaches it as the window titlebar. The result is two visually different apps
sharing one codebase — different heights, fonts, colors, and button placement.

The app already has a design token system (`AppColors`, `AppTextSize`,
`AppRadius`) and a `Sidebar` that carries its own logo block. This design
replaces the OS title bar with an app-drawn header so the chrome matches the
app's own design language on every platform.

`window_manager 0.5.1` (already a dependency) ships every primitive needed:
`TitleBarStyle.hidden`, `setAsFrameless()`, `DragToMoveArea`,
`DragToResizeArea`, and `VirtualWindowFrame`.

## Scope

**In scope:** Windows and Linux. A 36px app-drawn header spanning the full
window width, frameless window, window controls (minimize / maximize / close),
removal of the sidebar logo block, and the native changes needed to make the
Linux window undecorated from the first frame.

**Out of scope:** macOS (no `macos/` directory in this repo); moving page
titles or page actions into the header; service-status indicators in the
header; a runtime escape hatch back to the native title bar.

## Architecture

```
MaterialApp(builder: VirtualWindowFrameInit())
└─ Scaffold
   └─ Column
      ├─ AppHeader                    36px, full width
      └─ Expanded
         └─ Row
            ├─ Sidebar                240px
            └─ Expanded → page content
```

### Window state

`WindowOptions.titleBarStyle` changes from `TitleBarStyle.normal` to
`TitleBarStyle.hidden`, and `windowButtonVisibility: false` is passed so the
macOS-only traffic-light buttons are never requested.

The Dart-side call reaches `setTitleBarStyle` through
`waitUntilReadyToShow`. On Windows that path only resets the DWM frame margins
and clears `is_frameless_`; the window style keeps `WS_THICKFRAME`, so Aero
Snap, edge resize, and the system shadow continue to work. On Linux the same
call runs `gtk_window_set_decorated(window, false)`.

Because `waitUntilReadyToShow` resolves after the first Flutter frame — that is,
after GTK has already shown the window — relying on it alone on Linux would show
the native `GtkHeaderBar` for a frame and then make it disappear. The Linux
runner therefore drops its header bar construction entirely (see *Native
changes*), so the window is undecorated from creation and nothing flashes.

### Edge resize

`VirtualWindowFrameInit()` is registered as `MaterialApp.builder`. The
`VirtualWindowFrame` it installs wraps the app in a `DragToResizeArea` on Linux
and on Windows (with the top three edges enabled on Windows), and it disables
every resize edge while the window is maximized or full screen.

This is why the package widget is used rather than a hand-rolled
`DragToResizeArea`: when a window is maximized, its edges sit against the screen
edges, and an always-on 8px resize strip there would swallow clicks in a dead
zone the user cannot escape. The package widget also tracks
maximize/unmaximize/fullscreen through `WindowListener` and rebuilds its border
and shadow accordingly.

One consequence to accept: the resize strip covers the outermost 8px of the
window, including the top 8px of the header. The header's top 8px resizes the
window; the remaining 28px drags it. This matches the behavior of standard
desktop applications and is intentional.

## Components

### `AppHeader` — new file `lib/shared/layouts/app_header.dart`

A `ConsumerStatefulWidget` mixing in `WindowListener`, 36px tall, spanning the
full window width. Background `AppColors.background`, bottom border 1px
`AppColors.border` (matching the sidebar's right border).

**Left — identity.** `Image.asset('assets/images/icon.png')` at 24×24 inside a
container with `AppRadius.sm` corners and an `AppColors.accent` fill at 20%
alpha, then 12px gap, then the text `Ponta DevStack` (`AppTextSize.sm`,
`FontWeight.bold`, `AppColors.textPrimary`), wrapped in `TextOverflow.ellipsis`.
The sidebar's existing `LOCAL NODE` subtitle is not carried over — the header
stays a single line.

**Center — drag region.** `DragToMoveArea` filling the remaining horizontal
space, giving drag-to-move and double-click-to-toggle-maximize. Both come from
the package; no custom gesture code.

**Right — window controls.** Three buttons, each 46×36 (the Windows 11 caption
button metric, so pointer habits carry over). Each is a `Material` + `InkWell`
with hover state held in `AppHeader`'s own state:

| Button | Icon | Action |
| --- | --- | --- |
| Minimize | `LucideIcons.minus` | `windowManager.minimize()` |
| Maximize / Restore | `LucideIcons.square` / `LucideIcons.maximize` | `windowManager.maximize()` / `unmaximize()` |
| Close | `LucideIcons.x` | `windowManager.close()` |

- Idle: icon `AppColors.textSecondary` on transparent.
- Hover: background `AppColors.surfaceLight`, icon `AppColors.textPrimary`.
- Close hover: background `AppColors.error`, icon `AppColors.textOnColor`.
- The maximize icon is driven by `WindowListener.onWindowMaximize` /
  `onWindowUnmaximize`; `WindowListener` is also registered and unregistered in
  `initState` / `dispose`.
- Colors come from tokens only. No literal `Color(...)` values, keeping the
  app-wide token discipline established in the UI standardization work.

**Close semantics.** The close button calls `windowManager.close()`, not
`destroy()`. This routes through the existing `WindowService.onWindowClose()`,
preserving the `minimizeToTray` setting and the "stop all services, stop CLI
site processes, then destroy" shutdown path.

### `Sidebar` — `lib/shared/layouts/sidebar.dart`

Remove `_buildLogo()` and the two `SizedBox` spacers around it. The `ListView`
padding changes from `symmetric(horizontal: 16)` to
`symmetric(horizontal: 16, vertical: 12)` so nav items do not sit flush against
the header's bottom border. Navigation items are unchanged.

## Native changes

### `linux/runner/my_application.cc`

Delete the `use_header_bar` block: the `GDK_WINDOWING_X11` window-manager probe,
the `gtk_header_bar_new()` construction, and the `gtk_window_set_titlebar()`
call. The window is created undecorated and stays that way; `gtk_window_set_title`
stays for task switchers and Wayland compositors that read the title directly.

This is a build-time change: restoring the native title bar means editing and
rebuilding the runner. That trade is accepted deliberately — it removes the
first-frame flash and removes the dependency on the plugin locating the header
bar in the widget tree.

### `windows/runner/main.cpp`

Change `window.Create(L"dev_stack", ...)` to `L"Ponta DevStack"` so the Win32
window title matches the Linux runner and the app's display name. This title is
read by the taskbar, Alt-Tab, and the single-instance activation path in the same
file, which currently searches for `L"DevStack Dashboard"`.

## Error handling

Window control calls are fire-and-forget `Future`s against the plugin's method
channel. The plugin returns success for every window operation and the app has no
recovery action if a call fails, so failures are not surfaced to the user. If a
call throws, the platform channel error propagates as an unawaited future error,
consistent with how `window_service.dart` already calls these methods.

## Testing

**New: `test/shared/app_header_test.dart`.** Mocks the `window_manager` method
channel via `TestDefaultBinaryMessenger.setMockMethodCallHandler` and asserts:

1. All three control buttons render.
2. Tapping minimize invokes `minimize`.
3. Tapping close invokes `close` — explicitly *not* `destroy`, protecting the
   minimize-to-tray behavior.
4. The maximize button swaps its icon when `onWindowMaximize` fires and swaps
   back on `onWindowUnmaximize`.

**Existing: `test/widget_test.dart`.** Must keep passing. Baseline verified
green before this change.

**Manual, on Wayland (this machine runs `XDG_SESSION_TYPE=wayland`).** Drag the
header to move the window; double-click to maximize and restore; resize from all
four edges; minimize; close with `minimizeToTray` both off (app exits, services
stopped) and on (window hides to tray).

**Not verifiable here: Windows.** No Windows machine is available, and
`.github/workflows/build-assets.yml` only builds artifacts — it does not run the
GUI. Windows behavior must be verified by hand after this change.

## Risks

| Risk | Level | Handling |
| --- | --- | --- |
| Wayland: `gtk_window_begin_move_drag` is a no-op on some compositors, breaking drag-to-move | Medium | Verified by hand on this machine, which runs Wayland. Reported before the work is called done. |
| Windows behavior unverified | Medium | Called out explicitly; requires manual verification. |
| Loss of snap/tile by dragging to a screen edge on Linux | Low | Accepted; same as any frameless app on Wayland. |
| Top 8px of the header resizes instead of dragging | Low | Accepted; standard desktop behavior. |
| Native title bar can only be restored by rebuilding | Low | Accepted by decision; documented in `docs/linux-support-notes.md`. |

## Files touched

| File | Change |
| --- | --- |
| `lib/main.dart` | `TitleBarStyle.hidden`, `windowButtonVisibility: false`, `builder: VirtualWindowFrameInit()`, insert `AppHeader` above the body `Row` |
| `lib/shared/layouts/app_header.dart` | New — the header widget and its window controls |
| `lib/shared/layouts/sidebar.dart` | Remove the logo block; adjust list padding |
| `linux/runner/my_application.cc` | Remove the `GtkHeaderBar` construction |
| `windows/runner/main.cpp` | Window title → `Ponta DevStack` |
| `test/shared/app_header_test.dart` | New — control wiring and icon-state tests |
| `docs/linux-support-notes.md` | Document the frameless decision and how to restore the native title bar |
