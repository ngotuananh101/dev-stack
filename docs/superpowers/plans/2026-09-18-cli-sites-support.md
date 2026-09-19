# CLI Sites Support (Node.js, Bun, Deno, Custom CLI Apps) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide full lifecycle management, reverse proxying with WebSocket/HMR support, and real-time live terminal logging for CLI web applications (Node.js, Bun, Deno, Custom) in DevStack.

**Architecture:** Extend `SiteModel` in Isar with CLI attributes (`command`, `port`, `autoStart`). Update webserver builders (Nginx, Apache, Caddy) to generate reverse proxy vhosts forwarding traffic to `127.0.0.1:$port` with WebSocket upgrade headers. Create `CliProcessManager` to manage background child processes with cross-platform process tree termination and in-memory circular log buffering with real-time stream broadcasting. Integrate controls into `SiteTable`, `AddSiteModal`, `EditSiteModal`, and introduce `SiteLogsModal`.

**Tech Stack:** Flutter / Dart, Riverpod, Isar Database, OS Process Management (`dart:io` Process/ProcessSignal, Linux `kill`, Windows `taskkill`), Nginx / Apache / Caddy reverse proxy configs, Lucide Icons (`lucide_icons_flutter`).

**Spec:** `docs/superpowers/specs/2026-09-18-cli-sites-support-design.md`

## Global Constraints

- Support four site types: `'php'`, `'static'`, `'proxy'`, `'cli'`.
- All CLI processes must be terminated cleanly on application exit (no orphan or zombie processes).
- Reverse proxy configs must support HTTP/1.1 and WebSocket upgrade headers for modern frontend dev servers (Next.js, Vite, Nuxt, HMR).
- Cross-platform process termination: `kill -9 -- -<pid>` on POSIX, `taskkill /F /T /PID <pid>` on Windows.
- Circular buffer capacity: 1,000 log lines per site in memory.
- UI styling must match existing `AppColors` and DevStack desktop design language.

---

### Task 1: SiteModel Schema & Isar Code Generation

**Files:**
- Modify: `lib/features/sites/domain/site_model.dart`
- Test: `test/features/sites/site_model_test.dart`

**Interfaces:**
- Consumes: Existing `SiteModel` fields (`id`, `domain`, `rootDir`, `siteType`, `useSsl`, etc.)
- Produces: `SiteModel` with new fields `command` (`String?`), `port` (`int?`), `autoStart` (`bool`, default `false`), and support for `siteType == 'cli'`.

- [ ] **Step 1: Write the failing unit test for SiteModel with CLI fields**

Create `test/features/sites/site_model_test.dart`:
```dart
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteModel CLI fields', () {
    test('instantiates SiteModel with CLI fields', () {
      final site = SiteModel(
        domain: 'myapp.test',
        rootDir: '/path/to/app',
        siteType: 'cli',
        command: 'npm run dev',
        port: 3000,
        autoStart: true,
        useSsl: true,
      );

      expect(site.domain, 'myapp.test');
      expect(site.rootDir, '/path/to/app');
      expect(site.siteType, 'cli');
      expect(site.command, 'npm run dev');
      expect(site.port, 3000);
      expect(site.autoStart, isTrue);
      expect(site.useSsl, isTrue);
    });

    test('default autoStart is false and command/port are nullable', () {
      final site = SiteModel(
        domain: 'static.test',
        rootDir: '/path/to/static',
        siteType: 'static',
      );

      expect(site.autoStart, isFalse);
      expect(site.command, isNull);
      expect(site.port, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/site_model_test.dart`
Expected: Compilation failure because `command`, `port`, and `autoStart` are not defined in `SiteModel`.

- [ ] **Step 3: Update `SiteModel` and regenerate Isar code**

Edit `lib/features/sites/domain/site_model.dart`:
```dart
import 'package:isar/isar.dart';

part 'site_model.g.dart';

@collection
class SiteModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String domain;

  late String rootDir;

  String siteType = 'php'; // 'php', 'static', 'proxy', 'cli'

  String? phpVersion;
  int? phpPort;
  String? proxyTarget;

  String? command;
  int? port;
  bool autoStart = false;

  bool useSsl = false;
  DateTime? createdAt;

  SiteModel({
    this.id = Isar.autoIncrement,
    required this.domain,
    required this.rootDir,
    this.siteType = 'php',
    this.phpVersion,
    this.phpPort,
    this.proxyTarget,
    this.command,
    this.port,
    this.autoStart = false,
    this.useSsl = false,
    this.createdAt,
  });
}
```

Run build runner:
`dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/site_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/domain/site_model.dart lib/features/sites/domain/site_model.g.dart test/features/sites/site_model_test.dart
git commit -m "feat(sites): add CLI attributes to SiteModel"
```

