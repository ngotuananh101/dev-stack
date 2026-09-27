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
| `Additional .ini files parsed` | paths joined by `,\n`, or `(none)` |
| `extension_dir` | three-column `extension_dir => <path> => <path>` (Directive / Local Value / Master Value) |

Two formatting details matter to the parser and were verified in php-src:

- Text mode uses `" => "` as the column separator (`ext/standard/info.c`, `php_info_print_table_row`), so every row is `Label => Value`; the three-column INI rows (`main/php_ini.c`, `display_ini_entries`) are `Name => LocalValue => MasterValue`.
- `Additional .ini files parsed` is **not** space-separated: `main/php_ini.c` joins scanned paths with `",\n"` and terminates with `"\n"`. Split on commas/newlines, not spaces.

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

**Two consequences that shape the design.**

1. *`isInstalled` is not the same as "the package is installed".* Some extensions are compiled statically into the FPM binary and have no `.so` at all. `opcache` is the concrete case: verified against all three families for PHP 8.5 —
   - Debian/sury `trixie`: there is **no `php8.5-opcache` package at all** (the series stops at `php8.4-opcache`); `opcache.so` appears nowhere under `usr/lib/php/20250925/`.
   - Remi `enterprise/9/php85`: `php-common` ships `/etc/php.d/10-opcache.ini`, but no `opcache.so` under `/usr/lib64/php/modules/`.
   - Arch `extra`: the `php` package ships 22 `.so` files under `/usr/lib/php/modules/` and none of them is `opcache.so`.

   So `opcache` is **enabled but has no package to install**. It must still be listed (it is one of the most commonly toggled extensions) and its switch must work by writing/commenting an ini line. This is why the state assembly merges two sources instead of deriving everything from packages.

2. *A module can be enabled by a file we did not write.* On RHEL/Remi the package ships `/etc/php.d/20-<ext>.ini` already active, so installing auto-enables. Disabling therefore has to neutralise the distro's own file, not only ours. `php-fpm -i`'s `Additional .ini files parsed` list tells us exactly which files were read, and those files are world-readable.

### 2.6 Per-distro enabling differs in kind

| | Debian/Ubuntu | RHEL/Fedora (incl. Remi) | Arch |
|---|---|---|---|
| Mechanism | `mods-available/*.ini` + per-SAPI `conf.d/` **symlinks** | regular files in `/etc/php.d/*.ini` | regular files in `/etc/php/conf.d/*.ini` |
| Enable | `phpenmod -v <v> -s fpm <mod>` | write `<scanDir>/99-ponta-<ext>.ini` | write `<scanDir>/99-ponta-<ext>.ini` |
| Disable | `phpdismod -v <v> -s fpm <mod>` | comment the loader line in every parsed ini | comment the loader line in every parsed ini |
| Auto-enabled on install | **Yes** — `postinst` runs `php_invoke enmod` for every installed SAPI | **Yes** — the rpm ships `20-<ext>.ini` | **No** for bundled exts (gd, pgsql, …) — the package ships only the `.so`; PECL exts ship a commented `.ini` |

The Debian auto-enable has one hole: `php8.5-mbstring` does not depend on `php8.5-fpm`, and `enmod` skips SAPIs whose `conf.d` directory does not exist yet. If the extension is installed before the FPM SAPI, it is not enabled for FPM and `phpenmod` must be run afterwards. The design always runs the enable step explicitly rather than relying on `postinst`.

On Arch, extension packages are named `php-<ext>` and bundled ones (`php-gd`, `php-pgsql`, `php-sqlite`, …) ship **only** `/usr/lib/php/modules/<ext>.so`. Installing them does not enable them.

Files written into any of these directories survive package upgrades: dpkg/rpm/pacman only remove or replace files in their own manifests, and our files are unowned. Load order is alphabetical, so a `99-` prefix loads last.

### 2.7 Package → extension mapping is read from the package's own file list

