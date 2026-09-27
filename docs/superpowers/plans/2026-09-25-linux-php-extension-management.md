# Linux PHP Extension Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app-settings Extensions tab work on Linux — discovering every installable PHP extension for the installed PHP version from the distro package manager, and installing / enabling / disabling each one with a single switch.

**Architecture:** A new `LinuxPhpExtensionManager` orchestrates three collaborators. `LinuxPhpIntrospector` asks the resolved `php-fpm` binary itself for its scan dir, extension dir, parsed ini files (`php-fpm -i`) and enabled module set (`php-fpm -m`). A per-distro `LinuxPhpExtensionDriver` (Debian / RHEL / Arch) supplies package discovery, the package→extension mapping, and enable/disable. The manager merges the two sources into `PhpExtension` values, and runs install+enable under one elevation prompt via the existing `AppInstallerService.executePackageManagerCommands`, then reloads the running FPM master with `SIGUSR2`.

**Tech Stack:** Dart 3.10+, Flutter Desktop, Riverpod 3 (codegen), POSIX process signals (`SIGUSR2`), APT / DNF / pacman, `php-fpm -i` / `php-fpm -m` introspection.

**Spec:** `docs/superpowers/specs/2026-09-25-linux-php-extension-management-design.md`

## Global Constraints

- 100% backward compatibility on Windows: every existing Windows extension test must keep passing unchanged, and the Windows branch of `PhpSettings.getExtensions` / `toggleExtension` must not change behaviour.
- `PhpExtension` must keep its existing constructor parameters working: existing call sites construct it with `name`, `fileName`, `isEnabled`, `isFoundInIni`, `isZend` only. New fields must be optional with defaults.
- Never hardcode per-distro ini scan paths or `extension_dir`; always read them from `php-fpm -i`. The only per-distro literals allowed are package-manager binaries and package-name patterns.
- Extension and package names derived from package-manager output must match `RegExp(r'^[a-z0-9][a-z0-9._+-]*$')` before being interpolated into any command. Non-matching names are dropped, not sanitised.
- Every shell command executed through the existing catalog path must pass `PackageCommandValidator.validateAll`. Self-generated wrapper scripts (the `executePackageManagerCommands` temp script) are exempt, matching the existing `buildPackageManagerScript` behaviour.
- Disable never uninstalls: the package stays on disk.
- `SIGUSR2` is sent to the **master PID only** (`$pid`), never the process group (`-$pid`). Workers reset `SIGUSR2` to `SIG_DFL` in `fpm_signals_init_child()`, so a group signal would kill them abruptly.
- Tests run on Windows CI. Every Linux code path is exercised through injectable `runProcess` / string fixtures; no Linux host is required.
- `dart analyze` is the real gate in this repo (it reports issues that `flutter analyze` misses). Run it on the whole project before declaring a task done.

## Review Focus

Input classes and failure modes the spec implies but that no task's happy-path test exercises. Each is pinned to a test in the task that owns the code.

1. **`php-fpm -i` output where a field is `(none)`** (no `php.ini` loaded, or an empty scan dir). A reasonable user expects the extension list to still render, not to crash on a missing value.
2. **`php-fpm -m` output containing a module with no corresponding `.so` on disk** (a statically compiled extension). A reasonable user expects it listed as enabled, not hidden.
3. **A package-manager name that fails the safety regex** (`mbstring; rm -rf /`, a backtick, `$(id)`). A reasonable user expects the entry to be dropped silently and every other extension to still work.
4. **The FPM master not running when a toggle completes.** A reasonable user expects the toggle to be reported as successful with a "restart needed" note, not as a failure.
5. **A distro whose family is `unknown`** (non-Linux, or an unrecognised `ID`). A reasonable user expects an explicit "unsupported" message rather than a guessed package manager.

---

### Task 1: `buildLinuxReloadArgs` on `BackgroundProcess`

