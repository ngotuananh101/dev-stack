# Update cloudflared and ngrok from the Tunnels page — design

## Intent

Today each tunnel binary is downloaded once, automatically, when a
tunnel is started and the binary is missing
(`TunnelDownloaderService.downloadBinary`, called from
`TunnelManagerService._startTunnel` only when `isBinaryDownloaded` is
false). There is no way to replace an installed binary with a newer one,
and nothing shows which version is installed. Ponta wants a way to update
the binaries from inside the app — cloudflared first, then ngrok too.

## Goals

- Visible Update controls on the Tunnels page, one per binary
  (cloudflared and ngrok), each re-downloading the latest binary and
  replacing the installed one.
- The control reuses the existing downloader as-is: `downloadBinary`
  already downloads to a temp file and only replaces the target after a
  successful download, so a failed update leaves the old binary in place.
- Clear feedback: spinner while downloading, success toast when done, an
  error dialog when the download fails.
- Never fight a running tunnel for its binary: while a tunnel of that
  provider is starting or running, that provider's update must not start
  (on Windows the running exe is file-locked; on Linux the running
  process would keep the old binary anyway). A running ngrok tunnel does
  not block a cloudflared update, and vice versa.

## Non-goals

- No version display and no "update available" detection (no
  `cloudflared --version` parsing, no GitHub API release check).
- No automatic update on launch or on tunnel start.
- No changes to `TunnelDownloaderService` or `TunnelManagerService`.

## Approaches

- **Cách 1 (picked): buttons on the Tunnels page.** One AppButton per
  binary in the page header, next to "New Tunnel". Tap downloads the
  latest binary for that provider, with the guard and feedback above.
  Smallest change, reuses everything.
- **Cách 2 (not picked): "Tunnel binaries" section in Settings** with
  the installed version (`cloudflared --version`) and an Update button.
  More informative, but needs version parsing and a new Settings section
  for one button.
- **Cách 3 (not picked): auto-check on opening the Tunnels page** with
  an "update available" banner. Most work (GitHub API + version
  comparison) for a control Ponta will tap manually anyway.

## Design as approved (Cách 1)

- **Placement:** `TunnelsPage._buildHeader`, left of the "New Tunnel"
  button: `Update cloudflared`, 8px gap, `Update ngrok`, 8px gap, then
  "New Tunnel" (8px is the gap the app uses between header actions).
- **Narrow windows:** below 768px of page content the header stacks — the
  title takes its own row and the three buttons wrap underneath in a `Wrap`
  (labels and icons unchanged). The buttons plus gaps need 657px side by
  side and the title word needs 98px, so a single row only fits from about
  768px; at the 720px minimum window (608px of content) the single row
  overflowed by 49px. At or above 768px the single row above is used, so
  the 1024px default window keeps it.
- **Buttons:** `AppButton`, labels `Update cloudflared` and `Update
  ngrok`, icon `LucideIcons.download`, style `AppButtonStyle.success`
  (green: install/update actions are green app-wide). Always visible,
  even with zero tunnels configured — the binaries are shared tools,
  not tied to a tunnel row.
- **Call:** one shared handler `_updateBinary(provider, isBusy)` that
  calls
  `ref.read(tunnelDownloaderServiceProvider).downloadBinary(provider)`
  with no `onProgress` (the button's `isLoading` spinner is the progress
  indicator) and no `cancelToken` (no cancel UI for this action).
- **Busy guard:** per provider. The tap handler first checks whether
  any tunnel of that provider is busy — provider name compared
  case-insensitively, matching the downloader's switch — with a session
  status in `{downloadingBinary, connecting, running}`. If busy, it
  shows an info toast `Stop the running <Name> tunnel first, then
  update.` (name `Cloudflare` or `ngrok`) and does not download. The
  busy values are computed in `build()` from `tunnelsAsync.value`
  (null while the list is still loading) plus `tunnelSessionsProvider`,
  and passed into `_buildHeader` as named parameters — they stay fresh
  because `build()` re-runs when sessions change.
- **In-progress state:** a `Set<String> _updating` on
  `_TunnelsPageState` holding the provider names currently downloading;
  each button's `isLoading` is `_updating.contains(provider)`. Add
  before the await, remove in a `finally`. Every `setState` and every
  toast/dialog after an await is guarded by `mounted`.
- **Feedback copy (exact, `<name>` is `cloudflared` or `ngrok`):**
  success → `AppDialogs.showToast(context, '<name> updated to the
  latest version')`; failure → `AppDialogs.showErrorFrom(context, error,
  title: 'Could not update <name>')`.
- **Verification:** widget tests for both buttons (rendered, tap
  downloads with a fake downloader, busy guard per provider, failure
  dialog, loading list); `flutter analyze` on touched files; full suite
  green.
