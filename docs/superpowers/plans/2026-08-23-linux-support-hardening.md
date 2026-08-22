# Linux Support Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all defects found by the independent re-verification of Linux support: OS-aware catalog URL, unusable source-tarball catalog entries, `.exe`-hardcoded service dispatch, Windows-only DB-init/mkcert/systeminfo commands, and Windows-only Composer/pyenv post-install hooks.

**Architecture:** Normalize executable filenames once (strip `.exe`/`.bat`/`.cmd`) so Linux ELF names and Windows names share one dispatch table; make every remaining Windows-only subprocess (`systeminfo`, `netstat`, `mkcert`, DB init tools) branch on `Platform.isLinux` with a tested equivalent; add two new installer archive handlers (Zonky PG jar, raw Linux binary); replace bad catalog entries with verified prebuilt binaries.

**Tech Stack:** Dart 3.10+, Flutter Desktop, Riverpod, system `tar`/`ss`/`chmod`, Zonky embedded-postgres-binaries (Maven Central), mkcert v1.4.4 multi-arch assets (already added by user in `assets/bin/`).

## Global Constraints

- Preserve 100% backward compatibility on Windows — every change is additive OS branching; all 253 tests stay green.
- No placeholders: every catalog URL must be verified reachable (HTTP 200) before commit; if a listed URL 404s, substitute the nearest existing version and record the substitution.
- Catalog policy (user decision): PostgreSQL uses Zonky embedded binaries; **Nginx, Apache, Redis entries are removed** from `apps-linux.json` until trustworthy prebuilt Linux sources exist.
- All path concatenations use `p.join(...)`; generated configs use forward slashes.
- Prerequisite (manual, outside git): publish `apps-linux.json` to the catalog gist `https://gist.githubusercontent.com/ngotuananh101/d2e69956bc2030b0bcf27707aef9e9cd/raw/` as a second file named exactly `apps-linux.json`, so Task 1's URL resolves. Until then Linux auto-update safely no-ops (404 → catch-and-log).
- Do NOT modify Windows behavior of `mkcert.exe` resolution — Windows keeps its existing three-tier lookup untouched.

---

### Task 1: OS-Aware Remote Catalog URL

**Files:**
- Modify: `lib/features/apps/data/apps_provider.dart:32-33` (and any other `catalogUrl` reference)
- Test: `test/features/apps/catalog_url_test.dart`

**Interfaces:**
- Consumes: `AppsRepository.catalogFileNameFor({required bool isLinux})` (exists, returns `'apps-linux.json'` / `'apps.json'`).
- Produces: `AppsNotifier.catalogUrl` becomes `static String get catalogUrl` returning the gist raw URL whose filename matches the current platform.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/apps/catalog_url_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/data/apps_repository.dart';