---

### Task 2: Webserver Reverse Proxy & WebSocket Configuration

**Files:**
- Modify: `lib/core/config/nginx_config_builder.dart:240-275`
- Modify: `lib/core/config/apache_config_builder.dart:210-230`
- Modify: `lib/core/config/caddy_config_builder.dart:100-135`
- Create: `test/features/sites/cli_site_config_test.dart`

**Interfaces:**
- Consumes: `siteType == 'cli'`, `port` (`int?`), `rootDir` (`String`), `domain` (`String`), `useSsl` (`bool`)
- Produces: Virtual host configs for Nginx, Apache, and Caddy proxying to `http://127.0.0.1:$port` with WebSocket upgrade headers (`$http_upgrade`, `Connection "upgrade"`).

- [ ] **Step 1: Write the failing tests for CLI webserver configurations**

Create `test/features/sites/cli_site_config_test.dart`:
```dart
import 'package:dev_stack/core/config/apache_config_builder.dart';
import 'package:dev_stack/core/config/caddy_config_builder.dart';
import 'package:dev_stack/core/config/nginx_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CLI Site Configuration Builders', () {
    test('Nginx siteConfig for CLI generates proxy_pass and WebSocket upgrade headers', () {
      final config = NginxConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        useSsl: false,
        cliPort: 3000,
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('proxy_pass http://127.0.0.1:3000;'));
      expect(config, contains('proxy_http_version 1.1;'));
      expect(config, contains(r'proxy_set_header Upgrade $http_upgrade;'));
      expect(config, contains('proxy_set_header Connection "upgrade";'));
      expect(config, contains(r'proxy_set_header Host $host;'));
      expect(config, contains(r'proxy_read_timeout 86400s;'));
    });

    test('Apache siteConfig for CLI generates WebSocket rewrite rule and ProxyPassReverse', () {
      final config = ApacheConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        useSsl: false,
        cliPort: 3000,
        accessLogPath: '/logs/access.log',
        errorLogPath: '/logs/error.log',
        allowLanAccess: false,
      );

      expect(config, contains('RewriteEngine On'));
      expect(config, contains('RewriteCond %{HTTP:Upgrade} =websocket [NC]'));
      expect(config, contains('RewriteRule /(.*) ws://127.0.0.1:3000/\$1 [P,L]'));
      expect(config, contains('RewriteCond %{HTTP:Upgrade} !=websocket [NC]'));
      expect(config, contains('RewriteRule /(.*) http://127.0.0.1:3000/\$1 [P,L]'));
      expect(config, contains('ProxyPassReverse / http://127.0.0.1:3000/'));
    });

    test('Caddy siteConfig for CLI generates reverse_proxy to 127.0.0.1:port', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'nodeapp.test',
        bindAddress: '127.0.0.1',
        rootDir: '/projects/nodeapp',
        siteType: 'cli',
        cliPort: 3000,
        useSsl: false,
        accessLogPath: '/logs/access.log',
      );

      expect(config, contains('reverse_proxy 127.0.0.1:3000'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/cli_site_config_test.dart`
Expected: FAIL because `cliPort` parameter does not exist on builder methods.

- [ ] **Step 3: Implement CLI configuration in Nginx, Apache, and Caddy builders**

1. In `lib/core/config/nginx_config_builder.dart`:
Add `int? cliPort` to `siteConfig`:
```dart
  static String siteConfig({
    required String domain,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    required String errorLogPath,
    required bool allowLanAccess,
    int? phpPort,
    String? proxyTarget,
    int? cliPort,
    String? certPath,
    String? keyPath,
  }) {
    // ...
    if (siteType != 'proxy' && siteType != 'cli') {
      config += '    root "$rootDirUnix";\n';
      config += '    index index.php index.html;\n';
    }
    // ...
    if (siteType == 'proxy') {
      config += '    location / {\n';
      config += '        proxy_pass $proxyTarget;\n';
      config += '        proxy_set_header Host \$host;\n';
      config += '        proxy_set_header X-Real-IP \$remote_addr;\n';
      config += '        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n';
      config += '        proxy_set_header X-Forwarded-Proto \$scheme;\n';
      config += '    }\n';
    } else if (siteType == 'cli') {
      config += '    location / {\n';
      config += '        proxy_pass http://127.0.0.1:$cliPort;\n';
      config += '        proxy_http_version 1.1;\n';
      config += '        proxy_set_header Upgrade \$http_upgrade;\n';
      config += '        proxy_set_header Connection "upgrade";\n';
      config += '        proxy_set_header Host \$host;\n';
      config += '        proxy_set_header X-Real-IP \$remote_addr;\n';
      config += '        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n';
      config += '        proxy_set_header X-Forwarded-Proto \$scheme;\n';
      config += '        proxy_read_timeout 86400s;\n';
      config += '        proxy_send_timeout 86400s;\n';
      config += '    }\n';
    } else {
      // PHP and Static location blocks...
    }
```

