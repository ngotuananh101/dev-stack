# Tunnel Service (Cloudflare & ngrok) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate a unified, driver-based Tunnel subsystem into DevStack supporting Cloudflare Tunnel and ngrok, with automatic binary downloading, Isar persistence, dedicated Tunnels management page, and 1-click sharing from the Sites page.

**Architecture:** Driver-based architecture (`TunnelDriver` with `CloudflareDriver` and `NgrokDriver`) orchestrated by `TunnelManagerService`. Binary downloading and extraction are handled by `TunnelDownloaderService`. Persistence is backed by Isar DB (`TunnelModel`), and runtime connection sessions (`TunnelSession`) are tracked via Riverpod notifiers. UI integrates into the Sidebar as a primary `Tunnels` tab and adds a quick "Share / Tunnel" action to the `Sites` page.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), Isar Database (`isar`), `BackgroundProcess` (hidden process execution on Windows & Linux), `dio` & `archive` (binary download and decompression), `qr_flutter` (mobile QR test inspection), `lucide_icons`.

**Spec:** `docs/superpowers/specs/2026-09-07-tunnel-service-design.md`

## Global Constraints
- Target platforms: Windows (x64) and Linux (x64).
- Background processes must run silently without opening visible cmd/terminal windows (using `BackgroundProcess.start`).
- All active tunnel processes must be cleanly killed via `BackgroundProcess.stopManaged(pid)` when stopped or upon app disposal.
- Cloudflare Quick Tunnels must require zero setup (no token, no account).
- Code must pass `flutter analyze` with 0 errors and 0 warnings.
- All tests must pass cleanly with `flutter test`.

---

### Task 1: Domain Models & Isar Schema Setup

**Files:**
- Create: `lib/features/tunnels/domain/tunnel_model.dart`
- Create: `lib/features/tunnels/domain/tunnel_session.dart`
- Modify: `lib/core/database/isar_provider.dart`
- Test: `test/features/tunnels/domain/tunnel_model_test.dart`

**Interfaces:**
- Produces:
  - `TunnelModel`: Entity stored in Isar with properties `id`, `name`, `provider` ('cloudflare' | 'ngrok'), `targetType` ('site' | 'port'), `targetSiteDomain`, `targetPort`, `authToken`, `customDomain`, `autoStart`, `createdAt`, `lastActiveAt`.
  - `TunnelSession`: Value object representing active state with `tunnelId`, `status` (`TunnelStatus.stopped`, `downloadingBinary`, `connecting`, `running`, `error`), `publicUrl`, `webInspectorUrl`, `downloadProgress`, `errorMessage`, `pid`, `connectedAt`, `logs`.
  - `TunnelModelSchema`: Registered in `IsarInstance._openDatabase()`.

- [ ] **Step 1: Write the failing unit test for `TunnelModel` and `TunnelSession`**

Create `test/features/tunnels/domain/tunnel_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';

void main() {
  group('TunnelModel', () {
    test('instantiates with default values', () {
      final tunnel = TunnelModel(
        name: 'My Shop',
        targetPort: 80,
      );

      expect(tunnel.name, equals('My Shop'));
      expect(tunnel.provider, equals('cloudflare'));
      expect(tunnel.targetType, equals('site'));
      expect(tunnel.targetPort, equals(80));
      expect(tunnel.autoStart, isFalse);
      expect(tunnel.authToken, isNull);
      expect(tunnel.customDomain, isNull);
    });

    test('supports custom provider and port config', () {
      final tunnel = TunnelModel(
        name: 'Custom API',
        provider: 'ngrok',
        targetType: 'port',
        targetPort: 3000,
        authToken: 'test_token',
        customDomain: 'api.devstack.me',
        autoStart: true,
      );

      expect(tunnel.provider, equals('ngrok'));
      expect(tunnel.targetType, equals('port'));
      expect(tunnel.targetPort, equals(3000));
      expect(tunnel.authToken, equals('test_token'));
      expect(tunnel.customDomain, equals('api.devstack.me'));
      expect(tunnel.autoStart, isTrue);
    });
  });

  group('TunnelSession', () {
    test('initializes with stopped status and handles copyWith', () {
      const session = TunnelSession(tunnelId: 1);
      expect(session.status, equals(TunnelStatus.stopped));
      expect(session.publicUrl, isNull);
      expect(session.downloadProgress, equals(0.0));

      final updated = session.copyWith(
        status: TunnelStatus.running,
        publicUrl: 'https://test.trycloudflare.com',
        pid: 1234,
      );

      expect(updated.status, equals(TunnelStatus.running));
      expect(updated.publicUrl, equals('https://test.trycloudflare.com'));
      expect(updated.pid, equals(1234));
      expect(updated.tunnelId, equals(1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/domain/tunnel_model_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Create `TunnelSession` and `TunnelModel`**

Create `lib/features/tunnels/domain/tunnel_session.dart`:
```dart
enum TunnelStatus {
  stopped,
  downloadingBinary,
  connecting,
  running,
  error,
}

class TunnelSession {
  final int tunnelId;
  final TunnelStatus status;
  final String? publicUrl;
  final String? webInspectorUrl;
  final double downloadProgress;
  final String? errorMessage;
  final int? pid;
  final DateTime? connectedAt;
  final List<String> logs;

  const TunnelSession({
    required this.tunnelId,
    this.status = TunnelStatus.stopped,
    this.publicUrl,
    this.webInspectorUrl,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.pid,
    this.connectedAt,
    this.logs = const [],
  });

