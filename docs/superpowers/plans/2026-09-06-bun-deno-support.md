# Bun and Deno Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class support for Bun and Deno runtimes on Windows and Linux, including catalog metadata, release automation, installer extraction with directory un-nesting, shimming (bun, bunx, deno), and isolated global package PATH management for Node.js, Bun, and Deno.

**Architecture:** Integrate `bun` and `deno` into `assets/data/update.js`, `apps.json`, and `apps-linux.json`; adapt `AppInstallerService` to ensure `bunx.exe` is configured and permissions are set; update `PathService` to create core shims in `binDir` while routing runtime global packages to dedicated directories in User `PATH`; and register brand icons and colors in the UI widgets.

**Tech Stack:** Dart 3 / Flutter desktop, Node.js (updater script), PowerShell (Windows User PATH), POSIX shell (Linux profile PATH), Isar DB, Riverpod.

**Spec:** `docs/superpowers/specs/2026-09-06-bun-deno-support-design.md`

## Global Constraints
- Target platforms: Windows (x64) and Linux (x64).
- Runtime binary types: Portable `.zip` archives containing x64 executables.
- Bin directory isolation: `C:\Ponta\bin` (Windows) and `~/.local/share/ponta/bin` (Linux) must only contain DevStack shims and symlinks. No runtime global packages may be installed directly into `binDir`.
- Global package directories:
  - Node.js (NPM): `%APPDATA%\npm` (Windows) / `~/.npm-global/bin` (Linux).
  - Bun: `%USERPROFILE%\.bun\bin` (Windows) / `~/.bun/bin` (Linux).
  - Deno: `%USERPROFILE%\.deno\bin` (Windows) / `~/.deno/bin` (Linux).
- All new tests must pass with `flutter test`.

---

### Task 1: Official Brand Assets (Bun & Deno Icons)

**Files:**
- Create: `assets/images/bun.png`
- Create: `assets/images/deno.png`
- Test: `test/assets/bun_deno_assets_test.dart`

**Interfaces:**
- Consumes: Flutter asset bundle configured in `pubspec.yaml` (`assets/images/`).
- Produces: PNG files readable as image assets: `assets/images/bun.png` and `assets/images/deno.png`.

- [ ] **Step 1: Write the failing test**

Create `test/assets/bun_deno_assets_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bun and Deno brand icon assets', () {
    test('assets/images/bun.png exists and is a valid non-empty PNG', () async {
      final file = File('assets/images/bun.png');
      expect(await file.exists(), isTrue, reason: 'bun.png must exist in assets/images/');
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: 'bun.png must be non-empty');
      // PNG header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    test('assets/images/deno.png exists and is a valid non-empty PNG', () async {
      final file = File('assets/images/deno.png');
      expect(await file.exists(), isTrue, reason: 'deno.png must exist in assets/images/');
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: 'deno.png must be non-empty');
      // PNG header: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/assets/bun_deno_assets_test.dart`
Expected: FAIL (files do not exist yet).

- [ ] **Step 3: Download and generate official PNG icons**