2. In `lib/core/config/apache_config_builder.dart`:
Add `int? cliPort` to `siteConfig`:
```dart
  static String siteConfig({
    required String domain,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    required String errorLogPath,
    required bool allowLanAccess,
    int? phpPort,
    String? proxyTarget,
    int? cliPort,
    String? certPath,
    String? keyPath,
  }) {
    // ...
    if (siteType != 'proxy' && siteType != 'cli') {
      config += '    DocumentRoot "$rootDirUnix"\n';
    }
    // ...
    if (siteType == 'proxy') {
      final target = proxyTarget ?? '';
      final safeTarget = target.endsWith('/') ? target : '$target/';
      config += '    ProxyPreserveHost On\n';
      config += '    ProxyPass / $safeTarget\n';
      config += '    ProxyPassReverse / $safeTarget\n';
    } else if (siteType == 'cli') {
      config += '    RewriteEngine On\n';
      config += '    RewriteCond %{HTTP:Upgrade} =websocket [NC]\n';
      config += '    RewriteRule /(.*) ws://127.0.0.1:$cliPort/\$1 [P,L]\n';
      config += '    RewriteCond %{HTTP:Upgrade} !=websocket [NC]\n';
      config += '    RewriteRule /(.*) http://127.0.0.1:$cliPort/\$1 [P,L]\n';
      config += '    ProxyPassReverse / http://127.0.0.1:$cliPort/\n';
    } else {
      // Directory options & PHP handlers...
    }
```

3. In `lib/core/config/caddy_config_builder.dart`:
Add `int? cliPort` to `siteConfig` and update allowed `siteType`:
```dart
  static String siteConfig({
    required String domain,
    required String bindAddress,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    int? phpPort,
    String? proxyTarget,
    int? cliPort,
    String? certPath,
    String? keyPath,
  }) {
    if (!const {'static', 'php', 'proxy', 'cli'}.contains(siteType)) {
      throw ArgumentError('Unsupported site type: $siteType');
    }
    if (siteType == 'cli' && (cliPort == null || cliPort <= 0)) {
      throw ArgumentError('CLI sites require a valid port');
    }
    // ...
    final handlers = switch (siteType) {
      'proxy' => '    reverse_proxy $proxyTarget',
      'cli' => '    reverse_proxy 127.0.0.1:$cliPort',
      'php' =>
        '''    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server''',
      _ =>
        '''    root * "${_path(rootDir)}"
    file_server''',
    };
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sites/cli_site_config_test.dart`
Run: `flutter test test/features/sites/proxy_site_config_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/nginx_config_builder.dart lib/core/config/apache_config_builder.dart lib/core/config/caddy_config_builder.dart test/features/sites/cli_site_config_test.dart
git commit -m "feat(webserver): add reverse proxy and WebSocket configs for CLI sites"
```

---

### Task 3: CliProcessManager Architecture & Implementation

**Files:**
- Create: `lib/features/sites/data/cli_process_manager.dart`
- Create: `test/features/sites/cli_process_manager_test.dart`

**Interfaces:**
- Consumes: `SiteModel` (or `siteId`, `domain`, `rootDir`, `command`, `port`)
- Produces:
  - `cliProcessManagerProvider` (Riverpod)
  - `startSite(SiteModel site)` -> `Future<bool>`
  - `stopSite(int siteId)` -> `Future<bool>`
  - `restartSite(SiteModel site)` -> `Future<bool>`
  - `isSiteRunning(int siteId)` -> `bool`
  - `getSitePid(int siteId)` -> `int?`
  - `getLogBuffer(int siteId)` -> `List<String>`
  - `getLogStream(int siteId)` -> `Stream<String>`
  - `clearLogs(int siteId)` -> `void`
  - `stopAll()` -> `Future<void>`
  - `statusStream` -> `Stream<int>` (notifies when site status changes)

- [ ] **Step 1: Write the failing tests for `CliProcessManager`**