An earlier revision of this design assumed the extension name could be recovered by stripping a version prefix off the package name (`php8.5-mbstring` → `mbstring`, `php85-php-mbstring` → `mbstring`) and consulting a small exception table. **Real repository data refutes that.** Measured for PHP 8.5 against the actual indices the package managers download:

| Family | Repository | Packages | Shipping ≥1 `.so` | Package name ≠ extension name |
|---|---|---|---|---|
| Debian | sury `trixie` | 84 | 77 | 4 |
| RHEL/Fedora | Remi `enterprise/9/php85` | 341 | 194 | **162** |
| Arch | `extra` | 16 | 13 | 5 |

Two independent reasons the prefix heuristic cannot work:

1. **The name is often unrelated.** Remi's `php-common` ships `bz2`, `calendar`, `ctype`, `curl`, `exif`, `fileinfo`, `ftp`, `gettext`, `iconv`, `phar`, `tokenizer`; `php-pdo` ships `pdo`, `pdo_sqlite`, `sqlite3`; `php-process` ships `posix`, `shmop`, `sysvmsg`, `sysvsem`, `sysvshm`; `php-pecl-redis6` → `redis`; `php-pecl-xdebug3` → `xdebug`; `php-pecl-trie` → `php_trie`; `php-libvirt` → `libvirt-php`. On Debian, `php8.5-interbase` → `pdo_firebird` and `php8.5-sybase` → `pdo_dblib`.
2. **Two package naming schemes exist side-by-side in RHEL/Fedora.** Remi publishes two distinct repository layouts:
   - **Modular / base** (`enterprise/9/php85`, `fedora/41/modular`): packages are named `php-<ext>` (`php-common`, `php-pdo`, `php-pecl-redis6`), INIs live in `/etc/php.d/`, and `.so` modules live in `/usr/lib64/php/modules/`. This layout is used by the catalog's CentOS entry (`dnf module enable -y php:remi-8.5`).
   - **Software Collections (SCL)** (`enterprise/9/remi`, `fedora/41/remi`): packages are version-prefixed `php<N>-php-*` (`php85-php-common`, `php85-php-pecl-redis6`), INIs live in `/etc/opt/remi/php<N>/php.d/`, `.so` modules live in `/opt/remi/php<N>/root/usr/lib64/php/modules/`, and the binary lives at `/opt/remi/php<N>/root/usr/sbin/php-fpm`. This layout is used by the catalog's Fedora entry (`--enablerepo=remi php85-php-*`). Measured for PHP 8.5: the SCL repo ships **354** `php85-php-*` packages on EL9 and **267** on Fedora 41. Stripping `php85-php-` still fails on `php85-php-common` (which supplies 11 extensions) and `php85-php-pecl-redis6` (which supplies `redis`).

The correct rule needs no mapping table and no exclusion list:

> **An extension is a `.so` file whose immediate parent directory is the binary's `extension_dir`** (read from `php-fpm -i`, §2.1).

This is correct by construction. Junk is excluded automatically because it lives elsewhere: Remi's `php-embedded` ships `/usr/lib64/libphp.so`, `uwsgi-plugin-php` ships `/usr/lib64/uwsgi/php_plugin.so`, Arch's `php-apache` ships `/usr/lib/httpd/modules/libphp.so` and `php-embed` ships `/usr/lib/libphp.so` — all outside `/usr/lib64/php/modules` and `/usr/lib/php/modules` respectively. Debian's `php8.5-dev` ships build files *under* the ABI directory but no top-level `.so`. A package that is not an extension (or is one, like `php-common`) needs no special-casing either way.

`opcache` is the one extension this rule cannot reach, because it has no `.so` on any family (§2.5). It is supplied from the `php-fpm -m` side instead, which is also how a statically compiled extension is found.

### 2.8 Discovery commands

Two queries are needed: **which packages exist**, and **what files each ships**. The second is what produces extension names (§2.7).