**Files:**
- Modify: `lib/core/services/background_process.dart` (add next to `buildLinuxKillArgs`, around line 69)
- Test: `test/core/services/background_process_linux_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `static ({String executable, List<String> arguments}) BackgroundProcess.buildLinuxReloadArgs(int pid)` — returns `(executable: 'kill', arguments: ['-USR2', '--', '$pid'])`. Used by Task 8.

- [ ] **Step 1: Write the failing test**

In `test/core/services/background_process_linux_test.dart`, add to the existing `group('BackgroundProcess command formatting', ...)` block, right after the `builds Linux kill command arguments with negative PID for process group` test:

```dart
    test('builds Linux reload command targeting the master PID, not the group', () {
      final cmd = BackgroundProcess.buildLinuxReloadArgs(12345);
      expect(cmd.executable, equals('kill'));
      // No leading '-' on the PID: SIGUSR2 must reach only the php-fpm master.
      // Workers reset SIGUSR2 to SIG_DFL, so a group signal would kill them.
      expect(cmd.arguments, equals(['-USR2', '--', '12345']));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/background_process_linux_test.dart`
Expected: FAIL — compile error, `The method 'buildLinuxReloadArgs' isn't defined for the type 'BackgroundProcess'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/services/background_process.dart`, immediately after `buildLinuxKillArgs` (line 69-71):

```dart
  /// Builds the argv that asks a running php-fpm master to reload in place.
  ///
  /// Unlike [buildLinuxKillArgs], the PID is **not** negated. `SIGUSR2` must be
  /// delivered to the master process only: php-fpm workers reset `SIGUSR2` to
  /// `SIG_DFL` in `fpm_signals_init_child()`, so signalling the whole process
  /// group would terminate every worker instead of triggering a graceful
  /// reload. Upstream systemd uses `ExecReload=/bin/kill -USR2 $MAINPID`.
  @visibleForTesting
  static ({String executable, List<String> arguments}) buildLinuxReloadArgs(int pid) {
    return (executable: 'kill', arguments: ['-USR2', '--', '$pid']);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/background_process_linux_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/background_process.dart test/core/services/background_process_linux_test.dart
git commit -m "feat: add buildLinuxReloadArgs for SIGUSR2 php-fpm reload"
```

---

### Task 2: Extend `PackageCommandValidator` allowlist

**Files:**
- Modify: `lib/features/apps/data/package_command_validator.dart` (the `_allowedBinaries` set, lines 20-45)
- Test: `test/features/apps/package_command_validator_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `PackageCommandValidator.validate` now accepts `apt-cache`, `apt-file`, `pacman`, `phpenmod`, `phpdismod` as leading binaries, and `tee` may write into a PHP ini directory (the manager's enable/disable step of Task 8). Used by Task 8.

- [ ] **Step 1: Write the failing test**

In `test/features/apps/package_command_validator_test.dart`, add a new group inside the top-level `group('PackageCommandValidator', ...)`, after the `catalog commands (positive cases)` group:

```dart
    group('extension management binaries', () {
      test('accepts read-only discovery commands', () {
        expect(PackageCommandValidator.validate('apt-cache search --names-only php8.5-'), isNull);
        expect(PackageCommandValidator.validate('apt-file list -x ^php8\\.5-'), isNull);
        expect(PackageCommandValidator.validate('pacman -Ss php-'), isNull);
        expect(PackageCommandValidator.validate('pacman -Fy'), isNull);
        expect(PackageCommandValidator.validate('pacman -Fl php-gd'), isNull);
        expect(PackageCommandValidator.validate("dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'"), isNull);
      });

      test('accepts the RHEL annotated file list query format', () {
        // The separator is a space, never a pipe: the validator splits every
        // command on '|' to validate pipeline segments separately.
        expect(
          PackageCommandValidator.validate(
            "dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'",
          ),
          isNull,
        );
      });

      test('rejects a query format that smuggles in a pipe', () {
        expect(
          PackageCommandValidator.validate(
            "dnf repoquery -l --qf '[%{=NAME}|%{FILENAMES}\\n]' 'php-*'",
          ),
          isNotNull,
        );
      });

      test('accepts Debian module enable/disable commands', () {
        expect(PackageCommandValidator.validate('phpenmod -v 8.5 -s fpm mbstring'), isNull);
        expect(PackageCommandValidator.validate('phpdismod -v 8.5 -s fpm mbstring'), isNull);
      });

      test('accepts the manager writing an ini line into the PHP scan dir', () {
        // The enable/disable step on RHEL and Arch pipes one ini line into
        // <scanDir>/99-ponta-<ext>.ini. `echo` and `tee` are already on the
        // allowlist; the target regex is what keeps this narrow.
        expect(
          PackageCommandValidator.validate(
            "echo 'extension=redis' | tee /etc/php.d/99-ponta-redis.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'opcache.enable=0' | tee /etc/php/conf.d/99-ponta-opcache.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'zend_extension=xdebug' | tee /etc/php/8.5/fpm/conf.d/99-ponta-xdebug.ini",
          ),
          isNull,
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'extension=redis' | tee /etc/opt/remi/php85/php.d/99-ponta-redis.ini",
          ),
          isNull,
        );
      });

      test('rejects the disable comment line, which carries a semicolon', () {
        // The disable path never writes a comment — it rewrites the ini in
        // place with `sed` (Task 8). If it ever tried to `echo '; disabled…'`
        // the validator would reject it outright: `;` is a forbidden
        // substring, because it chains commands. Pinned here so nobody
        // "fixes" a failing disable test by reintroducing that line.
        expect(
          PackageCommandValidator.validate(
            "echo '; disabled by Ponta' | tee /etc/php/8.5/fpm/conf.d/99-ponta-redis.ini",
          ),
          contains('Forbidden pattern'),
        );
      });

      test('still rejects a tee write outside the allowed targets', () {
        // Widening tee for the PHP ini dirs must not turn it into a
        // write-anywhere primitive for catalog commands.
        expect(
          PackageCommandValidator.validate("echo 'x' | tee /etc/passwd"),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'x' | tee /root/.ssh/authorized_keys",
          ),
          contains('not allowed'),
        );
        expect(
          PackageCommandValidator.validate(
            "echo 'x' | tee /etc/php.d/../../shadow",
          ),
          contains('not allowed'),
        );
      });

      test('still rejects chaining smuggled through the new binaries', () {
        expect(
          PackageCommandValidator.validate('phpenmod -v 8.5 -s fpm mbstring; rm -rf /'),
          contains('Forbidden pattern'),
        );
        expect(
          PackageCommandValidator.validate('pacman -Ss php- && rm -rf /'),
          contains('Forbidden pattern'),
        );
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/package_command_validator_test.dart`
Expected: FAIL — the discovery assertions and both enable/disable assertions return `'Binary "..." is not in the allowed list'` instead of `null`.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/apps/data/package_command_validator.dart`, extend `_allowedBinaries`:

```dart
  static const Set<String> _allowedBinaries = {
    // Debian/Ubuntu package management
    'apt-get',
    'apt',
    'apt-cache',
    'apt-file',
    'dpkg',
    'add-apt-repository',
    'apt-key',
    // Debian/Ubuntu PHP extension enable/disable (mods-available + conf.d symlinks)
    'phpenmod',
    'phpdismod',
    // RHEL/CentOS package management
    'dnf',
    'yum',
    'rpm',
    // Arch package management
    'pacman',
    // Repo keys, sources, downloads
    'gpg',
    'tee',
    'curl',
    'wget',
    'echo',
    'sed',
    'mkdir',
    'touch',
    'chmod',
    'chown',
    'ln',
    // Service control (post-install hooks)
    'systemctl',
  };
```

Leave `_forbiddenSubstrings` untouched — it is what makes the chaining and pipe tests above still pass.

Then widen the `tee` target regex so it also covers the PHP ini directories the extension manager writes into (spec §5.1/§5.2, §6.3). The pattern is deliberately a closed set of two shapes: the pre-existing apt source-list target, plus one *file* inside `/etc/php…` whose parent directory is `conf.d` or `php.d`:

```dart
  /// Targets that tee is allowed to write to: apt source lists (pre-existing)
  /// and the single PHP ini file the extension manager owns across supported
  /// layouts: RHEL modular (/etc/php.d/), Arch (/etc/php/conf.d/), Debian
  /// versioned (/etc/php/<v>/<sapi>/conf.d/), and Remi SCL on Fedora/RHEL
  /// (/etc/opt/remi/php<N>/php.d/). Each alternative ends in one plain path
  /// component — no `/`, so `..` cannot escape the directory, and `sed`/`tee`
  /// cannot be turned into a write-anywhere primitive for catalog commands.
  static final RegExp _allowedTeeTargets = RegExp(
    r'^(?:'
    r'/etc/apt/sources\.list\.d/[a-zA-Z0-9_.-]+\.list'
    r'|/etc/php\.d/[a-zA-Z0-9_.-]+\.ini'
    r'|/etc/php/conf\.d/[a-zA-Z0-9_.-]+\.ini'
    r'|/etc/php/\d+\.\d+/[a-z0-9_.-]+/conf\.d/[a-zA-Z0-9_.-]+\.ini'
    r'|/etc/opt/remi/php\d+/php\.d/[a-zA-Z0-9_.-]+\.ini'
    r')$',
  );
```

The four accepted forms are `/etc/php.d/99-ponta-<ext>.ini` (RHEL/Remi modular), `/etc/php/conf.d/99-ponta-<ext>.ini` (Arch), the versioned Debian form `/etc/php/8.5/fpm/conf.d/99-ponta-<ext>.ini`, and the Remi SCL form `/etc/opt/remi/php85/php.d/99-ponta-<ext>.ini`. `/etc/passwd`, `/root/.ssh/authorized_keys`, and any `..` traversal fail the regex.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/package_command_validator_test.dart`
Expected: PASS, including the pre-existing `all package manager commands in apps-linux.json pass validation` test.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/package_command_validator.dart test/features/apps/package_command_validator_test.dart
git commit -m "feat: allow apt-cache, apt-file, pacman, phpenmod, phpdismod in validator"
```

---

### Task 3: Move `PhpExtension` to its own domain file and add the new fields

**Files:**
- Create: `lib/features/apps/domain/php_extension.dart`
- Modify: `lib/features/apps/data/php_settings_provider.dart` (remove the class at lines 245-259, add an export)
- Test: `test/features/apps/php_extension_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `class PhpExtension` in `package:dev_stack/features/apps/domain/php_extension.dart`, with:

```dart
const PhpExtension({
  required String name,
  required String fileName,
  required bool isEnabled,
  required bool isFoundInIni,
  required bool isZend,
  bool isInstalled = true,        // NEW
  String? packageName,            // NEW
  String? description,            // NEW
})
```

The constructor is `const` because the widget tests in Task 10 declare `const _curl = PhpExtension(...)` / `const _zip = PhpExtension(...)` fixtures — a non-const constructor makes those a compile error.

plus `PhpExtension copyWith({bool? isEnabled, bool? isInstalled, String? packageName, String? description})`. `php_settings_provider.dart` re-exports it so every existing import keeps working. Used by Tasks 4-8.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/php_extension_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/php_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhpExtension', () {
    test('defaults isInstalled to true and the Linux fields to null', () {
      final ext = PhpExtension(
        name: 'curl',
        fileName: 'php_curl.dll',
        isEnabled: true,
        isFoundInIni: true,
        isZend: false,
      );
      expect(ext.isInstalled, isTrue);
      expect(ext.packageName, isNull);
      expect(ext.description, isNull);
    });

    test('carries the Linux package metadata', () {
      final ext = PhpExtension(
        name: 'mbstring',
        fileName: 'mbstring.so',
        isEnabled: false,
        isFoundInIni: true,
        isZend: false,
        isInstalled: false,
        packageName: 'php8.5-mbstring',
        description: 'MBSTRING module for PHP',
      );
      expect(ext.isInstalled, isFalse);
      expect(ext.packageName, 'php8.5-mbstring');
      expect(ext.description, 'MBSTRING module for PHP');
    });

    test('copyWith changes only the named fields', () {
      final ext = PhpExtension(
        name: 'zip',
        fileName: 'zip.so',
        isEnabled: false,
        isFoundInIni: false,
        isZend: false,
        isInstalled: false,
        packageName: 'php8.5-zip',
      );
      final after = ext.copyWith(isEnabled: true, isInstalled: true);
      expect(after.name, 'zip');
      expect(after.packageName, 'php8.5-zip');
      expect(after.isEnabled, isTrue);
      expect(after.isInstalled, isTrue);
      expect(after.isZend, isFalse);
    });

    test('is reachable through the php_settings_provider re-export', () {
      // The re-export is what keeps every existing import site compiling.
      final ext = PhpExtension(
        name: 'gd',
        fileName: 'gd.so',
        isEnabled: true,
        isFoundInIni: true,
        isZend: false,
      );
      expect(ext, isA<PhpExtension>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/php_extension_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'dev_stack/features/apps/domain/php_extension.dart'` (file does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/apps/domain/php_extension.dart`:

```dart
/// A PHP extension as presented in the app-settings Extensions tab.
///
/// The first five fields are shared by every platform. The last three are
/// Linux-only: on Windows an extension is always already on disk next to the
/// PHP binary and is never installed by a package manager, so [isInstalled]
/// defaults to `true` and [packageName] / [description] stay null.
class PhpExtension {
  final String name;

  /// 'mbstring.so' on Linux, 'php_mbstring.dll' on Windows.
  final String fileName;
  final bool isEnabled;
  final bool isFoundInIni;
  final bool isZend;

  /// Linux only — whether the extension's `.so` exists in `extension_dir`.
  final bool isInstalled;

  /// Linux only — e.g. 'php8.5-mbstring'. Null on Windows.
  final String? packageName;

  /// Linux only — the package manager's one-line description. Null on Windows.
  final String? description;

  const PhpExtension({
    required this.name,
    required this.fileName,
    required this.isEnabled,
    required this.isFoundInIni,
    required this.isZend,
    this.isInstalled = true,
    this.packageName,
    this.description,
  });

  PhpExtension copyWith({
    bool? isEnabled,
    bool? isInstalled,
    String? packageName,
    String? description,
  }) {
    return PhpExtension(
      name: name,
      fileName: fileName,
      isEnabled: isEnabled ?? this.isEnabled,
      isFoundInIni: isFoundInIni,
      isZend: isZend,
      isInstalled: isInstalled ?? this.isInstalled,
      packageName: packageName ?? this.packageName,
      description: description ?? this.description,
    );
  }
}
```

In `lib/features/apps/data/php_settings_provider.dart`, delete the `class PhpExtension { ... }` block at the end of the file (lines 245-259) and add near the top, after the existing imports:

```dart
import '../domain/php_extension.dart';
export '../domain/php_extension.dart';
```

Both lines are required, and they do different jobs. The `import` puts `PhpExtension` in *this file's* scope, which the Linux branch added in Task 9 needs for its `Future<List<PhpExtension>>` return type. The `export` re-publishes the symbol so every existing `import '.../php_settings_provider.dart';` site that refers to `PhpExtension` keeps compiling — an `export` alone would not do that, because a library's own declarations are not brought into its scope by its own export directive.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/php_extension_test.dart`
Expected: PASS (4 tests).

Then confirm nothing else broke:

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/domain/php_extension.dart lib/features/apps/data/php_settings_provider.dart test/features/apps/php_extension_test.dart
git commit -m "refactor: move PhpExtension to domain/ and add Linux package fields"
```

---

### Task 4: `LinuxPhpIntrospector` — read the binary's own configuration

**Files:**
- Create: `lib/features/apps/data/linux_php_introspector.dart`
- Test: `test/features/apps/linux_php_introspector_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:

```dart
class PhpFpmInfo {
  final String? scanDir;        // null when phpinfo printed '(none)'
  final String? extensionDir;
  final String? iniPath;        // 'Loaded Configuration File'
  final List<String> scannedIniFiles;
}

class LinuxPhpIntrospector {
  LinuxPhpIntrospector({
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  });

  Future<PhpFpmInfo> readInfo(String binaryPath);
  Future<Set<String>> readModules(String binaryPath);
}
```

`readInfo` runs `php-fpm -i`; `readModules` runs `php-fpm -m`. Both tolerate a non-zero exit by returning empty results rather than throwing. Used by Task 8.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/linux_php_introspector_test.dart`. The fixture strings below are copied verbatim from real `php-fpm -i` / `php-fpm -m` output, including the ` => ` separator, the three-column `extension_dir` row, and the `,\n` joining of scanned ini files.

```dart
import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:flutter_test/flutter_test.dart';

const _phpInfoFixture = '''
phpinfo()
PHP Version => 8.2.29

Configuration File (php.ini) Path => /etc/php/8.2/fpm
Loaded Configuration File => /etc/php/8.2/fpm/php.ini
Scan this dir for additional .ini files => /etc/php/8.2/fpm/conf.d
Additional .ini files parsed => /etc/php/8.2/fpm/conf.d/10-mysqlnd.ini,
/etc/php/8.2/fpm/conf.d/10-opcache.ini,
/etc/php/8.2/fpm/conf.d/20-mbstring.ini

extension_dir => /usr/lib/php/20220829 => /usr/lib/php/20220829
''';

const _phpInfoNoIniFixture = '''
phpinfo()
PHP Version => 8.2.29

Configuration File (php.ini) Path => /etc/php/8.2/fpm
Loaded Configuration File => (none)
Scan this dir for additional .ini files => (none)
Additional .ini files parsed => (none)

extension_dir => /usr/lib/php/20220829 => /usr/lib/php/20220829
''';

const _modulesFixture = '''
[PHP Modules]
Core
ctype
curl
date
json
mbstring
mysqli
opcache
pcre
standard
tokenizer

[Zend Modules]
Zend OPcache
''';

void main() {
  group('LinuxPhpIntrospector.readInfo', () {
    test('parses scan dir, extension dir, ini path and scanned files', () async {
      final calls = <({String exec, List<String> args})>[];
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async {
          calls.add((exec: exec, args: args));
          return ProcessResult(1, 0, _phpInfoFixture, '');
        },
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(calls.single.exec, '/usr/sbin/php-fpm8.2');
      expect(calls.single.args, equals(['-i']));
      expect(info.scanDir, '/etc/php/8.2/fpm/conf.d');
      expect(info.extensionDir, '/usr/lib/php/20220829');
      expect(info.iniPath, '/etc/php/8.2/fpm/php.ini');
      expect(info.scannedIniFiles, equals([
        '/etc/php/8.2/fpm/conf.d/10-mysqlnd.ini',
        '/etc/php/8.2/fpm/conf.d/10-opcache.ini',
        '/etc/php/8.2/fpm/conf.d/20-mbstring.ini',
      ]));
    });

    test('maps "(none)" to null instead of the literal string', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => ProcessResult(1, 0, _phpInfoNoIniFixture, ''),
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(info.scanDir, isNull);
      expect(info.iniPath, isNull);
      expect(info.scannedIniFiles, isEmpty);
      // extension_dir is always present, even when no ini was loaded.
      expect(info.extensionDir, '/usr/lib/php/20220829');
    });

    test('returns empty info when the binary cannot be executed', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => throw const ProcessException('php-fpm', [], 'No such file'),
      );

      final info = await introspector.readInfo('/nonexistent/php-fpm');

      expect(info.scanDir, isNull);
      expect(info.extensionDir, isNull);
      expect(info.iniPath, isNull);
      expect(info.scannedIniFiles, isEmpty);
    });

    test('returns empty info on a non-zero exit code', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => ProcessResult(1, 127, '', 'command not found'),
      );

      final info = await introspector.readInfo('/usr/sbin/php-fpm8.2');

      expect(info.scanDir, isNull);
      expect(info.extensionDir, isNull);
    });
  });

  group('LinuxPhpIntrospector.readModules', () {
    test('parses the [PHP Modules] and [Zend Modules] sections', () async {
      final calls = <({String exec, List<String> args})>[];
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async {
          calls.add((exec: exec, args: args));
          return ProcessResult(1, 0, _modulesFixture, '');
        },
      );

      final modules = await introspector.readModules('/usr/sbin/php-fpm8.2');

      expect(calls.single.args, equals(['-m']));
      expect(modules, contains('mbstring'));
      expect(modules, contains('curl'));
      expect(modules, contains('opcache'));
      // Section headers and blank lines are not module names.
      expect(modules, isNot(contains('[PHP Modules]')));
      expect(modules, isNot(contains('')));
      expect(modules.length, equals(12));
    });

    test('returns an empty set when the binary cannot be executed', () async {
      final introspector = LinuxPhpIntrospector(
        runProcess: (exec, args) async => throw const ProcessException('php-fpm', [], 'No such file'),
      );

      expect(await introspector.readModules('/nonexistent/php-fpm'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/linux_php_introspector_test.dart`
Expected: FAIL — `Couldn't resolve the package 'dev_stack/features/apps/data/linux_php_introspector.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/apps/data/linux_php_introspector.dart`:

```dart
import 'dart:io';

/// The effective PHP-FPM configuration, as reported by the binary itself.
///
/// Every field is nullable because phpinfo prints `(none)` for unset values,
/// and because a binary that fails to run yields no information at all.
class PhpFpmInfo {
  final String? scanDir;
  final String? extensionDir;
  final String? iniPath;
  final List<String> scannedIniFiles;

  const PhpFpmInfo({
    this.scanDir,
    this.extensionDir,
    this.iniPath,
    this.scannedIniFiles = const [],
  });

  static const PhpFpmInfo empty = PhpFpmInfo();
}

/// Reads a php-fpm binary's own view of its configuration.
///
/// `php-fpm -i` runs `php_module_startup()` (which loads php.ini and the
/// compile-time scan directory) and prints phpinfo as plain text, then exits
/// before `fpm_init()`. It therefore needs no `-y` pool config, does not
/// daemonize, does not bind a socket, and does not refuse to run as root.
/// `php-fpm -m` lists the compiled-in and loaded modules the same way.
///
/// The scan directory and `extension_dir` are properties of the binary — each
/// SAPI is built with its own `--with-config-file-scan-dir` — so reading them
/// here is always correct and no per-distro path needs to be hardcoded.
class LinuxPhpIntrospector {
  LinuxPhpIntrospector({
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) : _runProcess = runProcess ?? Process.run;

  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  Future<PhpFpmInfo> readInfo(String binaryPath) async {
    final stdout = await _run(binaryPath, ['-i']);
    if (stdout == null) return PhpFpmInfo.empty;

    final values = <String, String>{};
    String? currentLabel;
    for (final line in stdout.split('\n')) {
      if (line.trim().isEmpty) {
        // A blank line ends the directive it belonged to. This matters
        // because `-i` output is sectioned (`Core`, `date`, …) and a section
        // header carries no ` => `, so without this reset it would be
        // appended to whichever directive happened to precede it.
        currentLabel = null;
        continue;
      }
      final idx = line.indexOf(' => ');
      if (idx > 0) {
        currentLabel = line.substring(0, idx).trim();
        values.putIfAbsent(currentLabel, () => line.substring(idx + 4).trim());
        continue;
      }
      // A continuation of a wrapped value. `main/php_ini.c` joins the scanned
      // ini list with `",\n"`, so every path after the first lands on its own
      // line with no ` => ` to anchor it. Appending it to the label we are
      // inside of is what makes `scannedIniFiles` complete instead of a
      // one-element list.
      final label = currentLabel;
      if (label != null) {
        final continuation = line.trim();
        values.update(label, (v) => '$v\n$continuation');
      }
    }

    return PhpFpmInfo(
      scanDir: _orNull(values['Scan this dir for additional .ini files']),
      // `extension_dir` is a three-column row — `extension_dir => <local> =>
      // <master>` — unlike the two-column rows around it, so the value here
      // is still `<local> => <master>`. Take the first column.
      extensionDir: _orNull(values['extension_dir']?.split(' => ').first),
      iniPath: _orNull(values['Loaded Configuration File']),
      scannedIniFiles: _splitIniList(values['Additional .ini files parsed']),
    );
  }

  Future<Set<String>> readModules(String binaryPath) async {
    final stdout = await _run(binaryPath, ['-m']);
    if (stdout == null) return <String>{};

    final modules = <String>{};
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('[')) continue;
      modules.add(line);
    }
    return modules;
  }

  /// Runs the binary and returns stdout, or null when it cannot be used.
  Future<String?> _run(String binaryPath, List<String> args) async {
    try {
      final result = await _runProcess(binaryPath, args);
      if (result.exitCode != 0) return null;
      return result.stdout.toString();
    } catch (_) {
      return null;
    }
  }

  static String? _orNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '(none)') return null;
    return trimmed;
  }

  /// `main/php_ini.c` joins scanned ini paths with `",\n"` and terminates the
  /// list with `"\n"` — not spaces, which a naive split would get wrong.
  static List<String> _splitIniList(String? value) {
    if (value == null) return const [];
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '(none)') return const [];
    return trimmed
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/linux_php_introspector_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/linux_php_introspector.dart test/features/apps/linux_php_introspector_test.dart
git commit -m "feat: add LinuxPhpIntrospector reading php-fpm -i and -m"
```

---

### Task 5: Driver base class, factory, and the Debian driver

**Files:**
- Create: `lib/features/apps/data/linux_php_extension_driver.dart`
- Create: `lib/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart`
- Create: `lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart` (stub; replaced in Task 6)
- Create: `lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart` (stub; replaced in Task 7)
- Test: `test/features/apps/debian_php_extension_driver_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:

```dart
class PackageCandidate {
  final String name;                 // 'php8.5-mbstring', or '' for a synthetic entry
  final String description;          // '' when the package list had none
  final List<String> extensionNames; // ['mbstring']; empty when not an extension

  const PackageCandidate({
    required this.name,
    this.description = '',
    this.extensionNames = const [],
  });

  /// An extension that exists only as an enabled module (statically compiled,
  /// e.g. opcache): there is no package to install.
  const PackageCandidate.synthetic(this.extensionNames) : name = '', description = '';

  bool get hasPackage => name.isNotEmpty;
}

/// How a family turns an extension on and off.
enum PhpIniStrategy {
  /// Debian/Ubuntu: `phpenmod` / `phpdismod` manage `conf.d` symlinks. We write
  /// no ini file of our own.
  externalTool,

  /// RHEL/Fedora and Arch: we own `<scanDir>/99-ponta-<ext>.ini`. Disabling also
  /// has to neutralise any ini the distro shipped for the same extension (Remi
  /// ships an active `20-<ext>.ini`).
  ownIniFile,
}

abstract class LinuxPhpExtensionDriver {
  String get family;                                        // 'debian' | 'rhel' | 'arch'
  PhpIniStrategy get iniStrategy;

  /// Lists installable packages (name + description).
  List<String> packageListCommands(String phpVersion);
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion);

  /// Lists the files each package ships. [packages] is used by Arch, whose
  /// `pacman -Fl` needs explicit package names; Debian and RHEL ignore it and
  /// pass a pattern instead.
  List<String> fileListCommands(String phpVersion, List<PackageCandidate> packages);

  /// Splits one line of the file-list output into (package, absolute path).
  /// Debian prints `pkg: /path`, RHEL `pkg /path`, Arch `pkg path` (no slash).
  ({String package, String path})? parseFileListLine(String line);

  /// Applies [parseFileListLine] and keeps only `.so` files whose parent
  /// directory is [extensionDir]. This is the whole of §2.7 and is shared by
  /// every family, so it lives here rather than in each driver.
  Map<String, List<String>> parseFileList(String stdout, String extensionDir);

  /// Attaches [extensionNames] to each package. Shared; packages that ship no
  /// extension in [extensionDir] are dropped.
  List<PackageCandidate> combine(
    List<PackageCandidate> packages,
    Map<String, List<String>> filesByPackage,
  );

  List<String> installCommands(PackageCandidate pkg, String phpVersion);
  List<String> enableCommands(String phpVersion, String extName);
  List<String> disableCommands(String phpVersion, String extName);

  String iniFileNameFor(String extName) => '99-ponta-$extName.ini';
  bool isZendExtension(String extName);

  static bool isSafeName(String name);
}

/// Null when [family] is not one of the three supported families.
LinuxPhpExtensionDriver? driverForFamily(String family);
```

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/debian_php_extension_driver_test.dart`. The file-list fixture is copied from real `apt-file list -x '^php8\.5-'` output; the extension directory is what `php-fpm -i` reports for sury PHP 8.5 (`usr/lib/php/20250925`).

```dart
import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = DebianPhpExtensionDriver();
  const extDir = '/usr/lib/php/20250925';

  group('driverForFamily', () {
    test('maps ubuntu and debian to the Debian driver', () {
      expect(driverForFamily('ubuntu'), isA<DebianPhpExtensionDriver>());
      expect(driverForFamily('debian'), isA<DebianPhpExtensionDriver>());
    });

    test('returns null for unknown, which callers must treat as unsupported', () {
      expect(driverForFamily('unknown'), isNull);
      expect(driverForFamily('nixos'), isNull);
    });
  });

  group('isSafeName', () {
    test('accepts real package and extension names', () {
      expect(LinuxPhpExtensionDriver.isSafeName('mbstring'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('php8.5-mbstring'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('pdo_mysql'), isTrue);
      expect(LinuxPhpExtensionDriver.isSafeName('php-pecl-zip'), isTrue);
    });

    test('rejects injection attempts', () {
      expect(LinuxPhpExtensionDriver.isSafeName('mbstring; rm -rf /'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName(r'a$(id)'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('a`id`'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('a b'), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName(''), isFalse);
      expect(LinuxPhpExtensionDriver.isSafeName('-flag'), isFalse);
    });
  });

  group('splitCommand', () {
    test('strips the single quotes so the pattern reaches the tool intact', () {
      // Discovery runs through Process.run (direct argv, no shell), so a kept
      // quote would arrive at apt-file as a literal character and the pattern
      // would match nothing — a silent empty extension list.
      expect(
        LinuxPhpExtensionDriver.splitCommand("apt-file list -x '^php8.5-'"),
        equals(['apt-file', 'list', '-x', '^php8.5-']),
      );
      expect(
        LinuxPhpExtensionDriver.splitCommand("dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'"),
        equals(['dnf', 'repoquery', '--qf', '[%{=NAME}\\n]', 'php-*']),
      );
      // An unquoted command is unchanged.
      expect(
        LinuxPhpExtensionDriver.splitCommand('pacman -Ss php-'),
        equals(['pacman', '-Ss', 'php-']),
      );
      // A space inside quotes does not split the argument.
      expect(
        LinuxPhpExtensionDriver.splitCommand("dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'"),
        equals([
          'dnf',
          'repoquery',
          '-l',
          '--qf',
          '[%{=NAME} %{FILENAMES}\\n]',
          'php-*',
        ]),
      );
    });
  });

  group('disableIniPattern', () {
    test('is anchored so pdo cannot match pdo_mysql', () {
      final re = RegExp(driver.disableIniPattern('pdo'));
      expect(re.hasMatch('extension=pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo'), isTrue);
      expect(re.hasMatch('zend_extension="pdo.so"'), isTrue);
      expect(re.hasMatch('extension=/usr/lib64/php/modules/pdo.so'), isTrue);
      expect(re.hasMatch('  extension = pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo_mysql.so'), isFalse);
      expect(re.hasMatch('extension=pdo_pgsql.so'), isFalse);
    });

    test('gives opcache its directive form rather than a loader line', () {
      final pattern = driver.disableIniPattern('opcache');
      final re = RegExp(pattern);
      expect(re.hasMatch('opcache.enable=1'), isTrue);
      expect(re.hasMatch('opcache.enable = 0'), isTrue);
      // It must NOT match a loader line: there is no opcache.so to load.
      expect(re.hasMatch('extension=opcache.so'), isFalse);
    });

    test('contains no literal semicolon, which the validator forbids', () {
      // The `;` is emitted by sed as the escape `\x3b`; the pattern itself is
      // only the match side, so this guards the whole generated command.
      for (final name in ['pdo', 'opcache', 'mbstring', 'pdo_mysql']) {
        expect(driver.disableIniPattern(name), isNot(contains(';')));
      }
    });
  });

  group('DebianPhpExtensionDriver.parsePackageList', () {
    test('parses apt-cache search name - description lines', () {
      const stdout = '''
php8.5-mbstring - MBSTRING module for PHP
php8.5-curl - CURL module for PHP
php8.5-zip - Zip module for PHP
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.length, equals(3));
      expect(candidates[0].name, 'php8.5-mbstring');
      expect(candidates[0].description, 'MBSTRING module for PHP');
      expect(candidates[2].name, 'php8.5-zip');
    });

    test('ignores lines that are not name - description pairs', () {
      const stdout = '''
php8.5-mbstring - MBSTRING module for PHP
WARNING: apt does not have a stable CLI interface.
''';
      expect(driver.parsePackageList(stdout, '8.5').length, equals(1));
    });

    test('drops a name that fails the safety check', () {
      const stdout = 'php8.5-a b; rm -rf / - evil\nphp8.5-curl - CURL module for PHP\n';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php8.5-curl']));
    });
  });

  group('DebianPhpExtensionDriver.parseFileList', () {
    test('keeps only .so files whose parent is extensionDir', () {
      const stdout = '''
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
php8.5-mysql: /usr/lib/php/20250925/mysqli.so
php8.5-mysql: /usr/lib/php/20250925/mysqlnd.so
php8.5-mysql: /usr/lib/php/20250925/pdo_mysql.so
php8.5-common: /usr/lib/php/20250925/ctype.so
php8.5-common: /usr/lib/php/20250925/calendar.so
php8.5-dev: /usr/lib/php/20250925/build/phpize.m4
php8.5-common: /usr/share/doc/php8.5-common/changelog.gz
php8.5-fpm: /usr/bin/php-fpm8.5
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php8.5-mbstring'], equals(['mbstring']));
      expect(byPackage['php8.5-mysql'], equals(['mysqli', 'mysqlnd', 'pdo_mysql']));
      expect(byPackage['php8.5-common'], equals(['calendar', 'ctype']));
      // php8.5-dev ships files under extensionDir but no .so, and php8.5-fpm
      // ships none at all: neither is an extension package.
      expect(byPackage.containsKey('php8.5-dev'), isFalse);
      expect(byPackage.containsKey('php8.5-fpm'), isFalse);
    });

    test('ignores a .so that lives outside extensionDir', () {
      // /usr/lib/php/20250925 is extensionDir; a sibling ABI directory is not.
      const stdout = '''
php8.5-other: /usr/lib/php/20240924/other.so
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);
      expect(byPackage.keys, equals(['php8.5-mbstring']));
    });

    test('a package whose name differs from its extension is still resolved', () {
      // Real sury data: php8.5-interbase ships pdo_firebird.so, php8.5-sybase
      // ships pdo_dblib.so. No prefix-stripping heuristic could find these.
      const stdout = '''
php8.5-interbase: /usr/lib/php/20250925/pdo_firebird.so
php8.5-sybase: /usr/lib/php/20250925/pdo_dblib.so
''';
      final byPackage = driver.parseFileList(stdout, extDir);
      expect(byPackage['php8.5-interbase'], equals(['pdo_firebird']));
      expect(byPackage['php8.5-sybase'], equals(['pdo_dblib']));
    });
  });

  group('combine', () {
    test('attaches extension names and drops non-extension packages', () {
      final packages = driver.parsePackageList('''
php8.5-mbstring - MBSTRING module for PHP
php8.5-fpm - server-side, HTML-embedded scripting language (FPM-CGI binary)
php8.5-common - documentation, examples and common module for PHP
''', '8.5');
      final files = driver.parseFileList('''
php8.5-mbstring: /usr/lib/php/20250925/mbstring.so
php8.5-common: /usr/lib/php/20250925/ctype.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php8.5-mbstring', 'php8.5-common']));
      expect(combined[0].extensionNames, equals(['mbstring']));
      expect(combined[0].description, 'MBSTRING module for PHP');
      expect(combined[1].extensionNames, equals(['ctype']));
    });
  });

  group('DebianPhpExtensionDriver commands', () {
    test('discovers packages and file lists for the requested version', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(['apt-cache search --names-only php8.5-']),
      );
      expect(
        driver.fileListCommands('8.5', const []),
        equals(["apt-file list -x '^php8.5-'"]),
      );
    });

    test('installs with apt-get install -y', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php8.5-mbstring'),
          '8.5',
        ),
        equals(['apt-get install -y php8.5-mbstring']),
      );
    });

    test('enables and disables through phpenmod/phpdismod', () {
      expect(driver.iniStrategy, PhpIniStrategy.externalTool);
      expect(
        driver.enableCommands('8.5', 'mbstring'),
        equals(['phpenmod -v 8.5 -s fpm mbstring']),
      );
      expect(
        driver.disableCommands('8.5', 'mbstring'),
        equals(['phpdismod -v 8.5 -s fpm mbstring']),
      );
    });

    test('marks opcache and xdebug as zend extensions', () {
      expect(driver.isZendExtension('opcache'), isTrue);
      expect(driver.isZendExtension('xdebug'), isTrue);
      expect(driver.isZendExtension('mbstring'), isFalse);
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const []),
        ...driver.installCommands(const PackageCandidate(name: 'php8.5-mbstring'), '8.5'),
        ...driver.enableCommands('8.5', 'mbstring'),
        ...driver.disableCommands('8.5', 'mbstring'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/debian_php_extension_driver_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/apps/data/linux_php_extension_driver.dart`:

```dart
import 'package:path/path.dart' as p;

/// A package the distro can install, together with the extensions it provides.
class PackageCandidate {
  final String name;
  final String description;
  final List<String> extensionNames;

  const PackageCandidate({
    required this.name,
    this.description = '',
    this.extensionNames = const [],
  });

  /// An extension with no package behind it: it is compiled into the PHP
  /// binary itself, so there is nothing to install. `opcache` is the case that
  /// matters in practice — it ships no `.so` on Debian, RHEL or Arch for 8.5.
  const PackageCandidate.synthetic(this.extensionNames)
    : name = '',
      description = '';

  bool get hasPackage => name.isNotEmpty;
}

/// How a family turns an extension on and off.
enum PhpIniStrategy {
  /// Debian/Ubuntu: `phpenmod` / `phpdismod` manage the `conf.d` symlinks, so we
  /// never write an ini file ourselves.
  externalTool,

  /// RHEL/Fedora and Arch: we own `<scanDir>/99-ponta-<ext>.ini`. Disabling
  /// also has to neutralise any ini the distro shipped for the same extension.
  ownIniFile,
}

/// Supplies everything distro-specific about managing PHP extensions.
///
/// The package-to-extension mapping is **not** a table: it is read from each
/// package's own file list and filtered by the binary's `extension_dir`
/// (see the spec, §2.7). That is why [parseFileList] lives here and is shared
/// by every family.
abstract class LinuxPhpExtensionDriver {
  String get family;

  PhpIniStrategy get iniStrategy;

  List<String> packageListCommands(String phpVersion);

  List<PackageCandidate> parsePackageList(String stdout, String phpVersion);

  List<String> fileListCommands(String phpVersion, List<PackageCandidate> packages);

  /// Splits one file-list line into its package and absolute path, or null when
  /// the line carries no file entry.
  ({String package, String path})? parseFileListLine(String line);

  /// Keeps only `.so` files whose immediate parent directory is [extensionDir].
  ///
  /// This single rule replaces the prefix-stripping heuristic and its exception
  /// table. Junk is excluded by construction: Remi's `php-embedded` ships
  /// `/usr/lib64/libphp.so`, `uwsgi-plugin-php` ships
  /// `/usr/lib64/uwsgi/php_plugin.so`, and Arch's `php-apache` ships
  /// `/usr/lib/httpd/modules/libphp.so` — none of them under an
  /// `extension_dir`.
  Map<String, List<String>> parseFileList(String stdout, String extensionDir) {
    final byPackage = <String, List<String>>{};
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final entry = parseFileListLine(line);
      if (entry == null) continue;
      if (!LinuxPhpExtensionDriver.isSafeName(entry.package)) continue;

      final path = entry.path;
      if (!path.endsWith('.so')) continue;
      // Compare directories, not the file name: the extension name is the file
      // name, and the package name is irrelevant.
      if (p.posix.dirname(path) != extensionDir) continue;

      final extName = p.posix.basenameWithoutExtension(path);
      if (!LinuxPhpExtensionDriver.isSafeName(extName)) continue;
      byPackage.putIfAbsent(entry.package, () => <String>[]).add(extName);
    }
    for (final names in byPackage.values) {
      names.sort();
    }
    return byPackage;
  }

  /// Attaches the extension names from [filesByPackage] to each package,
  /// dropping the packages that ship none.
  List<PackageCandidate> combine(
    List<PackageCandidate> packages,
    Map<String, List<String>> filesByPackage,
  ) {
    final result = <PackageCandidate>[];
    for (final pkg in packages) {
      final names = filesByPackage[pkg.name];
      if (names == null || names.isEmpty) continue;
      result.add(
        PackageCandidate(
          name: pkg.name,
          description: pkg.description,
          extensionNames: names,
        ),
      );
    }
    return result;
  }

  List<String> installCommands(PackageCandidate pkg, String phpVersion);

  List<String> enableCommands(String phpVersion, String extName);

  List<String> disableCommands(String phpVersion, String extName);

  String iniFileNameFor(String extName) => '99-ponta-$extName.ini';

  /// `opcache` and `xdebug` need `zend_extension=` rather than `extension=`.
  bool isZendExtension(String extName) =>
      extName == 'opcache' || extName == 'xdebug';

  /// The ERE body (no `s,`/delimiter, no replacement) that comments out the
  /// line loading [extName] in an ini file. Shared by RHEL and Arch; Debian
  /// uses `phpdismod` and never builds a pattern.
  ///
  /// Two forms exist and both are covered:
  /// - a loader line — `extension=redis.so`, `zend_extension="redis.so"`,
  ///   `extension=/usr/lib64/php/modules/redis.so`, `extension=redis`;
  /// - `opcache`'s directive form, `opcache.enable=1`, which is an assignment
  ///   rather than a loader line (spec §2.5) and needs its own alternative.
  ///
  /// The name is anchored (`(.*/)?NAME(\.so)?"?\s*$`) so `pdo` cannot
  /// match `pdo_mysql`. ERE, not BRE: busybox `sed` has no `\?`.
  ///
  /// `\s`, not `[[:space:]]`: Dart's `RegExp` is ECMAScript, where the POSIX
  /// class is not a class at all — it is the literal set `{[, :, s, p, a, c, e}`,
  /// so `^[[:space:]]*$` would match `":"` and *reject* a line of spaces.
  /// `\s` works in both runtimes (Dart `RegExp` and GNU/busybox `sed`).
  ///
  /// Every `\s` sits in a **raw** string: in a non-raw literal `'\s'` is the
  /// escape `\s`, which Dart silently reduces to `s`, turning the anchor into
  /// `...s*$` — a pattern that matches almost nothing. The name is spliced in
  /// by concatenation because a raw string also disables `$name`
  /// interpolation.
  String disableIniPattern(String extName) {
    final name = RegExp.escape(extName);
    if (extName == 'opcache') {
      return r'^\s*opcache\.enable\s*=.*$';
    }
    return r'^\s*(zend_)?extension\s*=\s*"?(.*/)?' +
        name +
        r'(\.so)?"?\s*$';
  }

  /// Splits a discovery command into argv, stripping the single quotes the
  /// commands carry.
  ///
  /// The commands are written quoted (`apt-file list -x '^php8.5-'`) because
  /// that is how a human would paste them into a shell. But discovery runs
  /// through `Process.run` — direct argv, no shell — so the quotes would reach
  /// `apt-file`/`dnf` as literal characters and the pattern would match
  /// nothing. This is why the tests stub `apt-file list -x ^php8.5-` with no
  /// quotes.
  static List<String> splitCommand(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inSingle = false;
    for (var i = 0; i < command.length; i++) {
      final ch = command[i];
      if (ch == "'") {
        inSingle = !inSingle;
        continue;
      }
      if ((ch == ' ' || ch == '\t') && !inSingle) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(ch);
    }
    if (buffer.isNotEmpty) parts.add(buffer.toString());
    return parts;
  }

  /// Package and extension names come from package-manager output, which is a
  /// semi-trusted source. Anything that is not a plain lower-case name is
  /// dropped rather than sanitised, so it can never reach a shell.
  static final RegExp _safeName = RegExp(r'^[a-z0-9][a-z0-9._+-]*$');

  static bool isSafeName(String name) => _safeName.hasMatch(name);
}
```

Create `lib/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart`:

```dart
import '../linux_php_extension_driver.dart';

/// Debian and Ubuntu.
///
/// Extensions are enabled through `mods-available/*.ini` plus per-SAPI
/// `conf.d/` symlinks, managed by `phpenmod` / `phpdismod`. Installing a
/// package usually enables it already (its `postinst` runs `php_invoke enmod`),
/// but only for SAPIs whose `conf.d` directory already exists — so the manager
/// always runs the enable step explicitly rather than relying on `postinst`.
///
/// File lists come from `apt-file`, which needs a one-time `apt-file update`
/// before it can answer. `apt-file list -x` matches the pattern against package
/// names and prints `package: /path`.
class DebianPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'debian';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.externalTool;

  @override
  List<String> packageListCommands(String phpVersion) => [
    'apt-cache search --names-only php$phpVersion-',
  ];

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      final sep = line.indexOf(' - ');
      if (sep <= 0) continue;
      final name = line.substring(0, sep).trim();
      if (!LinuxPhpExtensionDriver.isSafeName(name)) continue;
      candidates.add(
        PackageCandidate(
          name: name,
          description: line.substring(sep + 3).trim(),
        ),
      );
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    // Matches the spec §2.8 form exactly: the version prefix, then a literal
    // '-'. The trailing dot of an earlier draft (`^php8\.5\.`) matched
    // `php8.5-...` by accident while reading as if it targeted `php8.5.`
    // packages; the dash is what the Debian archive actually uses.
    return ["apt-file list -x '^php$phpVersion-'"];
  }

  @override
  ({String package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(': ');
    if (sep <= 0) return null;
    return (package: line.substring(0, sep), path: line.substring(sep + 2));
  }

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) => [
    'apt-get install -y ${pkg.name}',
  ];

  @override
  List<String> enableCommands(String phpVersion, String extName) => [
    'phpenmod -v $phpVersion -s fpm $extName',
  ];

  @override
  List<String> disableCommands(String phpVersion, String extName) => [
    'phpdismod -v $phpVersion -s fpm $extName',
  ];
}
```

Create the two stubs. They keep this task's test runnable; Tasks 6 and 7 replace them:

```dart
// lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart
import '../linux_php_extension_driver.dart';

/// Implemented in Task 6.
class RhelPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'rhel';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) => throw UnimplementedError();

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) =>
      throw UnimplementedError();

  @override
  List<String> fileListCommands(String phpVersion, List<PackageCandidate> packages) =>
      throw UnimplementedError();

  @override
  ({String package, String path})? parseFileListLine(String line) =>
      throw UnimplementedError();

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) =>
      throw UnimplementedError();

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
```

```dart
// lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart
import '../linux_php_extension_driver.dart';

/// Implemented in Task 7.
class ArchPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'arch';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) => throw UnimplementedError();

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) =>
      throw UnimplementedError();

  @override
  List<String> fileListCommands(String phpVersion, List<PackageCandidate> packages) =>
      throw UnimplementedError();

  @override
  ({String package, String path})? parseFileListLine(String line) =>
      throw UnimplementedError();

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) =>
      throw UnimplementedError();

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
```

Finally, append the factory to `lib/features/apps/data/linux_php_extension_driver.dart`:

```dart
/// Returns the driver for [family], or null when the family is unsupported.
///
/// `unknown` deliberately yields null: the extension manager must show an
/// explicit "unsupported distribution" message rather than guess a package
/// manager.
LinuxPhpExtensionDriver? driverForFamily(String family) {
  switch (family) {
    case 'ubuntu':
    case 'debian':
      return DebianPhpExtensionDriver();
    case 'centos':
    case 'fedora':
      return RhelPhpExtensionDriver();
    case 'arch':
      return ArchPhpExtensionDriver();
    default:
      return null;
  }
}
```

Add these imports at the top of the same file, below the `package:path` import:

```dart
import 'php_extension_drivers/arch_php_extension_driver.dart';
import 'php_extension_drivers/debian_php_extension_driver.dart';
import 'php_extension_drivers/rhel_php_extension_driver.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/debian_php_extension_driver_test.dart`
Expected: PASS (20 tests).

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/linux_php_extension_driver.dart lib/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart test/features/apps/debian_php_extension_driver_test.dart
git commit -m "feat: add LinuxPhpExtensionDriver base, factory and Debian driver"
```

---

### Task 6: RHEL / Fedora driver

**Files:**
- Modify: `lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart` (replace the Task 5 stub)
- Test: `test/features/apps/rhel_php_extension_driver_test.dart` (create)

**Interfaces:**
- Consumes: `LinuxPhpExtensionDriver`, `PackageCandidate`, `driverForFamily` from Task 5.
- Produces: a complete `RhelPhpExtensionDriver` with `family == 'rhel'` and `iniStrategy == PhpIniStrategy.ownIniFile`. Used by Task 8.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/rhel_php_extension_driver_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = RhelPhpExtensionDriver();
  const extDir = '/usr/lib64/php/modules';

  group('RhelPhpExtensionDriver commands', () {
    test('discovers packages and file lists using dnf repoquery for both modular and SCL patterns', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(["dnf repoquery --qf '[%{=NAME}\\n]' 'php-*' 'php85-php-*'"]),
      );
      expect(
        driver.fileListCommands('8.5', const []),
        equals(["dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*' 'php85-php-*'"]),
      );
    });

    test('installs with dnf install -y', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php-pdo'),
          '8.5',
        ),
        equals(['dnf install -y php-pdo']),
      );
    });

    test('enables and disables through ownIniFile strategy (empty command lists)', () {
      expect(driver.iniStrategy, PhpIniStrategy.ownIniFile);
      expect(driver.enableCommands('8.5', 'redis'), isEmpty);
      expect(driver.disableCommands('8.5', 'redis'), isEmpty);
      expect(driver.iniFileNameFor('redis'), equals('99-ponta-redis.ini'));
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const []),
        ...driver.installCommands(const PackageCandidate(name: 'php-pdo'), '8.5'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });

  group('RhelPhpExtensionDriver parsing', () {
    test('parses dnf repoquery name lines into package candidates', () {
      const stdout = '''
php-common
php-pdo
php-pecl-redis6
php-embedded
php-fpm
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.map((c) => c.name), equals([
        'php-common',
        'php-pdo',
        'php-pecl-redis6',
        'php-embedded',
        'php-fpm',
      ]));
    });

    test('ignores blank lines and drops unsafe names in package list', () {
      const stdout = '''

php-pdo
php-unsafe; rm -rf /

php-fpm
''';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php-pdo', 'php-fpm']));
    });

    test('parseFileListLine parses space-separated pkg and path with leading slash', () {
      final entry = driver.parseFileListLine('php-common /usr/lib64/php/modules/bz2.so');
      expect(entry, isNotNull);
      expect(entry!.package, equals('php-common'));
      expect(entry.path, equals('/usr/lib64/php/modules/bz2.so'));
    });

    test('parseFileList filters to extensionDir and excludes runtime libraries', () {
      // Real Remi repository files:
      // php-common ships multiple .so and .ini files
      // php-pdo ships pdo, pdo_sqlite, sqlite3
      // php-pecl-redis6 ships redis.so (name != extension)
      // php-embedded ships /usr/lib64/libphp.so (junk: outside extensionDir)
      // php-fpm ships /usr/sbin/php-fpm (not .so)
      const stdout = '''
php-common /usr/lib64/php/modules/bz2.so
php-common /usr/lib64/php/modules/curl.so
php-common /etc/php.d/20-bz2.ini
php-pdo /usr/lib64/php/modules/pdo.so
php-pdo /usr/lib64/php/modules/pdo_sqlite.so
php-pdo /usr/lib64/php/modules/sqlite3.so
php-pecl-redis6 /usr/lib64/php/modules/redis.so
php-embedded /usr/lib64/libphp.so
php-fpm /usr/sbin/php-fpm
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php-common'], equals(['bz2', 'curl']));
      expect(byPackage['php-pdo'], equals(['pdo', 'pdo_sqlite', 'sqlite3']));
      expect(byPackage['php-pecl-redis6'], equals(['redis']));
      expect(byPackage.containsKey('php-embedded'), isFalse);
      expect(byPackage.containsKey('php-fpm'), isFalse);
    });

    test('parseFileList handles Remi SCL paths under /opt/remi', () {
      const sclExtDir = '/opt/remi/php85/root/usr/lib64/php/modules';
      const stdout = '''
php85-php-common /opt/remi/php85/root/usr/lib64/php/modules/bz2.so
php85-php-common /opt/remi/php85/root/usr/lib64/php/modules/curl.so
php85-php-common /etc/opt/remi/php85/php.d/20-bz2.ini
php85-php-pecl-redis6 /opt/remi/php85/root/usr/lib64/php/modules/redis.so
php85-php-fpm /opt/remi/php85/root/usr/sbin/php-fpm
''';
      final byPackage = driver.parseFileList(stdout, sclExtDir);

      expect(byPackage['php85-php-common'], equals(['bz2', 'curl']));
      expect(byPackage['php85-php-pecl-redis6'], equals(['redis']));
      expect(byPackage.containsKey('php85-php-fpm'), isFalse);
    });

    test('combine matches packages with their discovered extensions', () {
      final packages = driver.parsePackageList('''
php-common
php-pdo
php-pecl-redis6
php-embedded
php-fpm
''', '8.5');

      final files = driver.parseFileList('''
php-common /usr/lib64/php/modules/bz2.so
php-common /usr/lib64/php/modules/curl.so
php-pdo /usr/lib64/php/modules/pdo.so
php-pdo /usr/lib64/php/modules/sqlite3.so
php-pecl-redis6 /usr/lib64/php/modules/redis.so
php-embedded /usr/lib64/libphp.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php-common', 'php-pdo', 'php-pecl-redis6']));
      expect(combined[0].extensionNames, equals(['bz2', 'curl']));
      expect(combined[1].extensionNames, equals(['pdo', 'sqlite3']));
      expect(combined[2].extensionNames, equals(['redis']));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/rhel_php_extension_driver_test.dart`