Create `test/features/sites/cli_process_manager_test.dart`:
```dart
import 'dart:io';
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CliProcessManager', () {
    late CliProcessManager manager;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cli_test_');
      manager = CliProcessManager(logsDirectory: tempDir.path);
    });

    tearDown(() async {
      await manager.stopAll();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initial state has no running processes', () {
      expect(manager.isSiteRunning(1), isFalse);
      expect(manager.getSitePid(1), isNull);
      expect(manager.getLogBuffer(1), isEmpty);
    });

    test('startSite runs command and records stdout', () async {
      final site = SiteModel(
        id: 42,
        domain: 'test-app.test',
        rootDir: tempDir.path,
        siteType: 'cli',
        command: Platform.isWindows ? 'echo Hello CLI Test' : 'echo "Hello CLI Test"',
        port: 3000,
      );

      final started = await manager.startSite(site);
      expect(started, isTrue);

      // Wait a moment for output to flush
      await Future.delayed(const Duration(milliseconds: 300));

      final logs = manager.getLogBuffer(42);
      expect(logs.any((l) => l.contains('Hello CLI Test')), isTrue);
    });

    test('circular buffer caps at 1000 lines', () {
      final buffer = CircularLogBuffer(maxLines: 5);
      for (var i = 0; i < 10; i++) {
        buffer.add('Line $i');
      }

      final lines = buffer.lines;
      expect(lines.length, 5);
      expect(lines.first, 'Line 5');
      expect(lines.last, 'Line 9');
    });

    test('stopSite terminates process cleanly', () async {
      final site = SiteModel(
        id: 99,
        domain: 'sleeper.test',
        rootDir: tempDir.path,
        siteType: 'cli',
        command: Platform.isWindows ? 'ping 127.0.0.1 -n 10' : 'sleep 10',
        port: 8080,
      );

      await manager.startSite(site);
      expect(manager.isSiteRunning(99), isTrue);

      final stopped = await manager.stopSite(99);
      expect(stopped, isTrue);
      expect(manager.isSiteRunning(99), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/cli_process_manager_test.dart`
Expected: FAIL because `CliProcessManager` and `CircularLogBuffer` do not exist.

- [ ] **Step 3: Implement `CliProcessManager` and `CircularLogBuffer`**

