# musl-dynamic Runtime Bundles for Linux (PHP, Redis, Apache, PostgreSQL)

## Intent

The builder `ngotuananh101/devstack-app-builder` no longer publishes glibc PHP
bundles. It now publishes four Linux x86_64 runtimes, and musl-dynamic is the
only dynamic target it produces. DevStack's Linux catalog must follow, the
installer must actually install and start them, and the code paths that only
existed for the dropped glibc / Zonky / system-package flows must go away.

Current state, verified against releases `runtimes-20261107-musl-c95d643` and
`runtimes-20261108-1` and against the real archives:

- `assets/data/update.js` matches PHP only as
  `php-<v>-glibc-full-x86_64-<build>.tar.gz`. No such asset exists any more, so
  Linux PHP silently becomes unavailable.
- Redis still matches (`redis-<v>-musl-x86_64-<build>.tar.gz`).
- Apache and PostgreSQL have no fetcher at all, and `applyFallbackVersions`
  deliberately erases their cached versions on Linux.
- Even with correct URLs, installation fails: `PhpRuntimeBundle.load` demands
  `target: glibc` and `profile: full`, neither of which a musl-dynamic manifest
  declares.

The user decided on 2026-11-08:

1. One dynamic target only — `musl-dynamic` — for every builder-produced app.
   Redis stays `musl` (static). Nothing else is accepted.
2. PostgreSQL and Apache are supported runtimes like PHP and Redis.
3. The Zonky jar install path is removed outright.
4. glibc support is removed outright. There is no back-compatibility obligation
   for directories installed by earlier versions: stale installs are simply
   unrecognized and can be deleted and reinstalled.

## Goals / non-goals

Goals: discover the four builder runtimes in the Linux catalog, validate only
musl-dynamic manifests, install and start Apache and PostgreSQL from their
bundles, and delete every code path that only served the removed flows.

Non-goals: Windows behavior, the builder repository itself, ARM, additional PHP
series, migrating already-installed glibc PHP or Zonky PostgreSQL directories.

Anti-goal: publishing a Linux catalog where PHP, Apache, PostgreSQL or Redis is
silently missing because discovery half-failed. A builder discovery failure
still fails closed and writes no catalog.

## Catalog (`assets/data/update.js`)

Replace the two hard-coded patterns with a per-runtime table. Every builder
runtime is discovered from one shared paginated release scan (already
implemented) and every one participates in `isBuilderBacked`, so an incomplete
scan aborts the run instead of publishing partial availability.

| runtime | accepted asset name | notes |
|---|---|---|
| `php` | `php-<x.y.z>-musl-dynamic-x86_64-<16 hex>.tar.gz` | replaces `glibc-full` |
| `redis` | `redis-<x.y.z>-musl-x86_64-<16 hex>.tar.gz` | unchanged (static musl) |
| `apache` | `apache-<x.y.z>-musl-dynamic-x86_64-<16 hex>.tar.gz` | new |
| `postgresql` | `postgresql-<x.y[.z]>-musl-dynamic-x86_64-<16 hex>.tar.gz` | new; PostgreSQL has used two-part versions since 10, so the version group is `\d+(?:\.\d+)+` |

Rules that stay as they are: URL basename must equal the asset name, only
`https://github.com/<builder>/releases/download/…` URLs are accepted, newest
release wins for a repeated patch, `sha256:<hex>` asset digests become the
catalog `sha256` map, and a discovery failure fails closed for these four apps.

`applyFallbackVersions` gains the same builder-owned-URL filtering for
`apache` and `postgresql` that `php`/`redis` already have, and the special case
that blanks those two on Linux is removed. Old cached catalogs therefore keep
only URLs the builder actually published; a successful empty scan still clears
them.

Linux app definitions keep `exec_file`/`cli_file` as ordinary names (`httpd`,
`postgres`/`psql`) and carry no package-manager metadata. An app with no
accepted bundle stays unavailable — no synthetic `latest`.

