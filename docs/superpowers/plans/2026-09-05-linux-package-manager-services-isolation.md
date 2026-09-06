# Linux Package Manager Services Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Apache, PostgreSQL, Redis, and PHP-FPM on Linux to use system package manager installation (`apt-get`, `dnf`) while running in user-space foreground mode with isolated configurations and data inside `~/.ponta`.

**Architecture:**
1. Update `assets/data/apps-linux.json` and `assets/data/update.js` to define package manager commands for `apache`, `postgresql`, `redis`, and `php82`..`php85`, ensuring default systemd daemons are disabled immediately upon installation (`sudo systemctl disable --now <service>`).
2. Refactor `AppInstallerService` with a generalized binary locator (`_findInstalledBinary`), support system binary capabilities for webservers, and generate isolated configurations (`httpd.conf`, `redis.conf`, `php-fpm.conf`) and database clusters (`initdb` with `0700` permissions) within `~/.ponta`.
3. Update `AppServiceManager` to execute Apache, PostgreSQL, Redis, and PHP-FPM directly as foreground user processes with real-time stdout/stderr log streaming and standard POSIX signal teardown (`SIGTERM`/`SIGKILL`), removing all runtime dependencies on `systemctl`.

**Tech Stack:** Dart 3.10+, Flutter Desktop, Riverpod, POSIX Process signals (`SIGTERM`, `SIGKILL`), APT / DNF, systemd disable hooks.

**Spec:** `docs/superpowers/specs/2026-09-05-linux-package-manager-services-design.md`

## Global Constraints

- 100% backward compatibility on Windows (all existing Windows tests must continue to pass).
- No hardcoded paths; use `AppConfig.dataDir`, `AppConfig.vhostsDir`, `AppConfig.logsDir`, `AppConfig.baseDir`, and `p.join`.
- All shell commands in catalog must pass `PackageCommandValidator.validateAll` (no chaining, no shell substitution, allowlisted binaries).
- All services on Linux must run in user space without requiring `systemctl` for runtime lifecycle.
- Data directories for PostgreSQL must have restricted permissions (`0700`) so `initdb` and `postgres` accept them.

---

### Task 1: Update Linux App Catalog (`assets/data/apps-linux.json` & `assets/data/update.js`)

**Files:**
- Modify: `assets/data/apps-linux.json`
- Modify: `assets/data/update.js`
- Test: `test/features/apps/package_command_validator_test.dart`

**Interfaces:**
- Consumes: `PackageCommandValidator.validateAll(List<String> commands)`
- Produces: Validated catalog entries for `apache`, `postgresql`, `redis`, `php82`, `php83`, `php84`, `php85` with `install_method: "package_manager"` and `systemctl disable --now` commands.

- [ ] **Step 1: Write test verifying catalog commands for all package manager apps in `apps-linux.json`**

In `test/features/apps/package_command_validator_test.dart`, add a test group that loads `assets/data/apps-linux.json` and verifies that all `package_manager_commands` pass validation:

```dart
    group('real linux catalog validation', () {
      test('all package manager commands in apps-linux.json pass validation', () async {
        final catalogFile = File('assets/data/apps-linux.json');
        expect(catalogFile.existsSync(), isTrue);
        final jsonContent = jsonDecode(await catalogFile.readAsString()) as List<dynamic>;

        final packageManagerApps = jsonContent.where(
          (app) => app['install_method'] == 'package_manager',
        );

        final expectedAppIds = {'apache', 'postgresql', 'redis', 'php82', 'php83', 'php84', 'php85'};
        final foundAppIds = packageManagerApps.map((a) => a['id'] as String).toSet();
        expect(foundAppIds, containsAll(expectedAppIds));

        for (final app in packageManagerApps) {
          final commandsMap = app['package_manager_commands'] as Map<String, dynamic>?;
          expect(commandsMap, isNotNull, reason: '${app['id']} missing package_manager_commands');
          
          for (final entry in commandsMap!.entries) {
            final distro = entry.key;
            final commands = (entry.value as List<dynamic>).cast<String>();
            // Emulate placeholder resolution for validation
            final resolved = commands.map((c) => c.replaceAll('{codename}', 'bookworm')).toList();
            final errors = PackageCommandValidator.validateAll(resolved);
            expect(
              errors,
              isEmpty,
              reason: 'Commands for ${app['id']} on $distro failed validation: $errors',
            );

            // Verify systemctl disable command is present
            final hasDisable = commands.any((c) => c.contains('systemctl disable --now'));
            expect(
              hasDisable,
              isTrue,
              reason: '${app['id']} on $distro must disable default systemd daemon',
            );
          }
        }
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/apps/package_command_validator_test.dart`
Expected: FAIL (missing `apache`, `postgresql`, and `redis` package manager entries, and PHP entries lack `systemctl disable --now`).