Expected: FAIL — `UnimplementedError` from `packageListCommands`.

- [ ] **Step 3: Write minimal implementation**

Replace `lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart` entirely:

```dart
import '../linux_php_extension_driver.dart';

/// RHEL, CentOS, Rocky, AlmaLinux and Fedora, including the Remi repository.
///
/// Extensions are discovered via `dnf repoquery`.
/// Extension names are resolved from package file lists (§2.7), which handles
/// arbitrary package naming without heuristics or exception tables (e.g.
/// `php-common` providing multiple extensions, `php-pecl-redis6` providing `redis`,
/// and non-extension libraries like `php-embedded` excluded by `extension_dir`).
///
/// Enabling and disabling uses [PhpIniStrategy.ownIniFile]: the manager writes
/// `<scanDir>/99-ponta-<ext>.ini` when enabling, and comments out the loader
/// line in every parsed ini (ours *and* any distro-shipped one) when disabling.
/// Nothing is ever deleted — `rm` is not on the validator's allowlist.
class RhelPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'rhel';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) {
    final scl = _sclPattern(phpVersion);
    return [
      "dnf repoquery --qf '[%{=NAME}\\n]' 'php-*'$scl",
    ];
  }

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (!LinuxPhpExtensionDriver.isSafeName(line)) continue;
      candidates.add(PackageCandidate(name: line, description: ''));
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    final scl = _sclPattern(phpVersion);
    return [
      "dnf repoquery -l --qf '[%{=NAME} %{FILENAMES}\\n]' 'php-*'$scl",
    ];
  }

  static String _sclPattern(String phpVersion) {
    final noDot = phpVersion.replaceAll('.', '');
    return noDot.isNotEmpty ? " 'php$noDot-php-*'" : '';
  }

  @override
  ({String package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(' ');
    if (sep <= 0) return null;
    var path = line.substring(sep + 1).trim();
    if (!path.startsWith('/')) path = '/$path';
    return (package: line.substring(0, sep).trim(), path: path);
  }

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) => [
    'dnf install -y ${pkg.name}',
  ];

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/rhel_php_extension_driver_test.dart`
Expected: PASS.

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart test/features/apps/rhel_php_extension_driver_test.dart
git commit -m "feat: implement RhelPhpExtensionDriver with file-list discovery"
```

---

### Task 7: Arch driver

**Files:**
- Modify: `lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart` (replace the Task 5 stub)
- Test: `test/features/apps/arch_php_extension_driver_test.dart` (create)

**Interfaces:**
- Consumes: `LinuxPhpExtensionDriver`, `PackageCandidate`, `driverForFamily` from Task 5.
- Produces: a complete `ArchPhpExtensionDriver` with `family == 'arch'` and `iniStrategy == PhpIniStrategy.ownIniFile`. Used by Task 8.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/arch_php_extension_driver_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/package_command_validator.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final driver = ArchPhpExtensionDriver();
  const extDir = '/usr/lib/php/modules';

  group('ArchPhpExtensionDriver commands', () {
    test('discovers packages with pacman -Ss', () {
      expect(
        driver.packageListCommands('8.5'),
        equals(['pacman -Ss php-']),
      );
    });

    test('discovers file lists with pacman -Fl for candidate packages', () {
      final packages = [
        const PackageCandidate(name: 'php-gd'),
        const PackageCandidate(name: 'php-sqlite'),
      ];
      expect(
        driver.fileListCommands('8.5', packages),
        equals(['pacman -Fl php-gd php-sqlite']),
      );
    });

    test('falls back to bare pacman -Fl when candidate package list is empty', () {
      expect(
        driver.fileListCommands('8.5', const []),
        equals(['pacman -Fl']),
      );
    });

    test('installs with pacman -S --noconfirm', () {
      expect(
        driver.installCommands(
          const PackageCandidate(name: 'php-gd'),
          '8.5',
        ),
        equals(['pacman -S --noconfirm php-gd']),
      );
    });

    test('enables and disables through ownIniFile strategy (empty command lists)', () {
      expect(driver.iniStrategy, PhpIniStrategy.ownIniFile);
      expect(driver.enableCommands('8.5', 'gd'), isEmpty);
      expect(driver.disableCommands('8.5', 'gd'), isEmpty);
      expect(driver.iniFileNameFor('gd'), equals('99-ponta-gd.ini'));
    });

    test('every generated command passes PackageCommandValidator', () {
      for (final cmd in [
        ...driver.packageListCommands('8.5'),
        ...driver.fileListCommands('8.5', const [PackageCandidate(name: 'php-gd')]),
        ...driver.installCommands(const PackageCandidate(name: 'php-gd'), '8.5'),
      ]) {
        expect(PackageCommandValidator.validate(cmd), isNull, reason: 'rejected: $cmd');
      }
    });
  });

  group('ArchPhpExtensionDriver parsing', () {
    test('parses repo/name version lines with indented descriptions', () {
      const stdout = '''
extra/php 8.4.11-1
    A general-purpose scripting language
extra/php-gd 8.4.11-1
    GD extension for PHP
extra/php-sqlite 8.4.11-1
    sqlite extension for PHP
extra/php-apache 8.4.11-1
    Apache SAPI for PHP
''';
      final candidates = driver.parsePackageList(stdout, '8.5');

      expect(candidates.map((c) => c.name), equals([
        'php',
        'php-gd',
        'php-sqlite',
        'php-apache',
      ]));
      expect(candidates[1].description, equals('GD extension for PHP'));
      expect(candidates[2].description, equals('sqlite extension for PHP'));
    });

    test('ignores blank lines and drops unsafe package names', () {
      const stdout = '''
extra/php-gd 8.4.11-1
    GD extension for PHP

extra/php-bad;rm 8.4.11-1
    Bad
''';
      final candidates = driver.parsePackageList(stdout, '8.5');
      expect(candidates.map((c) => c.name), equals(['php-gd']));
    });

    test('parseFileListLine handles pacman relative paths and prepends slash', () {
      final entry = driver.parseFileListLine('php-gd usr/lib/php/modules/gd.so');
      expect(entry, isNotNull);
      expect(entry!.package, equals('php-gd'));
      expect(entry.path, equals('/usr/lib/php/modules/gd.so'));
    });

    test('parseFileList filters to extensionDir and excludes runtime libraries', () {
      // Arch real data:
      // php-gd ships usr/lib/php/modules/gd.so
      // php-sqlite ships usr/lib/php/modules/pdo_sqlite.so and sqlite3.so
      // php-apache ships usr/lib/httpd/modules/libphp.so (junk: outside extensionDir)
      // php ships usr/bin/php (not .so)
      const stdout = '''
php-gd usr/lib/php/modules/gd.so
php-sqlite usr/lib/php/modules/pdo_sqlite.so
php-sqlite usr/lib/php/modules/sqlite3.so
php-apache usr/lib/httpd/modules/libphp.so
php usr/bin/php
''';
      final byPackage = driver.parseFileList(stdout, extDir);

      expect(byPackage['php-gd'], equals(['gd']));
      expect(byPackage['php-sqlite'], equals(['pdo_sqlite', 'sqlite3']));
      expect(byPackage.containsKey('php-apache'), isFalse);
      expect(byPackage.containsKey('php'), isFalse);
    });

    test('combine matches Arch packages with discovered extensions', () {
      final packages = driver.parsePackageList('''
extra/php 8.4.11-1
    A general-purpose scripting language
extra/php-gd 8.4.11-1
    GD extension for PHP
extra/php-sqlite 8.4.11-1
    sqlite extension for PHP
extra/php-apache 8.4.11-1
    Apache SAPI for PHP
''', '8.5');

      final files = driver.parseFileList('''
php-gd usr/lib/php/modules/gd.so
php-sqlite usr/lib/php/modules/pdo_sqlite.so
php-sqlite usr/lib/php/modules/sqlite3.so
php-apache usr/lib/httpd/modules/libphp.so
''', extDir);

      final combined = driver.combine(packages, files);

      expect(combined.map((c) => c.name), equals(['php-gd', 'php-sqlite']));
      expect(combined[0].extensionNames, equals(['gd']));
      expect(combined[1].extensionNames, equals(['pdo_sqlite', 'sqlite3']));
      expect(combined[0].description, equals('GD extension for PHP'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/arch_php_extension_driver_test.dart`
