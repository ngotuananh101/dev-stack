# Design Document: Linux PHP Extension Management

**Date:** 2026-09-25
**Topic:** Discovering, installing, enabling and disabling PHP extensions on Linux via distro package managers
**Status:** Draft — awaiting review

---

## 1. Overview & Objectives

The Extensions tab of the app-settings modal works on Windows but is **completely empty on Linux**. This document specifies a replacement that discovers every installable extension for the installed PHP version, and lets the user install and toggle each one with a single switch.

### 1.1 Root cause

`PhpSettings.getExtensions()` in `lib/features/apps/data/php_settings_provider.dart` begins with:

```dart
final extDir = Directory('${app.location}${Platform.pathSeparator}ext');
if (!await extDir.exists()) return [];
```

Linux package-manager installs set `app.location == AppInstallerService.systemPackageMarker` (`"system_package"`), which is not a real directory. The method therefore returns `[]` unconditionally. `toggleExtension()` has the same problem: it builds a Windows-style absolute path `<location>/ext/<file>.dll|.so` and appends it to `php.ini` — meaningless on Linux, where extensions are loaded by module name from a distro-managed scan directory.

### 1.2 Goals

- Discover **all installable** extensions for the installed PHP version by querying the distro package manager (not a static embedded list).
- Discover the **real** `extension_dir` and ini scan directory from the PHP binary itself, never from hardcoded per-distro paths.
- Support **Debian/Ubuntu (apt), RHEL/CentOS/Fedora (dnf), Arch (pacman)**.
- One switch per extension: turning on a not-yet-installed extension installs **and** enables it under a single elevation prompt.
- Turning off disables only; the package is never removed.
- Reload the running PHP-FPM automatically (graceful, same PID) so the change takes effect immediately.
- Leave the Windows code path completely unchanged.

### 1.3 Non-goals

- **PECL** (`pecl install …`). Distro packages only. PECL needs a compiler toolchain and multi-minute builds; it is out of scope.
- Removing packages. Disable never uninstalls.
- Managing extensions for the CLI SAPI or Apache `mod_php`. The scope is the PHP-FPM SAPI that Ponta runs.
- Changing anything about how Windows extensions are discovered or toggled.

---

## 2. Verified Platform Facts

Every claim below was verified against php-src, distro packaging repositories, or extracted package contents during design. They are load-bearing: the architecture in §3 depends on each one.

### 2.1 `php-fpm -i` reveals the effective configuration

`php-fpm` accepts `-i` (`--info`) and, unlike `php-cgi -i`, forces `phpinfo_as_text = 1`, producing plain `Label => Value` text. The FPM-specific option table in `sapi/fpm/fpm/fpm_main.c` includes `-c`, `-d`, `-i`, `-m`, `-n`, `-y`, `-t`, `-tt`.

The `-i` block runs `cgi_sapi_module.startup()` (→ `php_module_startup()` → `php_init_config()`, which loads `php.ini` and the scan dir), calls `php_print_info(0xFFFFFFFF)`, then exits **before `fpm_init()` is reached**. Consequences:

- It does **not** need `-y` to exist.
- It does **not** daemonize.
- It does **not** bind a socket.
- It does **not** refuse to run as root (the root check lives in `fpm_init`).

Labels it prints (stable from PHP 7.4 through 8.5), with `=>` separator:

| Label | Value |
|---|---|
| `Configuration File (php.ini) Path` | e.g. `/etc/php/8.2/fpm` |
| `Loaded Configuration File` | path, or `(none)` |
| `Scan this dir for additional .ini files` | path, or `(none)` |
| `Additional .ini files parsed` | space-separated list, or `(none)` |
| `extension_dir` | two-column `Local Value => Master Value` |

`php-fpm -m` prints `[PHP Modules]` / `[Zend Modules]` sections, one module name per line, alphabetically. It likewise exits before `fpm_init()` and needs neither root nor `-y`.

`php-fpm` does **not** support `-r` or `--ri` (CLI-only), nor `--ini`.

### 2.2 The scan directory is a property of the binary