- [ ] **Step 3: Update `assets/data/apps-linux.json` and `assets/data/update.js`**

1. In `assets/data/apps-linux.json`:
   - Add `apache`:
     ```json
     {
       "id": "apache",
       "name": "Apache",
       "description": "World No. 1 web server",
       "category": "webserver",
       "group_name": "webserver",
       "exec_file": "apache2",
       "cli_file": "apache2",
       "install_method": "package_manager",
       "package_manager_commands": {
         "ubuntu": [
           "sudo apt-get update",
           "sudo apt-get install -y apache2",
           "sudo systemctl disable --now apache2"
         ],
         "debian": [
           "sudo apt-get update",
           "sudo apt-get install -y apache2",
           "sudo systemctl disable --now apache2"
         ],
         "centos": [
           "sudo dnf install -y httpd",
           "sudo systemctl disable --now httpd"
         ]
       },
       "versions": {
         "system": "package_manager"
       }
     }
     ```
   - Convert `postgresql`:
     ```json
     {
       "id": "postgresql",
       "name": "PostgreSQL",
       "description": "Advanced open source relational database.",
       "category": "database",
       "group_name": "database",
       "exec_file": "postgres",
       "cli_file": "psql",
       "install_method": "package_manager",
       "package_manager_commands": {
         "ubuntu": [
           "sudo apt-get update",
           "sudo apt-get install -y postgresql postgresql-contrib",
           "sudo systemctl disable --now postgresql"
         ],
         "debian": [
           "sudo apt-get update",
           "sudo apt-get install -y postgresql postgresql-contrib",
           "sudo systemctl disable --now postgresql"
         ],
         "centos": [
           "sudo dnf install -y postgresql-server postgresql-contrib",
           "sudo systemctl disable --now postgresql"
         ]
       },
       "versions": {
         "system": "package_manager"
       }
     }
     ```
   - Convert `redis`:
     ```json
     {
       "id": "redis",
       "name": "Redis",
       "description": "High-performance in-memory data structure store.",
       "category": "database",
       "group_name": "redis",
       "exec_file": "redis-server",
       "cli_file": "redis-cli",
       "install_method": "package_manager",
       "package_manager_commands": {
         "ubuntu": [
           "sudo apt-get update",
           "sudo apt-get install -y redis-server",
           "sudo systemctl disable --now redis-server"
         ],
         "debian": [
           "sudo apt-get update",
           "sudo apt-get install -y redis-server",
           "sudo systemctl disable --now redis-server"
         ],
         "centos": [
           "sudo dnf install -y redis",
           "sudo systemctl disable --now redis"
         ]
       },
       "versions": {
         "system": "package_manager"
       }
     }
     ```
   - Update `php82`, `php83`, `php84`, `php85` in `assets/data/apps-linux.json`:
     Append `"sudo systemctl disable --now php8.x-fpm"` (or `php-fpm` for centos) to their `package_manager_commands`.

2. In `assets/data/update.js`:
   - Add `apache` to `baseLinuxApps`.
   - Update `postgresql` and `redis` in `baseLinuxApps` to use `install_method: "package_manager"` and remove dynamic tarball/Zonky fetches for Linux.
   - Add `sudo systemctl disable --now` to `baseLinuxApps` PHP definitions.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/features/apps/package_command_validator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit catalog changes**

```bash
git add assets/data/apps-linux.json assets/data/update.js test/features/apps/package_command_validator_test.dart
git commit -m "feat(catalog): convert apache, postgresql, redis, and php to package manager on linux"
```

---

### Task 2: Binary Detection & Path Resolution in `AppInstallerService`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Test: `test/features/apps/installer_binary_resolver_test.dart`
- Test: `test/features/apps/installer_linux_capability_test.dart`

**Interfaces:**
- Consumes: `app.execFile`, `app.category`, `AppConfig.appsDir`
- Produces:
  - `Future<String?> findInstalledBinary(String name, {List<String>? candidates, Future<ProcessResult> Function(String, List<String>)? runProcess})`
  - Capability support in `setLinuxCapabilityForWebserver` for system binaries (`/usr/sbin/apache2`, `/usr/sbin/httpd`, `/usr/bin/apache2`, `/usr/bin/httpd`).

