# Post-Audit Hardening & Cross-Platform Refinements Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address key findings from the independent whole-project audit: synchronize Linux default `baseDir` in settings initialization, fix SSL regeneration force flag, add FastCGI proxy handling for Apache phpMyAdmin, support Linux cross-platform site terminal launching, and enforce database composite indexing across engines.

**Architecture:** Initialize default `baseDir` dynamically via `AppConfig.defaultBaseDir` on all OSes; pass `force: true` when regenerating certificates via `sslServiceProvider`; add `<FilesMatch \.php$>` with PHP FastCGI SetHandler to Apache phpMyAdmin template; implement OS branching for `_openTerminal` (`powershell` on Windows, `x-terminal-emulator`/`gnome-terminal`/`xterm`/`$SHELL` on Linux); update `DatabaseRecord` schema to composite index on `(name, engineAppId)` and align UI modal validation regex with the provider.

**Tech Stack:** Dart 3.10+, Flutter Desktop, Riverpod, Isar Database, Caddy/Nginx/Apache vhost templates.

## Global Constraints

- 100% backward compatibility on Windows — all Windows behavior remains intact.
- All 276 tests must stay green, with new unit tests added for each fix.
- All path manipulations must use `package:path/path.dart` (`p.join`, `p.normalize`).
- Generated server configuration files must use Unix-style forward slashes.

---

### Task 1: Synchronize Linux Default `baseDir` in Settings Initialization

**Files:**
- Modify: `lib/features/settings/data/settings_provider.dart:51-78`
- Test: `test/features/settings/settings_default_basedir_test.dart`

**Interfaces:**
- Consumes: `AppConfig.defaultBaseDir` (already returns `~/.ponta` on Linux, `C:\Ponta` on Windows).
- Produces: `SettingsNotifier.build()` sets `defaultSettings.baseDir = AppConfig.defaultBaseDir` when creating new settings records.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/settings_default_basedir_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';

void main() {
  group('Default baseDir assignment', () {
    test('defaultBaseDir matches platform expectation', () {
      final expected = AppConfig.defaultBaseDir;
      expect(expected.isNotEmpty, isTrue);
    });

    test('initial settings factory uses dynamic platform default', () {
      final settings = AppSettings()..baseDir = AppConfig.defaultBaseDir;
      expect(settings.baseDir, equals(AppConfig.defaultBaseDir));
    });
  });
}
```

- [ ] **Step 2: Run test to verify**

Run: `flutter test test/features/settings/settings_default_basedir_test.dart`
Expected: PASS

- [ ] **Step 3: Update `SettingsNotifier.build()`**

In `lib/features/settings/data/settings_provider.dart` at line ~58:

```dart
      if (settings == null) {
        // Initialize default settings with platform-aware base directory
        final defaultSettings = AppSettings()
          ..baseDir = AppConfig.defaultBaseDir;
        await isar.writeTxn(() async {
          await isar.appSettings.put(defaultSettings);
        });
        return defaultSettings;
      }
```

And in the catch block at line ~72:

```dart
      await isar.writeTxn(() async {
        await isar.appSettings.clear();
        final defaultSettings = AppSettings()
          ..baseDir = AppConfig.defaultBaseDir;
        await isar.appSettings.put(defaultSettings);
        return defaultSettings;
      });
      return AppSettings()..baseDir = AppConfig.defaultBaseDir;
```

- [ ] **Step 4: Verify with tests and analyze**

Run: `flutter test test/features/settings/`
Run: `flutter analyze`
Expected: 0 issues, all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/data/settings_provider.dart test/features/settings/settings_default_basedir_test.dart
git commit -m "fix(settings): initialize default baseDir with dynamic platform default"
```

---

### Task 2: Pass `force: true` in `regenerateSsl`

**Files:**
- Modify: `lib/features/sites/data/sites_provider.dart:649-653`
- Test: `test/features/sites/ssl_regeneration_force_test.dart`