Expected: FAIL — `UnimplementedError` from `packageListCommands`.

- [ ] **Step 3: Write minimal implementation**

Replace `lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart` entirely:

```dart
import '../linux_php_extension_driver.dart';

/// Arch Linux and derivatives (Manjaro, EndeavourOS, ...).
///
/// Extensions are discovered via `pacman -Ss` and `pacman -Fl`.
/// Output paths from `pacman -Fl` lack a leading slash (`usr/lib/php/modules/gd.so`),
/// so [parseFileListLine] normalises them by prepending `/`.
///
/// Bundled packages (`php-gd`, `php-sqlite`, etc.) ship only `.so` files with
/// no ini files in `/etc/php/conf.d/`. Enabling and disabling uses
/// [PhpIniStrategy.ownIniFile]: the manager writes `<scanDir>/99-ponta-<ext>.ini`
/// when enabling, and comments out the loader line in every parsed ini when
/// disabling. Nothing is ever deleted — `rm` is not on the validator's allowlist.
class ArchPhpExtensionDriver extends LinuxPhpExtensionDriver {
  @override
  String get family => 'arch';

  @override
  PhpIniStrategy get iniStrategy => PhpIniStrategy.ownIniFile;

  @override
  List<String> packageListCommands(String phpVersion) => ['pacman -Ss php-'];

  @override
  List<PackageCandidate> parsePackageList(String stdout, String phpVersion) {
    final candidates = <PackageCandidate>[];
    final lines = stdout.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith(' ')) continue;
      final slash = line.indexOf('/');
      if (slash < 0) continue;
      final name = line.substring(slash + 1).split(' ').first;
      if (!LinuxPhpExtensionDriver.isSafeName(name)) continue;

      var description = '';
      if (i + 1 < lines.length && lines[i + 1].startsWith(' ')) {
        description = lines[i + 1].trim();
      }
      candidates.add(PackageCandidate(name: name, description: description));
    }
    return candidates;
  }

  @override
  List<String> fileListCommands(
    String phpVersion,
    List<PackageCandidate> packages,
  ) {
    final names = packages
        .map((p) => p.name)
        .where(LinuxPhpExtensionDriver.isSafeName)
        .toList();
    if (names.isEmpty) return ['pacman -Fl'];
    return ['pacman -Fl ${names.join(' ')}'];
  }

  @override
  ({String package, String path})? parseFileListLine(String line) {
    final sep = line.indexOf(' ');
    if (sep <= 0) return null;
    var path = line.substring(sep + 1).trim();
    if (!path.startsWith('/')) path = '/$path';
    return (package: line.substring(0, sep).trim(), path: path);
  }

  @override
  List<String> installCommands(PackageCandidate pkg, String phpVersion) => [
    'pacman -S --noconfirm ${pkg.name}',
  ];

  @override
  List<String> enableCommands(String phpVersion, String extName) => const [];

  @override
  List<String> disableCommands(String phpVersion, String extName) => const [];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/arch_php_extension_driver_test.dart`