Create `lib/features/sites/data/cli_process_manager.dart`:
```dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';
import '../../../core/services/log_service.dart';
import '../domain/site_model.dart';

class CircularLogBuffer {
  final int maxLines;
  final Queue<String> _queue = Queue<String>();

  CircularLogBuffer({this.maxLines = 1000});

  void add(String line) {
    if (_queue.length >= maxLines) {
      _queue.removeFirst();
    }
    _queue.addLast(line);
  }

  void clear() {
    _queue.clear();
  }

  List<String> get lines => _queue.toList();
}

class ManagedCliProcess {
  final int siteId;
  final String domain;
  final Process process;
  final CircularLogBuffer logBuffer;
  final StreamController<String> streamController;
  final IOSink? logFileSink;

  ManagedCliProcess({
    required this.siteId,
    required this.domain,
    required this.process,
    required this.logBuffer,
    required this.streamController,
    this.logFileSink,
  });
}

class CliProcessManager {
  final String? logsDirectory;
  final Map<int, ManagedCliProcess> _processes = {};
  final StreamController<int> _statusController = StreamController<int>.broadcast();

  CliProcessManager({this.logsDirectory});

  Stream<int> get statusStream => _statusController.stream;

  bool isSiteRunning(int siteId) => _processes.containsKey(siteId);

  int? getSitePid(int siteId) => _processes[siteId]?.process.pid;

  List<String> getLogBuffer(int siteId) => _processes[siteId]?.logBuffer.lines ?? [];

  Stream<String> getLogStream(int siteId) {
    final proc = _processes[siteId];
    if (proc != null) {
      return proc.streamController.stream;
    }
    return const Stream.empty();
  }

  void clearLogs(int siteId) {
    _processes[siteId]?.logBuffer.clear();
  }

  Map<String, String> _buildEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final pathSeparator = Platform.isWindows ? ';' : ':';
    final currentPath = env['PATH'] ?? '';

    // Append common tool directories if not present
    final extraPaths = <String>[];
    if (Platform.isLinux || Platform.isMacOS) {
      extraPaths.addAll([
        '$home/.nvm/versions/node/current/bin',
        '$home/.bun/bin',
        '$home/.deno/bin',
        '$home/.cargo/bin',
        '/usr/local/bin',
        '/usr/bin',
        '/bin',
      ]);
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      extraPaths.addAll([
        '$appData\\npm',
        '$localAppData\\Programs\\bun',
        '$home\\.deno\\bin',
      ]);
    }

    final validExtras = extraPaths.where((p) => Directory(p).existsSync()).toList();
    if (validExtras.isNotEmpty) {
      env['PATH'] = '${validExtras.join(pathSeparator)}$pathSeparator$currentPath';
    }

    return env;
  }

  Future<bool> startSite(SiteModel site) async {
    if (site.command == null || site.command!.trim().isEmpty) {
      throw ArgumentError('Site start command cannot be empty');
    }
    if (isSiteRunning(site.id)) {
      return true;
    }

    final workDir = Directory(site.rootDir);
    if (!workDir.existsSync()) {
      throw StateError('Root directory does not exist: ${site.rootDir}');
    }

    final logBase = logsDirectory ?? p.join(AppConfig.baseDir, 'logs');
    final siteLogDir = Directory(p.join(logBase, site.domain));
    if (!siteLogDir.existsSync()) {
      siteLogDir.createSync(recursive: true);
    }
    final logFile = File(p.join(siteLogDir.path, 'cli_app.log'));
    final sink = logFile.openWrite(mode: FileMode.append);

    final logBuffer = CircularLogBuffer();
    final streamController = StreamController<String>.broadcast();

    Process process;
    final env = _buildEnvironment();

    try {
      if (Platform.isWindows) {
        process = await Process.start(
          'cmd.exe',
          ['/c', site.command!],
          workingDirectory: site.rootDir,
          environment: env,
        );
      } else {
        process = await Process.start(
          '/bin/sh',
          ['-c', site.command!],
          workingDirectory: site.rootDir,
          environment: env,
        );
      }
    } catch (e) {
      sink.close();
      rethrow;
    }

    final managed = ManagedCliProcess(
      siteId: site.id,
      domain: site.domain,
      process: process,
      logBuffer: logBuffer,
      streamController: streamController,
      logFileSink: sink,
    );

    _processes[site.id] = managed;
    _statusController.add(site.id);

    void handleLine(String line) {
      logBuffer.add(line);
      if (!streamController.isClosed) {
        streamController.add(line);
      }
      sink.writeln('[${DateTime.now().toIso8601String()}] $line');
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((err) => handleLine('[ERROR] $err'));

    process.exitCode.then((code) {
      handleLine('[Process exited with code $code]');
      _cleanupSite(site.id);
      _statusController.add(site.id);
    });

    return true;
  }

  Future<bool> stopSite(int siteId) async {
    final managed = _processes[siteId];
    if (managed == null) return false;

    final pid = managed.process.pid;
    await _killProcessTree(pid);
    _cleanupSite(siteId);
    _statusController.add(siteId);
    return true;
  }

  Future<bool> restartSite(SiteModel site) async {
    if (isSiteRunning(site.id)) {
      await stopSite(site.id);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return startSite(site);
  }

  Future<void> _killProcessTree(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
      } else {
        // Kill process group
        try {
          await Process.run('kill', ['-TERM', '--', '-$pid']);
        } catch (_) {
          await Process.run('kill', ['-TERM', pid.toString()]);
        }
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await Process.run('kill', ['-9', '--', '-$pid']);
        } catch (_) {
          await Process.run('kill', ['-9', pid.toString()]);
        }
      }
    } catch (_) {
      // Fallback direct kill
    }
  }

  void _cleanupSite(int siteId) {
    final managed = _processes.remove(siteId);
    if (managed != null) {
      managed.logFileSink?.flush();
      managed.logFileSink?.close();
    }
  }

  Future<void> stopAll() async {
    final ids = _processes.keys.toList();
    for (final id in ids) {
      await stopSite(id);
    }
  }

  void dispose() {
    stopAll();
    _statusController.close();
  }
}

final cliProcessManagerProvider = Provider<CliProcessManager>((ref) {
  final manager = CliProcessManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sites/cli_process_manager_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/data/cli_process_manager.dart test/features/sites/cli_process_manager_test.dart
git commit -m "feat(sites): implement CliProcessManager with process tree killing and circular logs"
```

---

### Task 4: SitesProvider & Lifecycle Integration (Auto-start & App Shutdown)

**Files:**
- Modify: `lib/features/sites/data/sites_provider.dart`
- Modify: `lib/core/services/window_service.dart`
- Test: `test/features/sites/cli_sites_provider_test.dart`

**Interfaces:**
- Consumes: `CliProcessManager`, `SiteModel` with CLI fields
- Produces:
  - `addSite` and `updateSite` accepting `command`, `port`, `autoStart`
  - Vhost generation in `_generateVhostFiles` passing `cliPort` to Nginx, Apache, and Caddy builders
  - Auto-start CLI sites during `SitesNotifier.build()`
  - Cleanup running CLI process when site is deleted
  - Graceful stop of all CLI processes in `WindowService` on window close and quit

- [ ] **Step 1: Write the failing test for SitesProvider CLI validation and vhost generation**