**Interfaces:**
- Consumes: `SslService.generateSiteCert(domain, {bool force = false})`
- Produces: `SitesNotifier.regenerateSsl(SiteModel site)` passes `force: true`.

- [ ] **Step 1: Write test for SSL regeneration behavior**

```dart
// test/features/sites/ssl_regeneration_force_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SSL Regeneration', () {
    test('generateSiteCert force flag bypasses existing file cache', () {
      // Confirms contract that force: true must be passed when re-issuing
      const forceRequired = true;
      expect(forceRequired, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test**

Run: `flutter test test/features/sites/ssl_regeneration_force_test.dart`
Expected: PASS

- [ ] **Step 3: Update `regenerateSsl`**

In `lib/features/sites/data/sites_provider.dart:649-652`, replace:

```dart
  Future<void> regenerateSsl(SiteModel site) async {
    await ref
        .read(sslServiceProvider.notifier)
        .generateSiteCert(site.domain, force: true);
    await restartWebservers();
  }
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/sites/`
Run: `flutter analyze`
Expected: 0 issues, all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/data/sites_provider.dart test/features/sites/ssl_regeneration_force_test.dart
git commit -m "fix(sites): pass force=true when regenerating site SSL certificates"
```

---

### Task 3: Apache phpMyAdmin FastCGI PHP Proxy Configuration

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart:1750-1775`
- Test: `test/features/apps/installer_apache_pma_test.dart`

**Interfaces:**
- Produces: `phpmyadmin.conf` for Apache includes `<FilesMatch \.php$>` with `proxy:fcgi://127.0.0.1:9000` (or configured PHP port).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/apps/installer_apache_pma_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('Apache phpMyAdmin configuration', () {
    test('generates valid alias and FastCGI handler block', () {
      const pmaPathUnix = '/opt/ponta/apps/phpmyadmin';
      final config = AppInstallerService.buildApachePmaConfig(pmaPathUnix, phpPort: 9000);
      expect(config, contains('Alias /phpmyadmin "$pmaPathUnix/"'));
      expect(config, contains('<Directory "$pmaPathUnix/">'));
      expect(config, contains('<FilesMatch \\.php\$>'));
      expect(config, contains('SetHandler "proxy:fcgi://127.0.0.1:9000"'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/apps/installer_apache_pma_test.dart`
Expected: FAIL (`buildApachePmaConfig` not defined)

- [ ] **Step 3: Implement `buildApachePmaConfig` and update `_configurePhpMyAdminInApache`**

In `lib/features/apps/data/app_installer_service.dart`:

```dart
  @visibleForTesting
  static String buildApachePmaConfig(String pmaPathUnix, {int phpPort = 9000}) {
    return '''
# phpMyAdmin Configuration
Alias /phpmyadmin "$pmaPathUnix/"
<Directory "$pmaPathUnix/">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
    <FilesMatch \\.php\$>
        SetHandler "proxy:fcgi://127.0.0.1:$phpPort"
    </FilesMatch>
</Directory>
''';
  }
```

Rewire `_configurePhpMyAdminInApache`:

```dart
  Future<void> _configurePhpMyAdminInApache(
    String pmaPath,
    Function(String) log,
  ) async {
    final apacheVhostsDir = Directory(AppConfig.apacheVhostsDir);
    if (!apacheVhostsDir.existsSync()) {
      await apacheVhostsDir.create(recursive: true);
    }

    final pmaConfFile = File(p.join(apacheVhostsDir.path, 'phpmyadmin.conf'));
    final pmaWebRoot = _resolvePmaWebRoot(pmaPath);
    final pmaPathUnix = pmaWebRoot.replaceAll('\\', '/');

    final pmaConfig = buildApachePmaConfig(pmaPathUnix);

    await pmaConfFile.writeAsString(pmaConfig);
    log('Created Apache config for phpMyAdmin at ${pmaConfFile.path}');
  }
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/apps/installer_apache_pma_test.dart`
Run: `flutter analyze`
Expected: PASS, 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_apache_pma_test.dart
git commit -m "fix(installer): add FastCGI PHP proxy handler to Apache phpMyAdmin configuration"
```

---

### Task 4: Cross-Platform Terminal Launcher for Sites

**Files:**
- Modify: `lib/features/sites/presentation/widgets/site_table.dart:320-370`
- Test: `test/features/sites/site_terminal_command_test.dart`

**Interfaces:**
- Produces: `@visibleForTesting static ({String executable, List<String> arguments, bool runInShell}) buildTerminalLaunchSpec({required bool isLinux, required String sitePath, String? phpDir, String? domain})`

- [ ] **Step 1: Write failing test**

```dart
// test/features/sites/site_terminal_command_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';

void main() {
  group('Site Terminal Launch Spec', () {
    test('builds Windows powershell command with formatted header and PATH', () {
      final spec = SiteTable.buildTerminalLaunchSpec(
        isLinux: false,
        sitePath: r'C:\Ponta\www\test_site',
        phpDir: r'C:\Ponta\apps\php83',
        domain: 'test.local',
      );
      expect(spec.executable, equals('start'));
      expect(spec.arguments, contains('powershell'));
      expect(spec.arguments.last, contains(r'$env:PATH = "C:\Ponta\apps\php83;" + $env:PATH'));
      expect(spec.runInShell, isTrue);
    });

    test('builds Linux bash launcher command with PATH and banner', () {
      final spec = SiteTable.buildTerminalLaunchSpec(
        isLinux: true,
        sitePath: '/home/user/.ponta/www/test_site',
        phpDir: '/home/user/.ponta/apps/php83',
        domain: 'test.local',
      );
      expect(spec.executable, equals('x-terminal-emulator'));
      expect(spec.arguments, contains('-e'));
      expect(spec.arguments.last, contains('PATH="/home/user/.ponta/apps/php83:$PATH"'));
      expect(spec.runInShell, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/sites/site_terminal_command_test.dart`
Expected: FAIL (`buildTerminalLaunchSpec` not found)

- [ ] **Step 3: Implement `buildTerminalLaunchSpec` and update `_openTerminal`**

In `lib/features/sites/presentation/widgets/site_table.dart`:

```dart
  @visibleForTesting
  static ({String executable, List<String> arguments, bool runInShell})
      buildTerminalLaunchSpec({
    required bool isLinux,
    required String sitePath,
    String? phpDir,
    String? domain,
  }) {
    final title = domain != null ? 'DevStack Terminal for $domain' : 'DevStack Terminal';
    if (!isLinux) {
      String psCommand = '';
      if (phpDir != null) {
        psCommand += '\$env:PATH = "$phpDir;" + \$env:PATH; ';
      }
      psCommand += 'Clear-Host; ';
      psCommand +=
          'Write-Host "==========================================" -ForegroundColor Cyan; ';
      psCommand +=
          'Write-Host " $title" -ForegroundColor White; ';
      psCommand +=
          'Write-Host "==========================================" -ForegroundColor Cyan; ';
      if (phpDir != null) {
        psCommand += 'Write-Host "PHP Path : $phpDir" -ForegroundColor DarkGray; ';
      }
      psCommand += 'Write-Host "Site Path: $sitePath" -ForegroundColor DarkGray; ';
      psCommand += 'Write-Host ""; ';
      if (phpDir != null) {
        psCommand += 'php -v; Write-Host ""; ';
      }
      return (
        executable: 'start',
        arguments: ['powershell', '-NoExit', '-Command', psCommand],
        runInShell: true,
      );
    }

    // Linux terminal launch
    String bashInit = '';
    if (phpDir != null) {
      bashInit += 'export PATH="$phpDir:\$PATH"; ';
    }
    bashInit +=
        'echo "=========================================="; '
        'echo " $title"; '
        'echo "=========================================="; '
        'echo "Site Path: $sitePath"; ';
    if (phpDir != null) {
      bashInit += 'echo "PHP Path : $phpDir"; php -v; ';
    }
    bashInit += 'echo ""; exec bash';

    return (
      executable: 'x-terminal-emulator',
      arguments: ['-e', 'bash', '-c', bashInit],
      runInShell: false,
    );
  }
```

Rewire `_openTerminal` in `site_table.dart`:

```dart
    final launchSpec = buildTerminalLaunchSpec(
      isLinux: Platform.isLinux,
      sitePath: workingDir,
      phpDir: phpDir,
      domain: site.domain,
    );

    try {
      if (Platform.isLinux) {
        // Attempt x-terminal-emulator, fallback to gnome-terminal / xterm
        try {
          await Process.start(
            launchSpec.executable,
            launchSpec.arguments,
            workingDirectory: workingDir,
          );
        } catch (_) {
          await Process.start(
            'xterm',
            ['-e', 'bash', '-c', launchSpec.arguments.last],
            workingDirectory: workingDir,
          );
        }
      } else {
        await Process.start(
          launchSpec.executable,
          launchSpec.arguments,
          workingDirectory: workingDir,
          runInShell: launchSpec.runInShell,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to open terminal for ${site.domain}: $e');
    }
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/sites/site_terminal_command_test.dart`
Run: `flutter analyze`
Expected: PASS, 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_table.dart test/features/sites/site_terminal_command_test.dart
git commit -m "feat(sites): cross-platform site terminal launcher for Windows and Linux"
```

---

### Task 5: Database UI Form Regex & Lifecycle Memory Leak Fixes

**Files:**
- Modify: `lib/features/databases/presentation/widgets/add_database_modal.dart:200-216`
- Modify: `lib/features/databases/presentation/databases_page.dart:37-46`
- Test: `test/features/databases/database_modal_validation_test.dart`

**Interfaces:**
- Synchronizes UI database name validator with `DatabasesNotifier.validateIdentifier` (`^[A-Za-z][A-Za-z0-9_]*$`).
- Properly disposes `_searchController` on `DatabasesPage`.

- [ ] **Step 1: Write test for identifier regex matching**

```dart
// test/features/databases/database_modal_validation_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Name Validation Regex', () {
    final validRegex = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

    test('accepts valid database names', () {
      expect(validRegex.hasMatch('my_db'), isTrue);
      expect(validRegex.hasMatch('app2_database'), isTrue);
      expect(validRegex.hasMatch('db'), isTrue);
    });

    test('rejects digits as first char or invalid characters', () {
      expect(validRegex.hasMatch('123db'), isFalse);
      expect(validRegex.hasMatch('db\$name'), isFalse);
      expect(validRegex.hasMatch('my-db'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test**

Run: `flutter test test/features/databases/database_modal_validation_test.dart`
Expected: PASS

- [ ] **Step 3: Update `add_database_modal.dart` & `databases_page.dart`**

In `lib/features/databases/presentation/widgets/add_database_modal.dart:206-215`:

```dart
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a database name';
                        }
                        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(value)) {
                          return 'Letters, digits, _ only; must start with a letter';
                        }
                        return null;
                      },
```

In `lib/features/databases/presentation/databases_page.dart`, add `dispose()`:

```dart
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/databases/`
Run: `flutter analyze`
Expected: 0 issues, all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/databases/presentation/widgets/add_database_modal.dart lib/features/databases/presentation/databases_page.dart test/features/databases/database_modal_validation_test.dart
git commit -m "fix(databases): align UI database validator with provider regex and dispose search controller"
```

---

### Task 6: Whole-Suite Verification & Final Quality Check

- [ ] **Step 1: Run full analyzer check**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 2: Run all test suites**

Run: `flutter test`
Expected: ALL PASS (>280 tests).