void main() {
  group('OS-aware catalog URL', () {
    test('filename segment matches catalogFileNameFor', () {
      final expected =
          AppsRepository.catalogFileNameFor(isLinux: Platform.isLinux);
      expect(AppsNotifier.catalogUrl, endsWith('/$expected'));
    });

    test('points at the shared gist raw base', () {
      expect(
        AppsNotifier.catalogUrl,
        startsWith(
          'https://gist.githubusercontent.com/ngotuananh101/'
          'd2e69956bc2030b0bcf27707aef9e9cd/raw/',
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/catalog_url_test.dart`
Expected: FAIL — `catalogUrl` is a `const` ending in `/apps.json`; on the Linux assertion branch it mismatches (and `endsWith('/apps.json')` vs `'/apps-linux.json'` fails the first test's expectation on any host because the test compares against the platform-correct name while the constant is fixed).

- [ ] **Step 3: Implement**

In `lib/features/apps/data/apps_provider.dart` replace lines 32-33:

```dart
  /// Remote catalog source, refreshed via [updateCatalog] / the manual
  /// "Update list" button and on app startup when online. The filename
  /// segment always matches the OS-specific catalog file, so a Linux
  /// auto-update can never overwrite apps-linux.json with Windows data.
  static const String _catalogBaseUrl =
      'https://gist.githubusercontent.com/ngotuananh101/'
      'd2e69956bc2030b0bcf27707aef9e9cd/raw';

  static String get catalogUrl =>
      '$_catalogBaseUrl/${AppsRepository.catalogFileNameFor(isLinux: Platform.isLinux)}';
```

(`dart:io` is already imported in apps_provider.dart — no import change needed.) Update `autoUpdateCatalog()` (line ~488): it already calls `repository.updateAppListFromUrl(catalogUrl)` — unchanged, now platform-correct. Check `updateCatalog(url)` callers in `lib/features/apps/presentation/apps_page.dart` pass `AppsNotifier.catalogUrl` (a getter read is identical syntax).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/catalog_url_test.dart test/assets/linux_catalog_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/apps_provider.dart test/features/apps/catalog_url_test.dart
git commit -m "fix: derive remote catalog URL from OS-specific catalog filename"
```

---

### Task 2: Repair Linux Catalog Entries (PG→Zonky, drop source-only apps, fix PHP)

**Files:**
- Modify: `assets/data/apps-linux.json`
- Modify: `test/assets/linux_catalog_test.dart`

**Interfaces:**
- Produces: catalog entries consumed by Tasks 3-5: `postgresql` versions point at Zonky `.jar` URLs on `repo1.maven.org`; `php82..php85` `exec_file` becomes `"php"`; `nginx`, `apache`, `redis` keys are gone.

- [ ] **Step 1: Verify candidate URLs are live (do this BEFORE editing the catalog)**

> ✅ PRE-VERIFIED 2026-08-23 by planner via `curl -sI`: BOTH URLs return
> HTTP 200 (`application/java-archive`). The implementer may skip re-checking
> and use them verbatim.

Use WebFetch (or `curl -sI`) on each; require HTTP 200:
- `https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/17.2.0/embedded-postgres-binaries-linux-amd64-17.2.0.jar`
- `https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/16.6.0/embedded-postgres-binaries-linux-amd64-16.6.0.jar`

If a URL 404s, query the Maven directory listing (`https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/` via WebFetch: "list available version directories") and substitute the closest lower existing version; record the substitution in the commit message.

- [ ] **Step 2: Write the failing test additions**

In `test/assets/linux_catalog_test.dart`: first add a loader helper inside `main()` (before the existing groups), because the existing `apps` variable is local to the second test:

```dart
    Future<List<Map<String, dynamic>>> loadApps() async {
      final raw = await File('assets/data/apps-linux.json').readAsString();
      return ((jsonDecode(raw) as Map<String, dynamic>)['apps'] as List)
          .cast<Map<String, dynamic>>();
    }
```

Then add these tests inside the existing group:

```dart
    test('linux catalog excludes source-only apps pending prebuilt sources',
        () async {
      final apps = await loadApps();
      final ids = apps.map((a) => a['id'] as String).toSet();
      expect(ids, isNot(contains('nginx')));
      expect(ids, isNot(contains('apache')));
      expect(ids, isNot(contains('redis')));
    });

    test('postgresql points at Zonky prebuilt jars on Maven Central', () async {
      final apps = await loadApps();
      final pg = apps.firstWhere((a) => a['id'] == 'postgresql');
      final versions = pg['versions'] as Map<String, dynamic>;
      expect(versions, isNotEmpty);
      for (final url in versions.values) {
        expect(url, startsWith('https://repo1.maven.org/maven2/'));
        expect(url, contains('embedded-postgres-binaries-linux-amd64'));
        expect(url, endsWith('.jar'));
      }
    });

    test('static-php entries expose the CLI binary as exec_file', () async {
      final apps = await loadApps();
      final phpApps =
          apps.where((a) => (a['id'] as String).startsWith('php'));
      expect(phpApps, isNotEmpty);
      for (final app in phpApps) {
        expect(app['exec_file'], equals('php'),
            reason: '${app['id']} ships the static-php-cli CLI binary');
        expect(app['cli_file'], equals('php'));
      }
    });
```

Adjust the existing "essential apps" test (`test/assets/linux_catalog_test.dart:27-34`): delete `'nginx'` and `'redis'` from the `essentialIds` list (apache is not listed there) — keep `nodejs`, `caddy`, `mysql`, `pyenv`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/assets/linux_catalog_test.dart`
Expected: FAIL (entries still present / wrong URLs / php exec_file mismatch)

- [ ] **Step 4: Edit `assets/data/apps-linux.json`**

1. Delete the three whole objects with `"id": "nginx"`, `"id": "apache"`, `"id": "redis"`.
2. Replace the `postgresql` object's versions (keep id/name/description/category/group_name/exec_file `postgres`/cli_file `psql`) with the verified URLs from Step 1:

```json
      "versions": {
        "17.2": "https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/17.2.0/embedded-postgres-binaries-linux-amd64-17.2.0.jar",
        "16.6": "https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/16.6.0/embedded-postgres-binaries-linux-amd64-16.6.0.jar"
      }
```

(use the actually-verified URLs; bump the version key if you substituted, e.g. `"16.4": "...16.4.0.jar"`)

3. In each of `php85`, `php84`, `php83`, `php82`: change `"exec_file": "php-fpm"` → `"exec_file": "php"`. These static-php-cli archives contain only the CLI `php` binary; the CLI drives the same `-S host:port` built-in-server path the Windows `php.exe` branch already uses (enabled by Task 4's normalization).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/assets/linux_catalog_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add assets/data/apps-linux.json test/assets/linux_catalog_test.dart
git commit -m "fix(linux-catalog): Zonky PG binaries, drop source-only nginx/apache/redis, correct PHP exec_file"
```

---

### Task 3: Installer — Zonky jar extraction + raw Linux binary handling

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (archive-type section at lines ~142-228)
- Test: `test/features/apps/installer_linux_zonky_test.dart`

**Interfaces:**
- Consumes: existing `_extractZip(bytes, path, onLog)`, `buildTarExtractArgs(archive, dest, {bool stripComponents = true})`, `ensureLinuxPermissions(path, logInfo:)`, `_flattenDirectory`, `_detectFiles`.
- Produces: `@visibleForTesting static bool isZonkyPgJar(String urlOrPath)`; `@visibleForTesting static Future<void> extractZonkyJar(...)`-equivalent private method invoked from `install()`; raw-binary branch for extension-less downloads on Linux.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/apps/installer_linux_zonky_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('Zonky PostgreSQL jar detection', () {
    test('recognizes embedded-postgres-binaries jars', () {
      expect(
        AppInstallerService.isZonkyPgJar(
          'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
          'embedded-postgres-binaries-linux-amd64/17.2.0/'
          'embedded-postgres-binaries-linux-amd64-17.2.0.jar',
        ),
        isTrue,
      );
    });

    test('rejects unrelated jars, zips and tarballs', () {
      expect(AppInstallerService.isZonkyPgJar('https://example.com/app.jar'),
          isFalse);
      expect(AppInstallerService.isZonkyPgJar('https://example.com/x.zip'),
          isFalse);
      expect(AppInstallerService.isZonkyPgJar('https://example.com/x.tar.gz'),
          isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/apps/installer_linux_zonky_test.dart`
Expected: FAIL — `isZonkyPgJar` undefined.

- [ ] **Step 3: Implement detection + extraction + raw-binary branch**

Add near `isTarArchive`:

```dart
  /// True when [urlOrPath] is a Zonky embedded-postgres-binaries jar: a zip
  /// wrapper whose payload is a single `.txz` holding the actual PG install.
  @visibleForTesting
  static bool isZonkyPgJar(String urlOrPath) {
    final lower = urlOrPath.toLowerCase();
    return lower.endsWith('.jar') && lower.contains('embedded-postgres-binaries');
  }
```

Private extraction (place beside `_extractZip`):

```dart
  /// Extracts a Zonky PG jar: unzip to a scratch dir, then `tar -xf` the
  /// inner `.txz` (which has NO wrapping top-level folder) into [installPath].
  Future<void> _extractZonkyJar(
    File jarFile,
    String installPath,
    void Function(String)? onLog,
  ) async {
    final scratch = await Directory.systemTemp.createTemp('ponta_zonky_');
    try {
      final bytes = await jarFile.readAsBytes();
      await _extractZip(bytes, scratch.path, onLog);
      final txzs = scratch
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.txz'))
          .toList();
      if (txzs.isEmpty) {
        throw Exception(
            'No .txz payload found inside Zonky jar ${jarFile.path}');
      }
      final result = await Process.run(
        'tar',
        buildTarExtractArgs(txzs.first.path, installPath),
      );
      if (result.exitCode != 0) {
        throw Exception('Zonky txz extraction failed: ${result.stderr}');
      }
    } finally {
      if (scratch.existsSync()) {
        await scratch.delete(recursive: true);
      }
    }
  }
```

Wire into `install()` — replace the archive-dispatch head (lines ~143-146):

```dart
    final uri = Uri.parse(url);
    final isTar = isTarArchive(url);
    final extension = isTar ? '.tar' : p.extension(uri.path).toLowerCase();
    final isZip = extension == '.zip';
    final isExe = extension == '.exe';
    final isZonky = Platform.isLinux &&
        app.appId.contains('postgresql') &&
        isZonkyPgJar(url);
    // Raw prebuilt Linux binaries (e.g. meilisearch) arrive with no archive
    // extension; on Windows the legacy fallback treats unknown types as ZIP.
    final isRawBinary =
        Platform.isLinux && !isTar && !isZip && !isExe && !isZonky;
    final downloadExt =
        isZonky ? '.jar' : (extension.isEmpty ? '.bin' : extension);
```

Use `downloadExt` in the `tempFile` construction (line ~151). Insert a branch **before** `if (isTar)`:

```dart
      if (isZonky) {
        logInfo('Extracting Zonky PostgreSQL bundle for ${app.name}');
        onProgress?.call(0.82, 'Extracting...');
        await Directory(installPath).create(recursive: true);
        await _extractZonkyJar(tempFile, installPath, onLog);
        await ensureLinuxPermissions(installPath, logInfo: logInfo);
        onProgress?.call(0.9, 'Extracted');
      } else if (isRawBinary) {
        logInfo('Handling raw Linux binary for ${app.name}');
        onProgress?.call(0.85, 'Moving binary...');
        final fileName = app.execFile ?? p.basename(uri.path);
        final targetFile = File(p.join(installPath, fileName));
        await tempFile.copy(targetFile.path);
        await ensureLinuxPermissions(installPath, logInfo: logInfo);
        onProgress?.call(0.9, 'Binary ready');
      } else if (isTar) {
```

(leave the existing tar/zip/exe/fallback chain intact below it).

- [ ] **Step 4: Verify tests pass + suite green**

Run: `flutter test test/features/apps/installer_linux_zonky_test.dart test/features/apps/installer_linux_tar_test.dart`
Expected: PASS. Then `flutter analyze` → 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_linux_zonky_test.dart
git commit -m "feat(installer): Zonky PG jar extraction and raw Linux binary installs"
```

---

### Task 4: Service Manager — filename normalization, Linux port check, Linux force-kill

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart` (lines ~128-237 dispatch helpers, ~260-393 start branches, force-kill methods)
- Test: `test/features/apps/service_manager_linux_dispatch_test.dart`

**Interfaces:**
- Produces: `@visibleForTesting static String normalizeExecutableName(String fileName)` (lowercase, strips trailing `.exe|.bat|.cmd`); dispatch tables keyed on bare names; `@visibleForTesting static Set<String> parseListeningSocketsLinux(String ssOutput)`; Linux branch in `_checkPortConflicts` and in PID force-kill.

- [ ] **Step 1: Write failing tests**

```dart
// test/features/apps/service_manager_linux_dispatch_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';

void main() {
  group('normalizeExecutableName', () {
    test('strips windows extensions and lowercases', () {
      expect(AppServiceManager.normalizeExecutableName('CADDY.EXE'), 'caddy');
      expect(AppServiceManager.normalizeExecutableName('elasticsearch.bat'),
          'elasticsearch');
      expect(AppServiceManager.normalizeExecutableName('redis-server'), 'redis-server');
      expect(AppServiceManager.normalizeExecutableName('php-cgi.exe'), 'php-cgi');
    });
  });

  group('linux dispatch tables accept ELF names', () {
    test('webservers run detached without extension', () {
      expect(AppServiceManager.runsDetachedExecutable('caddy'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('nginx'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('redis-server'), isFalse);
    });

    test('caddy gets run args and socket requirements', () {
      final sockets =
          AppServiceManager.requiredSocketsForExecutable('caddy');
      expect(sockets, hasLength(2));
      final args =
          AppServiceManager.argumentsForExecutable('caddy', '/opt/caddy');
      expect(args, containsAll(['run', '--adapter', 'caddyfile']));
    });
  });

  group('parseListeningSocketsLinux', () {
    test('collects LISTEN rows and expands wildcard stars', () {
      const ss = ''
          'State  Recv-Q Send-Q Local Address:Port Peer Address:Port\n'
          'LISTEN 0      128        127.0.0.1:9082      0.0.0.0:*   \n'
          'LISTEN 0      511            *:80               *:*     \n'
          'LISTEN 0      4096       [::]:443            [::]:*     \n'
          'ESTAB  0      0        10.0.0.2:22         10.0.0.1:5000\n';
      final sockets = AppServiceManager.parseListeningSocketsLinux(ss);
      expect(sockets.contains('127.0.0.1:9082'), isTrue);
      expect(sockets.contains('0.0.0.0:80'), isTrue);
      expect(sockets.contains('[::]:80'), isTrue); // '*' expands to both wildcards
      expect(sockets.contains('[::]:443'), isTrue);
      expect(sockets.any((s) => s.contains(':22')), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/apps/service_manager_linux_dispatch_test.dart`
Expected: FAIL — `normalizeExecutableName` undefined; ELF names miss the `.exe`-keyed tables; Linux parser undefined.

- [ ] **Step 3: Implement**

3a. Normalizer + retargeted dispatch (replace lines ~206-237):

```dart
  /// Lowercases and strips a trailing Windows extension so Windows
  /// (`caddy.exe`) and Linux (`caddy`) dispatch identically.
  @visibleForTesting
  static String normalizeExecutableName(String fileName) => fileName
      .toLowerCase()
      .replaceFirst(RegExp(r'\.(exe|bat|cmd)$'), '');

  @visibleForTesting
  static bool runsDetachedExecutable(String fileName) => const {
        'nginx',
        'httpd',
        'apache',
        'caddy',
      }.contains(normalizeExecutableName(fileName));

  @visibleForTesting
  static List<String> argumentsForExecutable(
    String fileName,
    String workingDir,
  ) {
    if (normalizeExecutableName(fileName) == 'caddy') {
      return [
        'run',
        '--config',
        p.join(workingDir, 'Caddyfile'),
        '--adapter',
        'caddyfile',
      ];
    }
    return <String>[];
  }

  @visibleForTesting
  static List<({String host, int port})> requiredSocketsForExecutable(
    String fileName,
  ) {
    if (normalizeExecutableName(fileName) != 'caddy') return const [];
    return [(host: '*', port: 80), (host: '*', port: 443)];
  }
```

3b. In `start()`: replace the `fileName` computation (lines 264-267) with

```dart
      final fileName = normalizeExecutableName(
        exeFile.path.split(Platform.pathSeparator).last,
      );
```

then rewrite EVERY equality comparison to the bare names `'php-cgi'`,
`'php'`, `'redis-server'`, `'mysqld'`, `'mariadbd'`, `'mongod'`,
`'rustfs'`, `'meilisearch'`, `'elasticsearch'`, `'postgres'` (old spellings:
`php-cgi.exe`, `php.exe`, `redis-server.exe`, `mysqld.exe`, `mariadbd.exe`,
`mongod.exe`, `rustfs.exe`, `meilisearch.exe`, `elasticsearch.bat`,
`postgres.exe`). Inside the php branch collapse the inner
`if (fileName == 'php-cgi.exe')` split to `if (fileName == 'php-cgi')`,
keeping `args = ['-b', '$bindAddress:$port']` for php-cgi and
`['-S', '$bindAddress:$port']` otherwise.

3c. Port conflicts — replace line 150 gate and add the Linux parser:

```dart
    if (requiredSockets.isEmpty) return;
    final ProcessResult res;
    try {
      if (Platform.isWindows) {
        res = await Process.run('netstat', ['-ano']);
      } else if (Platform.isLinux) {
        res = await Process.run('ss', ['-tulpn']);
      } else {
        return;
      }
    } catch (_) {
      return; // probe unavailable — don't gate startup on it
    }
    if (res.exitCode != 0) return;
    final sockets = Platform.isWindows
        ? parseListeningSockets(res.stdout.toString())
        : parseListeningSocketsLinux(res.stdout.toString());
```

```dart
  /// Parses `ss -tulpn` stdout into listening `host:port` sockets. A literal
  /// `*:port` local address expands to BOTH IPv4 (`0.0.0.0:port`) and IPv6
  /// (`[::]:port`) wildcards so it matches any required bind host.
  @visibleForTesting
  static Set<String> parseListeningSocketsLinux(String ssOutput) {
    final result = <String>{};
    for (final raw in ssOutput.split('\n')) {
      final tokens = raw.trim().split(RegExp(r'\s+'));
      if (tokens.length < 4 || tokens[0] != 'LISTEN') continue;
      final local = tokens[3];
      final idx = local.lastIndexOf(':');
      if (idx <= 0) continue;
      var host = local.substring(0, idx);
      final port = local.substring(idx + 1);
      if (int.tryParse(port) == null) continue;
      if (host == '*') {
        result..add('0.0.0.0:$port')..add('[::]:$port');
      } else {
        result.add(local);
      }
    }
    return result;
  }
```

3d. Force-kill by PID: in `forceKillPid` (lines 564-583) add a Linux branch before the `_isWindows()` guard:

```dart
    if (!Platform.isWindows) {
      try {
        await _run('kill', ['-9', '$pid']);
      } catch (e) {
        _logger.warning('Failed to kill PID $pid: $e');
      }
      return;
    }
```

(keep the existing Windows `taskkill /F /T /PID` body untouched). In
`forceKillByNames` (lines 585-605), replace the early-return
`if (!_isWindows()) return;` with an OS split: on non-Windows, for each name
run `await _run('pkill', ['-9', '-x', name])` (exact-match by process name,
no `.exe` suffix appended); keep the Windows `taskkill /IM` loop verbatim.

> Policy-test note: these calls go through the existing `_run` indirection
> (`Process.run` default) — `background_process_policy_test.dart` only bans
> direct console spawns for ssl_service.dart, not here.

- [ ] **Step 4: Verify**

Run: `flutter test test/features/apps/service_manager_linux_dispatch_test.dart test/features/apps/port_conflict_test.dart test/features/apps/service_manager_disposed_test.dart test/features/apps/force_kill_pid_tree_test.dart`
Expected: ALL PASS (Windows assertions unaffected — `'caddy.exe'` normalizes to `'caddy'`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_service_manager.dart test/features/apps/service_manager_linux_dispatch_test.dart
git commit -m "feat(service-manager): OS-neutral executable dispatch, ss port probe, Linux force-kill"
```

---

### Task 5: Database Init — extensionless tool resolution on Linux

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (`_initializeDatabase` lines ~582-603, `_initializePostgresql` lines ~672-678)
- Test: `test/features/apps/installer_db_init_paths_test.dart`

**Interfaces:**
- Produces: `@visibleForTesting static String resolveDbTool(String installPath, String name)` — returns `<install>/bin/<name>.exe` if it exists else `<install>/bin/<name>` (existence-checked, absolute path returned either way).

- [ ] **Step 1: Write failing test**

```dart
// test/features/apps/installer_db_init_paths_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('resolveDbTool', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('dbinit_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('prefers the .exe variant when present (Windows layout)', () {
      Directory(p.join(tmp.path, 'bin')).createSync();
      File(p.join(tmp.path, 'bin', 'initdb.exe')).writeAsStringSync('');
      final got = AppInstallerService.resolveDbTool(tmp.path, 'initdb');
      expect(got, endsWith('initdb.exe'));
      expect(File(got).existsSync(), isTrue);
    });

    test('falls back to the extensionless ELF (Linux layout)', () {
      Directory(p.join(tmp.path, 'bin')).createSync();
      File(p.join(tmp.path, 'bin', 'initdb')).writeAsStringSync('');
      final got = AppInstallerService.resolveDbTool(tmp.path, 'initdb');
      expect(p.basename(got), equals('initdb'));
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/apps/installer_db_init_paths_test.dart`
Expected: FAIL — member not found.

- [ ] **Step 3: Implement + rewire**

```dart
  /// Resolves a database maintenance tool inside `<installPath>/bin`,
  /// preferring the Windows `.exe` spelling and falling back to the bare ELF
  /// name so Linux layouts (mysqld, mariadb-install-db, initdb) resolve.
  @visibleForTesting
  static String resolveDbTool(String installPath, String name) {
    final bin = p.join(installPath, 'bin');
    final exe = File(p.join(bin, '$name.exe'));
    if (exe.existsSync()) return exe.path;
    return p.join(bin, name);
  }
```

Rewire (the method already has a local `binDir` = `Directory(p.join(installPath, 'bin'))`, and `resolveDbTool` returns absolute paths, so `File(resolveDbTool(...))` replaces the `File(p.join(binDir.path, ...))` probes):
- `_initializeDatabase` MySQL branch (line 586): `initExec = resolveDbTool(installPath, 'mysqld');` (drop the hardcoded `'mysqld.exe'` join).
- MariaDB branch (lines 594-595): probe via `final mdbInstall = File(resolveDbTool(installPath, 'mariadb-install-db'));` and `final mysqlInstall = File(resolveDbTool(installPath, 'mysql_install_db'));` — keep semantics: check `mdbInstall.existsSync()` then `mysqlInstall.existsSync()`; when neither exists leave `initExec == null` so the existing loud-failure path throws.
- `_initializePostgresql` (lines 672-678): replace the `initdb.exe` existence check with

```dart
    final initdbPath = resolveDbTool(installPath, 'initdb');
    if (!File(initdbPath).existsSync()) {
      throw Exception(
        'initdb not found at $initdbPath; cannot initialize the cluster.',
      );
    }
```

and use `initdbPath` in the run call (`Process.run(initdbPath, args)` at line 701) plus the log line.

Note: MariaDB on Linux also commonly needs `--basedir=<installPath>`; append it in the args list only when `Platform.isLinux`:

```dart
      args = [
        '--datadir=${dataDir.path}',
        if (Platform.isLinux) '--basedir=$installPath',
      ];
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/apps/installer_db_init_paths_test.dart test/features/apps/app_installer_data_dir_test.dart`
Expected: PASS. `flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_db_init_paths_test.dart
git commit -m "feat(installer): OS-neutral database init tool resolution (mysqld/mariadb-install-db/initdb)"
```

---

### Task 6: SslService — Linux mkcert assets, /dev/null device, exec permissions

**Files:**
- Modify: `lib/core/services/ssl_service.dart` (`mkcertPath` lines 28-57, `checkStatus` lines 72-78)
- Test: `test/core/services/ssl_service_linux_test.dart`

**Interfaces:**
- Consumes: user-provided assets `assets/bin/mkcert-v1.4.4-linux-{amd64,arm64,arm}`, existing `BackgroundProcess.run/runElevated` (Linux elevation already routes through pkexec).
- Produces: `@visibleForTesting static String mkcertAssetBasename({bool? isLinux, String? dartVersion})`; Linux `mkcertPath` copies the bundled binary to `AppConfig.binDir/mkcert` and `chmod 755`s it.

- [ ] **Step 1: Write failing tests**

```dart
// test/core/services/ssl_service_linux_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/services/ssl_service.dart';

void main() {
  group('mkcert asset basename', () {
    test('windows keeps the legacy unversioned exe', () {
      expect(SslService.mkcertAssetBasename(isLinux: false),
          equals('mkcert.exe'));
    });

    test('linux selects per-arch versioned binary', () {
      expect(
        SslService.mkcertAssetBasename(
            isLinux: true, dartVersion: '3.10.4 (stable) ... on "linux_x64"'),
        equals('mkcert-v1.4.4-linux-amd64'),
      );
      expect(
        SslService.mkcertAssetBasename(
            isLinux: true, dartVersion: '3.10.4 (stable) ... on "linux_arm64"'),
        equals('mkcert-v1.4.4-linux-arm64'),
      );
    });

    test('unknown linux arch defaults to amd64', () {
      expect(SslService.mkcertAssetBasename(isLinux: true, dartVersion: ''),
          equals('mkcert-v1.4.4-linux-amd64'));
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/ssl_service_linux_test.dart`
Expected: FAIL — member not found.

- [ ] **Step 3: Implement**

Add the static helper:

```dart
  /// Bundled mkcert asset name for the host platform. Windows keeps the
  /// legacy unversioned `mkcert.exe`; Linux picks the versioned binary whose
  /// architecture matches the Dart VM (`Platform.version` embeds `linux_x64`,
  /// `linux_arm64`, ...), defaulting to amd64.
  @visibleForTesting
  static String mkcertAssetBasename({bool? isLinux, String? dartVersion}) {
    final linux = isLinux ?? Platform.isLinux;
    if (!linux) return 'mkcert.exe';
    final version = dartVersion ?? Platform.version;
    if (version.contains('arm64')) return 'mkcert-v1.4.4-linux-arm64';
    if (RegExp(r'arm(?!64)').hasMatch(version)) {
      return 'mkcert-v1.4.4-linux-arm';
    }
    return 'mkcert-v1.4.4-linux-amd64';
  }
```

(needs `import 'package:flutter/foundation.dart';` for `@visibleForTesting`)

Replace `mkcertPath` (lines 28-57):

```dart
  String get mkcertPath {
    final binCopy = p.join(AppConfig.binDir, 'mkcert');
    final assetName = mkcertAssetBasename();

    // Windows resolution is unchanged: prefer an installed copy, then the
    // dev/prod asset copies of mkcert.exe.
    if (!Platform.isLinux) {
      final binPath = p.join(AppConfig.binDir, 'mkcert.exe');
      if (File(binPath).existsSync()) return binPath;

      final devPath = p.join(
          Directory.current.path, 'assets', 'bin', 'mkcert.exe');
      if (File(devPath).existsSync()) return devPath;

      final prodPath = p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'bin',
        'mkcert.exe',
      );
      if (File(prodPath).existsSync()) return prodPath;
      return devPath;
    }

    // Linux: asset-bundle files are not executable, so materialise a copy
    // into ~/.ponta/bin and mark it +x. Re-copy when the asset changed size
    // (version upgrade).
    final candidates = [
      p.join(AppConfig.binDir, assetName),
      p.join(Directory.current.path, 'assets', 'bin', assetName),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'bin',
        assetName,
      ),
    ];
    final source = candidates
        .map(File)
        .firstWhere((f) => f.existsSync(), orElse: () => File(''));
    if (source.path.isEmpty) return binCopy;

    try {
      final target = File(binCopy);
      final needsCopy = !target.existsSync() ||
          target.lengthSync() != source.lengthSync();
      if (needsCopy) {
        if (!Directory(AppConfig.binDir).existsSync()) {
          Directory(AppConfig.binDir).createSync(recursive: true);
        }
        source.copySync(binCopy);
        Process.runSync('chmod', ['755', binCopy]);
      }
    } catch (_) {}
    return binCopy;
  }
```

In `checkStatus` replace the two `'nul'` literals (lines 74, 76):

```dart
      final nullDevice = Platform.isWindows ? 'nul' : '/dev/null';
      final testResult = await BackgroundProcess.run(mkcertPath, [
        '-cert-file',
        nullDevice,
        '-key-file',
        nullDevice,
        'test.local',
      ]);
```

Also fix the log message at line 174: `'mkcert.exe not found at $mkcertPath'` → `'mkcert binary not found at $mkcertPath'` (line 178's "SSL not found" message is fine as-is). `initializeRootCA`/`uninstallRootCA` already route through `runElevated` → pkexec on Linux; no change.

- [ ] **Step 4: Verify**

Run: `flutter test test/core/services/ssl_service_linux_test.dart test/core/services/background_process_policy_test.dart`
Expected: PASS (policy tests confirm mkcert still never spawns a raw console `Process.run(mkcertPath...)`).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/ssl_service.dart test/core/services/ssl_service_linux_test.dart
git commit -m "feat(ssl): per-arch Linux mkcert assets, exec staging, /dev/null null device"
```

---

### Task 7: Post-install hooks — Composer global bin + pyenv on Linux

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (`_ensureComposerGlobalBinInPath` lines ~1985-1997, `_writeComposerWrappers` tail ~2028-2034, `_configurePyenv` lines ~1781-1813, `cleanupPyenv`)
- Test: `test/features/apps/installer_linux_hooks_test.dart`

**Interfaces:**
- Consumes: `pathService.addRawPathToUserPath` / `removeRawPathFromUserPath` (already OS-branched from Task 4 of the previous plan).
- Produces: `@visibleForTesting static String composerGlobalBinDir({bool? isWindows, String? home})`.

- [ ] **Step 1: Write failing test**

```dart
// test/features/apps/installer_linux_hooks_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('composerGlobalBinDir', () {
    test('uses APPDATA vendor bin on Windows', () {
      final got = AppInstallerService.composerGlobalBinDir(
        isWindows: true,
        home: '/home/u',
        appData: r'C:\Users\u\AppData\Roaming',
      );
      expect(got,
          equals(r'C:\Users\u\AppData\Roaming' + r'\Composer\vendor\bin'));
    });

    test('uses XDG config path on Linux', () {
      expect(
        AppInstallerService.composerGlobalBinDir(
          isWindows: false,
          home: '/home/u',
        ),
        equals('/home/u/.config/composer/vendor/bin'),
      );
    });
  });
}
```

(If the Windows assertion's exact separator is brittle, assert `contains('Composer')` + `contains('vendor')` instead — match whatever `p.join` yields.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/apps/installer_linux_hooks_test.dart`
Expected: FAIL — member not found.

- [ ] **Step 3: Implement**

```dart
  /// Per-user Composer global bin directory for global packages.
  @visibleForTesting
  static String composerGlobalBinDir({
    bool? isWindows,
    String? home,
    String? appData,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    if (windows) {
      final dir = appData ?? Platform.environment['APPDATA'];
      if (dir == null || dir.isEmpty) return '';
      return p.join(dir, 'Composer', 'vendor', 'bin');
    }
    final homeDir = home ?? Platform.environment['HOME'] ?? '';
    if (homeDir.isEmpty) return '';
    return p.join(homeDir, '.config', 'composer', 'vendor', 'bin');
  }
```

> Note: on Windows the test passes `appData:` explicitly; the real call site
> (`_ensureComposerGlobalBinInPath`) reads it from the environment.

Rewire `_ensureComposerGlobalBinInPath`:

```dart
  Future<void> _ensureComposerGlobalBinInPath(Function(String) logInfo) async {
    final pathService = _ref.read(pathServiceProvider);
    await pathService.ensurePontaBinInPath();

    final composerBinPath = composerGlobalBinDir();
    if (composerBinPath.isEmpty) return;
    await pathService.addRawPathToUserPath(composerBinPath);
    logInfo('Added Composer global bin directory to PATH: $composerBinPath');
  }
```

In `_writeComposerWrappers` (lines 1999-2035), right after the extensionless `composer` shim is written (after line 2027, before the legacy `.ps1` cleanup), make it executable on Linux:

```dart
    if (Platform.isLinux) {
      final shim = File(p.join(PathService.binDir, 'composer'));
      if (shim.existsSync()) {
        await Process.run('chmod', ['755', shim.path]);
      }
    }
```

`_configurePyenv` (lines 1781-1813) — prepend an OS split right after the signature; keep the existing Windows body verbatim under `if (Platform.isWindows) { ...existing body... return; }` and add:

```dart
    // Linux: real pyenv (github.com/pyenv/pyenv) — the master.zip layout is
    // bin/pyenv + libexec/pyenv-* directly under installPath (no pyenv-win/
    // nesting); shims activate via `pyenv init` in the shell rc.
    final pathService = _ref.read(pathServiceProvider);
    await pathService.setUserEnvVar('PYENV_ROOT', installPath);
    await pathService.addRawPathToUserPath(p.join(installPath, 'bin'));
    await pathService.addRawPathToUserPath(p.join(installPath, 'shims'));
    logInfo(
      'pyenv configured. Add `eval "$(pyenv init -)"` to your shell rc '
      'for full shim activation.',
    );
```

(No `PYENV`/`PYENV_HOME` on Linux — those are pyenv-win-only variables.)

Mirror in `cleanupPyenv` (lines 1815-1836): same OS split; on non-Windows remove only `PYENV_ROOT`, plus `removeRawPathFromUserPath` for `<installPath>/bin` and `<installPath>/shims`; keep the Windows body verbatim under its branch.

- [ ] **Step 4: Verify**

Run: `flutter test test/features/apps/installer_linux_hooks_test.dart`
Expected: PASS. `flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_linux_hooks_test.dart
git commit -m "feat(installer): Linux Composer global-bin PATH, executable wrapper, pyenv-linux config"
```

---

### Task 8: SystemInfo — Linux collection branch

**Files:**
- Modify: `lib/features/system/data/system_info_provider.dart` (`_fetchSystemInfo` lines 21-44)
- Test: `test/features/system/system_info_os_label_test.dart`

**Interfaces:**
- Produces: `@visibleForTesting static ({String rawOutput, String frameworkLabel}) collectPlatformInfo({bool? isWindows, Future<ProcessResult> Function(String, List<String>)? run})` — pure enough to unit-test.

- [ ] **Step 1: Write failing test**

```dart
// test/features/system/system_info_os_label_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/system/data/system_info_provider.dart';

void main() {
  group('collectPlatformInfo', () {
    test('labels Windows and requests systeminfo', () async {
      String? ran;
      final r = await SystemInfoNotifier.collectPlatformInfo(
        isWindows: true,
        run: (exe, args) async {
          ran = exe;
          return ProcessResult(0, 0, 'win-output', '');
        },
      );
      expect(ran, equals('systeminfo'));
      expect(r.rawOutput, equals('win-output'));
      expect(r.frameworkLabel, equals('Flutter (Windows)'));
    });

    test('falls back to uname -a on Linux', () async {
      String? ran;
      final r = await SystemInfoNotifier.collectPlatformInfo(
        isWindows: false,
        run: (exe, args) async {
          ran = exe;
          return ProcessResult(0, 0, 'Linux box 6.8.0 x86_64', '');
        },
      );
      expect(ran, equals('uname'));
      expect(r.rawOutput, contains('6.8.0'));
      expect(r.frameworkLabel, equals('Flutter (Linux)'));
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/system/system_info_os_label_test.dart`
Expected: FAIL — member not found.

- [ ] **Step 3: Implement**

Add to `SystemInfoNotifier`:

```dart
  @visibleForTesting
  static Future<({String rawOutput, String frameworkLabel})>
      collectPlatformInfo({
    bool? isWindows,
    Future<ProcessResult> Function(String, List<String>)? run,
  }) async {
    final windows = isWindows ?? Platform.isWindows;
    final runner = run ?? Process.run;
    try {
      final res = windows
          ? await runner('systeminfo', [])
          : await runner('uname', ['-a']);
      return (
        rawOutput: res.stdout.toString(),
        frameworkLabel: windows ? 'Flutter (Windows)' : 'Flutter (Linux)',
      );
    } catch (_) {
      return (
        rawOutput: windows ? '' : 'system info unavailable',
        frameworkLabel: windows ? 'Flutter (Windows)' : 'Flutter (Linux)',
      );
    }
  }
```

(Requires `import 'package:flutter/foundation.dart';` for `@visibleForTesting`.) Rewire `_fetchSystemInfo` to consume it:

```dart
  Future<SystemInfo> _fetchSystemInfo() async {
    final platformInfo = await collectPlatformInfo();

    final packageInfo = await PackageInfo.fromPlatform();
    final appDir = Directory.current.path;
    final supportDir = await getApplicationSupportDirectory();

    return SystemInfo(
      rawOutput: platformInfo.rawOutput,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      frameworkVersion: platformInfo.frameworkLabel,
      dartVersion: Platform.version.split(' ')[0],
      databaseVersion: 'Isar 3.1.0',
      engineVersion: 'Chromium-based (Flutter)',
      appPath: appDir,
      userDataPath: supportDir.path,
      generatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 4: Verify**

Run: `flutter test test/features/system/system_info_os_label_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/system/data/system_info_provider.dart test/features/system/system_info_os_label_test.dart
git commit -m "fix(system-info): uname-based collection on Linux, guarded systeminfo on Windows"
```

---

### Task 9: Whole-suite verification + known-limitations doc

**Files:**
- Create: `docs/linux-support-notes.md`

- [ ] **Step 1: Full verification**

Run: `flutter analyze` → 0 issues.
Run: `flutter test` → all pass (≥253 + new tests).

- [ ] **Step 2: Write known-limitations notes**

```markdown
# Linux Support — Known Limitations & Follow-ups

## Catalog scope (as of 2026-08-23)
- **Nginx, Apache, Redis** are intentionally ABSENT from `apps-linux.json`:
  upstream publishes no official portable prebuilt Linux binaries. Re-add
  only when a trustworthy signed source exists.
- **PostgreSQL** uses Zonky embedded binaries (Maven Central), unpacked from
  the jar's inner `.txz` by the installer.

## Runtime limitations
- Linux PHP (static-php-cli) ships the CLI SAPI only: services run via
  `php -S host:port` (built-in server). Nginx↔PHP-FastCGI integration is a
  follow-up requiring an fpm build.
- mkcert CA trust install requires the Polkit agent (pkexec prompt).
- Port-conflict probing uses `ss -tulpn` on Linux (best-effort, skips
  silently when unavailable — same policy as netstat on Windows).

## External prerequisites
- The catalog gist must contain `apps-linux.json` alongside `apps.json`
  (multi-file gist) or Linux auto-update silently no-ops (logged).
```

- [ ] **Step 3: Commit**

```bash
git add docs/linux-support-notes.md
git commit -m "docs: Linux support known limitations and catalog policy"
```