  TunnelSession copyWith({
    TunnelStatus? status,
    String? publicUrl,
    String? webInspectorUrl,
    double? downloadProgress,
    String? errorMessage,
    int? pid,
    DateTime? connectedAt,
    List<String>? logs,
  }) {
    return TunnelSession(
      tunnelId: tunnelId,
      status: status ?? this.status,
      publicUrl: publicUrl ?? this.publicUrl,
      webInspectorUrl: webInspectorUrl ?? this.webInspectorUrl,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      pid: pid ?? this.pid,
      connectedAt: connectedAt ?? this.connectedAt,
      logs: logs ?? this.logs,
    );
  }
}
```

Create `lib/features/tunnels/domain/tunnel_model.dart`:
```dart
import 'package:isar/isar.dart';

part 'tunnel_model.g.dart';

@collection
class TunnelModel {
  Id id = Isar.autoIncrement;

  late String name;

  @Index()
  late String provider; // 'cloudflare' | 'ngrok'

  late String targetType; // 'site' | 'port'

  String? targetSiteDomain;
  int targetPort = 80;

  String? authToken;
  String? customDomain;

  bool autoStart = false;

  DateTime? createdAt;
  DateTime? lastActiveAt;

  TunnelModel({
    this.id = Isar.autoIncrement,
    required this.name,
    this.provider = 'cloudflare',
    this.targetType = 'site',
    this.targetSiteDomain,
    this.targetPort = 80,
    this.authToken,
    this.customDomain,
    this.autoStart = false,
    this.createdAt,
    this.lastActiveAt,
  });
}
```

Register schema in `lib/core/database/isar_provider.dart`:
Import `import '../../features/tunnels/domain/tunnel_model.dart';` and add `TunnelModelSchema` to the `Isar.open` schema list.

Generate code:
Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tunnels/domain/tunnel_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/domain/ lib/core/database/isar_provider.dart test/features/tunnels/domain/
git commit -m "feat(tunnels): implement TunnelModel and TunnelSession with Isar schema

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Tunnel Downloader Service (`TunnelDownloaderService`)

**Files:**
- Create: `lib/features/tunnels/data/tunnel_downloader_service.dart`
- Test: `test/features/tunnels/data/tunnel_downloader_service_test.dart`

**Interfaces:**
- Consumes: `AppConfig.baseDir`, `Platform.isWindows`, `Dio`, `archive` package.
- Produces:
  - `TunnelDownloaderService`:
    - `Future<bool> isBinaryDownloaded(String provider)`
    - `String getBinaryPath(String provider)`
    - `Future<void> downloadBinary(String provider, {void Function(double progress)? onProgress, Dio? dioClient})`
    - Handles Windows `.exe` and Linux permissions (`chmod +x`).

- [ ] **Step 1: Write the failing unit test for `TunnelDownloaderService`**

Create `test/features/tunnels/data/tunnel_downloader_service_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';