Expected: PASS.

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/php_extension_drivers/arch_php_extension_driver.dart test/features/apps/arch_php_extension_driver_test.dart
git commit -m "feat: implement ArchPhpExtensionDriver with file-list discovery"
```

---

<!-- PLAN_PART_4 -->

### Task 8: `LinuxPhpExtensionManager` — state assembly and the single-switch flow

**Files:**
- Create: `lib/features/apps/data/linux_php_extension_manager.dart`
- Test: `test/features/apps/linux_php_extension_manager_test.dart` (create)

**Interfaces:**
- Consumes: `LinuxPhpIntrospector` (Task 4: `readInfo`, `readModules`), `LinuxPhpExtensionDriver` + `PackageCandidate` + `driverForFamily` (Task 5), `AppInstallerService.executePackageManagerCommands` and `BackgroundProcess.buildLinuxReloadArgs` (existing + Task 1), `AppModel.servicePid` (existing).
- Produces: `LinuxPhpExtensionManager.listExtensions` and `LinuxPhpExtensionManager.applyToggle`. Used by Task 9.

`LinuxPhpExtensionManager` is constructed with the resolved `php-fpm` binary
path (`app.execFilePath`), the driver for the host family, and injectable
collaborators so every code path runs on Windows CI with string fixtures. All
 elevated work flows through `AppInstallerService.executePackageManagerCommands`
(a single `pkexec` prompt), and reload through `kill -USR2 <master pid>`.

```dart
class LinuxPhpExtensionManager {
  LinuxPhpExtensionManager({
    required LinuxPhpIntrospector introspector,
    required LinuxPhpExtensionDriver driver,
    required Future<ProcessResult> Function(String, List<String>) runProcess,
    Future<ProcessResult> Function({
      required List<String> commands,
      required void Function(String) logInfo,
      required void Function(String) logError,
    })? runElevated,
    Future<void> Function(int pid)? reloader,
    bool Function(String path)? fileExists,
  });

  /// The full extension list for the Extensions tab (spec §3.1).
  Future<List<PhpExtension>> listExtensions({
    required String binaryPath,
    required String phpVersion,
  });

  /// Installs (if needed) + enables, or disables, [extName], then reloads.
  /// Returns a short human-readable outcome for the UI snackbar.
  Future<String> applyToggle({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    required bool enable,
    int? servicePid,
  });
}
```

Detailed behaviour (each paragraph below is pinned by a named test in Step 1):

- `listExtensions` runs discovery through the driver's `packageListCommands` /
  `parsePackageList` / `fileListCommands` / `parseFileList` / `combine` (one
  `runProcess` call per command string; a non-zero exit yields that command's
  contribution as empty rather than throwing — the tab renders what it could
  learn). A **missing** tool surfaces as a `ProcessException` from
  `Process.run` (there is no shell to report exit 127), and the manager throws
  `LinuxPhpDiscoveryUnavailable` (a plain `Exception` subclass with a message
  naming the missing tool) instead of degrading to a name heuristic — a wrong
  list is worse than an honest error (spec §2.8). The exit-127 arm is kept for
  fake runners that model the shell convention. Every `PackageCandidate`
  carrying a `null` version match is skipped, and every package or extension
  name failing `LinuxPhpExtensionDriver.isSafeName` is dropped silently.
- Indexing follows spec §3.1 steps 3–4: `byExtension` maps each discovered
  extension name to its package (first package wins when two packages ship the
  same `.so`); every module from `readModules` not covered by a package becomes
  a `PackageCandidate.synthetic([name])` entry, so statically compiled
  extensions (opcache) still render. `isEnabled` is membership in the module
  set; `isInstalled` is `fileExists('$extensionDir/<name>.so')` **or** the
  extension being synthetic (no `.so` can exist, yet it is manageable — it must
  not render "Not installed"); `isFoundInIni` is `isEnabled || isInstalled`;
  `isZend` is `driver.isZendExtension(name)`; `fileName` is `'<name>.so'`.
  The returned list is sorted by name.
- `applyToggle` enable path (spec §5.1): builds one ordered command list —
  install first (`driver.installCommands`, only when the extension has a
  package **and** `!isInstalled`), then enable (`driver.enableCommands` for
  Debian; for `ownIniFile` families a single
  `echo '<line>' | tee <scanDir>/99-ponta-<ext>.ini` writing
  `extension=<name>`, or `zend_extension=<name>` when `isZend`).
  `tee` (not a shell redirection) is what keeps this legal: `>` is a forbidden
  substring in `PackageCommandValidator`, while `echo … | tee <path>` is two
  allowlisted binaries and a target the widened `_allowedTeeTargets` accepts.
  The target is deliberately **unquoted** — the regex only admits
  `[\w.-]+\.ini`, so a `scanDir` containing whitespace fails validation
  (fail-closed) instead of silently splitting into extra shell words.
  `opcache` is the package-less special case the code must handle explicitly:
  its "install" step is skipped and its ini line is `opcache.enable=1` (a static
  zend module compiled into the FPM binary has no `.so` to load — spec §2.5 — so
  `zend_extension=opcache` would only produce `Failed loading Zend extension`
  warnings; the `opcache.enable` INI boolean is the on/off switch).
- `applyToggle` disable path (spec §5.2): the package is never removed.
  Debian emits `driver.disableCommands`. For `ownIniFile` families every ini
  file the binary actually parsed (`parsedIniFiles`, from `php-fpm -i`) is
  rewritten in place with a single `sed -E -i` that comments out the loader
  line for this extension — including our own `99-ponta-<ext>.ini`, which is in
  that list by construction (it is a file in `scanDir`, so a freshly spawned
  `php-fpm -i` reports it). Commenting rather than deleting keeps the change
  reversible and needs no `rm` (which is **not** on the validator's allowlist).
  The pattern is anchored on the loader directive and on the extension name, so
  disabling `pdo` cannot knock out `pdo_mysql`:
  `^\s*(zend_)?extension\s*=\s*"?(.*/)?NAME(\.so)?"?\s*$`
  (ERE, so no `\?` — busybox `sed` has no `\?`). `opcache` gets its own pattern
  `^\s*opcache\.enable\s*=.*$`, because its line form is a
  directive assignment, not a loader line. `\s` (not `[[:space:]]`) because
  Dart's `RegExp` is ECMAScript, where the POSIX class is the literal set
  `{[, :, s, p, a, c, e}` — `^[[:space:]]*$` matches `":"` and rejects a
  spaces-only line; every `\s` lives in a **raw** string literal.
  The comment character is written as the escape `\x3b`, never as a literal
  `;`: the validator rejects `;` anywhere in a command, and PHP's ini scanner
  treats **only** `;` as a comment (`#` is *not* a comment — verified against
  `Zend/zend_ini_scanner.l` and by running PHP). `\x3b` in a `sed` replacement
  is a GNU extension; that is already assumed here because `sed -i` without a
  suffix argument is itself GNU-only, and all three supported families ship GNU
  sed. The result is `;extension=redis.so`, a real comment.
- The script runs through `runElevated` (default:
  `AppInstallerService.executePackageManagerCommands`) so install+enable share
  a single elevation prompt. Every command string is passed through
  `PackageCommandValidator.validateAll` first; on rejection the toggle aborts
  before elevation. When `enableCommands`/`disableCommands` is empty **and** the
  family uses `ownIniFile`, the manager still proceeds (the ini write is the
  enable); when the list is empty on an `externalTool` family, it throws
  `StateError` rather than reporting a false success.
- Discovery on the toggle path is best-effort (a failure must not block a toggle
  whose `.so` is already on disk), but it must not fail *silently* either: if
  the extension has no owning package, is not already installed, and discovery
  failed, the manager rethrows `LinuxPhpDiscoveryUnavailable` naming the
  missing tool. Without that, the user sees "did not load after enabling"
  instead of "install `apt-file`".
- After elevation, unless `servicePid` is null (app not running — skip silently):
  `reloader` (default: `Process.run` with `BackgroundProcess.buildLinuxReloadArgs`
  argv) sends `SIGUSR2` to the master PID only. A reload failure does not fail
  the toggle — the returned message notes a restart is needed.
- Re-introspection (spec §5.1 step 4): after reload, `readModules` runs again;
  if enabling and the name is absent from the module set, the manager throws
  with the elevated command's captured stdout folded into the message — never a
  false success. (Disabling cannot be verified this way for `opcache` on a
  static build: `opcache.enable=0` keeps the module listed in `php-fpm -m` while
  disabling acceleration, so the disable path skips the absent-check for
  synthetic entries and trusts the reload.)

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/linux_php_extension_manager_test.dart`. Fixtures use
a Debian-style binary (`scanDir /etc/php/8.5/fpm/conf.d`,
`extensionDir /usr/lib/php/20250925`) and a Remi-style binary
(`scanDir /etc/php.d`, `extensionDir /usr/lib64/php/modules`):

```dart
import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/linux_php_extension_manager.dart';
import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/rhel_php_extension_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake runProcess keyed on exact command strings.
///
/// The key is built from the **argv as the manager passes it**, which is after
/// [LinuxPhpExtensionDriver.splitCommand] has stripped the single quotes the
/// discovery commands carry. So `"apt-file list -x '^php8.5-'"` is stubbed as
/// `'apt-file list -x ^php8.5-'` — the pattern without quotes.
Future<ProcessResult> Function(String, List<String>) fakeRunner(
  Map<String, ({int exitCode, String stdout})> responses,
) {
  return (exe, args) async {
    final key = ([exe, ...args]).join(' ');
    final r = responses[key];
    if (r == null) {
      return ProcessResult(0, 127, '', 'not stubbed: $key');
    }
    return ProcessResult(0, r.exitCode, r.stdout, '');
  };
}

/// The discovery stub set every `applyToggle` test needs: `_enable` re-runs
/// discovery to find the owning package, so a test that stubs only `-m` gets
/// exit 127 from these three and never produces the install command.
Map<String, ({int exitCode, String stdout})> _debianDiscovery({
  String packages = 'php8.5-curl - CURL module for PHP\n',
  String files = 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
}) => {
  'apt-cache search --names-only php8.5-': (exitCode: 0, stdout: packages),
  'apt-file list -x ^php8.5-': (exitCode: 0, stdout: files),
};

const _debianInfo = '''
phpinfo()
PHP Version => 8.5.0

Scan this dir for additional .ini files => /etc/php/8.5/fpm/conf.d
Additional .ini files parsed => /etc/php/8.5/fpm/conf.d/20-mbstring.ini

extension_dir => /usr/lib/php/20250925 => /usr/lib/php/20250925
''';

const _debianModules = '''
[PHP Modules]
Core
mbstring
opcache
standard
''';

