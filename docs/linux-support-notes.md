# Linux Support — Known Limitations & Follow-ups

## Catalog scope (as of 2026-08-23)
- **Nginx, Apache, Redis** are intentionally ABSENT from `apps-linux.json`:
  upstream publishes no official portable prebuilt Linux binaries. Re-add
  only when a trustworthy signed source exists.
- **PostgreSQL** uses Percona Distribution for PostgreSQL (official prebuilt tarballs from downloads.percona.com) on Linux.

## Runtime limitations
- Linux PHP (static-php-cli) ships the CLI SAPI only: services run via
  `php -S host:port` (built-in server). Nginx↔PHP-FastCGI integration is a
  follow-up requiring an fpm build.
- mkcert CA trust install requires the Polkit agent (pkexec prompt).
- Port-conflict probing uses `ss -tulpn` on Linux (best-effort, skips
  silently when unavailable — same policy as netstat on Windows).

## External prerequisites
- The catalog gist must contain `apps-linux.json` alongside `apps.json`
  (multi-file gist) or Linux auto-update silently no-ops (logged).
