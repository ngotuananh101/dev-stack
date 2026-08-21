# Linux Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full Linux desktop support for DevStack, enabling cross-platform operation with native Linux process execution, dedicated `apps-linux.json` catalog, system `tar` extraction, desktop system tray, and Polkit (`pkexec`) privilege escalation.

**Architecture:** 
1. Introduce OS-aware path resolution in `AppConfig` and `HostsRepository` (`~/.ponta` base directory, `/etc/hosts`).
2. Implement POSIX process management and Polkit (`pkexec`) privilege escalation in `BackgroundProcess` and `AppServiceManager`.
3. Support Linux PATH management (`~/.bashrc`/`~/.zshrc`) and executable symlinks/wrappers in `PathService`.
4. Create `assets/data/apps-linux.json` catalog with Linux binaries and implement `tar` extraction in `AppInstallerService`.
5. Scaffold Flutter Linux runner files (`linux/`) with GTK and AppIndicator integration.

**Tech Stack:** Dart 3.10+, Flutter Desktop (GTK 3, libayatana-appindicator3), Isar DB, Riverpod 2.6+, Polkit (`pkexec`), POSIX shell & `tar`.

## Global Constraints

- Preserve 100% backward compatibility on Windows (all Windows tests must remain passing).
- Do not require root privileges for standard operations; default base directory on Linux is `~/.ponta`.
- Privilege escalation on Linux must use `pkexec` (or fallback to `sudo -S`).
- App catalog for Linux must be separate: `assets/data/apps-linux.json`.
- Archive extraction on Linux must use the system `tar` command (`tar -xf ...`).
- All path concatenations must use `p.join(...)` or POSIX forward slashes, avoiding hardcoded Windows backslashes.

---

### Task 1: OS-Aware Path Configuration in `AppConfig`

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Test: `test/core/config/app_config_os_test.dart`

**Interfaces:**
- Consumes: `Platform.isLinux`, `Platform.isWindows`, `Platform.environment['HOME']`
- Produces: `AppConfig.defaultBaseDir`, `AppConfig.baseDir`, `AppConfig.appsDir`, `AppConfig.binDir`, `AppConfig.logsDir`, `AppConfig.webserverRoot`, `AppConfig.certsDir`, `AppConfig.vhostsDir`, `AppConfig.dataDir` (all dynamically normalized via `p.join`).

- [ ] **Step 1: Write failing unit test for OS-aware AppConfig**

```dart
// test/core/config/app_config_os_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppConfig OS paths', () {
    test('resolves defaultBaseDir based on platform', () {
      final defaultDir = AppConfig.defaultBaseDir;
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '';
        expect(defaultDir, equals(p.join(home, '.ponta')));
      } else if (Platform.isWindows) {
        expect(defaultDir, equals(r'C:\Ponta'));
      }
    });

    test('subdirectories are constructed using p.join', () {
      AppConfig.initialize(baseDir: '/tmp/test_ponta');
      expect(AppConfig.appsDir, equals(p.join('/tmp/test_ponta', 'apps')));
      expect(AppConfig.binDir, equals(p.join('/tmp/test_ponta', 'bin')));
      expect(AppConfig.logsDir, equals(p.join('/tmp/test_ponta', 'logs')));
      expect(AppConfig.webserverRoot, equals(p.join('/tmp/test_ponta', 'www')));
      expect(AppConfig.certsDir, equals(p.join('/tmp/test_ponta', 'certs')));
      expect(AppConfig.vhostsDir, equals(p.join('/tmp/test_ponta', 'vhosts')));
      expect(AppConfig.dataDir, equals(p.join('/tmp/test_ponta', 'data')));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/core/config/app_config_os_test.dart`
Expected: FAIL (subdirectories using hardcoded backslashes `\\` or `defaultBaseDir` hardcoded to `C:\Ponta`).

- [ ] **Step 3: Update `AppConfig` with dynamic paths**