## Bundle validation (`PhpRuntimeBundle`)

Accept the producer's current PHP manifest:

- `schema_version == 1`, `runtime == "php"`, `architecture == "x86_64"`,
  `verification == "PASSED"`, `linkage == "dynamic"`.
- `target == "musl-dynamic"`. Any other target — `glibc` included — is a
  `FormatException`. No `profile` key exists in musl manifests and none is
  required.

Everything else — path containment, launcher identity, shared-module registry,
hash verification, exact-version match — is unchanged and still fails closed.

## Installation

### Shared

`_detectFiles`' recursive name search is ambiguous for these bundles: both
`bin/httpd` and `libexec/bin/httpd` (and `bin/initdb` vs `libexec/bin/initdb`)
exist, and the `libexec/` ELF is only runnable through the bundle's own musl
loader. For any app whose install root carries a `manifest.json` with
`runtime` in `{apache, postgresql}`, resolve the executable to
`<root>/bin/<name>` and never accept a `libexec/` path.

The manifests list their programs in different shapes — Apache uses
`launchers: ["httpd", …]` (strings), PostgreSQL uses
`binaries: [{path: "libexec/bin/initdb", …}, …]` (objects). Read either and
normalize to bare names; `<root>/bin/<name>` is the launcher to execute.

### Apache

Post-extract setup generates `<AppConfig.vhostsDir>/apache/httpd.conf` from the
bundle's `conf/httpd.conf`, leaving the bundle's own copy untouched. The
generator reuses `ApacheConfigBuilder.buildMainConfig` and adds:

- `Define SRVROOT` → installation root (so `ServerRoot`, `modules/`, `conf/`
  and `logs/` all resolve inside the bundle).
- `DocumentRoot` and its `<Directory>` → `AppConfig.webserverRoot`, with
  `AllowOverride All` / `Require all granted`.
- `Listen` lines normalized through `WebserverBindPolicy` (one HTTP listener,
  plus HTTPS when SSL is installed).
- `PidFile` and `ErrorLog` into `AppConfig.logsDir`.
- `ServerName localhost:80`.
- `LoadModule unixd_module modules/mod_unixd.so` when the module is not already
  loaded.
- `IncludeOptional "<vhosts>/apache/[!h]*.conf"`.

Two of these are not cosmetic, both verified against the real 2.4.66 bundle:

- The bracket expression is required. A plain `*.conf` glob matches `httpd.conf`
  itself and Apache dies with "Exceeded maximum include depth of 128".