| Distro | Packages | File lists |
|---|---|---|
| Debian/Ubuntu | `apt-cache search --names-only php8.5-` — one `name - description` per line | `apt-file list -x '^php8\.5-'` — requires a one-time `apt-file update` |
| RHEL/Fedora | `dnf repoquery --qf '[%{=NAME}\n]' 'php-*' 'php85-php-*'` | `dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\n]' 'php-*' 'php85-php-*'` — covers both modular and SCL layouts |
| Arch | `pacman -Ss php-` — `repo/name version` then an indented description | `pacman -Fl <pkg>…` — requires a one-time `pacman -Fy` |

Output formats, verified against each tool's own source or test suite:

- `apt-file list -x <regex>` prints `pkg: /path`, one line per file, sorted and de-duplicated (`lib/apt_file.pl`, `print_winners` → `print "$key: $_\n"`; the bundled test `list_regex1` expects `bash-debug: /usr/debug/bin/bash`). The leading `/` is present.
- `dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\n]'` prints `pkg /path` per line, with the leading `/` (rpm's documented "annotated file list", `rpm-queryformat.7`).
- `pacman -Fl <pkg>` prints `pkg /path` per line, **without** a leading `/` (`src/pacman/files.c`, `dump_file_list`: `printf("%s ", pkgname); printf("%s\n", file->name)` where `file->name` is relative to the root). The Arch driver must prepend `/` before comparing against `extension_dir`.

The separator is deliberately a **space, not a pipe**. An earlier draft used `%{=NAME}|%{FILENAMES}`, which `PackageCommandValidator` rejects: it splits every command on `|` to validate each pipeline segment separately, so a query format containing `|` becomes two segments and the second has no allowed leading binary. A space cannot appear in an rpm package name, so splitting on the first space is unambiguous.

All six commands are read-only and none needs root. The two bootstrap steps are the cost of exactness and are the reason this design depends on external tooling:

- `apt-file update` builds an index from the `Contents-<arch>` files. For sury's own repository that file is **133 KB** (`trixie`) / 134 KB (`bookworm`); the Debian archive's own is 11.6 MB. Debian ships `apt-file` separately from `apt`.
- `pacman -Fy` downloads the per-repository `.files` databases: `core.files` is 1.5 MB and `extra.files` is 51 MB, cached afterwards. **`pacman -Fy` does not require root.**

`dnf` needs no bootstrap because repositories already publish `filelists.xml` (Remi's is 88 KB) and `dnf repoquery` reads it directly.

If a bootstrap tool is absent (`apt-file` not installed), the driver reports discovery as unavailable rather than silently degrading to a name heuristic — a wrong list is worse than an honest error.

The mechanism matters and is easy to get wrong: discovery runs through `Process.run` (direct argv, **no shell**), so a missing executable makes Dart throw `ProcessException` — there is never an exit code 127 to inspect. The manager's `_runDiscovery` therefore has to catch `ProcessException` and rethrow it as the discovery-unavailable error; relying on an exit-127 check alone would let the exception fall into the generic catch, return `null`, and show the user a silently empty extension list. The exit-127 arm is retained only for fake runners that model the shell convention.

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
      DebianPhpExtensionDriver    apt-cache / apt-file / apt-get / phpenmod / phpdismod
      RhelPhpExtensionDriver      dnf repoquery (names + file lists) / dnf install
      ArchPhpExtensionDriver      pacman -Ss / pacman -Fl / pacman -S
```

The three drivers share one base class holding the logic that is identical everywhere (writing `99-ponta-<ext>.ini`, building the install+enable script, deciding which file lists to accept as extensions). Each subclass supplies only: the two discovery commands, the parsing of their output, the enable/disable commands, and the install command.

`LinuxPhpIntrospector` is instantiated with the **resolved php-fpm binary path** (`app.execFilePath`) and an injectable `runProcess`, so every code path is unit-testable without Linux or root.

### 3.1 State assembly

```dart
// 1. ask the binary
final info = await introspector.readInfo(binaryPath);        // scanDir, extensionDir
final enabled = await introspector.readModules(binaryPath);  // Set<String>

// 2. ask the package manager
final available = await driver.listAvailable(phpVersion);    // List<PackageCandidate>
//    each candidate carries the .so names its package ships (already filtered to
//    extensionDir by the driver), plus the description from the search command

// 3. index every extension any package can provide
final byExtension = <String, PackageCandidate>{};
for (final pkg in available) {
  for (final extName in pkg.extensionNames) {
    byExtension.putIfAbsent(extName, () => pkg);
  }
}

// 4. every enabled module the packages do not cover is still a real extension
//    (statically compiled, e.g. opcache) — synthesise a package-less entry
for (final extName in enabled) {
  byExtension.putIfAbsent(extName, () => PackageCandidate.none(extName));
}

// 5. build the list
for (final entry in byExtension.entries) {
  final extName = entry.key;
  final pkg = entry.value;
  PhpExtension(
    name: extName,
    isEnabled:   enabled.contains(extName),
    isInstalled: File('${info.extensionDir}/$extName.so').existsSync(),
    packageName: pkg.name,          // null for a synthesised entry
    description: pkg.description,   // null for a synthesised entry
    isZend:      driver.isZendExtension(extName),
  );
}
```

Steps 3–4 are why the two sources are merged rather than one being derived from the other. A package-only list would drop `opcache` and every other statically compiled module; a module-only list would drop everything not yet installed, which is precisely what the user needs to install.

`isFoundInIni` is retained for the Windows path; on Linux it is derived from `isEnabled || isInstalled`.

### 3.2 `opcache` and `xdebug` are no longer skipped on Linux

The current Windows implementation explicitly skips both:

```dart
if (lowerName == 'opcache' || lowerName == 'xdebug') continue;
```

On Linux both must be listed: they are among the most commonly toggled extensions. They are reached by different routes, which is why §3.1 merges two sources:

- `xdebug` is an ordinary extension package on every family (`php8.5-xdebug` on Debian, `php-pecl-xdebug3` → `xdebug.so` on Remi), so it arrives through the package list.
- `opcache` has **no `.so` on any family for PHP 8.5** (§2.5). It is compiled into the FPM binary and is already in `php-fpm -m`, so it arrives through the module list as a package-less entry. Toggling it writes or comments an ini line; there is nothing to install.

Because `opcache` is a **zend** extension, `isZendExtension('opcache')` must return true so the card renders the `ZEND` badge. Its *toggle* line is nevertheless **not** `zend_extension=opcache`: on a static build there is no `opcache.so` to load, and that line would only emit `Failed loading Zend extension` warnings. The real on/off switch is the INI boolean `opcache.enable=1` / `opcache.enable=0` (§2.5, §5.1). The Windows skip is left untouched.



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

`PhpSettings.getExtensions` keeps its signature and gains a Linux branch that delegates to the new subsystem. `toggleExtension` widens from `Future<void>` to `Future<String?>`: the Linux path returns the manager's message (which may carry the "PHP-FPM is not running — restart it to apply the change" note of §5.3), the Windows path returns `null`. This is source-compatible for every existing caller — they all just `await` and discard — and the modal only shows a snackbar when a non-empty message comes back, so the Windows UI is unchanged.

---

## 5. The Single-Switch Flow

### 5.1 Enabling

1. **Install**, if there is a package and it is not already installed. A package-less entry (§3.1, e.g. `opcache`) skips this step entirely.
2. **Enable**:
   - Debian: `phpenmod -v <phpVersion> -s fpm <name>`
   - RHEL/Arch: write `<scanDir>/99-ponta-<name>.ini` containing `extension=<name>` (or `zend_extension=<name>` when `isZend`). The write is `echo '<line>' | tee <file>` rather than a shell redirection, because `>` is a forbidden substring in `PackageCommandValidator` (§6.1) while `echo` and `tee` are both allowlisted. The target is left **unquoted** so the widened `_allowedTeeTargets` regex — which admits only `[\w.-]+\.ini` — is the thing that decides whether the write is legal.
   - Both enable steps are idempotent (`phpenmod` re-creates its symlink; `tee` overwrites our own file), so no "is it already loaded?" pre-check is needed. A distro-owned active ini for the same extension (§2.6) is harmless here: our file loads last (`99-` sorts after `20-`) and loading an already-loaded extension is a no-op.
3. **Reload** the running PHP-FPM master with `SIGUSR2` (no-op if not running) — §5.3.
4. **Re-introspect.** If `<name>` is **not** in `php-fpm -m` afterwards, surface a failure with the captured log — never report a false success. (Skipped for a static `opcache`, where `opcache.enable=0` leaves the module listed in `-m`; see §8.)

Steps 1 and 2 are written into **one temporary shell script executed through a single `pkexec` invocation**, so the user sees exactly one authorization prompt. This mirrors `AppInstallerService.executePackageManagerCommands`, which already does this for app installation.

### 5.2 Disabling

- Debian: `phpdismod -v <phpVersion> -s fpm <name>`
- RHEL/Arch: comment out the loader line in **every** ini the binary parsed — our own `99-ponta-<name>.ini` *and* any distro-owned ini that loads the same extension.

The second half is what makes disable actually work on RHEL. Remi ships `/etc/php.d/20-<ext>.ini` already active, so neutralising only our own file would leave the extension loaded and the switch would spring back on the next refresh. The manager already knows which files were read, from `php-fpm -i`'s `Additional .ini files parsed` (§2.1), and those files are world-readable, so it can find the owning file without guessing. Our own file is in that list too (it lives in `scanDir`, so a freshly spawned `php-fpm -i` reports it), which is why **one** code path covers both cases and no `rm` is needed — `rm` is not on the validator's allowlist.

Each matching line is commented out in place rather than deleted, so the change is reversible and the package's own manifest stays consistent:

```
extension=mbstring.so   →   ;extension=mbstring.so
```

This is a `sed -E -i 's,<pattern>,\x3b&,' <file>` invocation. Three details are load-bearing:

- The replacement is the **escape `\x3b`** (GNU sed), not a literal `;`: the validator forbids `;` anywhere in a command. PHP's ini scanner treats only `;` as a comment — `#` is *not* one — so this is not cosmetic.
- `,` is the **delimiter** rather than `/`, because the pattern itself contains `/` (the optional absolute-path group `(.*/)?`).
- The pattern is **anchored on the extension name**, so disabling `pdo` can never knock out `pdo_mysql`. `opcache` gets its own alternative (`^\s*opcache\.enable\s*=.*$`), because its line form is an assignment, not a loader line. Whitespace is matched with `\s`, not `[[:space:]]`: Dart's `RegExp` is ECMAScript, where `[[:space:]]` is not a POSIX class but the literal set `{[, :, s, p, a, c, e}` — so `^[[:space:]]*$` matches `":"` while *failing* to match a line of spaces. Every `\s` must sit in a **raw** Dart string literal; in a non-raw one, `'\s'` collapses to `s` and the anchor silently becomes `...s*$`.

`sed` is already on the validator's allowlist, so no new allowance is needed. But the allowlist does **not** constrain `sed`'s *target* — only its leading binary — so the file path must be gated by the manager itself. A bare `startsWith('/')` check is not enough, because the path is attacker-reachable (it is whatever `php-fpm -i` printed for `Additional .ini files parsed`, and a poisoned ini in a world-writable scan dir would appear there). Two failure modes, both verified by probe:

- `sed -i` would happily rewrite `/etc/shadow`, `/etc/sudoers`, or `/etc/systemd/system/*.service` — all of which pass `startsWith('/')`.
- The path is interpolated **inside single quotes**, so a filename containing `'` closes the quote early: `/etc/php.d/x.ini' -e 's,.*,PWNED,w /tmp/p' -e '` becomes extra `sed` expressions, and it contains none of the validator's forbidden substrings (`;`, `&&`, `` ` ``, `$(`, `>`, `<`), so `validate` returns null.

The gate is therefore structural — the file must be a **plain child of the scan dir the binary itself reported**, with a name that survives `isSafeName` (§6.2), which excludes `'`, `/`, spaces, and every other metacharacter:

```dart
if (p.posix.dirname(ini) != scanDir) continue;
if (!LinuxPhpExtensionDriver.isSafeName(p.posix.basename(ini))) continue;
```

Probed against a corpus: this blocks 10/10 hostile paths (`/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/root/.ssh/authorized_keys`, `..` traversal, quoted-name injection, nested subdirs, uppercase) and drops 0/6 legitimate ones (`/etc/php.d/…`, `/etc/php/conf.d/…`, `/etc/php/8.5/fpm/conf.d/…`).

Then reload. The package is never removed.

### 5.3 Reload

`BackgroundProcess` gains:

```dart
@visibleForTesting
static ({String executable, List<String> arguments}) buildLinuxReloadArgs(int pid) =>
    (executable: 'kill', arguments: ['-USR2', '--', '$pid']);
```

Notice: **no negative PID**. Unlike `buildLinuxKillArgs(pid)` which targets the process group (`-$pid`) to tear down workers alongside the master, `SIGUSR2` must target the **master PID only** (`$pid`). In php-fpm, worker processes reset `SIGUSR2` to `SIG_DFL` (default action: abnormal termination) via `fpm_signals_init_child()`. Sending `SIGUSR2` to the entire process group would instantly kill every active worker instead of letting the master perform a graceful reload. This matches the upstream systemd service definition (`ExecReload=/bin/kill -USR2 $MAINPID`).

The PID comes from `app.servicePid` (set in `AppServiceManager.start`). If the app is not running, reload is skipped silently. If the signal fails, the toggle still succeeded — the user is told a restart is needed.

## 6. Security

### 6.1 Allowlist additions

`PackageCommandValidator._allowedBinaries` gains:

- `apt-cache`, `apt-file` (read-only discovery; `apt-file` supplies the package file lists of §2.7)
- `pacman` (read-only discovery: `pacman -Ss`, `pacman -Fl`, and the `pacman -Fy` index refresh)
- `phpenmod`, `phpdismod` (enable/disable on Debian)

`PackageCommandValidator._allowedTeeTargets` is widened from `/etc/apt/sources.list.d/*.list` to also admit the ini files this feature writes:

```dart
RegExp(
  r'^(?:'
  r'/etc/apt/sources\.list\.d/[a-zA-Z0-9_.-]+\.list'
  r'|/etc/php\.d/[a-zA-Z0-9_.-]+\.ini'
  r'|/etc/php/conf\.d/[a-zA-Z0-9_.-]+\.ini'
  r'|/etc/php/\d+\.\d+/[a-z0-9_.-]+/conf\.d/[a-zA-Z0-9_.-]+\.ini'
  r'|/etc/opt/remi/php\d+/php\.d/[a-zA-Z0-9_.-]+\.ini'
  r')$',
);
```

This is a **tightening as much as a widening**: it covers RHEL/Remi modular (`/etc/php.d/`), Arch (`/etc/php/conf.d/`), Debian's versioned layout (`/etc/php/8.5/fpm/conf.d/`), and Remi's Software Collections layout on Fedora/RHEL (`/etc/opt/remi/php85/php.d/`). Each branch terminates in a single filename segment (`[a-zA-Z0-9_.-]+\.ini`) with no slash, and every path component explicitly disallows `..` directory traversal. It rejects `/etc/passwd`, `/root/.ssh/authorized_keys`, any `..` traversal (including `/etc/php/../../etc/evil.d/x.ini`), any non-`.ini` suffix, and arbitrary nested subdirectories. A tee target containing whitespace cannot match, which is why the write commands leave the path unquoted (§5.1).

`dnf`, `rpm`, `ln`, `systemctl`, `apt-get` are already present. `rm` is deliberately **not** added (§5.2). The forbidden-substring list (`` ` ``, `$(`, `;`, `&&`, `||`, `>`, `<`, …) is unchanged and still fail-closed.

Two constraints the query formats must respect, both checked by the validator:

- `%{...}` and `[` `]` are not forbidden substrings, so they are fine.
- **`|` is not usable as a separator** — the validator splits on `|` to check each pipeline segment, so a format containing it is rejected. This is why the RHEL file-list format separates package from path with a space (§2.8).

The exact command strings are asserted against the validator in each driver's test so this stays true.

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

- A package-name label (e.g. `php8.5-mbstring`) next to the existing `ZEND` badge, rendered muted and small so it reads as metadata rather than a second title.
- A "Not installed" chip when `!isInstalled`, so the user understands the switch will trigger a download.
- The existing switch drives install+enable in one action; while running, the card shows a spinner **in place of** the switch (the switch is removed, not merely disabled, so a second tap is impossible).

The search field filters on extension name and package name. The `x/y Active` counter continues to count `isEnabled`.

Two supporting changes make the UI honest about Linux failures:

- `_loadExtensions` catches `UnsupportedError` (an unsupported distro family, or a missing `apt-file`) and renders a message with a Retry button. Without the catch, an unsupported host would leave the tab spinning forever and the exception would escape the widget tree.
- `_toggleExtension` tracks the in-flight extension in a `Set<String>` so the card can show a spinner in place of the switch, and surfaces the provider's message in a snackbar — success-coloured for the manager's note, error-coloured for a thrown failure.

---

## 8. Testing

| Layer | What is asserted |
|---|---|
| `LinuxPhpIntrospector` | Parses real `php-fpm -i` text fixtures → `scanDir`, `extensionDir`, ini list. Parses `-m` → module set. Handles `(none)`. |
| Each driver | Given a fake `runProcess` returning captured distro output, produces the correct `List<PackageCandidate>` and the correct extension names. |
| Package→extension mapping | A file list yields exactly the `.so` names whose parent directory is `extensionDir` (§2.7). Table-driven cases: Remi `php-common` → its 11 extensions; `php-pdo` → `pdo`, `pdo_sqlite`, `sqlite3`; `php-pecl-redis6` → `redis`; `php-pecl-trie` → `php_trie`; Debian `php8.5-interbase` → `pdo_firebird`; Debian `php8.5-common` → its 17. Junk outside `extensionDir` is rejected: Remi `php-embedded`'s `libphp.so`, `uwsgi-plugin-php`'s `php_plugin.so`, Arch `php-apache`'s `libphp.so`. |
| Statically compiled extension | `opcache` (in `php-fpm -m`, in no file list, no `.so`) is listed, marked `isZend`, and its toggle writes `opcache.enable=1` — not `zend_extension=opcache`. |
| Enable/disable commands | Exact argv produced per driver per family, including `isZend` → `zend_extension`. |
| Disable neutralises a distro-owned ini | Given a fixture ini in the parsed-ini list, disabling comments out the matching `extension=` line rather than deleting it. |
| Injection guard | Malicious names (`mbstring; rm -rf /`, `a$(id)`, backtick) are rejected. |
| `PackageCommandValidator` | New binaries accepted; existing rejections still hold. |
| `buildLinuxReloadArgs` | Emits `kill -USR2 -- <pid>` (master only, not process group). |
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
- `lib/features/apps/data/package_command_validator.dart` — five new allowed binaries (`apt-cache`, `apt-file`, `pacman`, `phpenmod`, `phpdismod`)
- `lib/core/services/background_process.dart` — `buildLinuxReloadArgs`
- `lib/features/apps/presentation/widgets/app_settings_modal.dart` — badge + "Not installed" chip + busy state

---

## 10. Open Questions

None. Every platform fact in §2 is verified; the remaining decisions (distro scope, discovery method, single switch, disable-not-uninstall, auto graceful reload, allowlist extension, distro packages only) were confirmed with the user during design.