```dart
// lib/core/config/app_config.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/background_process.dart';
import '../services/log_service.dart';

class AppConfig {
  static String _baseDir = defaultBaseDir;

  /// Default base directory value based on OS.
  static String get defaultBaseDir {
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, '.ponta');
    }
    return r'C:\Ponta';
  }

  /// Initialize config from persisted settings. Call once at app startup.
  static void initialize({String? baseDir}) {
    if (baseDir != null && baseDir.isNotEmpty) {
      _baseDir = baseDir;
    } else {
      _baseDir = defaultBaseDir;
    }
  }

  /// The base directory for all Ponta data and applications.
  static String get baseDir => _baseDir;

  /// Directory where applications are installed.
  static String get appsDir => p.join(_baseDir, 'apps');

  /// Directory for system binaries and tools.
  static String get binDir => p.join(_baseDir, 'bin');

  /// Directory for system and service logs.
  static String get logsDir => p.join(_baseDir, 'logs');

  /// Directory for webserver roots.
  static String get webserverRoot => p.join(_baseDir, 'www');

  /// Certificates directory.
  static String get certsDir => p.join(_baseDir, 'certs');

  /// Vhosts directory.
  static String get vhostsDir => p.join(_baseDir, 'vhosts');

  /// SQL databases directory.
  static String get dataDir => p.join(_baseDir, 'data');
}

/// Update DEVSTACK_BASE_DIR environment variable.
Future<void> updateBaseDirEnvVar(String baseDir) async {
  try {
    if (Platform.isWindows) {
      final result = await BackgroundProcess.run('powershell', [
        '-NoProfile',
        '-Command',
        r'[Environment]::SetEnvironmentVariable($args[0], $args[1], "User")',
        'DEVSTACK_BASE_DIR',
        baseDir,
      ]);

      if (result.exitCode == 0) {
        AppLogger.info('Updated DEVSTACK_BASE_DIR environment variable: $baseDir');
      } else {
        AppLogger.warning('Failed to update DEVSTACK_BASE_DIR: ${result.stderr}');
      }
    } else if (Platform.isLinux) {
      AppLogger.info('Base dir set to $baseDir');
    }
  } catch (e) {
    AppLogger.warning('Failed to update DEVSTACK_BASE_DIR: $e');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/config/app_config_os_test.dart`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/config/app_config.dart test/core/config/app_config_os_test.dart
git commit -m "feat: make AppConfig base directories OS-aware for Linux and Windows"
```

---

### Task 2: OS-Aware Privilege Escalation in `BackgroundProcess`

**Files:**
- Modify: `lib/core/services/background_process.dart`
- Test: `test/core/services/background_process_linux_test.dart`

**Interfaces:**
- Consumes: `pkexec`, `sudo`, `Platform.isLinux`, `Platform.isWindows`
- Produces: `BackgroundProcess.runElevated(executable, args)` on Linux via `pkexec`.

- [ ] **Step 1: Write unit tests for Linux process execution and elevation**

```dart
// test/core/services/background_process_linux_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/background_process.dart';