Debian/Ubuntu build **one binary per SAPI**, each compiled with its own `--with-config-file-path` and `--with-config-file-scan-dir`. `php8.2-fpm`'s scan dir is `/etc/php/8.2/fpm/conf.d`; `php8.2-cli`'s is `/etc/php/8.2/cli/conf.d`. The `-y` flag only names the FPM **pool** config and never affects ini loading. The FPM SAPI sets `php_ini_ignore_cwd = 1`, so the working directory is not searched.

Therefore a binary spawned directly by Ponta via `Process.start` — with no `PHP_INI_SCAN_DIR` in its environment, not under systemd — loads exactly the same ini files the packaged systemd service would. The Debian `php8.2-fpm.service` unit sets no `Environment=` directives and no sandboxing directives.

### 2.3 `PHP_INI_SCAN_DIR` is honoured by the FPM master

`php_init_config()` reads `PHP_INI_SCAN_DIR` via `getenv()`, and the scan is gated only on `!sapi_module.php_ini_ignore`, which is `0` for FPM. The FPM master consumes the variable during startup, **before** forking workers; workers inherit the parsed configuration. The pool's `clear_env` (default `Yes`) clears the worker environment afterwards but cannot un-load ini entries.

An empty component in the value means "the compile-time default", so `:/custom/dir` **extends** rather than replaces.

### 2.4 `SIGUSR2` reloads the master in place

`SIGUSR2` → `fpm_pctl_exec()` → `execvp(saved_argv[0], saved_argv)`. `execvp` preserves the PID (POSIX), and the re-executed `main()` calls `php_module_startup()` → `php_init_config()`, re-reading `php.ini` and every scanned ini file, then re-reads `php-fpm.conf`. The upstream systemd unit uses `ExecReload=/bin/kill -USR2 $MAINPID`.

php-fpm's installed signal handlers are `SIGTERM`, `SIGINT`, `SIGUSR1`, `SIGUSR2`, `SIGCHLD`, `SIGQUIT`. **`SIGHUP` is not handled** — using it would kill the process.

### 2.5 Extension state is observable without querying the package database

- **Enabled** ⟺ module name ∈ `php-fpm -m`.
- **Installed** ⟺ `File('$extensionDir/<name>.so').existsSync()`.

Both are distro-neutral. Duplicate loads are non-fatal: a regular extension emits `E_CORE_WARNING: Module "X" is already loaded`; a zend extension prints `Cannot load X - it was already loaded` to stderr. The first load wins.

### 2.6 Per-distro enabling differs in kind

| | Debian/Ubuntu | RHEL/Fedora (incl. Remi) | Arch |
|---|---|---|---|
| Mechanism | `mods-available/*.ini` + per-SAPI `conf.d/` **symlinks** | regular files in `/etc/php.d/*.ini` | regular files in `/etc/php/conf.d/*.ini` |
| Enable | `phpenmod -v <v> -s fpm <mod>` | write `<scanDir>/99-ponta-<ext>.ini` | write `<scanDir>/99-ponta-<ext>.ini` |
| Disable | `phpdismod -v <v> -s fpm <mod>` | comment/remove our file | comment/remove our file |
| Auto-enabled on install | **Yes** — `postinst` runs `php_invoke enmod` for every installed SAPI | **Yes** — the rpm ships `20-<ext>.ini` | **No** for bundled exts (gd, pgsql, …) — the package ships only the `.so`; PECL exts ship a commented `.ini` |

The Debian auto-enable has one hole: `php8.5-mbstring` does not depend on `php8.5-fpm`, and `enmod` skips SAPIs whose `conf.d` directory does not exist yet. If the extension is installed before the FPM SAPI, it is not enabled for FPM and `phpenmod` must be run afterwards. The design always runs the enable step explicitly rather than relying on `postinst`.

On Arch, extension packages are named `php-<ext>` and bundled ones (`php-gd`, `php-pgsql`, `php-sqlite`, …) ship **only** `/usr/lib/php/modules/<ext>.so`. Installing them does not enable them.

Files written into any of these directories survive package upgrades: dpkg/rpm/pacman only remove or replace files in their own manifests, and our files are unowned. Load order is alphabetical, so a `99-` prefix loads last.