Create `test/features/sites/cli_sites_provider_test.dart`:
```dart
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesProvider CLI Validation', () {
    test('validateCliPort throws on null or out of range ports', () {
      expect(() => validateCliPort(null), throwsArgumentError);
      expect(() => validateCliPort(0), throwsArgumentError);
      expect(() => validateCliPort(65536), throwsArgumentError);
      expect(() => validateCliPort(-1), throwsArgumentError);
      expect(validateCliPort(3000), 3000);
      expect(validateCliPort(8080), 8080);
    });

    test('validateCliCommand throws on empty or invalid commands', () {
      expect(() => validateCliCommand(''), throwsArgumentError);
      expect(() => validateCliCommand('   '), throwsArgumentError);
      expect(validateCliCommand('npm run dev'), 'npm run dev');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/cli_sites_provider_test.dart`
Expected: FAIL because `validateCliPort` and `validateCliCommand` are undefined.

- [ ] **Step 3: Implement validation, vhost generation, auto-start, and shutdown**

1. In `lib/features/sites/data/sites_provider.dart`:
Add top-level validators:
```dart
int validateCliPort(int? port) {
  if (port == null || port < 1 || port > 65535) {
    throw ArgumentError('Port must be an integer between 1 and 65535');
  }
  return port;
}

String validateCliCommand(String? command) {
  if (command == null || command.trim().isEmpty) {
    throw ArgumentError('Start command cannot be empty');
  }
  return command.trim();
}
```

Update `addSite` and `updateSite` signatures to accept `command`, `port`, `autoStart`:
```dart
  Future<void> addSite({
    required String domain,
    required String rootDir,
    String siteType = 'php',
    String? phpAppId,
    String? proxyTarget,
    String? command,
    int? port,
    bool autoStart = false,
    bool useSsl = false,
    bool restartWebserver = true,
  }) async {
    // ...
    if (siteType == 'cli') {
      validateCliCommand(command);
      validateCliPort(port);
      validateRootDir(rootDir);
    }
    // ...
    final site = SiteModel(
      domain: domain,
      rootDir: rootDir,
      siteType: siteType,
      phpVersion: phpVersion,
      phpPort: phpPort,
      proxyTarget: proxyTarget,
      command: command,
      port: port,
      autoStart: autoStart,
      useSsl: useSsl,
      createdAt: DateTime.now(),
    );
```

Update `_generateVhostFiles(SiteModel site)`:
```dart
    // In buildNginxServer:
    // pass cliPort: site.port to NginxConfigBuilder.siteConfig or inline location
    // In buildApacheServer:
    // pass cliPort: site.port to ApacheConfigBuilder.siteConfig or inline vhost
    // In Caddy vhost:
    final caddyConfig = CaddyConfigBuilder.siteConfig(
      domain: validateDomain(site.domain),
      bindAddress: WebserverBindPolicy.caddyBind(allowLanAccess: allowLanAccess),
      rootDir: rootDirUnix,
      siteType: site.siteType,
      phpPort: site.phpPort,
      proxyTarget: safeTarget,
      cliPort: site.port,
      useSsl: site.useSsl,
      certPath: certPath,
      keyPath: keyPath,
      accessLogPath: p.join(logsDir.path, 'caddy_access.log'),
    );
```

In `deleteSite`:
```dart
    if (site != null) {
      if (site.siteType == 'cli') {
        ref.read(cliProcessManagerProvider).stopSite(site.id);
      }
      // continue deletion...
```

In `SitesNotifier.build()`:
```dart
    // After loading sites from DB:
    Future.microtask(() {
      final cliManager = ref.read(cliProcessManagerProvider);
      for (final site in sites) {
        if (site.siteType == 'cli' && site.autoStart) {
          cliManager.startSite(site).catchError((e) {
            ref.read(logServiceProvider).error('Auto-start failed for ${site.domain}: $e');
            return false;
          });
        }
      }
    });
```

2. In `lib/core/services/window_service.dart`:
In `onTrayMenuItemClick` for `'quit_app'` and in `onWindowClose`:
```dart
    // Stop all CLI sites
    await ref.read(cliProcessManagerProvider).stopAll();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sites/cli_sites_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/data/sites_provider.dart lib/core/services/window_service.dart test/features/sites/cli_sites_provider_test.dart
git commit -m "feat(sites): wire CLI site lifecycle, validation, and auto-start"
```

---

### Task 5: SiteLogsModal Terminal Dialog

**Files:**
- Create: `lib/features/sites/presentation/widgets/site_logs_modal.dart`
- Create: `test/features/sites/presentation/widgets/site_logs_modal_test.dart`

**Interfaces:**
- Consumes: `SiteModel site`, `cliProcessManagerProvider`
- Produces: `SiteLogsModal` dialog with auto-scroll toggle, clear logs, copy logs, and open log file actions.