void main() {
  group('LinuxPhpExtensionManager.listExtensions (Debian)', () {
    test('merges package candidates with enabled modules incl. synthetic opcache', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: _debianModules),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-mbstring - MBSTRING module for PHP\nphp8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-mbstring: /usr/lib/php/20250925/mbstring.so\n'
              'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['curl', 'mbstring', 'opcache']));
      final mb = exts[1];
      expect(mb.isEnabled, isTrue);
      expect(mb.isInstalled, isTrue);
      expect(mb.packageName, 'php8.5-mbstring');
      expect(mb.description, 'MBSTRING module for PHP');
      // opcache is enabled, manageable, and must NOT render "Not installed".
      final op = exts[2];
      expect(op.isEnabled, isTrue);
      expect(op.isInstalled, isTrue);
      expect(op.packageName, isNull);
      expect(op.isZend, isTrue);
      expect(op.fileName, 'opcache.so');
    });

    test('marks a discovered-but-absent .so as not installed', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => false,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      expect(exts.length, equals(1));
      expect(exts.single.name, 'curl');
      expect(exts.single.isInstalled, isFalse);
      expect(exts.single.isEnabled, isFalse);
    });

    test('drops a package name that fails the safety regex', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-evil; rm -rf / - boom\nphp8.5-curl - CURL module for PHP\n',
        ),
        'apt-file list -x ^php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl: /usr/lib/php/20250925/curl.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['curl']));
    });

    test('throws LinuxPhpDiscoveryUnavailable when apt-file is missing', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (exitCode: 0, stdout: '[PHP Modules]\nCore\n'),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
        // exit 127 with empty stdout: apt-file is not installed.
        'apt-file list -x ^php8.5-': (exitCode: 127, stdout: ''),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      expect(
        () => manager.listExtensions(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });

    test('treats a ProcessException from a missing tool as discovery unavailable', () async {
      // This is how a missing tool actually surfaces on a real host: discovery
      // runs through Process.run (no shell), so Dart throws ProcessException
      // when the executable is absent — there is no exit 127 to inspect. If
      // this arm were missing, the exception would be swallowed by the generic
      // catch and the user would see a silently empty extension list.
      Future<ProcessResult> runProcess(String exe, List<String> args) async {
        final key = ([exe, ...args]).join(' ');
        if (key == '/usr/sbin/php-fpm8.5 -i') {
          return ProcessResult(0, 0, _debianInfo, '');
        }
        if (key == '/usr/sbin/php-fpm8.5 -m') {
          return ProcessResult(0, 0, '[PHP Modules]\nCore\n', '');
        }
        if (key == 'apt-cache search --names-only php8.5-') {
          return ProcessResult(0, 0, 'php8.5-curl - CURL module for PHP\n', '');
        }
        if (key == 'apt-file list -x ^php8.5-') {
          throw const ProcessException('apt-file', [], 'No such file or directory');
        }
        return ProcessResult(0, 127, '', 'not stubbed: $key');
      }

      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (_) => true,
      );

      expect(
        () => manager.listExtensions(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });
  });

  group('LinuxPhpExtensionManager.listExtensions (RHEL)', () {
    test('resolves redis from php-pecl-redis6 through the file list', () async {
      const info = '''
phpinfo()
PHP Version => 8.5.0

Scan this dir for additional .ini files => /etc/php.d
Additional .ini files parsed => /etc/php.d/20-redis.ini

extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules
''';
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (exitCode: 0, stdout: info),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf [%{=NAME}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6\nphp-embedded\n',
        ),
        'dnf repoquery -l --qf [%{=NAME} %{FILENAMES}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6 /usr/lib64/php/modules/redis.so\n'
              'php-embedded /usr/lib64/libphp.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        fileExists: (path) => path.endsWith('/redis.so'),
      );

      final exts = await manager.listExtensions(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
      );

      expect(exts.map((e) => e.name), equals(['redis']));
      expect(exts.single.packageName, 'php-pecl-redis6');
      expect(exts.single.isEnabled, isTrue);
    });
  });

  group('LinuxPhpExtensionManager.applyToggle', () {
    test('enable installs then enables under one elevation with a reload', () async {
      final elevated = <List<String>>[];
      var reloadedPid = -1;
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (pid) async {
          reloadedPid = pid;
        },
      );

      final message = await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: 4242,
      );

      expect(elevated.length, equals(1));
      expect(
        elevated.single,
        equals([
          'apt-get install -y php8.5-curl',
          'phpenmod -v 8.5 -s fpm curl',
        ]),
      );
      expect(reloadedPid, equals(4242));
      expect(message, contains('curl'));
    });

    test('enable skips install when the .so is already present', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: null,
      );

      expect(elevated.single, equals(['phpenmod -v 8.5 -s fpm curl']));
    });

    test('enable of opcache writes opcache.enable=1 through tee, not zend_extension=', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => /etc/php.d\n'
              'extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules\n',
        ),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nopcache\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [],
        extName: 'opcache',
        enable: true,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(elevated.single.length, equals(1));
      expect(
        elevated.single.single,
        equals("echo 'opcache.enable=1' | tee /etc/php.d/99-ponta-opcache.ini"),
      );
      expect(elevated.single.single, isNot(contains('zend_extension=opcache')));
      // The command must survive the validator unchanged — `>` is banned, and
      // an unquoted tee target is what makes the widened regex enforceable.
      expect(PackageCommandValidator.validate(elevated.single.single), isNull);
    });

    test('enable of a normal extension writes extension= through tee', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => /etc/php.d\n'
              'extension_dir => /usr/lib64/php/modules => /usr/lib64/php/modules\n',
        ),
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf [%{=NAME}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6\n',
        ),
        'dnf repoquery -l --qf [%{=NAME} %{FILENAMES}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php-pecl-redis6 /usr/lib64/php/modules/redis.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [],
        extName: 'redis',
        enable: true,
        servicePid: null,
      );

      expect(
        elevated.single,
        equals(["echo 'extension=redis' | tee /etc/php.d/99-ponta-redis.ini"]),
      );
    });

    test('disable comments out the loader line in every parsed ini, incl. ours', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [
          '/etc/php.d/20-redis.ini',
          '/etc/php.d/99-ponta-redis.ini',
        ],
        extName: 'redis',
        enable: false,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(elevated.single.length, equals(2));
      // Our own file is in the parsed list, so commenting it out is the whole
      // disable — no `rm` (which is not on the validator's allowlist).
      for (final cmd in elevated.single) {
        expect(cmd, startsWith('sed -E -i '));
        expect(cmd, contains(r'\x3b'));
        expect(PackageCommandValidator.validate(cmd), isNull, reason: cmd);
      }
      expect(elevated.single[0], contains('/etc/php.d/20-redis.ini'));
      expect(elevated.single[1], contains('/etc/php.d/99-ponta-redis.ini'));
      // The pattern is anchored on the full name, so it cannot match a longer
      // name that merely starts with it (`pdo` must not knock out `pdo_mysql`).
      expect(elevated.single[0], contains(r'redis(\.so)?"?\s*$'));
    });

    test('disable refuses to sed a file outside the scan dir or with an unsafe name', () async {
      // The parsed-ini list is attacker-reachable (it is whatever `php-fpm -i`
      // printed), and the validator does not constrain `sed`'s target — only
      // its leading binary. So the manager must gate the path itself: a file
      // outside `scanDir`, or one whose name would break the single-quoted
      // shell word (a `'` in the basename injects extra `sed -e` expressions
      // that contain none of the validator's forbidden substrings), must be
      // skipped rather than rewritten.
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const [
          '/etc/php.d/20-redis.ini', // legitimate: kept
          '/etc/shadow', // outside scanDir: dropped
          '/etc/php.d/../../shadow', // traversal: dropped
          "/etc/php.d/x.ini' -e 's,.*,PWNED,w /tmp/p' -e '", // injection: dropped
          '/etc/php.d/sub/nested.ini', // not a plain child: dropped
          '/etc/php.d/UPPER.ini', // fails isSafeName: dropped
        ],
        extName: 'redis',
        enable: false,
        servicePid: null,
      );

      expect(elevated.length, equals(1));
      expect(
        elevated.single.length,
        equals(1),
        reason: 'only /etc/php.d/20-redis.ini may be rewritten',
      );
      expect(elevated.single.single, contains('/etc/php.d/20-redis.ini'));
      for (final bad in ['/etc/shadow', 'PWNED', 'nested.ini', 'UPPER.ini']) {
        expect(elevated.single.single, isNot(contains(bad)));
      }
    });

    test('enable and disable work on Remi SCL layout (/etc/opt/remi/php85/php.d)', () async {
      final elevated = <List<String>>[];
      const bin = '/opt/remi/php85/root/usr/sbin/php-fpm';
      const scanDir = '/etc/opt/remi/php85/php.d';
      const extDir = '/opt/remi/php85/root/usr/lib64/php/modules';
      final runProcess = fakeRunner({
        '$bin -i': (
          exitCode: 0,
          stdout: 'Scan this dir for additional .ini files => $scanDir\n'
              'extension_dir => $extDir => $extDir\n',
        ),
        '$bin -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nredis\n',
        ),
        'dnf repoquery --qf [%{=NAME}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php85-php-pecl-redis6\n',
        ),
        'dnf repoquery -l --qf [%{=NAME} %{FILENAMES}\\n] php-* php85-php-*': (
          exitCode: 0,
          stdout: 'php85-php-pecl-redis6 $extDir/redis.so\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      await manager.applyToggle(
        binaryPath: bin,
        phpVersion: '8.5',
        scanDir: scanDir,
        parsedIniFiles: const [],
        extName: 'redis',
        enable: true,
        servicePid: null,
      );

      expect(
        elevated.single,
        equals(["echo 'extension=redis' | tee $scanDir/99-ponta-redis.ini"]),
      );
      expect(PackageCommandValidator.validate(elevated.single.single), isNull);
    });

    test('the disable pattern is name-anchored so pdo cannot disable pdo_mysql', () {
      final driver = RhelPhpExtensionDriver();
      final pattern = driver.disableIniPattern('pdo');
      final re = RegExp(pattern);
      expect(re.hasMatch('extension=pdo.so'), isTrue);
      expect(re.hasMatch('zend_extension="pdo.so"'), isTrue);
      expect(re.hasMatch('extension=/usr/lib64/php/modules/pdo.so'), isTrue);
      expect(re.hasMatch('extension=pdo_mysql.so'), isFalse);
      expect(re.hasMatch('extension=pdo_pgsql.so'), isFalse);
    });

    test('disable of opcache uses the opcache.enable pattern, not the loader one', () async {
      final elevated = <List<String>>[];
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\nopcache\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: RhelPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          elevated.add(commands);
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {},
      );

      await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm',
        phpVersion: '8.5',
        scanDir: '/etc/php.d',
        parsedIniFiles: const ['/etc/php.d/10-opcache.ini'],
        extName: 'opcache',
        enable: false,
        servicePid: null,
      );

      expect(elevated.single.single, contains('opcache'));
      expect(elevated.single.single, contains(r'opcache\.enable'));
      expect(elevated.single.single, isNot(contains('zend_extension')));
    });

    test('reports restart-needed instead of failing when the master is not running', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\ncurl\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          return ProcessResult(0, 0, '', '');
        },
        reloader: (_) async {
          throw const ProcessException('kill', ['-USR2']);
        },
        fileExists: (_) => true,
      );

      final message = await manager.applyToggle(
        binaryPath: '/usr/sbin/php-fpm8.5',
        phpVersion: '8.5',
        scanDir: '/etc/php/8.5/fpm/conf.d',
        parsedIniFiles: const [],
        extName: 'curl',
        enable: true,
        servicePid: 4242,
      );

      expect(message.toLowerCase(), contains('restart'));
    });

    test('names the missing discovery tool instead of a misleading load failure', () async {
      // The .so is absent and discovery cannot say which package would provide
      // it: the user must be told to install `apt-file`, not that the extension
      // "did not load".
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
        // apt-file is not installed: exit 127.
        'apt-file list -x ^php8.5-': (exitCode: 127, stdout: ''),
        'apt-cache search --names-only php8.5-': (
          exitCode: 0,
          stdout: 'php8.5-curl - CURL module for PHP\n',
        ),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          fail('must not elevate when discovery is unavailable');
        },
        reloader: (_) async {},
        fileExists: (_) => false,
      );

      expect(
        () => manager.applyToggle(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: const [],
          extName: 'curl',
          enable: true,
          servicePid: null,
        ),
        throwsA(isA<LinuxPhpDiscoveryUnavailable>()),
      );
    });

    test('throws rather than reporting success when the module stays absent', () async {
      final runProcess = fakeRunner({
        '/usr/sbin/php-fpm8.5 -i': (exitCode: 0, stdout: _debianInfo),
        '/usr/sbin/php-fpm8.5 -m': (
          exitCode: 0,
          stdout: '[PHP Modules]\nCore\n',
        ),
        ..._debianDiscovery(),
      });
      final manager = LinuxPhpExtensionManager(
        introspector: LinuxPhpIntrospector(runProcess: runProcess),
        driver: DebianPhpExtensionDriver(),
        runProcess: runProcess,
        runElevated: ({required commands, required logInfo, required logError}) async {
          return ProcessResult(0, 0, 'some log', '');
        },
        reloader: (_) async {},
        fileExists: (_) => true,
      );

      expect(
        () => manager.applyToggle(
          binaryPath: '/usr/sbin/php-fpm8.5',
          phpVersion: '8.5',
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: const [],
          extName: 'curl',
          enable: true,
          servicePid: null,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/linux_php_extension_manager_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/apps/data/linux_php_extension_manager.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/apps/data/linux_php_extension_manager.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/services/background_process.dart';
import '../domain/php_extension.dart';
import 'app_installer_service.dart';
import 'linux_php_extension_driver.dart';
import 'linux_php_introspector.dart';
import 'package_command_validator.dart';

/// Thrown when package discovery cannot run honestly (spec §2.8): the
/// bootstrap tool (`apt-file`, or the `pacman` files database) is missing.
/// Callers show an explicit message rather than a guessed extension list.
class LinuxPhpDiscoveryUnavailable implements Exception {
  final String message;
  const LinuxPhpDiscoveryUnavailable(this.message);

  @override
  String toString() => 'LinuxPhpDiscoveryUnavailable: $message';
}

typedef _ElevatedRunner =
    Future<ProcessResult> Function({
      required List<String> commands,
      required void Function(String) logInfo,
      required void Function(String) logError,
    });

/// Orchestrates Linux PHP extension discovery and the single-switch toggle
/// flow (spec §3, §5). Every external interaction is injectable so the whole
/// flow runs on Windows CI with string fixtures.
class LinuxPhpExtensionManager {
  final LinuxPhpIntrospector _introspector;
  final LinuxPhpExtensionDriver _driver;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;
  final _ElevatedRunner _runElevated;
  final Future<void> Function(int pid) _reloader;
  final bool Function(String path) _fileExists;

  LinuxPhpExtensionManager({
    required LinuxPhpIntrospector introspector,
    required LinuxPhpExtensionDriver driver,
    required Future<ProcessResult> Function(String, List<String>) runProcess,
    _ElevatedRunner? runElevated,
    Future<void> Function(int pid)? reloader,
    bool Function(String path)? fileExists,
  }) : _introspector = introspector,
       _driver = driver,
       _runProcess = runProcess,
       _runElevated =
           runElevated ??
           ({
             required List<String> commands,
             required void Function(String) logInfo,
             required void Function(String) logError,
           }) => AppInstallerService.executePackageManagerCommands(
             commands: commands,
             logInfo: logInfo,
             logError: logError,
             runProcess: runProcess,
           ),
       _reloader =
           reloader ??
           ((pid) async {
             final args = BackgroundProcess.buildLinuxReloadArgs(pid);
             final result = await runProcess(args.executable, args.arguments);
             if (result.exitCode != 0) {
               throw ProcessException(
                 args.executable,
                 args.arguments,
                 result.stderr.toString(),
                 result.exitCode,
               );
             }
           }),
       _fileExists = fileExists ?? ((path) => File(path).existsSync());

  /// The full extension list for the Extensions tab (spec §3.1).
  Future<List<PhpExtension>> listExtensions({
    required String binaryPath,
    required String phpVersion,
  }) async {
    final info = await _introspector.readInfo(binaryPath);
    final enabled = await _introspector.readModules(binaryPath);
    final extensionDir = info.extensionDir ?? '';

    final packages = await _listPackages(phpVersion);
    final filesByPackage = await _listFiles(phpVersion, packages, extensionDir);
    final combined = _driver.combine(packages, filesByPackage);

    final byExtension = <String, PackageCandidate>{};
    for (final pkg in combined) {
      for (final extName in pkg.extensionNames) {
        byExtension.putIfAbsent(extName, () => pkg);
      }
    }
    // Statically compiled modules (opcache) arrive from the module side.
    for (final extName in enabled) {
      if (!LinuxPhpExtensionDriver.isSafeName(extName)) continue;
      byExtension.putIfAbsent(
        extName,
        () => PackageCandidate.synthetic([extName]),
      );
    }

    final result = <PhpExtension>[];
    for (final entry in byExtension.entries) {
      final extName = entry.key;
      final pkg = entry.value;
      final isEnabled = enabled.contains(extName);
      // A synthetic entry has no .so by construction; it is manageable, so it
      // must not render "Not installed".
      final isInstalled =
          !pkg.hasPackage || _fileExists('$extensionDir/$extName.so');
      result.add(
        PhpExtension(
          name: extName,
          fileName: '$extName.so',
          isEnabled: isEnabled,
          isFoundInIni: isEnabled || isInstalled,
          isZend: _driver.isZendExtension(extName),
          isInstalled: isInstalled,
          packageName: pkg.hasPackage ? pkg.name : null,
          description: pkg.hasPackage && pkg.description.isNotEmpty
              ? pkg.description
              : null,
        ),
      );
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<List<PackageCandidate>> _listPackages(String phpVersion) async {
    final out = <PackageCandidate>[];
    for (final cmd in _driver.packageListCommands(phpVersion)) {
      final stdout = await _runDiscovery(cmd);
      if (stdout == null) continue;
      out.addAll(_driver.parsePackageList(stdout, phpVersion));
    }
    return out;
  }

  Future<Map<String, List<String>>> _listFiles(
    String phpVersion,
    List<PackageCandidate> packages,
    String extensionDir,
  ) async {
    final merged = <String, List<String>>{};
    for (final cmd in _driver.fileListCommands(phpVersion, packages)) {
      final stdout = await _runDiscovery(cmd);
      if (stdout == null) continue;
      final parsed = _driver.parseFileList(stdout, extensionDir);
      for (final entry in parsed.entries) {
        merged.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
      }
    }
    for (final names in merged.values) {
      names.sort();
    }
    return merged;
  }

  /// Runs one discovery command. Returns null when the command failed but the
  /// list can still be partial; throws [LinuxPhpDiscoveryUnavailable] when the
  /// failure means the tool itself is missing.
  ///
  /// A missing tool does **not** arrive as exit 127 here: discovery goes
  /// through `Process.run` (direct argv, no shell), and Dart throws a
  /// [ProcessException] when the executable cannot be found — it never spawns
  /// a shell that could report 127. So the `ProcessException` arm is the one
  /// that matters for `apt-file` / `pacman` not being installed. Getting this
  /// wrong is a silent failure: the exception would fall into the generic
  /// `catch` below, discovery would return null, and the user would see an
  /// empty extension list with no explanation — exactly what spec §2.8 forbids
  /// ("a wrong list is worse than an honest error"). The 127 check is kept as
  /// a belt-and-braces for a fake runner that models the shell convention.
  Future<String?> _runDiscovery(String command) async {
    final parts = _splitCommand(command);
    try {
      final result = await _runProcess(parts.first, parts.sublist(1));
      if (result.exitCode != 0) {
        if (result.exitCode == 127) {
          throw LinuxPhpDiscoveryUnavailable(
            'Discovery tool is missing for: $command',
          );
        }
        return null;
      }
      return result.stdout.toString();
    } on LinuxPhpDiscoveryUnavailable {
      rethrow;
    } on ProcessException catch (e) {
      throw LinuxPhpDiscoveryUnavailable(
        'Discovery tool could not be run for "$command": ${e.message}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Installs (if needed) + enables, or disables, [extName], then reloads.
  Future<String> applyToggle({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    required bool enable,
    int? servicePid,
  }) async {
    if (!LinuxPhpExtensionDriver.isSafeName(extName)) {
      throw ArgumentError.value(extName, 'extName', 'Unsafe extension name');
    }
    if (enable) {
      return _enable(
        binaryPath: binaryPath,
        phpVersion: phpVersion,
        scanDir: scanDir,
        extName: extName,
        servicePid: servicePid,
      );
    }
    return _disable(
      binaryPath: binaryPath,
      phpVersion: phpVersion,
      scanDir: scanDir,
      parsedIniFiles: parsedIniFiles,
      extName: extName,
      servicePid: servicePid,
    );
  }

  Future<String> _enable({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required String extName,
    int? servicePid,
  }) async {
    // Resolve the owning package: the file list is the source of truth, so a
    // cheap re-discovery here handles toggles issued without a prior list.
    PackageCandidate? owner;
    String extensionDir = '';
    Object? discoveryError;
    try {
      final info = await _introspector.readInfo(binaryPath);
      extensionDir = info.extensionDir ?? '';
      final packages = await _listPackages(phpVersion);
      final files = await _listFiles(phpVersion, packages, extensionDir);
      final combined = _driver.combine(packages, files);
      for (final pkg in combined) {
        if (pkg.extensionNames.contains(extName)) {
          owner = pkg;
          break;
        }
      }
    } on LinuxPhpDiscoveryUnavailable catch (e) {
      // Remembered, not swallowed: if it turns out we needed the package (the
      // .so is not on disk) the caller gets the real reason — "install
      // apt-file" — instead of a misleading "did not load".
      discoveryError = e;
    } catch (_) {
      // Any other discovery failure is genuinely best-effort.
    }

    final isSynthetic = extName == 'opcache' && owner == null;
    final alreadyInstalled =
        isSynthetic || _fileExists('$extensionDir/$extName.so');

    if (owner == null && !alreadyInstalled && discoveryError != null) {
      throw discoveryError;
    }

    final commands = <String>[];
    if (owner != null && owner.hasPackage && !alreadyInstalled) {
      commands.addAll(_driver.installCommands(owner, phpVersion));
    }
    if (_driver.iniStrategy == PhpIniStrategy.externalTool) {
      commands.addAll(_driver.enableCommands(phpVersion, extName));
    } else {
      commands.add(_enableIniCommand(scanDir, extName));
    }
    if (commands.isEmpty) {
      throw StateError('No enable step produced for $extName');
    }

    final rejection = PackageCommandValidator.validateAll(commands);
    if (rejection.isNotEmpty) {
      throw StateError('Refusing to run rejected commands: $rejection');
    }

    final logs = StringBuffer();
    await _runElevated(
      commands: commands,
      logInfo: (m) => logs.writeln(m),
      logError: (m) => logs.writeln('ERROR: $m'),
    );

    final reloadNote = await _reload(servicePid);
    await _verifyEnabled(binaryPath, extName, isSynthetic, logs.toString());
    return 'Extension $extName enabled.$reloadNote';
  }

  /// The command that turns an extension on for `ownIniFile` families.
  ///
  /// `opcache` is compiled into the FPM binary on every family (spec §2.5), so
  /// there is no `.so` to load: `zend_extension=opcache` would only emit
  /// `Failed loading Zend extension` warnings. The `opcache.enable` INI
  /// boolean is the real on/off switch (Remi's own `10-opcache.ini` ships
  /// `opcache.enable=1`).
  ///
  /// The line is delivered with `echo … | tee <file>` rather than a shell
  /// redirection: `>` is a forbidden substring in `PackageCommandValidator`,
  /// and both `echo` and `tee` are allowlisted. The target is left unquoted so
  /// the widened `_allowedTeeTargets` regex — which admits only
  /// `[\w.-]+\.ini` — is the thing that decides whether the write is legal.
  String _enableIniCommand(String scanDir, String extName) {
    final line = extName == 'opcache'
        ? 'opcache.enable=1'
        : '${_driver.isZendExtension(extName) ? 'zend_extension' : 'extension'}=$extName';
    final target = '$scanDir/${_driver.iniFileNameFor(extName)}';
    return "echo '$line' | tee $target";
  }

  Future<String> _disable({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    int? servicePid,
  }) async {
    final commands = <String>[];
    if (_driver.iniStrategy == PhpIniStrategy.externalTool) {
      commands.addAll(_driver.disableCommands(phpVersion, extName));
    } else {
      // Comment out the loader line in every ini the binary actually parsed.
      // Our own `99-ponta-<ext>.ini` is in that list (it is a file in scanDir,
      // so a freshly spawned `php-fpm -i` reports it), so this one command
      // covers both "our file" and "the distro's file" — no `rm` needed, which
      // matters because `rm` is not on the validator's allowlist.
      //
      // The pattern is anchored on the extension name so disabling `pdo` can
      // never knock out `pdo_mysql`. The replacement is the escape `\x3b`
      // (GNU sed) rather than a literal `;`, which the validator forbids
      // anywhere in a command. `,` is the sed delimiter because the pattern
      // itself contains `/` (the optional absolute-path group).
      //
      // The ini path is attacker-reachable: it is whatever `php-fpm -i` printed
      // for `Additional .ini files parsed`, and a poisoned ini in a
      // world-writable scan dir would land there. Two consequences make a bare
      // `startsWith('/')` gate insufficient, both verified by probe:
      //   1. `sed -i` would happily rewrite `/etc/shadow` or `/etc/sudoers`.
      //   2. the path is interpolated inside single quotes, so a filename
      //      containing `'` closes the quote early — `/etc/php.d/x.ini' -e
      //      's,.*,PWNED,w /tmp/p' -e '` turns into extra `sed` expressions
      //      and contains none of the validator's forbidden substrings.
      // The gate is therefore structural: the file must be a *plain child* of
      // the scan dir the binary itself reported, with a name that survives
      // `isSafeName` (which excludes `'`, `/`, spaces, and every other
      // metacharacter). Probe: this blocks 10/10 hostile paths and drops 0/6
      // legitimate ones (`/etc/php.d/…`, `/etc/php/conf.d/…`,
      // `/etc/php/8.5/fpm/conf.d/…`).
      final pattern = _driver.disableIniPattern(extName);
      for (final ini in parsedIniFiles) {
        if (p.posix.dirname(ini) != scanDir) continue;
        if (!LinuxPhpExtensionDriver.isSafeName(p.posix.basename(ini))) continue;
        commands.add(r"sed -E -i 's," + pattern + r',\x3b&,' + " '$ini'");
      }
    }
    if (commands.isEmpty) {
      throw StateError('No disable step produced for $extName');
    }

    final rejection = PackageCommandValidator.validateAll(commands);
    if (rejection.isNotEmpty) {
      throw StateError('Refusing to run rejected commands: $rejection');
    }

    await _runElevated(
      commands: commands,
      logInfo: (_) {},
      logError: (_) {},
    );

    final reloadNote = await _reload(servicePid);
    // No post-disable module check: for a static build, `opcache.enable=0`
    // keeps `opcache` listed in `php-fpm -m` while disabling acceleration.
    return 'Extension $extName disabled.$reloadNote';
  }

  /// Reloads the running FPM master, or reports a restart note on any failure
  /// (spec §5.3 and Review Focus item 4).
  Future<String> _reload(int? servicePid) async {
    if (servicePid == null) return '';
    try {
      await _reloader(servicePid);
      return '';
    } catch (_) {
      return ' PHP-FPM is not running — restart it to apply the change.';
    }
  }

  Future<void> _verifyEnabled(
    String binaryPath,
    String extName,
    bool isSynthetic,
    String logs,
  ) async {
    if (isSynthetic) return;
    final enabled = await _introspector.readModules(binaryPath);
    if (!enabled.contains(extName)) {
      throw Exception(
        'Extension $extName did not load after enabling. Output:\n$logs',
      );
    }
  }

  List<String> _splitCommand(String command) =>
      LinuxPhpExtensionDriver.splitCommand(command);
}
```

Two details in the implementation deserve a second look from the reviewer:

- `LinuxPhpExtensionDriver.splitCommand` **removes** the single quotes rather
  than keeping them. Discovery runs through `runProcess` (direct argv, no
  shell), so a kept quote would travel literally into `apt-file`'s pattern
  argument and match nothing — `apt-file` would look for a package literally
  named `'^php8.5-'`. The tests therefore stub the unquoted form.
- The `sed` replacement uses `\x3b` (GNU sed) to emit the `;` comment prefix
  without the command text ever containing `;`, which the validator forbids.
  PHP's ini scanner treats only `;` as a comment — `#` is *not* one — so
  writing `\x3b` is not cosmetic. `&` (the whole match) keeps the original
  line intact after the new `;`, and the pattern is idempotent: running it
  twice does not produce `;;`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/linux_php_extension_manager_test.dart`
Expected: PASS (18 tests).

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/linux_php_extension_manager.dart test/features/apps/linux_php_extension_manager_test.dart
git commit -m "feat: add LinuxPhpExtensionManager with single-switch toggle flow"
```

---

### Task 9: Linux branch in `PhpSettings` + `LinuxPhpExtensionManager` wiring

**Files:**
- Modify: `lib/features/apps/data/php_settings_provider.dart` (`getExtensions` gains a Linux branch; `toggleExtension` gains a Linux branch; both delegate to `LinuxPhpExtensionManager`)
- Modify: `lib/features/apps/data/linux_php_extension_manager.dart` (add `forApp` factory — see Step 3)
- Test: `test/features/apps/php_settings_linux_branch_test.dart` (create)

**Interfaces:**
- Consumes: `LinuxPhpExtensionManager` + `LinuxPhpDiscoveryUnavailable` (Task 8), `driverForFamily` (Task 5), `LinuxDistroResolver.detectFamily` (existing), `AppInstallerService.systemPackageMarker` / `phpPrefixFor` (existing), `PhpExtension` (Task 3).
- Produces: `PhpSettings.getExtensions` / `toggleExtension` work on Linux for `system_package` apps without changing any Windows behaviour. `toggleExtension`'s signature widens from `Future<void>` to `Future<String?>` in this task (the Linux path returns the manager's message; the Windows path returns `null`). Used by Task 10.

The Linux entry condition is `Platform.isLinux && app.location == AppInstallerService.systemPackageMarker`. Anything else falls through to the existing Windows body unchanged (guard clause at the top, not an `if/else` rewrite — the diff must show the Windows lines untouched).

```dart
// In getExtensions, before the existing `if (app.location == null) return [];`:
if (Platform.isLinux && app.location == AppInstallerService.systemPackageMarker) {
  return getLinuxExtensions(app);
}

// In toggleExtension, before `final file = _getPhpIni(app);`.
// toggleExtension's return type becomes `Future<String?>` in Task 10; on
// Windows nothing changes but the `return null;` at the end.
if (Platform.isLinux && app.location == AppInstallerService.systemPackageMarker) {
  return toggleLinuxExtension(app, ext, enable);
}
```

`getLinuxExtensions` / `toggleLinuxExtension` are `@visibleForTesting` methods on `PhpSettings` so tests inject fakes without Linux or root:

```dart
@visibleForTesting
Future<List<PhpExtension>> getLinuxExtensions(
  AppModel app, {
  String? familyOverride,
  LinuxPhpExtensionManager? managerOverride,
}) async {
  final family = familyOverride ?? LinuxDistroResolver.detectFamily();
  final driver = driverForFamily(family);
  if (driver == null) {
    throw UnsupportedError(
      'PHP extensions are not supported on this Linux distribution ($family).',
    );
  }
  final binaryPath = app.execFilePath;
  if (binaryPath == null || binaryPath.isEmpty) {
    throw StateError('No php-fpm binary recorded for ${app.appId}.');
  }
  final manager = managerOverride ?? LinuxPhpExtensionManager.forApp(
    app: app,
    driver: driver,
  );
  final phpVersion = _linuxPhpVersion(app);   // e.g. 'php85' -> '8.5'
  try {
    return await manager.listExtensions(
      binaryPath: binaryPath,
      phpVersion: phpVersion,
    );
  } on LinuxPhpDiscoveryUnavailable catch (e) {
    throw UnsupportedError(e.message);
  }
}
```

`_linuxPhpVersion` reuses the existing `AppInstallerService.phpPrefixFor(app.appId)` (which already parses `php85` → `8.5`); when it returns null, fall back to `app.installedVersion`'s leading `X.Y`, and when that also fails throw `StateError` (a version-less Linux PHP app cannot form discovery commands — fail loudly, not with a guessed version). Its body is:

```dart
String _linuxPhpVersion(AppModel app) {
  final fromId = AppInstallerService.phpPrefixFor(app.appId);
  if (fromId != null) return fromId;

  final match = RegExp(r'^(\d+\.\d+)').firstMatch(app.installedVersion ?? '');
  if (match != null) return match.group(1)!;

  throw StateError(
    'Cannot determine the PHP version for ${app.appId}; '
    'extension discovery needs a major.minor version.',
  );
}
```

`AppInstallerService.phpPrefixFor` is `@visibleForTesting` and public, so qualifying it from `PhpSettings` needs no new export. `LinuxDistroResolver.detectFamily()` likewise already exists (see `lib/core/services/linux_distro_resolver.dart`); it takes no arguments and returns the *package-manager family* string — `ubuntu` / `debian` / `centos` / `fedora` / `arch` / `unknown` — which is exactly the vocabulary `driverForFamily` switches on. Note it does **not** return `rhel`; RHEL and its clones (rocky, almalinux, ol) come back as `centos`, and Fedora proper as `fedora`. Both map to `RhelPhpExtensionDriver`.

`toggleLinuxExtension` mirrors the same preamble (family → driver → binaryPath → version), then reads `PhpFpmInfo` once for `scanDir` + `parsedIniFiles` and calls `manager.applyToggle(...)` with `servicePid: app.servicePid`. It returns the manager's message string so the UI can show it in a snackbar (Task 10). Note `applyToggle` takes `parsedIniFiles`, and `PhpFpmInfo` calls that list `scannedIniFiles` — pass `info.scannedIniFiles`:

```dart
@visibleForTesting
Future<String?> toggleLinuxExtension(
  AppModel app,
  PhpExtension ext,
  bool enable, {
  String? familyOverride,
  LinuxPhpExtensionManager? managerOverride,
  LinuxPhpIntrospector? introspectorOverride,
  ({String? scanDir, List<String> parsedIniFiles})? infoOverride,
}) async {
  final family = familyOverride ?? LinuxDistroResolver.detectFamily();
  final driver = driverForFamily(family);
  if (driver == null) {
    throw UnsupportedError(
      'PHP extensions are not supported on this Linux distribution ($family).',
    );
  }
  final binaryPath = app.execFilePath;
  if (binaryPath == null || binaryPath.isEmpty) {
    throw StateError('No php-fpm binary recorded for ${app.appId}.');
  }
  final phpVersion = _linuxPhpVersion(app);

  String? scanDir;
  List<String> parsedIniFiles;
  if (infoOverride != null) {
    scanDir = infoOverride.scanDir;
    parsedIniFiles = infoOverride.parsedIniFiles;
  } else {
    final info = await (introspectorOverride ?? LinuxPhpIntrospector())
        .readInfo(binaryPath);
    scanDir = info.scanDir;
    parsedIniFiles = info.scannedIniFiles;
  }
  if (scanDir == null) {
    throw StateError(
      'PHP-FPM reported no scan directory for $binaryPath; '
      'there is nowhere to write the extension ini file.',
    );
  }

  final manager = managerOverride ?? LinuxPhpExtensionManager.forApp(
    app: app,
    driver: driver,
  );
  return manager.applyToggle(
    binaryPath: binaryPath,
    phpVersion: phpVersion,
    scanDir: scanDir,
    parsedIniFiles: parsedIniFiles,
    extName: ext.name,
    enable: enable,
    servicePid: app.servicePid,
  );
}
```

The `managerOverride` in the tests is a `_FakeManager` that overrides `applyToggle`, so the `introspectorOverride` / `infoOverride` split lets the test bypass `php-fpm -i` entirely while still asserting what the provider forwards. When `managerOverride` is supplied the `LinuxPhpExtensionManager.forApp` factory is never called, which is what keeps the test host-independent.

`LinuxPhpExtensionManager.forApp` (added to the Task 8 file in this task's Step 3):

```dart
factory LinuxPhpExtensionManager.forApp({
  required AppModel app,
  required LinuxPhpExtensionDriver driver,
  Future<ProcessResult> Function(String, List<String>)? runProcess,
}) {
  return LinuxPhpExtensionManager(
    introspector: LinuxPhpIntrospector(runProcess: runProcess),
    driver: driver,
    runProcess: runProcess ?? Process.run,
  );
}
```

Task 4's `LinuxPhpIntrospector` takes `runProcess` in its constructor and `binaryPath` per call (`readInfo(binaryPath)`), so no `binaryPath` is passed here — the manager already threads `binaryPath` through `listExtensions` / `applyToggle`. The factory exists so `PhpSettings` stays thin; it must not duplicate discovery logic.

Review Focus item 5 (`unknown` family → explicit unsupported message) is pinned here: the `driver == null` branch throws `UnsupportedError`, and the test below asserts it.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/php_settings_linux_branch_test.dart`:

```dart
import 'dart:io';

import 'package:dev_stack/features/apps/data/linux_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/linux_php_extension_manager.dart';
import 'package:dev_stack/features/apps/data/linux_php_introspector.dart';
import 'package:dev_stack/features/apps/data/php_extension_drivers/debian_php_extension_driver.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/domain/php_extension.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel so `_linuxPhpApp(execFilePath: null)` really means "no binary",
/// rather than falling back to the default.
const Object _unset = Object();

AppModel _linuxPhpApp({
  Object? execFilePath = _unset,
  String appId = 'php85',
  String? installedVersion = '8.5.0',
}) => AppModel(
  appId: appId,
  name: 'PHP 8.5',
  categories: ['runtime'],
  groupName: 'php',
  versions: ['8.5.0'],
  location: 'system_package',
  isInstalled: true,
  installedVersion: installedVersion,
  execFilePath: identical(execFilePath, _unset)
      ? '/usr/sbin/php-fpm8.5'
      : execFilePath as String?,
)..servicePid = 4242;

void main() {
  group('PhpSettings Linux branch', () {
    test('getLinuxExtensions returns the manager list for a known family', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(
        extensions: [
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: true,
            isFoundInIni: true,
            isZend: false,
            isInstalled: true,
            packageName: 'php8.5-curl',
            description: 'CURL module for PHP',
          ),
        ],
      );

      final exts = await settings.getLinuxExtensions(
        _linuxPhpApp(),
        familyOverride: 'ubuntu',
        managerOverride: manager,
      );

      expect(exts.length, equals(1));
      expect(manager.capturedVersion, equals('8.5'));
      expect(
        manager.capturedBinary,
        equals('/usr/sbin/php-fpm8.5'),
      );
    });

    test('getLinuxExtensions throws UnsupportedError for an unknown family', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(),
          familyOverride: 'unknown',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('getLinuxExtensions throws StateError when no binary is recorded', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(execFilePath: null),
          familyOverride: 'ubuntu',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('toggleLinuxExtension forwards scanDir, ini list and servicePid', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(extensions: const []);
      final app = _linuxPhpApp();

      final message = await settings.toggleLinuxExtension(
        app,
        PhpExtension(
          name: 'curl',
          fileName: 'curl.so',
          isEnabled: false,
          isFoundInIni: true,
          isZend: false,
          isInstalled: true,
          packageName: 'php8.5-curl',
        ),
        true,
        familyOverride: 'debian',
        managerOverride: manager,
        infoOverride: (
          scanDir: '/etc/php/8.5/fpm/conf.d',
          parsedIniFiles: ['/etc/php/8.5/fpm/conf.d/20-curl.ini'],
        ),
      );

      expect(manager.toggledName, equals('curl'));
      expect(manager.toggledEnable, isTrue);
      expect(manager.toggledPid, equals(4242));
      expect(manager.toggledScanDir, equals('/etc/php/8.5/fpm/conf.d'));
      expect(
        manager.toggledIniFiles,
        equals(['/etc/php/8.5/fpm/conf.d/20-curl.ini']),
      );
      // The manager's message is handed straight back to the caller, which is
      // what Task 10 renders in a snackbar.
      expect(message, equals('ok'));
    });

    test('toggleLinuxExtension throws UnsupportedError for an unknown family', () async {
      final settings = PhpSettings();
      final app = _linuxPhpApp();

      expect(
        () => settings.toggleLinuxExtension(
          app,
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: false,
            isFoundInIni: true,
            isZend: false,
          ),
          true,
          familyOverride: 'nixos',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('falls back to installedVersion when the appId is not phpNN', () async {
      final settings = PhpSettings();
      final manager = _FakeManager(extensions: const []);

      await settings.getLinuxExtensions(
        _linuxPhpApp(appId: 'php'),
        familyOverride: 'ubuntu',
        managerOverride: manager,
      );

      expect(manager.capturedVersion, equals('8.5'));
    });

    test('throws StateError when no version can be determined', () async {
      final settings = PhpSettings();

      expect(
        () => settings.getLinuxExtensions(
          _linuxPhpApp(appId: 'php', installedVersion: 'latest'),
          familyOverride: 'ubuntu',
          managerOverride: _FakeManager(extensions: const []),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when php-fpm reports no scan dir', () async {
      final settings = PhpSettings();
      final app = _linuxPhpApp();

      expect(
        () => settings.toggleLinuxExtension(
          app,
          PhpExtension(
            name: 'curl',
            fileName: 'curl.so',
            isEnabled: false,
            isFoundInIni: true,
            isZend: false,
          ),
          true,
          familyOverride: 'debian',
          managerOverride: _FakeManager(extensions: const []),
          infoOverride: (scanDir: null, parsedIniFiles: const []),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

/// Minimal fake standing in for LinuxPhpExtensionManager. It subclasses the
/// real manager with a Debian driver so no constructor signature can drift
/// unnoticed; only the two methods the provider calls are overridden.
class _FakeManager extends LinuxPhpExtensionManager {
  final List<PhpExtension> extensions;
  String? capturedBinary;
  String? capturedVersion;
  String? toggledName;
  bool? toggledEnable;
  int? toggledPid;
  String? toggledScanDir;
  List<String>? toggledIniFiles;

  _FakeManager({required this.extensions})
    : super(
        introspector: LinuxPhpIntrospector(runProcess: _noRun),
        driver: DebianPhpExtensionDriver(),
        runProcess: _noRun,
      );

  static Future<ProcessResult> _noRun(String exe, List<String> args) async =>
      ProcessResult(0, 0, '', '');

  @override
  Future<List<PhpExtension>> listExtensions({
    required String binaryPath,
    required String phpVersion,
  }) async {
    capturedBinary = binaryPath;
    capturedVersion = phpVersion;
    return extensions;
  }

  @override
  Future<String> applyToggle({
    required String binaryPath,
    required String phpVersion,
    required String scanDir,
    required List<String> parsedIniFiles,
    required String extName,
    required bool enable,
    int? servicePid,
  }) async {
    toggledName = extName;
    toggledEnable = enable;
    toggledPid = servicePid;
    toggledScanDir = scanDir;
    toggledIniFiles = parsedIniFiles;
    return 'ok';
  }
}
```

Every constructor parameter of `LinuxPhpExtensionManager` other than `introspector`, `driver` and `runProcess` is optional (Task 8: `runElevated`, `reloader`, `fileExists` all default), so `super(...)` above compiles without them — which is the point of subclassing the real manager here: if Task 8's required-parameter set ever drifts, this test stops compiling instead of silently faking a stale shape.

`_FakeIntrospector` is no longer needed: the fake manager is constructed with a real `LinuxPhpIntrospector` whose `runProcess` is `_noRun` (returns empty stdout), and `_FakeManager` overrides both `listExtensions` and `applyToggle`, so the introspector is never actually consulted.

`toggleLinuxExtension`'s `infoOverride` parameter exists only so the test can supply `scanDir`/`parsedIniFiles` without a Linux binary. Its type is `({String? scanDir, List<String> parsedIniFiles})?`, defaulting to null. The live path reads `PhpFpmInfo` once through a `LinuxPhpIntrospector` (`introspectorOverride`, or a default one) and throws `StateError` when `scanDir` is null — no scan dir means nowhere to write `99-ponta-*.ini`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/php_settings_linux_branch_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/apps/domain/php_extension.dart'` (Task 3 not yet built) or `The method 'getLinuxExtensions' isn't defined for the type 'PhpSettings'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/apps/data/php_settings_provider.dart`, add the Linux guard clauses plus the two `@visibleForTesting` methods. Required imports to add:

```dart
import 'dart:io' show Platform;   // already imported as dart:io — no change needed
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../core/services/linux_distro_resolver.dart';
import 'app_installer_service.dart';
import 'linux_php_extension_driver.dart';
import 'linux_php_extension_manager.dart';
import 'linux_php_introspector.dart';
import '../domain/php_extension.dart';   // Task 3 moves the class here
```

In `lib/features/apps/data/linux_php_extension_manager.dart`, add the `forApp` factory described in the Interfaces section (it passes `runProcess` only — Task 4's `LinuxPhpIntrospector` takes no constructor `binaryPath`).

Also widen `toggleExtension`'s return type from `Future<void>` to `Future<String?>` so the Linux guard clause above can `return` the manager's message. The Windows body is untouched except for the final `return null;`:

```dart
Future<String?> toggleExtension(AppModel app, PhpExtension ext, bool enable) async {
  if (Platform.isLinux && app.location == AppInstallerService.systemPackageMarker) {
    return toggleLinuxExtension(app, ext, enable);
  }

  final file = _getPhpIni(app);
  if (file == null || !await file.exists() || app.location == null) return null;
  // ... existing body unchanged ...
  await BackgroundProcess.writeStringElevated(file.path, content);
  return null;
}
```

This is source-compatible for every existing caller: they all `await` the result and discard it, and a `Future<String?>` is a subtype of `Future<void>` for override purposes — so no existing subclass of `PhpSettings` breaks. Task 10's modal is the first caller to read the value.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/php_settings_linux_branch_test.dart`
Expected: PASS (8 tests).

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/php_settings_provider.dart lib/features/apps/data/linux_php_extension_manager.dart test/features/apps/php_settings_linux_branch_test.dart
git commit -m "feat: delegate PhpSettings extension methods to Linux manager on system_package apps"
```

---

### Task 10: Extensions tab UI — package badge, "Not installed" chip, busy state

**Files:**
- Modify: `lib/features/apps/presentation/widgets/app_settings_modal.dart` (`_buildExtensionsTab`, `_buildExtensionCard`, `_loadExtensions`, `_toggleExtension`)
- Test: `test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart` (create)

**Interfaces:**
- Consumes: `PhpExtension.isInstalled` / `.packageName` / `.description` (Task 3), `PhpSettings.getExtensions` / `toggleExtension` (Task 9, `toggleExtension` now returns `Future<String?>`).
- Produces: the finished Extensions tab. Nothing consumes this task.

Spec §7 in full: a package-name badge next to the `ZEND` badge, a muted
"Not installed" chip when `!isInstalled`, the switch driving install+enable in
one action with a spinner and a disabled switch while it runs, and a search
field that filters on **extension name or package name**.

Two supporting changes make the UI honest about Linux failures:

- `toggleExtension` returns `Future<String?>` instead of `Future<void>`. The
  Linux path returns the manager's message (which may carry the
  "PHP-FPM is not running — restart it to apply the change" note of spec §5.3);
  the Windows path returns `null`. `Future<void>` → `Future<String?>` is
  source-compatible for every existing caller (they all just `await` it), and
  the modal only shows a snackbar when a non-empty message comes back — so the
  Windows UI is byte-for-byte unchanged.
- `_loadExtensions` catches `UnsupportedError` (an unsupported distro family, or
  `apt-file` missing — Task 9 rethrows `LinuxPhpDiscoveryUnavailable` as
  `UnsupportedError`). Without the catch, an unsupported host leaves the tab
  spinning forever and the exception escapes the widget tree.

- [ ] **Step 1: Write the failing test**

Create `test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart`:

```dart
import 'dart:async';

import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/app_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() => Future.value([]);
}

/// Stands in for the real provider. [toggleGate] lets a test hold a toggle
/// in flight so the busy state can be observed.
class _MockPhpSettings extends PhpSettings {
  final List<PhpExtension> _exts;
  final Completer<void>? _toggleGate;

  _MockPhpSettings(this._exts, {Completer<void>? toggleGate})
    : _toggleGate = toggleGate;

  @override
  Future<List<PhpExtension>> getExtensions(
    AppModel app, [
    String? iniContent,
  ]) async => _exts;

  @override
  Future<String?> toggleExtension(
    AppModel app,
    PhpExtension ext,
    bool enable,
  ) async {
    if (_toggleGate != null) await _toggleGate.future;
    return 'Extension ${ext.name} ${enable ? 'enabled' : 'disabled'}.';
  }
}

AppModel _phpApp() => AppModel(
  appId: 'php85',
  name: 'PHP 8.5',
  categories: ['runtime'],
  groupName: 'php',
  versions: ['8.5.0'],
  location: 'system_package',
  isInstalled: true,
  installedVersion: '8.5.0',
  execFilePath: '/usr/sbin/php-fpm8.5',
);

const _curl = PhpExtension(
  name: 'curl',
  fileName: 'curl.so',
  isEnabled: true,
  isFoundInIni: true,
  isZend: false,
  isInstalled: true,
  packageName: 'php8.5-curl',
  description: 'CURL module for PHP',
);

const _zip = PhpExtension(
  name: 'zip',
  fileName: 'zip.so',
  isEnabled: false,
  isFoundInIni: false,
  isZend: false,
  isInstalled: false,
  packageName: 'php8.5-zip',
  description: 'ZIP module for PHP',
);

Future<void> _openExtensionsTab(WidgetTester tester, PhpSettings settings) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appsProvider.overrideWith(() => _StaticAppsNotifier()),
        phpSettingsProvider.overrideWith(() => settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppSettingsModal(app: _phpApp(), onClose: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Extensions'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('renders the package badge and the Not installed chip', (tester) async {
    await _openExtensionsTab(tester, _MockPhpSettings([_curl, _zip]));

    expect(find.text('curl'), findsOneWidget);
    expect(find.text('zip'), findsOneWidget);

    // Both cards carry their owning package name.
    expect(find.text('php8.5-curl'), findsOneWidget);
    expect(find.text('php8.5-zip'), findsOneWidget);

    // Only the not-yet-installed extension warns about a download.
    expect(find.text('Not installed'), findsOneWidget);
    final chip = find.ancestor(
      of: find.text('Not installed'),
      matching: find.byKey(const ValueKey('ext-card-zip')),
    );
    expect(chip, findsOneWidget);
  });

  testWidgets('filters by package name, not only extension name', (tester) async {
    await _openExtensionsTab(tester, _MockPhpSettings([_curl, _zip]));

    await tester.enterText(
      find.byKey(const ValueKey('extensions-search')),
      'php8.5-zip',
    );
    await tester.pumpAndSettle();

    expect(find.text('zip'), findsOneWidget);
    expect(find.text('curl'), findsNothing);
  });

  testWidgets('shows a spinner and drops the switch while a toggle is in flight', (tester) async {
    final gate = Completer<void>();
    await _openExtensionsTab(
      tester,
      _MockPhpSettings([_curl, _zip], toggleGate: gate),
    );

    await tester.tap(find.byKey(const ValueKey('ext-switch-zip')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ext-spinner-zip')), findsOneWidget);
    expect(find.byKey(const ValueKey('ext-switch-zip')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ext-spinner-zip')), findsNothing);
    expect(find.byKey(const ValueKey('ext-switch-zip')), findsOneWidget);
  });

  testWidgets('surfaces an unsupported distribution instead of spinning forever', (tester) async {
    await _openExtensionsTab(tester, _FailingPhpSettings());

    expect(find.textContaining('not supported'), findsOneWidget);
  });
}

class _FailingPhpSettings extends PhpSettings {
  @override
  Future<List<PhpExtension>> getExtensions(
    AppModel app, [
    String? iniContent,
  ]) async {
    throw UnsupportedError(
      'PHP extensions are not supported on this Linux distribution (unknown).',
    );
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart`
Expected: FAIL — `find.text('php8.5-curl')` finds nothing (no badge rendered), and `find.byKey(const ValueKey('extensions-search'))` finds nothing (no key yet).

- [ ] **Step 3: Write minimal implementation**

In `lib/features/apps/presentation/widgets/app_settings_modal.dart`:

**3a.** Add the busy set and the error field next to the existing `_extensions` / `_searchQuery` declarations:

```dart
  List<PhpExtension> _extensions = [];
  String _searchQuery = '';
  final Set<String> _togglingExtensions = {};
  String? _extensionsError;
```

**3b.** Replace `_loadExtensions` so a Linux failure becomes a rendered message rather than an escaping exception:

```dart
  Future<void> _loadExtensions() async {
    if (_isExtensionsLoading) return;
    setState(() => _isExtensionsLoading = true);

    List<PhpExtension> exts = const [];
    String? error;
    try {
      exts = await ref
          .read(phpSettingsProvider.notifier)
          .getExtensions(widget.app);
    } on UnsupportedError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not read PHP extensions: $e';
    }

    if (!mounted) return;
    setState(() {
      _extensions = exts;
      _extensionsError = error;
      _isExtensionsLoaded = true;
      _isExtensionsLoading = false;
    });
  }
```

**3c.** Replace `_toggleExtension` with a version that tracks the in-flight
extension, surfaces the manager's message (Linux only — the Windows path
returns `null`), and reports failures:

```dart
  Future<void> _toggleExtension(PhpExtension ext, bool value) async {
    if (_togglingExtensions.contains(ext.name)) return;
    setState(() => _togglingExtensions.add(ext.name));

    try {
      final note = await ref
          .read(phpSettingsProvider.notifier)
          .toggleExtension(widget.app, ext, value);
      _isExtensionsLoaded = false;
      await _loadExtensions();

      if (mounted && note != null && note.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(note), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${value ? 'enable' : 'disable'} ${ext.name}: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingExtensions.remove(ext.name));
    }
  }
```

**3d.** Filter on extension name **or** package name, and give the search field a
key so widget tests can target it unambiguously (the Service tab's
`TextFormField`s also contain a `TextField`):

```dart
    final query = _searchQuery.toLowerCase();
    final filteredExtensions = _extensions.where((ext) {
      return ext.name.toLowerCase().contains(query) ||
          (ext.packageName?.toLowerCase().contains(query) ?? false);
    }).toList();
```

and on the search `TextField` add:

```dart
                  child: TextField(
                    key: const ValueKey('extensions-search'),
                    onChanged: (v) => setState(() => _searchQuery = v),
```

Also update the hint to mention the package name:

```dart
                      hintText:
                          'Search by extension or package (e.g. mbstring, php8.5-curl)...',
```

**3e.** Render the error branch before the empty branch in `_buildExtensionsTab`:

```dart
            child: _isExtensionsLoading
                ? const Center(child: CircularProgressIndicator())
                : _extensionsError != null
                ? _buildExtensionsError()
                : filteredExtensions.isEmpty
                ? _buildEmptyExtensions()
                : GridView.builder(
```

and add:

```dart
  Widget _buildExtensionsError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              _extensionsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton(
              onPressed: () {
                _isExtensionsLoaded = false;
                _loadExtensions();
              },
              style: AppButtonStyle.outline,
              label: 'Retry',
            ),
          ],
        ),
      ),
    );
  }
```

**3f.** Give the grid room for the badges (46 px still satisfies the existing
`<= 50 px` compactness assertion) and replace `_buildExtensionCard` with the
badge/chip/busy version. Add the `_buildExtensionBadge` helper beside it:

```dart
  Widget _buildExtensionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildExtensionCard(PhpExtension ext) {
    final isBusy = _togglingExtensions.contains(ext.name);
    return Container(
      key: ValueKey('ext-card-${ext.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ext.isEnabled
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ext.isZend ? Icons.bolt : Icons.extension_outlined,
            size: 16,
            color: ext.isEnabled ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    ext.name,
                    style: TextStyle(
                      fontWeight:
                          ext.isEnabled ? FontWeight.w600 : FontWeight.normal,
                      fontSize: AppTextSize.xs,
                      color: ext.isEnabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ext.isZend) ...[
                  const SizedBox(width: 4),
                  _buildExtensionBadge('ZEND', AppColors.accent),
                ],
                if (!ext.isInstalled) ...[
                  const SizedBox(width: 4),
                  _buildExtensionBadge('Not installed', AppColors.warning),
                ],
                if (ext.packageName != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ext.packageName!,
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isBusy)
            Padding(
              key: ValueKey('ext-spinner-${ext.name}'),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Transform.scale(
              scale: 0.7,
              alignment: Alignment.centerRight,
              child: Switch(
                key: ValueKey('ext-switch-${ext.name}'),
                value: ext.isEnabled,
                onChanged: (v) => _toggleExtension(ext, v),
                activeThumbColor: AppColors.success,
                activeTrackColor: AppColors.success.withValues(alpha: 0.2),
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.border,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
```

and change the grid delegate:

```dart
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 300,
                          mainAxisExtent: 46,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart`
Expected: PASS (4 tests).

Run the pre-existing widget tests, which pin the compact card size and the
absence of the "Standard extension" subtitle:

Run: `flutter test test/features/apps/presentation/widgets/`
Expected: PASS.

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/presentation/widgets/app_settings_modal.dart lib/features/apps/data/php_settings_provider.dart test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart
git commit -m "feat: show package badge, Not installed chip and busy state in PHP extensions tab"
```

---