- [ ] **Step 1: Write test for generalized binary resolution and webserver capability**

Create `test/features/apps/installer_binary_resolver_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppInstallerService installer;
  late Directory tempDir;

  setUp(() {
    installer = AppInstallerService(LogService(), _FakeRef());
    tempDir = Directory.systemTemp.createTempSync('ponta_bin_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('findInstalledBinary', () {
    test('resolves via which command when available', () async {
      final binaryPath = await installer.findInstalledBinary(
        'postgres',
        runProcess: (exec, args) async {
          if (exec == 'which' && args.first == 'postgres') {
            return ProcessResult(1, 0, '/usr/lib/postgresql/16/bin/postgres\n', '');
          }
          return ProcessResult(2, 1, '', 'not found');
        },
      );
      expect(binaryPath, equals('/usr/lib/postgresql/16/bin/postgres'));
    });

    test('falls back to candidate search if which fails', () async {
      final fakeBin = File(p.join(tempDir.path, 'apache2'))..createSync();
      final binaryPath = await installer.findInstalledBinary(
        'apache2',
        candidates: [fakeBin.path],
        runProcess: (exec, args) async => ProcessResult(1, 1, '', 'not found'),
      );
      expect(binaryPath, equals(fakeBin.path));
    });

    test('supports wildcard/glob-like candidate expansion for postgresql', () async {
      final pgDir = Directory(p.join(tempDir.path, 'usr', 'lib', 'postgresql', '16', 'bin'))..createSync(recursive: true);
      final pgBin = File(p.join(pgDir.path, 'postgres'))..createSync();

      final binaryPath = await installer.findInstalledBinary(
        'postgres',
        searchDirectories: [p.join(tempDir.path, 'usr', 'lib', 'postgresql')],
        runProcess: (exec, args) async => ProcessResult(1, 1, '', 'not found'),
      );
      expect(binaryPath, equals(pgBin.path));
    });
  });

  group('setLinuxCapabilityForWebserver with system binaries', () {
    test('allows setting capability on system webserver binaries (/usr/sbin/apache2)', () async {
      final logMessages = <String>[];
      final fakeSystemApache = File(p.join(tempDir.path, 'apache2'))..createSync();

      var setcapCalled = false;
      await installer.setLinuxCapabilityForWebserver(
        fakeSystemApache.path,
        logMessages.add,
        isLinuxOverride: true,
        allowSystemBinaries: true,
        runProcess: (executable, arguments) async {
          if (executable == 'sudo' && arguments.contains('cap_net_bind_service=+ep')) {
            setcapCalled = true;
            return ProcessResult(1, 0, '', '');
          }
          return ProcessResult(2, 1, '', 'failed');
        },
      );

      expect(setcapCalled, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/apps/installer_binary_resolver_test.dart`
Expected: FAIL (`findInstalledBinary` does not exist; `allowSystemBinaries` not defined).

- [ ] **Step 3: Implement `findInstalledBinary` and update `setLinuxCapabilityForWebserver`**

In `lib/features/apps/data/app_installer_service.dart`:

1. Add `findInstalledBinary`:
```dart
  /// Find installed executable in system PATH and standard candidate directories.
  @visibleForTesting
  Future<String?> findInstalledBinary(
    String binaryName, {
    List<String>? candidates,
    List<String>? searchDirectories,
    Function(String)? logInfo,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    final runner = runProcess ?? Process.run;
    try {
      // 1. Try 'which' command
      final whichResult = await runner('which', [binaryName]);
      if (whichResult.exitCode == 0) {
        final path = whichResult.stdout.toString().trim();
        if (path.isNotEmpty && File(path).existsSync()) {
          logInfo?.call('Found $binaryName via which at: $path');
          return path;
        }
      }
    } catch (_) {}

    // 2. Check explicit candidates
    final defaultCandidates = candidates ?? [
      '/usr/bin/$binaryName',
      '/usr/sbin/$binaryName',
      '/usr/local/bin/$binaryName',
      '/usr/local/sbin/$binaryName',
    ];

    for (final candidate in defaultCandidates) {
      if (File(candidate).existsSync()) {
        logInfo?.call('Found $binaryName at candidate path: $candidate');
        return candidate;
      }
    }

    // 3. Search directory trees (e.g. /usr/lib/postgresql/*/bin/$binaryName)
    if (searchDirectories != null) {
      for (final searchDir in searchDirectories) {
        final dir = Directory(searchDir);
        if (dir.existsSync()) {
          try {
            for (final entity in dir.listSync(recursive: true, followLinks: false)) {
              if (entity is File && p.basename(entity.path) == binaryName) {
                logInfo?.call('Found $binaryName in $searchDir at: ${entity.path}');
                return entity.path;
              }
            }
          } catch (_) {}
        }
      }
    }

    return null;
  }
```