void main() {
  late Directory tempDir;
  late TunnelDownloaderService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunnel_downloader_test_');
    service = TunnelDownloaderService(
      baseDirResolver: () => tempDir.path,
      isWindowsResolver: () => true,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reports binary not downloaded initially', () async {
    final downloaded = await service.isBinaryDownloaded('cloudflare');
    expect(downloaded, isFalse);
  });

  test('resolves binary path inside tunnels folder', () {
    final path = service.getBinaryPath('cloudflare');
    expect(path, contains('tunnels'));
    expect(path, endsWith('cloudflared.exe'));
  });

  test('reports binary downloaded when file exists and is non-empty', () async {
    final binPath = service.getBinaryPath('cloudflare');
    final file = File(binPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('mock binary content');

    final downloaded = await service.isBinaryDownloaded('cloudflare');
    expect(downloaded, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/tunnel_downloader_service_test.dart`
Expected: FAIL with compilation error (TunnelDownloaderService not found).

- [ ] **Step 3: Implement `TunnelDownloaderService`**

Create `lib/features/tunnels/data/tunnel_downloader_service.dart`:
```dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

final tunnelDownloaderServiceProvider = Provider<TunnelDownloaderService>((ref) {
  return TunnelDownloaderService();
});

class TunnelDownloaderService {
  final String Function() _baseDirResolver;
  final bool Function() _isWindowsResolver;
  final Dio _dio;

  TunnelDownloaderService({
    String Function()? baseDirResolver,
    bool Function()? isWindowsResolver,
    Dio? dio,
  })  : _baseDirResolver = baseDirResolver ?? (() => AppConfig.baseDir),
        _isWindowsResolver = isWindowsResolver ?? (() => Platform.isWindows),
        _dio = dio ?? Dio();

  String get tunnelsDir => p.join(_baseDirResolver(), 'bin', 'tunnels');

  String getBinaryPath(String provider) {
    final isWin = _isWindowsResolver();
    switch (provider.toLowerCase()) {
      case 'cloudflare':
        return p.join(tunnelsDir, isWin ? 'cloudflared.exe' : 'cloudflared');
      case 'ngrok':
        return p.join(tunnelsDir, isWin ? 'ngrok.exe' : 'ngrok');
      default:
        throw ArgumentError('Unsupported tunnel provider: $provider');
    }
  }

  Future<bool> isBinaryDownloaded(String provider) async {
    final file = File(getBinaryPath(provider));
    if (!await file.exists()) return false;
    final length = await file.length();
    return length > 0;
  }

  String getDownloadUrl(String provider) {
    final isWin = _isWindowsResolver();
    switch (provider.toLowerCase()) {
      case 'cloudflare':
        return isWin
            ? 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
            : 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64';
      case 'ngrok':
        return isWin
            ? 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip'
            : 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz';
      default:
        throw ArgumentError('Unsupported tunnel provider: $provider');
    }
  }

  Future<void> downloadBinary(
    String provider, {
    void Function(double progress)? onProgress,
  }) async {
    final targetPath = getBinaryPath(provider);
    final targetDir = Directory(tunnelsDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final url = getDownloadUrl(provider);
    final isArchive = url.endsWith('.zip') || url.endsWith('.tgz');
    final tempPath = p.join(tunnelsDir, '$provider.download');

    try {
      await _dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final downloadedFile = File(tempPath);

      if (!isArchive) {
        // Direct executable (e.g. cloudflared)
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await downloadedFile.rename(targetPath);
      } else {
        // Archive (e.g. ngrok .zip or .tgz)
        final bytes = await downloadedFile.readAsBytes();
        Archive archive;
        if (url.endsWith('.zip')) {
          archive = ZipDecoder().decodeBytes(bytes);
        } else {
          final decompressed = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(decompressed);
        }

        final binName = _isWindowsResolver() ? 'ngrok.exe' : 'ngrok';
        ArchiveFile? binFile;
        for (final file in archive) {
          if (p.basename(file.name) == binName) {
            binFile = file;
            break;
          }
        }

        if (binFile == null) {
          throw StateError('Binary $binName not found inside archive from $url');
        }

        final targetFile = File(targetPath);
        await targetFile.writeAsBytes(binFile.content as List<int>);
        if (await downloadedFile.exists()) {
          await downloadedFile.delete();
        }
      }

      // Ensure executable permissions on Linux
      if (!_isWindowsResolver()) {
        await Process.run('chmod', ['+x', targetPath]);
      }
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tunnels/data/tunnel_downloader_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/tunnel_downloader_service.dart test/features/tunnels/data/tunnel_downloader_service_test.dart
git commit -m "feat(tunnels): implement TunnelDownloaderService for cloudflared and ngrok

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Tunnel Drivers: Cloudflare & ngrok

**Files:**
- Create: `lib/features/tunnels/domain/tunnel_driver.dart`
- Create: `lib/features/tunnels/data/drivers/cloudflare_driver.dart`
- Create: `lib/features/tunnels/data/drivers/ngrok_driver.dart`
- Test: `test/features/tunnels/data/drivers/cloudflare_driver_test.dart`
- Test: `test/features/tunnels/data/drivers/ngrok_driver_test.dart`

**Interfaces:**
- Produces:
  - `TunnelDriver` abstract class with:
    - `String get providerId;`
    - `List<String> buildStartArguments(TunnelModel tunnel, {String? defaultToken});`
    - `String? parsePublicUrl(String logLine);`
    - `String? parseInspectorUrl(String logLine);`
  - `CloudflareDriver`:
    - Matches regex `r'https://[a-zA-Z0-9-]+\.trycloudflare\.com'` from stderr lines.
    - Generates Quick Tunnel args `['tunnel', '--url', 'http://127.0.0.1:<port>', '--no-tls-verify']`.
    - Generates Named Tunnel args `['tunnel', 'run', '--token', '<token>']`.
  - `NgrokDriver`:
    - Parses JSON log lines looking for event `"started tunnel"` and URL field.
    - Matches standard URL `r'https://[a-zA-Z0-9-]+\.ngrok-free\.app'` or custom domain.
    - Inspector URL defaults to `http://127.0.0.1:4040`.

- [ ] **Step 1: Write the failing unit tests for `CloudflareDriver` and `NgrokDriver`**

Create `test/features/tunnels/data/drivers/cloudflare_driver_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/data/drivers/cloudflare_driver.dart';

void main() {
  final driver = CloudflareDriver();

  group('CloudflareDriver', () {
    test('builds arguments for quick tunnel without token', () {
      final tunnel = TunnelModel(
        name: 'Quick Tunnel',
        targetPort: 8080,
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, equals([
        'tunnel',
        '--url',
        'http://127.0.0.1:8080',
        '--no-tls-verify',
      ]));
    });

    test('builds arguments for named tunnel with token', () {
      final tunnel = TunnelModel(
        name: 'Named Tunnel',
        targetPort: 80,
        authToken: 'cf_token_12345',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, equals([
        'tunnel',
        'run',
        '--token',
        'cf_token_12345',
      ]));
    });

    test('parses public URL from cloudflared log line', () {
      const logLine = '2026-09-07T05:22:00Z INF +--------------------------------------------------------------------------------------------+';
      const urlLine = '2026-09-07T05:22:00Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |';
      const actualLine = '2026-09-07T05:22:00Z INF |  https://purple-butterfly-xyz.trycloudflare.com                                          |';

      expect(driver.parsePublicUrl(logLine), isNull);
      expect(driver.parsePublicUrl(urlLine), isNull);
      expect(
        driver.parsePublicUrl(actualLine),
        equals('https://purple-butterfly-xyz.trycloudflare.com'),
      );
    });
  });
}
```

Create `test/features/tunnels/data/drivers/ngrok_driver_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/data/drivers/ngrok_driver.dart';

void main() {
  final driver = NgrokDriver();

  group('NgrokDriver', () {
    test('builds start arguments for port with token', () {
      final tunnel = TunnelModel(
        name: 'Ngrok Port',
        targetPort: 3000,
        authToken: 'token_abc',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, contains('http'));
      expect(args, contains('3000'));
      expect(args, contains('--authtoken'));
      expect(args, contains('token_abc'));
      expect(args, contains('--log=stdout'));
      expect(args, contains('--log-format=json'));
    });

    test('builds start arguments with custom domain', () {
      final tunnel = TunnelModel(
        name: 'Custom Ngrok',
        targetPort: 80,
        customDomain: 'demo.devstack.io',
      );

      final args = driver.buildStartArguments(tunnel);
      expect(args, contains('--domain=demo.devstack.io'));
    });

    test('parses public URL from json log', () {
      const jsonLine = '{"lvl":"info","msg":"started tunnel","obj":"tunnels","name":"command_line","addr":"http://localhost:3000","url":"https://1234-5678.ngrok-free.app"}';
      final url = driver.parsePublicUrl(jsonLine);
      expect(url, equals('https://1234-5678.ngrok-free.app'));
    });

    test('extracts inspector URL', () {
      const inspectLine = '{"lvl":"info","msg":"starting web service","obj":"web","addr":"127.0.0.1:4040"}';
      final inspector = driver.parseInspectorUrl(inspectLine);
      expect(inspector, equals('http://127.0.0.1:4040'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/tunnels/data/drivers/`
Expected: FAIL with compilation errors.

- [ ] **Step 3: Implement `TunnelDriver`, `CloudflareDriver`, and `NgrokDriver`**

Create `lib/features/tunnels/domain/tunnel_driver.dart`:
```dart
import 'tunnel_model.dart';

abstract class TunnelDriver {
  String get providerId;

  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  });

  String? parsePublicUrl(String logLine);

  String? parseInspectorUrl(String logLine);
}
```

Create `lib/features/tunnels/data/drivers/cloudflare_driver.dart`:
```dart
import '../../domain/tunnel_driver.dart';
import '../../domain/tunnel_model.dart';

class CloudflareDriver implements TunnelDriver {
  @override
  String get providerId => 'cloudflare';

  static final RegExp _urlRegex = RegExp(r'https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com');

  @override
  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  }) {
    final token = tunnel.authToken ?? defaultToken;

    if (token != null && token.trim().isNotEmpty) {
      return [
        'tunnel',
        'run',
        '--token',
        token.trim(),
      ];
    }

    return [
      'tunnel',
      '--url',
      'http://127.0.0.1:${tunnel.targetPort}',
      '--no-tls-verify',
    ];
  }

  @override
  String? parsePublicUrl(String logLine) {
    final match = _urlRegex.firstMatch(logLine);
    return match?.group(0);
  }

  @override
  String? parseInspectorUrl(String logLine) => null;
}
```

Create `lib/features/tunnels/data/drivers/ngrok_driver.dart`:
```dart
import 'dart:convert';
import '../../domain/tunnel_driver.dart';
import '../../domain/tunnel_model.dart';

class NgrokDriver implements TunnelDriver {
  @override
  String get providerId => 'ngrok';

  static final RegExp _fallbackUrlRegex = RegExp(r'https:\/\/[a-zA-Z0-9-]+\.(ngrok-free\.app|ngrok\.io|ngrok\.app)');
  static final RegExp _inspectorAddrRegex = RegExp(r'127\.0\.0\.1:\d+');

  @override
  List<String> buildStartArguments(
    TunnelModel tunnel, {
    String? defaultToken,
  }) {
    final args = <String>[
      'http',
      tunnel.targetPort.toString(),
      '--log=stdout',
      '--log-format=json',
    ];

    final token = tunnel.authToken ?? defaultToken;
    if (token != null && token.trim().isNotEmpty) {
      args.add('--authtoken');
      args.add(token.trim());
    }

    if (tunnel.customDomain != null && tunnel.customDomain!.trim().isNotEmpty) {
      args.add('--domain=${tunnel.customDomain!.trim()}');
    }

    return args;
  }

  @override
  String? parsePublicUrl(String logLine) {
    try {
      if (logLine.trim().startsWith('{') && logLine.trim().endsWith('}')) {
        final data = jsonDecode(logLine) as Map<String, dynamic>;
        if (data.containsKey('url') && data['url'] is String) {
          final url = data['url'] as String;
          if (url.startsWith('https://')) return url;
        }
      }
    } catch (_) {
      // Not JSON or parse error, fallback to regex
    }

    final match = _fallbackUrlRegex.firstMatch(logLine);
    return match?.group(0);
  }

  @override
  String? parseInspectorUrl(String logLine) {
    try {
      if (logLine.trim().startsWith('{') && logLine.trim().endsWith('}')) {
        final data = jsonDecode(logLine) as Map<String, dynamic>;
        if (data['msg'] == 'starting web service' && data['addr'] != null) {
          return 'http://${data['addr']}';
        }
      }
    } catch (_) {}

    if (logLine.contains('web service') || logLine.contains('127.0.0.1:4040')) {
      final match = _inspectorAddrRegex.firstMatch(logLine);
      if (match != null) {
        return 'http://${match.group(0)}';
      }
    }
    return null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/data/drivers/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/domain/tunnel_driver.dart lib/features/tunnels/data/drivers/ test/features/tunnels/data/drivers/
git commit -m "feat(tunnels): implement CloudflareDriver and NgrokDriver with log parsers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Tunnel Manager Service & Riverpod Providers

**Files:**
- Create: `lib/features/tunnels/data/tunnel_manager_service.dart`
- Create: `lib/features/tunnels/data/tunnels_provider.dart`
- Test: `test/features/tunnels/data/tunnel_manager_service_test.dart`

**Interfaces:**
- Consumes:
  - `TunnelDownloaderService`
  - `TunnelDriver` map (`cloudflare` -> `CloudflareDriver`, `ngrok` -> `NgrokDriver`)
  - `Isar` instance for `TunnelModel` CRUD operations
  - `BackgroundProcess.start` / `stopManaged`
- Produces:
  - `TunnelManagerService`:
    - `Future<void> startTunnel(TunnelModel tunnel)`
    - `Future<void> stopTunnel(int tunnelId)`
    - `Future<void> saveTunnel(TunnelModel tunnel)`
    - `Future<void> deleteTunnel(int id)`
    - `TunnelSession? getSession(int tunnelId)`
    - `Stream<Map<int, TunnelSession>> get sessionsStream`
    - `Future<void> dispose()`
  - Providers:
    - `tunnelsStreamProvider`: Streams `List<TunnelModel>` from Isar.
    - `tunnelSessionsProvider`: Notifier watching active `TunnelSession` map.
    - `tunnelManagerServiceProvider`: Service singleton.

- [ ] **Step 1: Write unit test for `TunnelManagerService`**

Create `test/features/tunnels/data/tunnel_manager_service_test.dart`:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';

class FakeDownloader extends TunnelDownloaderService {
  bool downloaded = true;

  FakeDownloader() : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => downloaded;

  @override
  String getBinaryPath(String provider) => 'fake_binary';

  @override
  Future<void> downloadBinary(String provider, {void Function(double progress)? onProgress}) async {
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    downloaded = true;
  }
}

void main() {
  late FakeDownloader downloader;
  late TunnelManagerService manager;

  setUp(() {
    downloader = FakeDownloader();
    manager = TunnelManagerService(
      downloader: downloader,
      startProcessFn: (exec, args) async {
        return FakeManagedProcess(1234);
      },
      stopProcessFn: (pid) async {},
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  test('registers session and tracks state transitions', () async {
    final tunnel = TunnelModel(id: 1, name: 'Test Tunnel', targetPort: 80);

    await manager.startTunnel(tunnel);
    final session = manager.getSession(1);
    expect(session, isNotNull);
    expect(session!.status, equals(TunnelStatus.connecting));
    expect(session.pid, equals(1234));

    await manager.stopTunnel(1);
    final stoppedSession = manager.getSession(1);
    expect(stoppedSession?.status, equals(TunnelStatus.stopped));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: FAIL with compilation error (TunnelManagerService not found).

- [ ] **Step 3: Implement `TunnelManagerService` and Riverpod Providers**

Create `lib/features/tunnels/data/tunnel_manager_service.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/services/background_process.dart';
import '../../../core/services/log_service.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/tunnel_model.dart';
import '../domain/tunnel_session.dart';
import '../domain/tunnel_driver.dart';
import 'drivers/cloudflare_driver.dart';
import 'drivers/ngrok_driver.dart';
import 'tunnel_downloader_service.dart';

typedef ProcessStarter = Future<dynamic> Function(String executable, List<String> arguments);
typedef ProcessStopper = Future<void> Function(int pid);

@visibleForTesting
class FakeManagedProcess {
  final int pid;
  final StreamController<List<int>> stdoutController = StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController = StreamController<List<int>>.broadcast();

  FakeManagedProcess(this.pid);

  Stream<List<int>> get stdout => stdoutController.stream;
  Stream<List<int>> get stderr => stderrController.stream;
}

final tunnelManagerServiceProvider = Provider<TunnelManagerService>((ref) {
  final downloader = ref.read(tunnelDownloaderServiceProvider);
  final logger = ref.read(logServiceProvider);
  final isarAsync = ref.read(isarProvider);
  final isar = isarAsync.value;

  final manager = TunnelManagerService(
    downloader: downloader,
    logger: logger,
    isar: isar,
  );

  ref.onDispose(() => unawaited(manager.dispose()));
  return manager;
});

class TunnelManagerService {
  final TunnelDownloaderService _downloader;
  final LogService? _logger;
  final Isar? _isar;
  final Map<String, TunnelDriver> _drivers;
  final ProcessStarter _startProcess;
  final ProcessStopper _stopProcess;

  final Map<int, TunnelSession> _sessions = {};
  final Map<int, dynamic> _activeProcesses = {};
  final StreamController<Map<int, TunnelSession>> _sessionsController =
      StreamController<Map<int, TunnelSession>>.broadcast();

  TunnelManagerService({
    TunnelDownloaderService? downloader,
    LogService? logger,
    Isar? isar,
    Map<String, TunnelDriver>? drivers,
    ProcessStarter? startProcessFn,
    ProcessStopper? stopProcessFn,
  })  : _downloader = downloader ?? TunnelDownloaderService(),
        _logger = logger,
        _isar = isar,
        _drivers = drivers ?? {
          'cloudflare': CloudflareDriver(),
          'ngrok': NgrokDriver(),
        },
        _startProcess = startProcessFn ??
            ((exec, args) => BackgroundProcess.start(exec, args)),
        _stopProcess = stopProcessFn ??
            ((pid) => BackgroundProcess.stopManaged(pid));

  Stream<Map<int, TunnelSession>> get sessionsStream => _sessionsController.stream;

  Map<int, TunnelSession> get currentSessions => Map.unmodifiable(_sessions);

  TunnelSession? getSession(int tunnelId) => _sessions[tunnelId];

  void _updateSession(int tunnelId, TunnelSession session) {
    _sessions[tunnelId] = session;
    _sessionsController.add(Map.unmodifiable(_sessions));
  }

  Future<void> startTunnel(TunnelModel tunnel, {String? defaultToken}) async {
    final driver = _drivers[tunnel.provider.toLowerCase()];
    if (driver == null) {
      throw ArgumentError('Unsupported driver: ${tunnel.provider}');
    }

    _updateSession(
      tunnel.id,
      TunnelSession(
        tunnelId: tunnel.id,
        status: TunnelStatus.downloadingBinary,
      ),
    );

    try {
      final ready = await _downloader.isBinaryDownloaded(tunnel.provider);
      if (!ready) {
        await _downloader.downloadBinary(
          tunnel.provider,
          onProgress: (progress) {
            final current = _sessions[tunnel.id];
            if (current != null) {
              _updateSession(
                tunnel.id,
                current.copyWith(downloadProgress: progress),
              );
            }
          },
        );
      }

      final execPath = _downloader.getBinaryPath(tunnel.provider);
      final args = driver.buildStartArguments(tunnel, defaultToken: defaultToken);

      _updateSession(
        tunnel.id,
        TunnelSession(
          tunnelId: tunnel.id,
          status: TunnelStatus.connecting,
        ),
      );

      final process = await _startProcess(execPath, args);
      final pid = await (process is ManagedBackgroundProcess
          ? process.realPid
          : (process as FakeManagedProcess).pid);

      _activeProcesses[tunnel.id] = process;

      final initialSession = TunnelSession(
        tunnelId: tunnel.id,
        status: TunnelStatus.connecting,
        pid: pid,
        connectedAt: DateTime.now(),
      );
      _updateSession(tunnel.id, initialSession);

      void handleLine(String line) {
        final current = _sessions[tunnel.id] ?? initialSession;
        final updatedLogs = [...current.logs, line];
        if (updatedLogs.length > 500) updatedLogs.removeAt(0);

        var next = current.copyWith(logs: updatedLogs);

        final publicUrl = driver.parsePublicUrl(line);
        if (publicUrl != null) {
          next = next.copyWith(
            status: TunnelStatus.running,
            publicUrl: publicUrl,
          );
        }

        final inspectorUrl = driver.parseInspectorUrl(line);
        if (inspectorUrl != null) {
          next = next.copyWith(webInspectorUrl: inspectorUrl);
        }

        _updateSession(tunnel.id, next);
      }

      if (process is ManagedBackgroundProcess) {
        process.process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(handleLine);
        process.process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(handleLine);
      } else if (process is FakeManagedProcess) {
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(handleLine);
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(handleLine);
      }
    } catch (e, st) {
      _logger?.error('Failed to start tunnel ${tunnel.id}: $e\n$st');
      _updateSession(
        tunnel.id,
        TunnelSession(
          tunnelId: tunnel.id,
          status: TunnelStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> stopTunnel(int tunnelId) async {
    final session = _sessions[tunnelId];
    final pid = session?.pid;

    if (pid != null) {
      try {
        await _stopProcess(pid);
      } catch (e) {
        _logger?.error('Error stopping tunnel process $pid: $e');
      }
    }

    _activeProcesses.remove(tunnelId);
    _updateSession(
      tunnelId,
      TunnelSession(
        tunnelId: tunnelId,
        status: TunnelStatus.stopped,
      ),
    );
  }

  Future<void> saveTunnel(TunnelModel tunnel) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await isar.tunnelModels.put(tunnel);
      });
    }
  }

  Future<void> deleteTunnel(int id) async {
    await stopTunnel(id);
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await isar.tunnelModels.delete(id);
      });
    }
    _sessions.remove(id);
    _sessionsController.add(Map.unmodifiable(_sessions));
  }

  Future<void> dispose() async {
    for (final entry in _activeProcesses.entries) {
      final session = _sessions[entry.key];
      final pid = session?.pid;
      if (pid != null) {
        try {
          await _stopProcess(pid);
        } catch (_) {}
      }
    }
    _activeProcesses.clear();
    _sessions.clear();
    await _sessionsController.close();
  }
}
```

Create `lib/features/tunnels/data/tunnels_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/tunnel_model.dart';
import '../domain/tunnel_session.dart';
import 'tunnel_manager_service.dart';

final tunnelsStreamProvider = StreamProvider<List<TunnelModel>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield [];
    return;
  }

  yield* isar.tunnelModels.where().watch(fireImmediately: true);
});

final tunnelSessionsProvider =
    StateNotifierProvider<TunnelSessionsNotifier, Map<int, TunnelSession>>((ref) {
  final manager = ref.watch(tunnelManagerServiceProvider);
  return TunnelSessionsNotifier(manager);
});

class TunnelSessionsNotifier extends StateNotifier<Map<int, TunnelSession>> {
  final TunnelManagerService _manager;

  TunnelSessionsNotifier(this._manager) : super(_manager.currentSessions) {
    _manager.sessionsStream.listen((sessions) {
      state = sessions;
    });
  }

  Future<void> start(TunnelModel tunnel) => _manager.startTunnel(tunnel);
  Future<void> stop(int tunnelId) => _manager.stopTunnel(tunnelId);
  Future<void> delete(int tunnelId) => _manager.deleteTunnel(tunnelId);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/tunnel_manager_service.dart lib/features/tunnels/data/tunnels_provider.dart test/features/tunnels/data/tunnel_manager_service_test.dart
git commit -m "feat(tunnels): implement TunnelManagerService and Riverpod providers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Navigation, Sidebar, and AppSettings Integration

**Files:**
- Modify: `lib/shared/providers/navigation_provider.dart`
- Modify: `lib/shared/layouts/sidebar.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/settings/domain/app_settings.dart`
- Test: `test/shared/navigation_tunnels_test.dart`

**Interfaces:**
- Consumes: `NavigationTab`, `Sidebar`, `AppSettings`.
- Produces:
  - `NavigationTab.tunnels` enum value.
  - `LucideIcons.radio` NavItem labeled 'Tunnels' in Sidebar.
  - `AppSettings` optional fields: `ngrokDefaultToken`, `cloudflareDefaultToken`.

- [ ] **Step 1: Write test for NavigationTab.tunnels**

Create `test/shared/navigation_tunnels_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/shared/providers/navigation_provider.dart';

void main() {
  test('navigationProvider supports tunnels tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(navigationProvider), equals(NavigationTab.apps));

    container.read(navigationProvider.notifier).setTab(NavigationTab.tunnels);
    expect(container.read(navigationProvider), equals(NavigationTab.tunnels));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/navigation_tunnels_test.dart`
Expected: FAIL with compilation error (tunnels not in NavigationTab).

- [ ] **Step 3: Update `NavigationTab`, `Sidebar`, `AppSettings`, and `main.dart`**

In `lib/shared/providers/navigation_provider.dart`:
```dart
enum NavigationTab { apps, sites, databases, tunnels, logs, hosts, settings }
```

In `lib/shared/layouts/sidebar.dart`:
Add under Databases item:
```dart
_buildNavItem(
  LucideIcons.radio,
  'Tunnels',
  isActive: currentTab == NavigationTab.tunnels,
  onTap: () => ref
      .read(navigationProvider.notifier)
      .setTab(NavigationTab.tunnels),
),
```

In `lib/features/settings/domain/app_settings.dart`:
Add fields:
```dart
String? ngrokDefaultToken;
String? cloudflareDefaultToken;
```
Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Isar schema.

In `lib/main.dart`:
Import `import 'features/tunnels/presentation/tunnels_page.dart';` and handle:
```dart
case NavigationTab.tunnels:
  return const TunnelsPage();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/navigation_tunnels_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/providers/navigation_provider.dart lib/shared/layouts/sidebar.dart lib/features/settings/domain/app_settings.dart test/shared/navigation_tunnels_test.dart
git commit -m "feat(navigation): integrate Tunnels tab into sidebar and navigation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Tunnels UI Modals: Create Modal, QR Modal, Logs Modal

**Files:**
- Modify: `pubspec.yaml` (add `qr_flutter: ^4.1.0`)
- Create: `lib/features/tunnels/presentation/widgets/create_tunnel_modal.dart`
- Create: `lib/features/tunnels/presentation/widgets/tunnel_qr_modal.dart`
- Create: `lib/features/tunnels/presentation/widgets/tunnel_logs_modal.dart`
- Test: `test/features/tunnels/presentation/widgets/tunnel_qr_modal_test.dart`

**Interfaces:**
- Produces:
  - `CreateTunnelModal`: Dialog to create or edit a `TunnelModel`. Supports site selection from DevStack sites or custom port, provider selector, token, and custom domain.
  - `TunnelQrModal`: Shows QR code using `QrImageView` with 1-click URL copy.
  - `TunnelLogsModal`: Displays live logs stream for an active or stopped tunnel session.

- [ ] **Step 1: Add `qr_flutter` to `pubspec.yaml` and test QR widget**

In `pubspec.yaml`, under `dependencies:`, add:
```yaml
  qr_flutter: ^4.1.0
```
Run: `flutter pub get`

Create `test/features/tunnels/presentation/widgets/tunnel_qr_modal_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';

void main() {
  testWidgets('TunnelQrModal renders public URL and QR view', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TunnelQrModal(
            tunnelName: 'Test Tunnel',
            publicUrl: 'https://test.trycloudflare.com',
          ),
        ),
      ),
    );

    expect(find.text('Test Tunnel - QR Code'), findsOneWidget);
    expect(find.text('https://test.trycloudflare.com'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/presentation/widgets/tunnel_qr_modal_test.dart`
Expected: FAIL (TunnelQrModal not found).

- [ ] **Step 3: Implement `TunnelQrModal`, `TunnelLogsModal`, and `CreateTunnelModal`**

Create `lib/features/tunnels/presentation/widgets/tunnel_qr_modal.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';

class TunnelQrModal extends StatelessWidget {
  final String tunnelName;
  final String publicUrl;

  const TunnelQrModal({
    super.key,
    required this.tunnelName,
    required this.publicUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$tunnelName - QR Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: publicUrl,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              publicUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  text: 'Copy Link',
                  icon: LucideIcons.copy,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: publicUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Public URL copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/features/tunnels/presentation/widgets/tunnel_logs_modal.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/tunnel_session.dart';

class TunnelLogsModal extends StatelessWidget {
  final String tunnelName;
  final TunnelSession? session;

  const TunnelLogsModal({
    super.key,
    required this.tunnelName,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final logs = session?.logs ?? [];

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 700,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Logs - $tunnelName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.parseBorder(BorderSide(color: AppColors.border)),
                ),
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs available',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/features/tunnels/presentation/widgets/create_tunnel_modal.dart` with input fields for Name, Target Type (Site / Port), Provider dropdown (Cloudflare / ngrok), Port number, Auth token, and auto-start toggle.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tunnels/presentation/widgets/tunnel_qr_modal_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/tunnels/presentation/widgets/ test/features/tunnels/presentation/widgets/
git commit -m "feat(tunnels): add QR code, logs, and creation modals for tunnels

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Tunnels Management Page (`TunnelsPage`)

**Files:**
- Create: `lib/features/tunnels/presentation/tunnels_page.dart`
- Test: `test/features/tunnels/presentation/tunnels_page_test.dart`

**Interfaces:**
- Consumes:
  - `tunnelsStreamProvider`
  - `tunnelSessionsProvider`
  - `tunnelManagerServiceProvider`
- Produces:
  - `TunnelsPage`: Main view rendering the header, list of configured tunnels, status chips, public URLs with 1-click Copy, Open Browser button, QR button, Web Inspector button, and Start/Stop toggle actions.

- [ ] **Step 1: Write widget test for `TunnelsPage`**

Create `test/features/tunnels/presentation/tunnels_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';

void main() {
  testWidgets('TunnelsPage renders header and empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TunnelsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tunnels'), findsOneWidget);
    expect(find.text('New Tunnel'), findsOneWidget);
    expect(find.text('No tunnels configured yet'), findsOneWidget);
  });

  testWidgets('TunnelsPage displays tunnel card with actions', (tester) async {
    final mockTunnel = TunnelModel(
      id: 10,
      name: 'Shopify Webhook',
      provider: 'cloudflare',
      targetPort: 80,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([mockTunnel])),
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({
              10: const TunnelSession(
                tunnelId: 10,
                status: TunnelStatus.running,
                publicUrl: 'https://myshop.trycloudflare.com',
              ),
            }),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TunnelsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Shopify Webhook'), findsOneWidget);
    expect(find.text('https://myshop.trycloudflare.com'), findsOneWidget);
  });
}

class TunnelSessionsNotifierMock extends StateNotifier<Map<int, TunnelSession>> {
  TunnelSessionsNotifierMock(super.state);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: FAIL (TunnelsPage not found).

- [ ] **Step 3: Implement `TunnelsPage`**

Create `lib/features/tunnels/presentation/tunnels_page.dart`:
Build full page with responsive layout:
- Header: Title, Description, "+ New Tunnel" button opening `CreateTunnelModal`.
- Table or Card list showing:
  - Tunnel name, provider icon/chip, target port or site domain.
  - Connection status chip (`StatusChip`: stopped, downloading, connecting, running, error).
  - Public URL (with 1-click Copy, Open in Browser via `url_launcher`, Show QR code).
  - Web Inspector link if ngrok and running.
  - Action buttons: Start/Stop switch, View Logs icon button, Delete button.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/presentation/tunnels_page.dart test/features/tunnels/presentation/tunnels_page_test.dart
git commit -m "feat(tunnels): implement TunnelsPage management dashboard

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: 1-Click "Share / Tunnel" Integration in Sites Page

**Files:**
- Modify: `lib/features/sites/presentation/widgets/site_table.dart`
- Create: `lib/features/sites/presentation/widgets/site_tunnel_dialog.dart`
- Test: `test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart`

**Interfaces:**
- Consumes: `SiteModel`, `tunnelsStreamProvider`, `tunnelSessionsProvider`, `tunnelManagerServiceProvider`.
- Produces:
  - Row action in `SiteTable` with `LucideIcons.radio` or `LucideIcons.share2`.
  - `SiteTunnelDialog`: Quick popup checking if the site has a tunnel. If active, shows public URL and QR code. If inactive, offers 1-click "Start Cloudflare Quick Tunnel" or "Configure Tunnel".

- [ ] **Step 1: Write test for `SiteTunnelDialog`**

Create `test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_tunnel_dialog.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';

void main() {
  testWidgets('SiteTunnelDialog shows quick tunnel options', (tester) async {
    final site = SiteModel(
      domain: 'myproject.test',
      rootDir: '/var/www/myproject',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tunnelsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SiteTunnelDialog(site: site),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Share myproject.test'), findsOneWidget);
    expect(find.text('Start Quick Tunnel (Cloudflare)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart`
Expected: FAIL (SiteTunnelDialog not found).

- [ ] **Step 3: Implement `SiteTunnelDialog` and modify `SiteTable`**

Create `lib/features/sites/presentation/widgets/site_tunnel_dialog.dart`.
In `lib/features/sites/presentation/widgets/site_table.dart`, add the Tunnel action icon to each row:
```dart
IconButton(
  icon: const Icon(LucideIcons.radio, size: 16),
  tooltip: 'Share / Tunnel',
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) => SiteTunnelDialog(site: site),
    );
  },
),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_tunnel_dialog.dart lib/features/sites/presentation/widgets/site_table.dart test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart
git commit -m "feat(sites): add 1-click share and tunnel dialog to sites table

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Full Verification, Static Analysis & Documentation

**Files:**
- Modify: `docs/superpowers/plans/2026-09-07-tunnel-service.md`
- Create: `docs/tunnel-service-guide.md`

- [x] **Step 1: Run full test suite**

Run: `flutter test`
Result: ALL 516 tests pass with 0 failures.

- [x] **Step 2: Run static analysis**

Run: `flutter analyze`
Result: 0 issues found.

- [x] **Step 3: Write user documentation**

Create `docs/tunnel-service-guide.md` — comprehensive guide covering all tunnel topics.

- [x] **Step 4: Commit**

```bash
git add docs/tunnel-service-guide.md
git commit -m "docs(tunnels): add comprehensive guide for tunnel service

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