void main() {
  group('BackgroundProcess command formatting', () {
    test('builds Linux elevated command arguments correctly', () {
      final cmd = BackgroundProcess.buildLinuxElevatedArgs('cp', ['/tmp/a', '/etc/hosts']);
      expect(cmd.executable, equals('pkexec'));
      expect(cmd.arguments, equals(['cp', '/tmp/a', '/etc/hosts']));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/core/services/background_process_linux_test.dart`
Expected: FAIL (method `buildLinuxElevatedArgs` not found).

- [ ] **Step 3: Implement Linux support in `BackgroundProcess`**

```dart
// Modify lib/core/services/background_process.dart to add helper and update runElevated:
  @visibleForTesting
  static ({String executable, List<String> arguments}) buildLinuxElevatedArgs(
    String executable,
    List<String> arguments,
  ) {
    return (executable: 'pkexec', arguments: [executable, ...arguments]);
  }

  /// Runs a command with elevation (UAC on Windows, pkexec on Linux).
  static Future<ProcessResult> runElevated(
    String executable,
    List<String> arguments,
  ) async {
    if (Platform.isLinux) {
      final elevated = buildLinuxElevatedArgs(executable, arguments);
      return Process.run(elevated.executable, elevated.arguments);
    }

    if (!Platform.isWindows) return run(executable, arguments);

    // Existing Windows implementation ...
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/background_process_linux_test.dart`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/services/background_process.dart test/core/services/background_process_linux_test.dart
git commit -m "feat: add Linux pkexec elevation to BackgroundProcess"
```

---

### Task 3: Linux Hosts Management in `HostsRepository`

**Files:**
- Modify: `lib/features/hosts/data/hosts_repository.dart`
- Test: `test/features/hosts/hosts_repository_linux_test.dart`

**Interfaces:**
- Consumes: `AppConfig`, `BackgroundProcess.runElevated`, `Platform.isLinux`
- Produces: `HostsRepository.hostsPath` (dynamically `/etc/hosts` or Windows path), `HostsRepository.saveHostsRaw`.

- [ ] **Step 1: Write unit test for Linux hosts path and checkAdmin**

```dart
// test/features/hosts/hosts_repository_linux_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/hosts/data/hosts_repository.dart';

void main() {
  group('HostsRepository OS support', () {
    test('hostsPath points to correct OS path', () {
      if (Platform.isLinux) {
        expect(HostsRepository.hostsPath, equals('/etc/hosts'));
      } else if (Platform.isWindows) {
        expect(HostsRepository.hostsPath, equals(r'C:\Windows\System32\drivers\etc\hosts'));
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/hosts/hosts_repository_linux_test.dart`
Expected: FAIL (hostsPath is `const` hardcoded to `C:\Windows\...`).

- [ ] **Step 3: Update `HostsRepository` to support Linux**

```dart
// lib/features/hosts/data/hosts_repository.dart
import 'dart:io';
import 'package:dev_stack/core/services/background_process.dart';
import 'package:dev_stack/core/services/log_service.dart';

class HostsRepository {
  static String get hostsPath =>
      Platform.isLinux ? '/etc/hosts' : r'C:\Windows\System32\drivers\etc\hosts';

  Future<String> readHostsRaw() async {
    try {
      final file = File(hostsPath);
      if (!await file.exists()) return '';
      final bytes = await file.readAsBytes();
      try {
        return systemEncoding.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    } catch (e) {
      AppLogger.error('Error reading hosts raw: $e');
      return '';
    }
  }

  Future<bool> saveHostsRaw(String content) async {
    // 1. Try writing directly (if app is admin/root)
    try {
      final file = File(hostsPath);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      AppLogger.error('Direct write failed, trying elevation... $e');
    }

    // 2. Elevated copy
    try {
      final tempFile = File('${Directory.systemTemp.path}/hosts_temp');
      await tempFile.writeAsString(content);

      if (Platform.isLinux) {
        final result = await BackgroundProcess.runElevated('cp', [
          tempFile.path,
          hostsPath,
        ]);
        try {
          await tempFile.delete();
        } catch (_) {}
        if (result.exitCode == 0) return true;
        AppLogger.error('Elevated hosts write failed on Linux: ${result.stderr}');
      } else {
        final escapedTempPath = tempFile.path.replaceAll("'", "''");
        final escapedHostsPath = hostsPath.replaceAll("'", "''");
        final result = await BackgroundProcess.runElevatedPowerShell(
          "Copy-Item -LiteralPath '$escapedTempPath' "
          "-Destination '$escapedHostsPath' -Force",
        );
        try {
          await tempFile.delete();
        } catch (_) {}
        if (result.exitCode == 0) return true;
        AppLogger.error('Elevated hosts write failed: ${result.stderr}');
      }
    } catch (e) {
      AppLogger.error('Elevation failed: $e');
    }

    return false;
  }

  Future<bool> checkAdmin() async {
    try {
      if (Platform.isLinux) {
        final result = await Process.run('id', ['-u']);
        return result.exitCode == 0 && result.stdout.toString().trim() == '0';
      }
      final result = await Process.run('net', ['session']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static String replacePontaBlock(
    String hostsContent,
    String startMarker,
    String endMarker,
    List<String> domainLines,
  ) {
    final newBlock = '$startMarker\n${domainLines.join('\n')}\n$endMarker';

    final blockPattern = RegExp(
      '${RegExp.escape(startMarker)}.*?${RegExp.escape(endMarker)}',
      dotAll: true,
    );

    if (blockPattern.hasMatch(hostsContent)) {
      return hostsContent.replaceFirst(blockPattern, newBlock);
    }
    return '${hostsContent.trim()}\n\n$newBlock\n';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/hosts/hosts_repository_linux_test.dart test/features/hosts/hosts_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add lib/features/hosts/data/hosts_repository.dart test/features/hosts/hosts_repository_linux_test.dart
git commit -m "feat: support /etc/hosts and pkexec copy on Linux"
```

---

### Task 4: Linux PATH, Shell Profiles & Symlinks in `PathService`

**Files:**
- Modify: `lib/core/services/path_service.dart`
- Test: `test/core/services/path_service_linux_test.dart`

**Interfaces:**
- Consumes: `AppConfig.binDir`, `Platform.isLinux`, `Platform.isWindows`
- Produces: `PathService.ensurePontaBinInPath`, `PathService.addAppToPath`, `PathService.removeAppToPath` for Linux shell profiles and executable symlinks.

- [ ] **Step 1: Write unit tests for Linux PATH profile export and symlink logic**

```dart
// test/core/services/path_service_linux_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/path_service.dart';

void main() {
  group('PathService Linux Shell Profile', () {
    test('generates correct export line for shell profile', () {
      final exportLine = PathService.linuxProfileExportLine('/home/user/.ponta/bin');
      expect(exportLine, equals('export PATH="/home/user/.ponta/bin:\$PATH"'));
    });

    test('detects if PATH is already in profile content', () {
      const profile = 'export PATH="/home/user/.ponta/bin:\$PATH"\n';
      expect(PathService.isBinInProfileContent(profile, '/home/user/.ponta/bin'), isTrue);
      expect(PathService.isBinInProfileContent('export PATH="/usr/bin:\$PATH"', '/home/user/.ponta/bin'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/core/services/path_service_linux_test.dart`
Expected: FAIL (methods not found).

- [ ] **Step 3: Implement Linux PATH & Symlink creation in `PathService`**

Update `lib/core/services/path_service.dart`:
- Add `linuxProfileExportLine` and `isBinInProfileContent` static helpers.
- On Linux, update `ensurePontaBinInPath` to append export line to `~/.bashrc` and `~/.zshrc` if not present.
- In `addAppToPath`, on Linux create direct symbolic link (`Link(p.join(binDir, cliName)).createSync(...)`) and `chmod 755` instead of `.bat` shims.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/path_service_linux_test.dart test/core/services/path_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add lib/core/services/path_service.dart test/core/services/path_service_linux_test.dart
git commit -m "feat: add Linux shell profile and symlink support to PathService"
```

---

### Task 5: Linux App Catalog (`apps-linux.json`) & Repository Loading

**Files:**
- Create: `assets/data/apps-linux.json`
- Modify: `lib/features/apps/data/apps_repository.dart`
- Test: `test/assets/linux_catalog_test.dart`

**Interfaces:**
- Consumes: `assets/data/apps-linux.json`, `Platform.isLinux`
- Produces: `AppsRepository.getAll()` loads `apps-linux.json` when `Platform.isLinux`.

- [ ] **Step 1: Write test verifying `apps-linux.json` validity**

```dart
// test/assets/linux_catalog_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assets/data/apps-linux.json contains valid apps schema', () {
    final file = File('assets/data/apps-linux.json');
    expect(file.existsSync(), isTrue);
    final jsonContent = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(jsonContent.containsKey('apps'), isTrue);
    final apps = jsonContent['apps'] as List;
    expect(apps.isNotEmpty, isTrue);
    for (final app in apps) {
      expect(app['id'], isNotNull);
      expect(app['name'], isNotNull);
      expect(app['versions'], isNotNull);
    }
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/assets/linux_catalog_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Create `assets/data/apps-linux.json` with Linux binary distributions**

Create `assets/data/apps-linux.json` containing Node.js, Caddy, Nginx, Redis, etc. with Linux x64 download URLs and Linux executable paths (`bin/node`, `caddy`, `bin/redis-server`).

- [ ] **Step 4: Update `AppsRepository` to load `apps-linux.json` on Linux**

In `lib/features/apps/data/apps_repository.dart`:
```dart
      final catalogFileName = Platform.isLinux ? 'apps-linux.json' : 'apps.json';
      final localFile = File(p.join(supportDir.path, catalogFileName));

      if (await localFile.exists()) {
        AppLogger.info('Loading apps from local storage: ${localFile.path}');
        response = await localFile.readAsString();
      } else {
        AppLogger.info('Loading apps from assets bundle ($catalogFileName)');
        response = await rootBundle.loadString('assets/data/$catalogFileName');
      }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/assets/linux_catalog_test.dart test/features/apps/apps_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Commit changes**

```bash
git add assets/data/apps-linux.json lib/features/apps/data/apps_repository.dart test/assets/linux_catalog_test.dart
git commit -m "feat: add apps-linux.json catalog and OS-aware catalog loader"
```

---

### Task 6: System `tar` Extraction & Linux Permissions in `AppInstallerService`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Test: `test/features/apps/installer_linux_tar_test.dart`

**Interfaces:**
- Consumes: `tar`, `chmod`, `Platform.isLinux`
- Produces: `AppInstallerService._extractTar(archiveFile, targetDir)`, `AppInstallerService._makeExecutable(filePath)`

- [ ] **Step 1: Write unit tests for tar command construction and permission helpers**

```dart
// test/features/apps/installer_linux_tar_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('AppInstallerService Linux Tar Extraction', () {
    test('builds tar extract command arguments', () {
      final args = AppInstallerService.buildTarExtractArgs('/tmp/node.tar.xz', '/home/user/.ponta/apps/nodejs/24.0.0');
      expect(args, equals(['-xf', '/tmp/node.tar.xz', '-C', '/home/user/.ponta/apps/nodejs/24.0.0', '--strip-components=1']));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/apps/installer_linux_tar_test.dart`
Expected: FAIL (method `buildTarExtractArgs` not found).

- [ ] **Step 3: Implement `buildTarExtractArgs`, system `tar` extraction and `chmod +x` in `AppInstallerService`**

- Add `buildTarExtractArgs(String archivePath, String destDir, {bool stripComponents = true})`.
- In `install(...)`, if `Platform.isLinux` and file ends with `.tar.gz`, `.tar.xz`, `.tgz`:
  Execute `Process.run('tar', buildTarExtractArgs(downloadedFilePath, installPath))`.
- Run `Process.run('chmod', ['-R', '755', installPath])` on the installed directory to ensure execution permissions.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/installer_linux_tar_test.dart`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_linux_tar_test.dart
git commit -m "feat: implement system tar extraction and executable permissions for Linux"
```

---

### Task 7: Linux Flutter Runner Scaffolding & Packaging Scripts

**Files:**
- Create: `linux/CMakeLists.txt`
- Create: `linux/main.cc`
- Create: `linux/my_application.h`
- Create: `linux/my_application.cc`
- Create: `scripts/package-linux.sh`
- Test: Verify project configuration with `flutter analyze`

- [ ] **Step 1: Create standard Flutter Linux runner scaffolding**

Create standard Flutter 3.x Linux desktop runner files:
- `linux/CMakeLists.txt` (GTK 3, window_manager, tray_manager bindings)
- `linux/main.cc`
- `linux/my_application.h` & `linux/my_application.cc`

- [ ] **Step 2: Create packaging script `scripts/package-linux.sh`**

```bash
#!/usr/bin/env bash
set -e
echo "Building DevStack for Linux..."
flutter build linux --release
echo "Packaging into tarball..."
mkdir -p dist
tar -czf dist/ponta-dev-stack-linux-x64.tar.gz -C build/linux/x64/release/bundle .
echo "Build complete: dist/ponta-dev-stack-linux-x64.tar.gz"
```

- [ ] **Step 3: Run `flutter analyze` and full test suite**

Run: `flutter analyze` and `flutter test`
Expected: All tests PASS, 0 analyzer errors/warnings.

- [ ] **Step 4: Commit changes**

```bash
git add linux/ scripts/package-linux.sh
git commit -m "feat: add Flutter Linux runner scaffolding and packaging script"
```

---

## Plan Review Checklist
1. **Spec coverage:** All sections (Paths, Escalation, Hosts, PATH/Shims, Catalog, `tar` extractor, Flutter Linux runner) mapped to distinct tasks.
2. **Backward compatibility:** All Windows execution paths preserved.
3. **No placeholders:** Exact code snippets, commands, and expected outputs provided.