- The shipped `httpd.conf` contains `<IfModule unixd_module>` and
  `User daemon`/`Group daemon` but never `LoadModule unixd_module`. Without the
  load the server refuses to start ("Server MUST relinquish startup privileges
  before accepting connections"), because `User` is then compiled out. With
  `mod_unixd` loaded it serves normally as an unprivileged process.

`setcap cap_net_bind_service=+ep` must target
`<root>/lib/musl/ld-musl-x86_64.so.1`, the file the kernel actually executes,
not the `bin/` shell launcher. Failure stays a logged warning; the generated
config is still valid either way.

The service manager already launches `httpd -DFOREGROUND -f
<vhosts>/apache/httpd.conf` for Linux, so it needs no change.

`configureIsolatedApache` today invents a config from `/etc/httpd` or
`/etc/apache2` and is reachable only from tests. It is replaced by the
bundle-sourced generator above, which is called from both the install pipeline
and `reconfigureWebservers`.

`webserverSettingsProvider` prefers the isolated config whenever it exists, so
the settings editor opens the file Apache really reads.

### PostgreSQL

Post-extract setup calls `configureIsolatedPostgresql` with the bundle's own
launcher:

- `resolveDbTool(installPath, 'initdb')` already resolves `<root>/bin/initdb`,
  which is the bundle's launcher script.
- The data directory `AppConfig.dataDir/postgresql-<version>` is exactly what
  the service manager computes for `postgres -D <dataDir> -k /tmp`.
- `initdb -E UTF8 --locale=C -A scram-sha-256 --pwfile` succeeds with the real
  bundle and `psql` connects afterwards; `unix_socket_directories` is set to
  `/tmp` to match the service manager's `-k /tmp`.

The install pipeline therefore stops calling the current
`_initializePostgresql` and calls `configureIsolatedPostgresql` instead, so
there is one cluster-initialization implementation rather than two. The Zonky
jar path (`isZonkyPgJar`, `_installFromZonkyJar`, `_extractZonkyJar`) is
deleted.

### Redis

Unchanged. `configureIsolatedRedis` still writes the `redis.conf` the service
manager launches with.

## Dead code removal

No part of this is optional cleanup: each item exists only to serve glibc, the
Zonky jar, or OS-package-managed installs, and keeping it means keeping
unreachable branches that no test can exercise meaningfully.

### Zonky jar

`isZonkyPgJar`, `_installFromZonkyJar`, `_extractZonkyJar`, the `isZonky` flag
threaded through `_extractPayload` and the download-extension choice, and
`test/features/apps/installer_linux_zonky_test.dart`. After removal a `.jar`
URL is just an unsupported extension like any other.

### System-package installs

The `system_package` marker and everything branching on it:

- `AppInstallerService.systemPackageMarker` and the legacy-record early return
  in `delete()`.
- The legacy uninstall branch in `apps_provider.dart` (record-only removal) —
  the marker no longer exists, so every install path is a real directory.
- `install_method` / `package_manager`: the `AppModel.installMethod` field, the
  `apps_repository` catalog filter, the `app_version_modal` install gate, the
  `app_installer_service` guard, and the `package_manager_commands` vocabulary.
  No shipped catalog carries `install_method`, and `PackageCommandValidator`
  already refuses every package-manager command.
- `resolvePhpIniPath`'s system-path candidate list
  (`/etc/php/<v>/fpm/php.ini`, `/etc/remi`, `/etc/php.d`, `/etc/php.ini`) and
  its `_extractPhpVersion` helper: the only remaining branch is
  `PhpRuntimeBundle.pathFor('php_ini')`, falling back to `<location>/php.ini`.
- The `system_package` branches in `php_settings_provider`, `redis_settings_provider`,
  `webserver_settings_provider` and `app_settings_modal` (legacy location label,
  system PHP ini resolution).

### System-PHP extension stack

Reachable only from `php_settings_provider.getLinuxExtensions` /
`toggleLinuxExtension`, both of which are themselves only reachable through the
`system_package` branch being removed. Delete:

- `lib/features/apps/data/linux_php_extension_driver.dart`
- `lib/features/apps/data/linux_php_extension_manager.dart`
- `lib/features/apps/data/linux_php_introspector.dart`
- `lib/features/apps/data/php_extension_drivers/` (arch, debian, rhel)
- `lib/features/apps/data/package_command_validator.dart`
- `lib/features/apps/data/php_config_command_runner.dart` (imported only by the
  manager)

Bundle PHP extension management (`getExtensions`/`toggleExtension` driven by
`PhpRuntimeBundle.sharedModules`) is untouched — that is the surviving path.

### System-binary helpers

- `findInstalledBinary` (whole `which` / candidate / tree-search resolver,
  referenced only by `installer_binary_resolver_test.dart`).
- `setLinuxCapabilityForWebserver`'s `allowSystemBinaries` parameter and its
  `/usr/sbin/{apache2,httpd,nginx,caddy}` allow-list; the `isInsideAppsDir`
  containment check stays and is the only policy.

### Distribution detection

`LinuxDistroResolver.detectFamily` and `resolveValkeyDistro` have no remaining
callers once the extension stack and package-manager vocabulary are gone, and no
catalog uses `{distro}`/`{valkey_distro}`.

**`LinuxDistroResolver.resolveUrl` and `resolveMongoDistro` stay**: the shipped
Linux catalog still needs `{mongo_distro}` substitution for MongoDB
(`app_installer_service.dart` calls `LinuxDistroResolver.resolveUrl(rawUrl)`).
Because `resolveMongoDistro` resolves through `detectCodename`, that helper
stays too — demoted to a private implementation detail rather than a
`@visibleForTesting` API. `parseOsRelease` and `detectVersionId` stay for the
same reason.

### Tests removed or rewritten

Deleted with their subjects: `installer_linux_zonky_test.dart`,
`installer_linux_package_manager_test.dart`, `linux_php_extension_manager_test.dart`,
`linux_php_introspector_test.dart`, `arch_php_extension_driver_test.dart`,
`debian_php_extension_driver_test.dart`, `rhel_php_extension_driver_test.dart`,
`php_settings_linux_branch_test.dart`, `php_ini_resolver_test.dart`,
`package_command_validator_test.dart`, `php_config_command_runner_test.dart`,
`presentation/widgets/app_settings_modal_linux_extensions_test.dart`.

Trimmed instead of deleted: `linux_distro_resolver_test.dart` (drops the
family and valkey groups; keeps `resolveUrl` and the `resolveMongoDistro`
cases, which now exercise codename detection indirectly),
`installer_binary_resolver_test.dart` (loses `findInstalledBinary` and the
`allowSystemBinaries` group), `apps_provider_uninstall_compatibility_test.dart`
and `app_installer_data_dir_test.dart` (drop the legacy-record cases),
`systemctl_service_test.dart` and `isolated_service_configs_test.dart` (drop
`installMethod: 'package_manager'` from fixtures).

Docs: `docs/linux-support-notes.md` and `README.md` drop the Zonky, "Apache
absent", and package-manager claims.

## Tests

Node (`test/assets/update_builder.test.js`, `update_php.test.js`,
`updater_test_helpers.cjs`): the fixture helper generalizes to
`bundleAsset(runtime, version, {target})` so PHP uses `musl-dynamic` and Redis
`musl`. Coverage: PHP pattern matches only `musl-dynamic`; Apache and
PostgreSQL discovery including the two-part PostgreSQL version; per-runtime
pagination; rejection of `glibc`/`aarch64` variants and of static-musl Apache;
newest-build preference; digest handling; fallback preservation for all four;
a failure in the shared scan still aborts before writing any catalog.

Flutter: fixture manifest moves to `target: 'musl-dynamic'` without `profile`,
plus a rejection case for `glibc`. `linux_catalog_test.dart` asserts
musl-dynamic PHP URLs, that Apache, PostgreSQL, Redis and PHP are all
installable, and that no Linux entry carries package-manager metadata. New
tests for the generated Apache config (`SRVROOT` from the bundle, bind policy,
`PidFile`/`ErrorLog` under logs, `[!h]*.conf` include, injected
`mod_unixd`), for launcher resolution ignoring `libexec/`, and for
`configureIsolatedPostgresql` being driven by the bundle manifest.

## Verification

Automated: full Node updater suite (via a `node:22` container, since this host
has no Node), full Flutter suite, `flutter analyze`.

Real execution, using a temporary `AppConfig` root so the user's live
installation is untouched: run the updater against the live GitHub API and
generate both catalogs; then, through the production installer code, download
and install PHP 8.4, Redis, Apache and PostgreSQL 18 from the generated URLs,
and prove each starts and answers:

- PHP-FPM listens on its configured port.
- Redis answers `PING`.
- PostgreSQL `psql` returns its version, then stops.
- Apache serves a page and reloads the generated config clean — under
  `unshare -r -n` because binding port 80 needs `CAP_NET_BIND_SERVICE` and this
  host has no passwordless sudo; the capability attempt itself is verified to
  run and report its warning.

Shipped `assets/data/apps-linux.json` is regenerated by the same run.
