# Linux Support — Known Limitations & Follow-ups

## Catalog scope (as of 2026-11-09)
- **Nginx** uses Jakub Jirutka static Linux binaries (`jirutka/nginx-binaries`).
- **Redis** ships as a static musl bundle from `devstack-app-builder`.
- **Apache and PostgreSQL** ship as musl-dynamic portable bundles from `devstack-app-builder`.

## Runtime limitations
- mkcert CA trust install requires the Polkit agent (pkexec prompt).
- Port-conflict probing uses `ss -tulpn` on Linux (best-effort, skips
  silently when unavailable — same policy as netstat on Windows).

### Window Chrome & Frameless Titlebar
- As of 2026-09-22, DevStack uses a Flutter-rendered custom header (`AppHeader`)
  across all platforms.
- `linux/runner/my_application.cc` no longer creates a `GtkHeaderBar` on startup.
- If native window decorations are required for troubleshooting on a specific
  compositor, revert the `use_header_bar` block in `my_application.cc` and set
  `titleBarStyle: TitleBarStyle.normal` in `lib/main.dart`.

## External prerequisites
- The catalog gist must contain `apps-linux.json` alongside `apps.json`
  (multi-file gist) or Linux auto-update silently no-ops (logged).