Fetch or render transparent high-resolution PNGs for Bun and Deno:
- Bun: Fetch official logo from `https://bun.sh/logo.svg` or `https://raw.githubusercontent.com/oven-sh/bun/main/packages/bun-landing/public/logo.svg` and convert/write to `assets/images/bun.png`.
- Deno: Fetch official logo from `https://raw.githubusercontent.com/denoland/dotland/main/public/images/deno-logo.svg` or `https://deno.land/logo.svg` and convert/write to `assets/images/deno.png`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/assets/bun_deno_assets_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/images/bun.png assets/images/deno.png test/assets/bun_deno_assets_test.dart
git commit -m "feat(assets): add official Bun and Deno brand icons"
```

---

### Task 2: Catalog Definitions & Automated Release Fetcher (`update.js`, `apps.json`, `apps-linux.json`)

**Files:**
- Modify: `assets/data/update.js`
- Modify: `assets/data/apps.json`
- Modify: `assets/data/apps-linux.json`
- Test: `test/assets/bun_deno_catalog_test.dart`

**Interfaces:**
- Consumes: GitHub Releases API for `oven-sh/bun` and `denoland/deno`.
- Produces: App entries for `bun` and `deno` in both `apps.json` and `apps-linux.json`.

- [ ] **Step 1: Write the failing catalog test**

Create `test/assets/bun_deno_catalog_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catalog entries for Bun and Deno', () {
    test('apps.json contains Windows definitions for bun and deno', () async {
      final raw = await File('assets/data/apps.json').readAsString();
      final catalog = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();

      final bun = apps.firstWhere((a) => a['id'] == 'bun', orElse: () => {});
      expect(bun['name'], equals('Bun'));
      expect(bun['category'], equals('runtime'));
      expect(bun['group_name'], equals('bun'));
      expect(bun['exec_file'], equals('bun.exe'));
      expect(bun['cli_file'], equals('bun.exe'));
      final bunVersions = bun['versions'] as Map<String, dynamic>;
      expect(bunVersions.isNotEmpty, isTrue);
      expect(bunVersions.values.first.toString(), endsWith('bun-windows-x64.zip'));

      final deno = apps.firstWhere((a) => a['id'] == 'deno', orElse: () => {});
      expect(deno['name'], equals('Deno'));
      expect(deno['category'], equals('runtime'));
      expect(deno['group_name'], equals('deno'));
      expect(deno['exec_file'], equals('deno.exe'));
      expect(deno['cli_file'], equals('deno.exe'));
      final denoVersions = deno['versions'] as Map<String, dynamic>;
      expect(denoVersions.isNotEmpty, isTrue);
      expect(denoVersions.values.first.toString(), contains('windows'));
    });

    test('apps-linux.json contains Linux definitions for bun and deno', () async {
      final raw = await File('assets/data/apps-linux.json').readAsString();
      final catalog = jsonDecode(raw) as Map<String, dynamic>;
      final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();

      final bun = apps.firstWhere((a) => a['id'] == 'bun', orElse: () => {});
      expect(bun['name'], equals('Bun'));
      expect(bun['category'], equals('runtime'));
      expect(bun['group_name'], equals('bun'));
      expect(bun['exec_file'], equals('bun'));
      expect(bun['cli_file'], equals('bun'));
      final bunVersions = bun['versions'] as Map<String, dynamic>;
      expect(bunVersions.isNotEmpty, isTrue);
      expect(bunVersions.values.first.toString(), endsWith('bun-linux-x64.zip'));

      final deno = apps.firstWhere((a) => a['id'] == 'deno', orElse: () => {});
      expect(deno['name'], equals('Deno'));
      expect(deno['category'], equals('runtime'));
      expect(deno['group_name'], equals('deno'));
      expect(deno['exec_file'], equals('deno'));
      expect(deno['cli_file'], equals('deno'));
      final denoVersions = deno['versions'] as Map<String, dynamic>;
      expect(denoVersions.isNotEmpty, isTrue);
      expect(denoVersions.values.first.toString(), contains('linux'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/assets/bun_deno_catalog_test.dart`
Expected: FAIL (bun and deno not yet in catalogs).

- [ ] **Step 3: Update `assets/data/update.js` to support Bun and Deno**

Modify `assets/data/update.js`:
1. In `COMMON_APP_DEFINITIONS`, add:
```javascript
  bun: {
    id: "bun",
    name: "Bun",
    description: "Fast all-in-one JavaScript runtime & toolkit.",
    category: "runtime",
    group_name: "bun",
    repo: "oven-sh/bun",
  },
  deno: {
    id: "deno",
    name: "Deno",
    description: "A modern, secure runtime for JavaScript and TypeScript.",
    category: "runtime",
    group_name: "deno",
    repo: "denoland/deno",
  },
```
2. In `baseWindowsApps`, add:
```javascript
  makeBinaryApp(COMMON_APP_DEFINITIONS.bun, "bun.exe", "bun.exe"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.deno, "deno.exe", "deno.exe"),
```
3. In `baseLinuxApps`, add:
```javascript
  makeBinaryApp(COMMON_APP_DEFINITIONS.bun, "bun", "bun"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.deno, "deno", "deno"),
```
4. Update GitHub fetcher in `fetchersWindows` and `fetchersLinux`:
   - Update tag regex to clean `bun-v`:
     `const ver = r.tag_name.replace(/^(bun-v|v|release-|redis-|redis|r(?=\d))/i, "");`
   - Windows asset selector:
     - For `oven-sh/bun`: match asset named `bun-windows-x64.zip`.
     - For `denoland/deno`: match asset containing `x86_64-pc-windows-msvc.zip`.
   - Linux asset selector:
     - For `oven-sh/bun`: match asset named `bun-linux-x64.zip`.
     - For `denoland/deno`: match asset containing `x86_64-unknown-linux-gnu.zip`.

- [ ] **Step 4: Update `apps.json` and `apps-linux.json` with fetched releases**

Run `node assets/data/update.js` or add the valid stable versions into `assets/data/apps.json` and `assets/data/apps-linux.json`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/assets/bun_deno_catalog_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add assets/data/update.js assets/data/apps.json assets/data/apps-linux.json test/assets/bun_deno_catalog_test.dart
git commit -m "feat(catalog): add bun and deno app definitions and update fetcher logic"
```

---

### Task 3: Installer Logic for Bun & Deno in `AppInstallerService`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Test: `test/features/apps/installer_runtimes_test.dart`

**Interfaces:**
- Consumes: `AppModel` with `appId == 'bun'` or `appId == 'deno'`.
- Produces: Installed runtime folder with `bunx.exe` generated on Windows alongside `bun.exe`.

- [ ] **Step 1: Write the failing installer test**

Create `test/features/apps/installer_runtimes_test.dart`:
```dart
import 'dart:io';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppInstallerService runtime post-configuration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('installer_runtime_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('configureBunWindows creates bunx.exe when bun.exe exists', () async {
      final bunExe = File(p.join(tempDir.path, 'bun.exe'));
      await bunExe.writeAsString('mock bun binary');

      final bunxExe = File(p.join(tempDir.path, 'bunx.exe'));
      expect(bunxExe.existsSync(), isFalse);

      await AppInstallerService.configureBunBinary(
        installPath: tempDir.path,
        isWindows: true,
        logInfo: (_) {},
      );

      expect(bunxExe.existsSync(), isTrue);
      expect(await bunxExe.readAsString(), equals('mock bun binary'));
    });

    test('configureBunBinary is a no-op when not on Windows', () async {
      final bunExe = File(p.join(tempDir.path, 'bun'));
      await bunExe.writeAsString('mock bun binary');

      await AppInstallerService.configureBunBinary(
        installPath: tempDir.path,
        isWindows: false,
        logInfo: (_) {},
      );

      final bunx = File(p.join(tempDir.path, 'bunx'));
      expect(bunx.existsSync(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/installer_runtimes_test.dart`
Expected: FAIL (`configureBunBinary` not defined).

- [ ] **Step 3: Implement `configureBunBinary` and wire into `_configureRuntimes`**

In `lib/features/apps/data/app_installer_service.dart`:
1. Add `@visibleForTesting static Future<void> configureBunBinary(...)`:
```dart
  @visibleForTesting
  static Future<void> configureBunBinary({
    required String installPath,
    required bool isWindows,
    required void Function(String) logInfo,
  }) async {
    if (!isWindows) return;
    final bunExe = File(p.join(installPath, 'bun.exe'));
    final bunxExe = File(p.join(installPath, 'bunx.exe'));

    if (bunExe.existsSync() && !bunxExe.existsSync()) {
      logInfo('Creating bunx.exe alias in $installPath');
      try {
        await bunExe.copy(bunxExe.path);
      } catch (e) {
        logInfo('Warning: Could not create bunx.exe: $e');
      }
    }
  }
```
2. In `_configureRuntimes(AppModel app, String installPath, ...)`:
```dart
    if (app.appId == 'bun') {
      await configureBunBinary(
        installPath: installPath,
        isWindows: Platform.isWindows,
        logInfo: logInfo,
      );
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/installer_runtimes_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_runtimes_test.dart
git commit -m "feat(installer): add bunx post-configuration for Bun on Windows"
```

---

### Task 4: Isolated Global Package Directories & Helpers in `PathService`

**Files:**
- Modify: `lib/core/services/path_service.dart`
- Test: `test/core/services/path_service_global_dirs_test.dart`

**Interfaces:**
- Consumes: `appId`, `isWindows`, environment variables map.
- Produces: `PathService.globalPackageDirForApp(String appId, {bool isWindows, Map<String, String>? environment}) -> String?`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/path_service_global_dirs_test.dart`:
```dart
import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService.globalPackageDirForApp', () {
    test('returns %APPDATA%\\npm for nodejs on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'nodejs',
        isWindows: true,
        environment: {'APPDATA': r'C:\Users\Alice\AppData\Roaming'},
      );
      expect(dir, equals(r'C:\Users\Alice\AppData\Roaming\npm'));
    });

    test('returns ~/.npm-global/bin for nodejs on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'nodejs',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.npm-global/bin'));
    });

    test('returns %USERPROFILE%\\.bun\\bin for bun on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'bun',
        isWindows: true,
        environment: {'USERPROFILE': r'C:\Users\Alice'},
      );
      expect(dir, equals(r'C:\Users\Alice\.bun\bin'));
    });

    test('returns ~/.bun/bin for bun on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'bun',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.bun/bin'));
    });

    test('returns %USERPROFILE%\\.deno\\bin for deno on Windows', () {
      final dir = PathService.globalPackageDirForApp(
        'deno',
        isWindows: true,
        environment: {'USERPROFILE': r'C:\Users\Alice'},
      );
      expect(dir, equals(r'C:\Users\Alice\.deno\bin'));
    });

    test('returns ~/.deno/bin for deno on Linux', () {
      final dir = PathService.globalPackageDirForApp(
        'deno',
        isWindows: false,
        environment: {'HOME': '/home/alice'},
      );
      expect(dir, equals('/home/alice/.deno/bin'));
    });

    test('returns null for non-JS apps', () {
      expect(PathService.globalPackageDirForApp('mysql'), isNull);
      expect(PathService.globalPackageDirForApp('nginx'), isNull);
      expect(PathService.globalPackageDirForApp('php84'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/path_service_global_dirs_test.dart`
Expected: FAIL (`globalPackageDirForApp` not defined).

- [ ] **Step 3: Implement `globalPackageDirForApp` in `PathService`**

In `lib/core/services/path_service.dart`:
```dart
  /// Trả về thư mục chứa các global package binaries riêng biệt cho từng runtime JS
  @visibleForTesting
  static String? globalPackageDirForApp(
    String appId, {
    bool? isWindows,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final onWindows = isWindows ?? Platform.isWindows;
    final id = appId.toLowerCase();

    if (id.contains('nodejs') || id == 'node') {
      if (onWindows) {
        final appData = env['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return p.join(appData, 'npm');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, '.npm-global', 'bin');
        }
      }
    }

    if (id.contains('bun')) {
      if (onWindows) {
        final userProfile = env['USERPROFILE'] ?? env['HOME'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return p.join(userProfile, '.bun', 'bin');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, '.bun', 'bin');
        }
      }
    }

    if (id.contains('deno')) {
      if (onWindows) {
        final userProfile = env['USERPROFILE'] ?? env['HOME'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return p.join(userProfile, '.deno', 'bin');
        }
      } else {
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return p.join(home, '.deno', 'bin');
        }
      }
    }

    return null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/path_service_global_dirs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/path_service.dart test/core/services/path_service_global_dirs_test.dart
git commit -m "feat(path): add global package directory resolution for Node, Bun, and Deno"
```

---

### Task 5: Shims, Symlinks, and User PATH Management for Node.js, Bun, and Deno in `PathService`

**Files:**
- Modify: `lib/core/services/path_service.dart`
- Test: `test/core/services/path_service_runtimes_test.dart`

**Interfaces:**
- Consumes: `addAppToPath(AppModel app)`, `removeAppFromPath(AppModel app)`.
- Produces: Correct shims/symlinks in `binDir` for `bun`, `bunx`, and `deno`; isolated User PATH updates for Node.js, Bun, and Deno.

- [ ] **Step 1: Write the failing tests for runtime shims and isolated PATH**

Create `test/core/services/path_service_runtimes_test.dart`:
```dart
import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService runtime shim and PATH management', () {
    test('shimNamesForApp includes bun and bunx for Bun', () {
      final shims = PathService.shimNamesForApp('bun');
      expect(shims, containsAll(['bun', 'bunx']));
    });

    test('shimNamesForApp includes deno for Deno', () {
      final shims = PathService.shimNamesForApp('deno');
      expect(shims, containsAll(['deno']));
    });

    test('shimNamesForApp includes node, npm, npx, corepack for Node.js', () {
      final shims = PathService.shimNamesForApp('nodejs');
      expect(shims, containsAll(['nodejs', 'node', 'npm', 'npx', 'corepack']));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/path_service_runtimes_test.dart`
Expected: FAIL (`shimNamesForApp` not defined).

- [ ] **Step 3: Implement `shimNamesForApp` and update `addAppToPath` / `removeAppFromPath`**

1. In `lib/core/services/path_service.dart`:
```dart
  @visibleForTesting
  static List<String> shimNamesForApp(String appId) {
    final id = appId.toLowerCase();
    if (id.contains('bun')) {
      return ['bun', 'bunx'];
    }
    if (id.contains('deno')) {
      return ['deno'];
    }
    if (id.contains('nodejs') || id == 'node') {
      return ['nodejs', 'node', 'npm', 'npx', 'corepack'];
    }
    return [appId];
  }
```
2. Update `addAppToPath(AppModel app)`:
   - For Linux:
     - If `app.appId.contains('bun')`:
       - `await createLinuxSymlinkOrShim(binDir, 'bun', app.cliFilePath!);`
       - `await createLinuxSymlinkOrShim(binDir, 'bunx', app.cliFilePath!);`
     - If `app.appId.contains('deno')`:
       - `await createLinuxSymlinkOrShim(binDir, 'deno', app.cliFilePath!);`
     - If `app.appId.contains('nodejs')`:
       - Configure npm prefix to `~/.npm-global` instead of `binDir`:
         `await Process.run(npmBin, ['config', 'set', 'prefix', p.join(home, '.npm-global'), '-g']);`
     - Resolve `final globalDir = globalPackageDirForApp(app.appId);` and if not null:
       `await addRawPathToUserPath(globalDir);`
   - For Windows:
     - If `app.appId.contains('bun')`:
       - `await _createShimSet('bun', app.cliFilePath!);`
       - `await _createShimSet('bunx', app.cliFilePath!);`
     - If `app.appId.contains('deno')`:
       - `await _createShimSet('deno', app.cliFilePath!);`
     - If `app.appId.contains('nodejs')`:
       - Remove the line that sets npm prefix to `binDir` (`C:\Ponta\bin`).
     - Resolve `final globalDir = globalPackageDirForApp(app.appId);` and if not null:
       `await addRawPathToUserPath(globalDir);`
3. Update `removeAppFromPath(AppModel app)`:
   - Delete all shims/symlinks in `shimNamesForApp(app.appId)`.
   - If `globalPackageDirForApp(app.appId)` is not null:
     `await removeRawPathFromUserPath(globalDir);`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/path_service_runtimes_test.dart`
Expected: PASS.

- [ ] **Step 5: Run existing PathService tests**

Run: `flutter test test/core/services/`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/path_service.dart test/core/services/path_service_runtimes_test.dart
git commit -m "feat(path): implement runtime shimming and isolated global package PATH integration"
```

---

### Task 6: UI Brand Colors & Icon Resolution (`AppVersionModal` & `CompactAppsTable`)

**Files:**
- Modify: `lib/features/apps/presentation/widgets/app_version_modal.dart`
- Modify: `lib/features/apps/presentation/widgets/compact_apps_table.dart`
- Test: `test/features/apps/app_brand_ui_test.dart`

**Interfaces:**
- Consumes: `app.appId`
- Produces: Correct icon file name (`'bun'`, `'deno'`) and accent brand color (`Color(0xFFE5A83B)` for Bun, `Color(0xFF70FFAF)` for Deno).

- [ ] **Step 1: Write failing UI brand mapping test**

Create `test/features/apps/app_brand_ui_test.dart`:
```dart
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper extracting icon and color logic for testability
String getAppIconName(String appId) {
  final id = appId.toLowerCase();
  if (id.contains('bun')) return 'bun';
  if (id.contains('deno')) return 'deno';
  if (id.contains('nodejs')) return 'nodejs';
  return id;
}

Color getAppIconColor(String appId) {
  final id = appId.toLowerCase();
  if (id.contains('bun')) return const Color(0xFFE5A83B);
  if (id.contains('deno')) return const Color(0xFF70FFAF);
  if (id.contains('node')) return const Color(0xFF68A063);
  return const Color(0xFF000000);
}

void main() {
  group('App Brand UI resolution for Bun and Deno', () {
    test('resolves bun icon and brand color', () {
      expect(getAppIconName('bun'), equals('bun'));
      expect(getAppIconColor('bun'), equals(const Color(0xFFE5A83B)));
    });

    test('resolves deno icon and brand color', () {
      expect(getAppIconName('deno'), equals('deno'));
      expect(getAppIconColor('deno'), equals(const Color(0xFF70FFAF)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/features/apps/app_brand_ui_test.dart`
Expected: PASS.

- [ ] **Step 3: Update `AppVersionModal` and `CompactAppsTable`**

1. In `lib/features/apps/presentation/widgets/app_version_modal.dart`:
   - In `_getIconFileName()`:
     ```dart
     if (id.contains('bun')) return 'bun';
     if (id.contains('deno')) return 'deno';
     ```
   - In `_getIconColor()`:
     ```dart
     } else if (widget.app.appId.contains('bun')) {
       return const Color(0xFFE5A83B);
     } else if (widget.app.appId.contains('deno')) {
       return const Color(0xFF70FFAF);
     ```
2. In `lib/features/apps/presentation/widgets/compact_apps_table.dart`:
   - In `_getIconFileName()`:
     ```dart
     if (id.contains('bun')) return 'bun';
     if (id.contains('deno')) return 'deno';
     ```
   - In `_getIconColor()`:
     ```dart
     if (appId.contains('bun')) {
       return const Color(0xFFE5A83B);
     }
     if (appId.contains('deno')) {
       return const Color(0xFF70FFAF);
     }
     ```

- [ ] **Step 4: Run Flutter test suite**

Run: `flutter test test/features/apps/app_brand_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/presentation/widgets/app_version_modal.dart lib/features/apps/presentation/widgets/compact_apps_table.dart test/features/apps/app_brand_ui_test.dart
git commit -m "feat(ui): add Bun and Deno brand icon and color mappings"
```

---

### Task 7: Full Test Suite Verification & Clean Up

**Files:**
- All tests across `test/`

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All 450+ tests pass with zero errors.

- [ ] **Step 2: Check git status and ensure workspace is clean**

Run: `git status`
Expected: clean working tree.

- [ ] **Step 3: Commit any final test adjustments**

```bash
git commit --allow-empty -m "chore: verify full test suite passes for bun and deno integration"
```