### 2.7 Package → extension name mapping is many-to-many

Debian packages that do **not** map 1:1:

| Package | Ships |
|---|---|
| `php8.5-mysql` | `mysqlnd`, `mysqli`, `pdo_mysql` |
| `php8.5-xml` | `dom`, `simplexml`, `xml`, `xmlreader`, `xmlwriter`, `xsl` |
| `php8.5-common` | 17 extensions incl. `ctype`, `fileinfo`, `iconv`, `phar`, `posix`, `sockets`, `tokenizer` |
| `php8.5-opcache` | `opcache` (a **zend** extension) |

Packages that are **not** extensions and must be excluded from discovery: `php8.5-cli`, `php8.5-fpm`, `php8.5-dev`, `php8.5-dbg`, `php8.5-phpdbg`, `php8.5-cgi`, `php8.5-apache2`. (`php8.5-common` is **not** excluded — it ships 17 real extensions.)

A package is offered if, after stripping the version prefix, its suffix resolves through the driver's mapping table to at least one extension name and is not on the exclusion list. The `.so` existence check is used **only** to compute `isInstalled` — never to decide whether to list, since a not-yet-installed extension has no `.so` by definition.

### 2.8 Discovery commands

| Distro | List installable | Notes |
|---|---|---|
| Debian/Ubuntu | `apt-cache search --names-only php8.5-` | one `name - description` per line |
| RHEL/Fedora | `dnf list available 'php85-php-*'` (Remi SCL) / `'php-*'` (modular) | |
| Arch | `pacman -Ss php-` | `repo/name version` then indented description |

### 2.9 `detectFamily()` originally did not recognise Arch — **already fixed**

`LinuxDistroResolver.detectFamily()` used to return only `ubuntu`, `debian`, `centos`, `fedora`, or `unknown`. An Arch host has `ID=arch` and no `ID_LIKE` matching any known family, so it fell through to the final `return 'ubuntu'` — Arch was **silently misidentified as Ubuntu**, and `_installViaPackageManager` ran `apt-get` on a system that has no apt.