2. Update `_findInstalledPhp` to delegate to `findInstalledBinary`:
```dart
  Future<String?> _findInstalledPhp(String phpName, Function(String) logInfo) =>
      findInstalledBinary(phpName, logInfo: logInfo);
```

3. Update `setLinuxCapabilityForWebserver` signature to accept `bool allowSystemBinaries = false`:
```dart
  Future<void> setLinuxCapabilityForWebserver(
    String executablePath,
    Function(String) logInfo, {
    Future<ProcessResult> Function(String executable, List<String> arguments)? runProcess,
    bool? isLinuxOverride,
    bool allowSystemBinaries = false,
  }) async {
    final isLinux = isLinuxOverride ?? Platform.isLinux;
    if (!isLinux) return;

    final isInsideAppsDir = p.isWithin(AppConfig.appsDir, executablePath) || p.equals(AppConfig.appsDir, executablePath);
    final isAllowedSystem = allowSystemBinaries && const {
      'apache2',
      'httpd',
      'caddy',
      'nginx',
    }.contains(p.basename(executablePath));

    if (!isInsideAppsDir && !isAllowedSystem) {
      logInfo('Warning: Executable path $executablePath is outside ${AppConfig.appsDir}, skipping capability setup for security');
      return;
    }

    final execFile = File(executablePath);
    if (!execFile.existsSync()) {
      logInfo('Warning: Executable not found at $executablePath, skipping capability setup');
      return;
    }

    logInfo('Setting CAP_NET_BIND_SERVICE capability for ${p.basename(executablePath)}...');
    final runner = runProcess ?? Process.run;
    try {
      final result = await runner('sudo', [
        'setcap',
        'cap_net_bind_service=+ep',
        executablePath,
      ]);
      if (result.exitCode == 0) {
        logInfo('Successfully set capability for ${p.basename(executablePath)}');
        return;
      }
      final pkexecResult = await runner('pkexec', [
        'setcap',
        'cap_net_bind_service=+ep',
        executablePath,
      ]);
      if (pkexecResult.exitCode == 0) {
        logInfo('Successfully set capability via pkexec for ${p.basename(executablePath)}');
      } else {
        logInfo('Warning: Could not set capability.');
      }
    } catch (e) {
      logInfo('Warning: Could not set capability: $e');
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test test/features/apps/installer_binary_resolver_test.dart test/features/apps/installer_linux_capability_test.dart`
Expected: PASS