- [ ] **Step 1: Write the failing widget test for SiteLogsModal**

Create `test/features/sites/presentation/widgets/site_logs_modal_test.dart`:
```dart
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_logs_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SiteLogsModal displays site domain and action buttons', (tester) async {
    final site = SiteModel(
      id: 1,
      domain: 'my-cli-app.test',
      rootDir: '/test',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SiteLogsModal(site: site),
          ),
        ),
      ),
    );

    expect(find.text('Logs: my-cli-app.test'), findsOneWidget);
    expect(find.byIcon(Icons.clear_all), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/presentation/widgets/site_logs_modal_test.dart`
Expected: FAIL because `SiteLogsModal` does not exist.

- [ ] **Step 3: Implement `SiteLogsModal`**

Create `lib/features/sites/presentation/widgets/site_logs_modal.dart`:
```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/cli_process_manager.dart';
import '../../domain/site_model.dart';

class SiteLogsModal extends ConsumerStatefulWidget {
  final SiteModel site;

  const SiteLogsModal({super.key, required this.site});

  @override
  ConsumerState<SiteLogsModal> createState() => _SiteLogsModalState();
}

class _SiteLogsModalState extends ConsumerState<SiteLogsModal> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    final manager = ref.read(cliProcessManagerProvider);
    _lines.addAll(manager.getLogBuffer(widget.site.id));

    _subscription = manager.getLogStream(widget.site.id).listen((line) {
      if (!mounted) return;
      setState(() {
        _lines.add(line);
      });
      if (_autoScroll) {
        _scrollToBottom();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _clearLogs() {
    ref.read(cliProcessManagerProvider).clearLogs(widget.site.id);
    setState(() {
      _lines.clear();
    });
  }

  void _openLogFile() {
    final logFilePath = p.join(
      AppConfig.baseDir,
      'logs',
      widget.site.domain,
      'cli_app.log',
    );
    if (File(logFilePath).existsSync()) {
      if (Platform.isWindows) {
        Process.run('cmd.exe', ['/c', 'start', '', logFilePath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [logFilePath]);
      } else {
        Process.run('xdg-open', [logFilePath]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 900,
        height: 600,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildLogView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.terminal, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            'Logs: ${widget.site.domain}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _autoScroll ? LucideIcons.arrowDownCircle : LucideIcons.pauseCircle,
              size: 16,
              color: _autoScroll ? AppColors.success : AppColors.textMuted,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16, color: AppColors.textSecondary),
            tooltip: 'Clear',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            tooltip: 'Copy all',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
            tooltip: 'Open log file',
            onPressed: _openLogFile,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogView() {
    if (_lines.isEmpty) {
      return const Center(
        child: Text(
          'No logs yet. Start the CLI application to view output.',
          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        final isError = line.contains('[ERROR]') || line.contains('Error:');
        return SelectableText(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isError ? const Color(0xFFF48771) : const Color(0xFFCCCCCC),
            height: 1.4,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/presentation/widgets/site_logs_modal_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_logs_modal.dart test/features/sites/presentation/widgets/site_logs_modal_test.dart
git commit -m "feat(ui): add SiteLogsModal terminal log viewer"
```

---

### Task 6: AddSiteModal & EditSiteModal CLI Form & Presets

**Files:**
- Modify: `lib/features/sites/presentation/widgets/add_site_modal.dart`
- Modify: `lib/features/sites/presentation/widgets/edit_site_modal.dart`
- Create: `test/features/sites/presentation/widgets/cli_site_modal_test.dart`

**Interfaces:**
- Consumes: `SiteModel` with CLI fields, preset configurations
- Produces: CLI site type selection, preset autofill (Node npm, pnpm, yarn, Bun, Deno, Custom), command and port validation, and auto-start toggle.

- [ ] **Step 1: Write the failing widget test for AddSiteModal CLI selection**

Create `test/features/sites/presentation/widgets/cli_site_modal_test.dart`:
```dart
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddSiteModal shows CLI App type option and presets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsNotifierProvider.overrideWith((ref) => Stream.value(<AppModel>[])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddSiteModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLI App'), findsOneWidget);

    // Tap CLI App button
    await tester.tap(find.text('CLI App'));
    await tester.pumpAndSettle();

    expect(find.text('Start Command'), findsOneWidget);
    expect(find.text('Internal Port'), findsOneWidget);
    expect(find.text('Preset'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/presentation/widgets/cli_site_modal_test.dart`
Expected: FAIL because 'CLI App' button does not exist in `AddSiteModal`.

- [ ] **Step 3: Implement CLI Form and Presets in `AddSiteModal` and `EditSiteModal`**