The Arch branch has since been added to `detectFamily()` (committed separately, ahead of this design's implementation):

```dart
if (id == 'arch' || idLike.contains('arch')) return 'arch';
```

It is placed after the Fedora branch and before the final `return 'ubuntu'`, so Arch derivatives declaring `ID_LIKE="arch"` (manjaro, endeavour) also resolve to `arch`. The `arch` value is documented in the method's doc comment as a deliberate return even though the bundled catalog defines no `package_manager_commands` entry for it: callers now fail with an explicit *"Unsupported Linux distribution: arch"* message instead of silently invoking apt-get.

The silent `ubuntu` fallback for genuinely unknown distros (`ID=nixos`, …) is left as-is for the existing installer path. The extension manager must not rely on it: its driver factory treats `ubuntu`/`debian` as Debian-family, `centos`/`fedora` as RHEL-family, `arch` as Arch, and **`unknown` as unsupported** (show a message rather than guessing).

---

## 3. Architecture

```
LinuxPhpExtensionManager                 (orchestration + state assembly)
│
├── LinuxPhpIntrospector                 (shared by all distros)
│     php-fpm -i   → scanDir, extensionDir, parsed ini files
│     php-fpm -m   → set of ENABLED module names
│
└── LinuxPhpExtensionDriver              (abstract; one implementation per family)
      DebianPhpExtensionDriver    apt-cache / apt-get / phpenmod / phpdismod
      RhelPhpExtensionDriver      dnf list / dnf install / write conf.d
      ArchPhpExtensionDriver      pacman -Ss / pacman -S / write conf.d
```

The three drivers share one base class holding the logic that is identical everywhere (writing `99-ponta-<ext>.ini`, building the install+enable script, parsing `php-fpm -m`). Each subclass supplies only: the discovery command, the package-name↔extension-name mapping, the enable/disable commands, and the install command.

`LinuxPhpIntrospector` is instantiated with the **resolved php-fpm binary path** (`app.execFilePath`) and an injectable `runProcess`, so every code path is unit-testable without Linux or root.

### 3.1 State assembly

```dart
// 1. ask the binary
final info = await introspector.readInfo(binaryPath);   // scanDir, extensionDir
final enabled = await introspector.readModules(binaryPath); // Set<String>

// 2. ask the package manager
final available = await driver.listAvailable(phpVersion);   // List<PackageCandidate>

// 3. merge
for (final pkg in available) {
  for (final extName in driver.extensionNamesFor(pkg)) {
    PhpExtension(
      name: extName,
      isEnabled:   enabled.contains(extName),
      isInstalled: File('${info.extensionDir}/$extName.so').existsSync(),
      packageName: pkg.name,
      description: pkg.description,
      isZend:      driver.isZendExtension(extName),
    );
  }
}
```

`isFoundInIni` is retained for the Windows path; on Linux it is derived from `isEnabled || isInstalled`.

### 3.2 `opcache` and `xdebug` are no longer skipped on Linux

The current Windows implementation explicitly skips both:

```dart
if (lowerName == 'opcache' || lowerName == 'xdebug') continue;
```

On Linux they are ordinary installable packages (`php8.5-opcache`, `php8.5-xdebug` from sury/Remi) and are among the most commonly toggled extensions, so the Linux path **must list them**. `opcache` is shipped by a dedicated package and is a **zend** extension, so its enable line is `zend_extension=opcache` and its mapping entry must set `isZend: true`. The Windows skip is left untouched.

---

## 4. Data Model

`PhpExtension` moves from `php_settings_provider.dart` to a new file `lib/features/apps/domain/php_extension.dart` and gains three fields:

```dart
class PhpExtension {
  final String name;          // 'mbstring'
  final String fileName;      // 'mbstring.so' (Linux) / 'php_mbstring.dll' (Windows)
  final bool isEnabled;
  final bool isFoundInIni;
  final bool isZend;
  final bool isInstalled;     // NEW — always true on Windows
  final String? packageName;  // NEW — 'php8.5-mbstring'; null on Windows
  final String? description;  // NEW — from the package manager; null on Windows
}
```

The existing `PhpSettings.getExtensions` / `toggleExtension` keep their signatures so the Windows call sites in `app_settings_modal.dart` are untouched; on Linux they delegate to the new subsystem.

---

## 5. The Single-Switch Flow

### 5.1 Enabling

1. If `!isInstalled` → install the package (elevated).
2. Enable the extension:
   - Debian: `phpenmod -v <phpVersion> -s fpm <name>`
   - RHEL/Arch: write `<scanDir>/99-ponta-<name>.ini` containing `extension=<name>` (or `zend_extension=<name>` when `isZend`).
3. Reload the running PHP-FPM master with `SIGUSR2` (no-op if not running).
4. Re-introspect. If `<name>` is **not** in `php-fpm -m` afterwards, surface a failure with the captured log — never report a false success.

Steps 1 and 2 are written into **one temporary shell script executed through a single `pkexec` invocation**, so the user sees exactly one authorization prompt. This mirrors `AppInstallerService.executePackageManagerCommands`, which already does this for app installation.

### 5.2 Disabling

- Debian: `phpdismod -v <phpVersion> -s fpm <name>`
- RHEL/Arch: delete `<scanDir>/99-ponta-<name>.ini` if we wrote it; otherwise comment the `extension=` line in the owning distro file.

Then reload. The package is never removed.

### 5.3 Reload

`BackgroundProcess` gains:

```dart
@visibleForTesting
static ({String executable, List<String> arguments}) buildLinuxReloadArgs(int pid) =>
    (executable: 'kill', arguments: ['-USR2', '--', '-$pid']);
```

The PID comes from `app.servicePid` (set in `AppServiceManager.start`). If the app is not running, reload is skipped silently. If the signal fails, the toggle still succeeded — the user is told a restart is needed.

---

## 6. Security

### 6.1 Allowlist additions

`PackageCommandValidator._allowedBinaries` gains:

- `apt-cache` (read-only discovery)
- `pacman` (read-only discovery; `pacman -Ss`)
- `phpenmod`, `phpdismod` (enable/disable on Debian)

`dnf`, `rpm`, `ln`, `systemctl`, `apt-get` are already present. The forbidden-substring list (`` ` ``, `$(`, `;`, `&&`, `||`, `>`, `<`, …) is unchanged and still fail-closed.

### 6.2 Injection defence

Extension and package names are derived from **package-manager output**, which is a semi-trusted source. Before any name is interpolated into a command, it must match:

```dart
RegExp(r'^[a-z0-9][a-z0-9._+-]*$')
```

Names failing this are dropped from the list, not sanitised.

### 6.3 Elevation model

Unchanged from the existing app-install path: prefer passwordless `sudo -n true`, else `pkexec sh <script>`. The script is written to a `Directory.systemTemp.createTemp` directory, `chmod 755`, and deleted in a `finally`. Note that the self-generated wrapper script does not pass through `PackageCommandValidator` — this matches the existing `buildPackageManagerScript` behaviour; validation happens on the individual commands before they are written.

---

## 7. UI

`_buildExtensionCard` in `app_settings_modal.dart` gains:

- A package-name badge (e.g. `php8.5-mbstring`) next to the existing `ZEND` badge.
- A muted "Not installed" chip when `!isInstalled`, so the user understands the switch will trigger a download.
- The existing switch drives install+enable in one action; while running, the card shows a spinner and the switch is disabled.

The search field filters on extension name and package name. The `x/y Active` counter continues to count `isEnabled`.

The `_loadExtensions` / `_toggleExtension` methods keep their shape; only the provider implementation behind them changes.

---

## 8. Testing

| Layer | What is asserted |
|---|---|
| `LinuxPhpIntrospector` | Parses real `php-fpm -i` text fixtures → `scanDir`, `extensionDir`, ini list. Parses `-m` → module set. Handles `(none)`. |
| Each driver | Given a fake `runProcess` returning captured distro output, produces the correct `List<PackageCandidate>` and the correct extension names. |
| Package→extension mapping | Every exception in §2.7, as a table-driven test. Non-extension packages are excluded. `opcache` is included and marked `isZend`. |
| Enable/disable commands | Exact argv produced per driver per family, including `isZend` → `zend_extension`. |
| Injection guard | Malicious names (`mbstring; rm -rf /`, `a$(id)`, backtick) are rejected. |
| `PackageCommandValidator` | New binaries accepted; existing rejections still hold. |
| `buildLinuxReloadArgs` | Emits `kill -USR2 -- -<pid>`. |
| `app_settings_modal` widget | Renders "Not installed" for an uninstalled extension; toggling calls install+enable; spinner while in flight. |
| Regression | All existing Windows extension tests still pass unchanged. |

Tests run on Windows CI; every Linux code path is exercised through the injectable `runProcess` and string fixtures, so no Linux host is required.

---

## 9. Files Touched

**New**

- `lib/features/apps/domain/php_extension.dart`
- `lib/features/apps/data/linux_php_introspector.dart`
- `lib/features/apps/data/linux_php_extension_driver.dart` (abstract base + factory)
- `lib/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart`
- `lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart`
- `lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart`
- `lib/features/apps/data/linux_php_extension_manager.dart`

**Modified**

- `lib/core/services/linux_distro_resolver.dart` — **already done** (separate commit, ahead of this work): `arch` branch added to `detectFamily()`, doc comment updated, `test/core/services/linux_distro_resolver_test.dart` covers `ID=arch`, `ID_LIKE=arch`, and the unknown-distro fallback (§2.9)
- `lib/features/apps/data/php_settings_provider.dart` — Linux branch delegates; `PhpExtension` re-exported from its new home
- `lib/features/apps/data/package_command_validator.dart` — four new allowed binaries
- `lib/core/services/background_process.dart` — `buildLinuxReloadArgs`
- `lib/features/apps/presentation/widgets/app_settings_modal.dart` — badge + "Not installed" chip + busy state

---

## 10. Open Questions

None. Every platform fact in §2 is verified; the remaining decisions (distro scope, discovery method, single switch, disable-not-uninstall, auto graceful reload, allowlist extension, distro packages only) were confirmed with the user during design.