- [ ] **Step 5: Commit binary resolver changes**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_binary_resolver_test.dart test/features/apps/installer_linux_capability_test.dart
git commit -m "feat(installer): add generalized binary resolution and system webserver capability support"
```

---

### Task 3: Isolated Configuration & Data Directories in `AppInstallerService`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Test: `test/features/apps/isolated_service_configs_test.dart`

**Interfaces:**
- Consumes: `AppModel`, `AppConfig`
- Produces:
  - `Future<void> configureIsolatedApache(AppModel app, Function(String) logInfo)`
  - `Future<void> configureIsolatedPostgresql(AppModel app, String version, String initdbPath, Function(String) logInfo, {Future<ProcessResult> Function(String, List<String>)? runProcess})`
  - `Future<void> configureIsolatedRedis(AppModel app, Function(String) logInfo)`
  - `Future<void> configureIsolatedPhpFpm(AppModel app, int port, Function(String) logInfo)`

- [ ] **Step 1: Write tests for isolated config generators**

Create `test/features/apps/isolated_service_configs_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppInstallerService installer;
  late Directory tempBaseDir;

  setUp(() {
    tempBaseDir = Directory.systemTemp.createTempSync('ponta_isolated_test_');
    AppConfig.initialize(baseDir: tempBaseDir.path);
    installer = AppInstallerService(LogService(), _FakeRef());
  });

  tearDown(() {
    if (tempBaseDir.existsSync()) {
      tempBaseDir.deleteSync(recursive: true);
    }
  });

  group('Isolated Service Configurations', () {
    test('generates isolated redis.conf with daemonize no and ponta data dir', () async {
      final app = AppModel(
        appId: 'redis',
        name: 'Redis',
        categories: ['database'],
        groupName: 'redis',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedRedis(app, (msg) {});
      final confFile = File(p.join(AppConfig.dataDir, 'redis', 'redis.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('daemonize no'));
      expect(content, contains('port 6379'));
      expect(content, contains('dir "${p.join(AppConfig.dataDir, 'redis').replaceAll('\\', '/')}"'));
    });

    test('generates isolated php-fpm.conf with ondemand and distinct port', () async {
      final app = AppModel(
        appId: 'php83',
        name: 'PHP 8.3',
        categories: ['runtime'],
        groupName: 'php',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedPhpFpm(app, 9083, (msg) {});
      final confFile = File(p.join(AppConfig.baseDir, 'php', 'php83', 'php-fpm.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('daemonize = no'));
      expect(content, contains('listen = 127.0.0.1:9083'));
      expect(content, contains('pm = ondemand'));
    });

    test('generates isolated apache httpd.conf with IncludeOptional for vhosts', () async {
      final app = AppModel(
        appId: 'apache',
        name: 'Apache',
        categories: ['webserver'],
        groupName: 'webserver',
        installMethod: 'package_manager',
      );

      await installer.configureIsolatedApache(app, (msg) {});
      final confFile = File(p.join(AppConfig.vhostsDir, 'apache', 'httpd.conf'));
      expect(confFile.existsSync(), isTrue);

      final content = confFile.readAsStringSync();
      expect(content, contains('ServerName localhost'));
      expect(content, contains('IncludeOptional'));
    });

    test('initializes isolated postgresql cluster with initdb and 0700 permissions', () async {
      final app = AppModel(
        appId: 'postgresql',
        name: 'PostgreSQL',
        categories: ['database'],
        groupName: 'database',
        installMethod: 'package_manager',
      );

      var initdbRan = false;
      final fakeInitdb = File(p.join(tempBaseDir.path, 'initdb'))..createSync();

      await installer.configureIsolatedPostgresql(
        app,
        '16',
        fakeInitdb.path,
        (msg) {},
        runProcess: (exec, args) async {
          if (exec == fakeInitdb.path && args.contains('-D')) {
            initdbRan = true;
            // Create dummy postgresql.conf to test post-configuration
            final targetDir = args[args.indexOf('-D') + 1];
            File(p.join(targetDir, 'postgresql.conf')).createSync(recursive: true);
            return ProcessResult(1, 0, 'ok', '');
          }
          return ProcessResult(2, 0, '', '');
        },
      );

      expect(initdbRan, isTrue);
      final dataDir = Directory(p.join(AppConfig.dataDir, 'postgresql-16'));
      expect(dataDir.existsSync(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/apps/isolated_service_configs_test.dart`
Expected: FAIL (methods not implemented).

- [ ] **Step 3: Implement config generators and wire into `_installViaPackageManager`**

In `lib/features/apps/data/app_installer_service.dart`:

1. Implement `configureIsolatedRedis`:
```dart
  @visibleForTesting
  Future<void> configureIsolatedRedis(AppModel app, Function(String) logInfo) async {
    final redisDir = Directory(p.join(AppConfig.dataDir, 'redis'));
    if (!redisDir.existsSync()) {
      redisDir.createSync(recursive: true);
    }
    final confFile = File(p.join(redisDir.path, 'redis.conf'));
    if (!confFile.existsSync()) {
      final normalizedDir = redisDir.path.replaceAll('\\', '/');
      final content = '''
# Ponta isolated Redis configuration
daemonize no
port 6379
bind 127.0.0.1
dir "$normalizedDir"
pidfile "$normalizedDir/redis.pid"
dbfilename dump.rdb
appendonly no
''';
      await confFile.writeAsString(content);
      logInfo('Generated isolated Redis config at: ${confFile.path}');
    }
  }
```

2. Implement `configureIsolatedPhpFpm`:
```dart
  @visibleForTesting
  Future<void> configureIsolatedPhpFpm(AppModel app, int port, Function(String) logInfo) async {
    final phpDir = Directory(p.join(AppConfig.baseDir, 'php', app.appId));
    if (!phpDir.existsSync()) {
      phpDir.createSync(recursive: true);
    }
    final confFile = File(p.join(phpDir.path, 'php-fpm.conf'));
    if (!confFile.existsSync()) {
      final logsDirNormalized = AppConfig.logsDir.replaceAll('\\', '/');
      final content = '''
[global]
error_log = $logsDirNormalized/${app.appId}-fpm.error.log
daemonize = no

[www]
listen = 127.0.0.1:$port
pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 10s
pm.max_requests = 500
catch_workers_output = yes
''';
      await confFile.writeAsString(content);
      logInfo('Generated isolated PHP-FPM config at: ${confFile.path}');
    }
  }
```

3. Implement `configureIsolatedApache`:
```dart
  @visibleForTesting
  Future<void> configureIsolatedApache(AppModel app, Function(String) logInfo) async {
    final apacheVhostsDir = Directory(p.join(AppConfig.vhostsDir, 'apache'));
    if (!apacheVhostsDir.existsSync()) {
      apacheVhostsDir.createSync(recursive: true);
    }
    final confFile = File(p.join(apacheVhostsDir.path, 'httpd.conf'));
    if (!confFile.existsSync()) {
      final vhostsGlob = p.join(AppConfig.vhostsDir, '*.conf').replaceAll('\\', '/');
      final wwwRoot = AppConfig.webserverRoot.replaceAll('\\', '/');
      final content = '''
# Ponta isolated Apache configuration
ServerRoot "/etc/apache2"
Listen 127.0.0.1:80
ServerName localhost:80
DocumentRoot "$wwwRoot"

<Directory "$wwwRoot">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# Include devstack virtual hosts
IncludeOptional "$vhostsGlob"
''';
      await confFile.writeAsString(content);
      logInfo('Generated isolated Apache config at: ${confFile.path}');
    }
  }
```

4. Implement `configureIsolatedPostgresql`:
```dart
  @visibleForTesting
  Future<void> configureIsolatedPostgresql(
    AppModel app,
    String version,
    String initdbPath,
    Function(String) logInfo, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    final clusterName = 'postgresql-$version';
    final dataDir = Directory(p.join(AppConfig.dataDir, clusterName));
    if (dataDir.existsSync() && dataDir.listSync().isNotEmpty) {
      logInfo('PostgreSQL data directory already initialized: ${dataDir.path}');
      return;
    }

    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    // Set 0700 permissions required by initdb on POSIX
    if (Platform.isLinux) {
      try {
        await Process.run('chmod', ['700', dataDir.path]);
      } catch (_) {}
    }

    final passwordFile = File(p.join(dataDir.path, 'postgres-password.txt'));
    if (!passwordFile.existsSync()) {
      await passwordFile.writeAsString(_generateSecret());
    }

    final args = [
      '-D',
      dataDir.path,
      '-E',
      'UTF8',
      '-U',
      'postgres',
      '--locale=C',
      '-A',
      'scram-sha-256',
      '--pwfile',
      passwordFile.path,
    ];

    final runner = runProcess ?? Process.run;
    logInfo('Running initdb: $initdbPath ${args.join(' ')}');
    final result = await runner(initdbPath, args);
    if (result.exitCode != 0) {
      throw Exception('initdb failed: ${result.stderr}');
    }

    final confFile = File(p.join(dataDir.path, 'postgresql.conf'));
    if (confFile.existsSync()) {
      var conf = await confFile.readAsString();
      conf = conf.replaceAll(
        RegExp(r"^#?listen_addresses\s*=\s*'.*?'", multiLine: true),
        "listen_addresses = '127.0.0.1'",
      );
      await confFile.writeAsString(conf);
    }
    logInfo('Initialized isolated PostgreSQL cluster at ${dataDir.path}');
  }
```

5. In `_installViaPackageManager`:
   - Replace `_findInstalledPhp` call with:
     ```dart
     final execName = app.execFile ?? 'php';
     final execPath = await findInstalledBinary(
       execName,
       candidates: [
         '/usr/bin/$execName',
         '/usr/sbin/$execName',
         '/usr/local/bin/$execName',
         '/usr/local/sbin/$execName',
         if (app.appId.contains('postgresql')) '/usr/lib/postgresql/*/bin/postgres',
       ],
       searchDirectories: app.appId.contains('postgresql') ? ['/usr/lib/postgresql'] : null,
       logInfo: logInfo,
     );
     ```
   - Wire post-install isolation hooks:
     ```dart
     if (app.appId == 'apache' || app.category == 'webserver') {
       await setLinuxCapabilityForWebserver(execPath, logInfo, allowSystemBinaries: true);
       await configureIsolatedApache(app, logInfo);
     } else if (app.appId == 'redis' || app.groupName == 'redis') {
       await configureIsolatedRedis(app, logInfo);
     } else if (app.appId.contains('postgresql')) {
       final initdb = await findInstalledBinary(
         'initdb',
         candidates: ['/usr/bin/initdb', '/usr/lib/postgresql/*/bin/initdb'],
         searchDirectories: ['/usr/lib/postgresql'],
         logInfo: logInfo,
       );
       if (initdb != null) {
         await configureIsolatedPostgresql(app, version, initdb, logInfo);
       }
     } else if (app.groupName == 'php') {
       final port = phpPortFor(app.appId);
       await configureIsolatedPhpFpm(app, port, logInfo);
     }
     ```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test test/features/apps/isolated_service_configs_test.dart`
Expected: PASS

- [ ] **Step 5: Commit isolated configuration changes**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/isolated_service_configs_test.dart
git commit -m "feat(installer): add isolated configuration and cluster initialization for linux package manager apps"
```

---

### Task 4: Foreground Lifecycle Execution & Removal of Systemctl Runtime Dependencies in `AppServiceManager`

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart`
- Modify: `test/features/apps/systemctl_service_test.dart`
- Modify: `test/features/apps/service_manager_linux_dispatch_test.dart`

**Interfaces:**
- Consumes: `AppModel`, `AppConfig`
- Produces:
  - `argumentsForExecutable` support for `apache2`, `httpd` on Linux (`-DFOREGROUND -f ...`), `postgres` (`-D ...`), `redis-server` (`conf`), and `php-fpm` (`-F -y ...`).
  - Direct execution in `start()` and `stop()` without `_startPhpFpmViaSystemctl` / `_stopPhpFpmViaSystemctl`.

- [ ] **Step 1: Write test for foreground arguments and socket detection**

In `test/features/apps/service_manager_linux_dispatch_test.dart`, add tests for arguments generated for `apache2`, `postgres`, `redis-server`, and `php-fpm`:

```dart
  group('linux foreground service arguments', () {
    test('apache2 gets foreground and isolated httpd.conf', () {
      final args = AppServiceManager.argumentsForExecutable(
        'apache2',
        '/usr/sbin',
        isLinux: true,
      );
      expect(args, contains('-DFOREGROUND'));
      expect(args, contains('-f'));
      expect(args.last, contains('httpd.conf'));
    });

    test('redis-server receives isolated redis.conf from ~/.ponta/data/redis', () {
      final args = AppServiceManager.argumentsForExecutable(
        'redis-server',
        '/usr/bin',
        isLinux: true,
      );
      expect(args, hasLength(1));
      expect(args.first, contains('redis.conf'));
    });

    test('php-fpm receives foreground -F and -y config flags', () {
      final args = AppServiceManager.argumentsForExecutable(
        'php-fpm8.2',
        '/usr/sbin',
        appId: 'php82',
        isLinux: true,
      );
      expect(args, containsAll(['-F', '-y']));
      expect(args.last, contains('php-fpm.conf'));
    });
  });

  group('requiredSocketsForExecutable includes database and runtime ports', () {
    test('redis requires 6379', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('redis-server');
      expect(sockets.any((s) => s.port == 6379), isTrue);
    });

    test('postgres requires 5432', () {
      final sockets = AppServiceManager.requiredSocketsForExecutable('postgres');
      expect(sockets.any((s) => s.port == 5432), isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/features/apps/service_manager_linux_dispatch_test.dart`
Expected: FAIL (`argumentsForExecutable` does not accept `isLinux`/`appId` and returns empty list for `apache2`/`php-fpm8.2`).

- [ ] **Step 3: Update `AppServiceManager` to support foreground execution and remove systemctl bypass**

1. In `lib/features/apps/data/app_service_manager.dart`:
   - Update `argumentsForExecutable`:
     ```dart
     @visibleForTesting
     static List<String> argumentsForExecutable(
       String fileName,
       String workingDir, {
       String? appId,
       String? installedVersion,
       bool? isLinux,
     }) {
       final name = normalizeExecutableName(fileName);
       final onLinux = isLinux ?? Platform.isLinux;

       if (name == 'caddy') {
         return [
           'run',
           '--config',
           p.join(workingDir, 'Caddyfile'),
           '--adapter',
           'caddyfile',
         ];
       }
       if (name == 'nginx') {
         final prefix = workingDir.replaceAll('\\', '/');
         final conf = p.join(workingDir, 'conf', 'nginx.conf').replaceAll('\\', '/');
         return ['-p', '$prefix/', '-c', conf];
       }
       if (onLinux && (name == 'apache2' || name == 'httpd')) {
         final conf = p.join(AppConfig.vhostsDir, 'apache', 'httpd.conf');
         return ['-DFOREGROUND', '-f', conf];
       }
       if (name == 'redis-server' || name == 'valkey-server') {
         final candidates = [
           p.join(AppConfig.dataDir, 'redis', 'redis.conf'),
           p.join(workingDir, 'valkey.conf'),
           p.join(workingDir, 'redis.conf'),
           p.join(workingDir, 'redis.windows.conf'),
         ];
         for (final confPath in candidates) {
           if (File(confPath).existsSync()) {
             return [confPath];
           }
         }
         return [p.join(AppConfig.dataDir, 'redis', 'redis.conf')];
       }
       if (name.startsWith('php-fpm')) {
         final targetAppId = appId ?? 'php82';
         final conf = p.join(AppConfig.baseDir, 'php', targetAppId, 'php-fpm.conf');
         return ['-F', '-y', conf];
       }
       if (name == 'postgres') {
         final ver = installedVersion ?? 'system';
         final targetId = appId ?? 'postgresql';
         final dataDir = p.join(AppConfig.dataDir, '$targetId-$ver');
         return ['-D', dataDir];
       }
       return <String>[];
     }
     ```

   - Update `requiredSocketsForExecutable`:
     ```dart
     @visibleForTesting
     static List<({String host, int port})> requiredSocketsForExecutable(
       String fileName, {
       String? appId,
     }) {
       final name = normalizeExecutableName(fileName);
       if (name == 'caddy' || name == 'nginx' || name == 'httpd' || name == 'apache' || name == 'apache2') {
         return [(host: '*', port: 80), (host: '*', port: 443)];
       }
       if (name == 'redis-server' || name == 'valkey-server') {
         return [(host: '127.0.0.1', port: 6379)];
       }
       if (name == 'postgres') {
         return [(host: '127.0.0.1', port: 5432)];
       }
       if (name.startsWith('php-fpm') && appId != null) {
         final port = AppInstallerService.phpPortFor(appId);
         return [(host: '127.0.0.1', port: port)];
       }
       return const [];
     }
     ```

   - In `start(AppModel app)`:
     - Remove the `if (app.installMethod == 'package_manager' && app.groupName == 'php')` block that called `_startPhpFpmViaSystemctl`.
     - Pass `appId: app.appId, installedVersion: app.installedVersion` to `argumentsForExecutable` and `requiredSocketsForExecutable`.
   - In `stop(AppModel app)`:
     - Remove the `if (app.installMethod == 'package_manager' && app.groupName == 'php')` block that called `_stopPhpFpmViaSystemctl`.
   - Remove `_startPhpFpmViaSystemctl`, `_stopPhpFpmViaSystemctl`, and `_isPhpFpmActiveViaSystemctl`.

2. Update `test/features/apps/systemctl_service_test.dart` to verify that PHP-FPM with `install_method: "package_manager"` now starts through standard process manager logic instead of calling systemctl.

- [ ] **Step 4: Run tests to verify they pass**

Run: `dart test test/features/apps/service_manager_linux_dispatch_test.dart test/features/apps/systemctl_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit service manager changes**

```bash
git add lib/features/apps/data/app_service_manager.dart test/features/apps/service_manager_linux_dispatch_test.dart test/features/apps/systemctl_service_test.dart
git commit -m "feat(service_manager): run linux apache, postgres, redis, and php-fpm in foreground mode"
```

---

### Task 5: End-to-End Regression & Test Suite Verification

**Files:**
- All existing tests in `test/`

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests PASS (0 failures).

- [ ] **Step 2: Run static analyzer**

Run: `dart analyze`
Expected: No analysis errors or warnings.

- [ ] **Step 3: Verify git status is clean and commit documentation**

```bash
git status
```
Expected: Clean working tree.