1. In `AddSiteModal`:
- Add state variables:
```dart
  final _commandController = TextEditingController(text: 'npm run dev');
  final _portController = TextEditingController(text: '3000');
  String _selectedPreset = 'node_npm';
  bool _autoStart = false;
```
- Preset definitions:
```dart
  final Map<String, ({String name, String command, int port})> _cliPresets = {
    'node_npm': (name: 'Node.js (npm)', command: 'npm run dev', port: 3000),
    'node_pnpm': (name: 'Node.js (pnpm)', command: 'pnpm dev', port: 3000),
    'node_yarn': (name: 'Node.js (yarn)', command: 'yarn dev', port: 3000),
    'bun': (name: 'Bun', command: 'bun dev', port: 3000),
    'deno': (name: 'Deno', command: 'deno task dev', port: 8000),
    'custom': (name: 'Custom', command: '', port: 3000),
  };
```
- Add `'CLI App'` to the `Site Type` row with `LucideIcons.terminal`.
- Add the CLI options block (preset dropdown, command field, port field, autoStart switch).
- Pass `command`, `port: int.tryParse(_portController.text.trim())`, `autoStart: _autoStart` to `addSite` or `updateSite`.

2. In `EditSiteModal`:
- Add CLI tab support and inputs for `command`, `port`, and `autoStart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/presentation/widgets/cli_site_modal_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/add_site_modal.dart lib/features/sites/presentation/widgets/edit_site_modal.dart test/features/sites/presentation/widgets/cli_site_modal_test.dart
git commit -m "feat(ui): add CLI presets, command, and port inputs in site modals"
```

---

### Task 7: SiteTable CLI Status & Action Buttons

**Files:**
- Modify: `lib/features/sites/presentation/widgets/site_table.dart`
- Create: `test/features/sites/presentation/widgets/site_table_cli_test.dart`

**Interfaces:**
- Consumes: `SiteModel` with `siteType == 'cli'`, `cliProcessManagerProvider`
- Produces:
  - TYPE column: `CLI :<port>` badge
  - PATH column: displays `rootDir` and `command` tooltip
  - OPERATE column: Start/Stop toggle button, Restart button, View Logs button

- [ ] **Step 1: Write the failing widget test for SiteTable CLI rendering**

Create `test/features/sites/presentation/widgets/site_table_cli_test.dart`:
```dart
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SiteTable renders CLI badge and action buttons', (tester) async {
    final site = SiteModel(
      id: 12,
      domain: 'myapp.test',
      rootDir: '/my/project',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SiteTable(
              sites: [site],
              selectedIds: const {},
              onEdit: (_) {},
              onToggleSelection: (_) {},
              onToggleAll: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('CLI :3000'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/presentation/widgets/site_table_cli_test.dart`
Expected: FAIL because `CLI :3000` is not rendered.

- [ ] **Step 3: Update `SiteTable` to support CLI sites**

In `lib/features/sites/presentation/widgets/site_table.dart`:
1. In the `TYPE` column:
```dart
SizedBox(
  width: 100,
  child: site.siteType == 'cli'
      ? Row(
          children: [
            const Icon(LucideIcons.terminal, size: 12, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              'CLI :${site.port ?? 3000}',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
      : Text(
          site.siteType == 'php'
              ? 'PHP ${site.phpVersion}'
              : site.siteType.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
)
```

2. In the `OPERATE` column:
When `site.siteType == 'cli'`:
- Read `cliProcessManagerProvider`.
- Check `final isRunning = cliManager.isSiteRunning(site.id);`
- Show:
  - Play / Stop button (`isRunning ? LucideIcons.square : LucideIcons.play`) with color `isRunning ? AppColors.error : AppColors.success`.
  - Restart button (`LucideIcons.rotateCw`, enabled only when running).
  - Logs button (`LucideIcons.scrollText`) opening `SiteLogsModal`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/presentation/widgets/site_table_cli_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_table.dart test/features/sites/presentation/widgets/site_table_cli_test.dart
git commit -m "feat(ui): add CLI status badge and action controls in SiteTable"
```

---

### Task 8: Full End-to-End Regression & Verification

**Files:**
- Verify all unit and widget tests across the repository.

- [ ] **Step 1: Run complete flutter test suite**

Run: `flutter test`
Expected: 100% tests passing.

- [ ] **Step 2: Verify Linux compilation dry-run**

Run: `PKG_CONFIG_PATH="/tmp/ayatana/root/usr/lib64/pkgconfig:${PKG_CONFIG_PATH}" flutter build linux --debug`
Expected: Build finishes successfully without warnings or compilation errors.

- [ ] **Step 3: Final commit**

```bash
git commit --allow-empty -m "chore(release): complete CLI sites support verification"
```
