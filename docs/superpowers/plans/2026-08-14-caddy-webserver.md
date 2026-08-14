# Caddy Web Server Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Caddy 2.11.x as a fully managed Windows web server alongside nginx and Apache, with catalog installation, process lifecycle, generated Caddyfiles, local TLS, per-site config editing, phpMyAdmin routing, logs, and UI integration.

**Architecture:** Follow the existing additive nginx/Apache branches rather than introducing a `WebServerType` strategy layer. Put Caddyfile string generation in one pure `CaddyConfigBuilder` so installer and site orchestration share syntax that can be unit-tested without Riverpod, Isar, or real processes. Keep site access logs per-domain; write Caddy runtime/error logs to one global file because Caddy cannot route runtime logs by hostname.

**Tech Stack:** Flutter/Dart, Riverpod, Isar, `path`, `re_highlight`, Caddy 2.11 Caddyfile adapter, Windows process management.

## Global Constraints

- Caddy remains a peer alongside nginx and Apache; do not remove or make it replace either server.
- Caddy conflicts with both nginx and Apache because all three bind ports 80/443.
- Use Caddy's foreground `run` command under the existing hidden managed-process launcher.
- Disable Caddy automatic HTTPS with global `auto_https off`; use certificates and keys supplied by `sslServiceProvider`.
- Generate one config per site under `AppConfig.vhostsDir\caddy\<domain>.conf` and import it from the main Caddyfile using an absolute, forward-slash-normalized glob.
- Keep phpMyAdmin integration snippets under `AppConfig.vhostsDir\caddy\integrations\*.conf`; import them inside the localhost site block.
- Keep per-site access logs at `AppConfig.logsDir\<domain>\caddy_access.log` and the shared runtime/error log at `AppConfig.logsDir\caddy_error.log`.
- Use the Caddyfile adapter only; do not add Caddy JSON/admin-API management.
- Map `Caddyfile` to plaintext highlighting because `re_highlight 0.0.3` has no Caddy grammar.
- Do not add a `WebServerType` enum or a web-server strategy refactor.
- Add no new Dart dependencies.
- Catalog only stable Windows amd64 releases: `2.11.4`, `2.11.3`, `2.11.2`, `2.11.1`, and `2.11.0`.
- Use the official Caddy icon from `https://raw.githubusercontent.com/caddyserver/website/15ac087cfd9c21a53b2ddfa10359fdc63d5ec9b6/src/resources/images/icon-transparent.png`.

## File Structure

**Create:**
- `lib/core/config/caddy_config_builder.dart` — pure builders for the main Caddyfile, per-site blocks, and phpMyAdmin route snippets.
- `lib/features/apps/domain/app_conflict_policy.dart` — models one-to-many installation conflicts such as Caddy versus nginx and Apache.
- `lib/features/sites/presentation/site_editor_options.dart` — shared Caddy/nginx/Apache config and log selector metadata.
- `assets/images/caddy.png` — official Caddy icon.
- `test/assets/caddy_catalog_test.dart` — verifies catalog metadata and release URLs.
- `test/core/config/caddy_config_builder_test.dart` — verifies valid Caddyfile output for all site types and TLS modes.
- `test/features/apps/app_conflict_policy_test.dart` — verifies one-to-many server conflicts.
- `test/features/apps/caddy_installer_policy_test.dart` — verifies Caddy participates in installer filtering.
- `test/features/apps/caddy_service_policy_test.dart` — verifies Caddy launch arguments, detached mode, and socket preflight policy.
- `test/features/apps/webserver_config_path_test.dart` — verifies `<install>/Caddyfile` resolution.
- `test/features/sites/caddy_vhost_paths_test.dart` — verifies supported config types and safe Caddy vhost paths.
- `test/features/sites/site_editor_options_test.dart` — verifies Caddy config/log UI metadata.

**Modify:**
- `assets/data/apps.json` — add Caddy catalog entry.
- `lib/core/config/webserver_bind_policy.dart` — add Caddy bind/site-address helpers.
- `lib/features/apps/data/app_installer_service.dart` — generate main Caddyfile, reconfigure Caddy, and generate phpMyAdmin integration.
- `lib/features/apps/data/app_service_manager.dart` — launch and manage `caddy.exe`.
- `lib/features/apps/data/webserver_settings_provider.dart` — resolve Caddy's main config.
- `lib/features/apps/presentation/widgets/app_settings_modal.dart` — expose Caddyfile in the config tab.
- `lib/features/apps/presentation/widgets/app_version_modal.dart` — use one-to-many conflict policy and Caddy visuals.
- `lib/features/apps/presentation/widgets/compact_apps_table.dart` — display Caddy icon/color.
- `lib/features/sites/data/sites_provider.dart` — generate/read/write/delete Caddy vhosts and expose logs.
- `lib/features/sites/presentation/widgets/edit_site_modal.dart` — show Caddy config and log selectors.
- `lib/shared/widgets/code_editor/language_for_config.dart` — map Caddyfile to plaintext.
- `test/features/settings/webserver_bind_policy_test.dart` — cover Caddy policy.
- `test/shared/widgets/code_editor/language_for_config_test.dart` — cover Caddyfile highlighting.
- `docs/superpowers/specs/2026-08-14-caddy-webserver-design.md` — align release versions, absolute imports, and logging details with verified Caddy behavior.

---

### Task 1: Register Caddy in the catalog and assets

**Files:**
- Modify: `assets/data/apps.json:378`
- Create: `assets/images/caddy.png`
- Create: `test/assets/caddy_catalog_test.dart`
- Modify: `test/features/apps/app_model_test.dart:158`

**Interfaces:**
- Consumes: `AppsRepository.getAll()` catalog schema (`id`, `category`, `group_name`, `exec_file`, `cli_file`, `repo`, `versions`).
- Produces: catalog app ID `caddy`, executable `caddy.exe`, and bundled icon `assets/images/caddy.png`.

- [ ] **Step 1: Write failing catalog and service-classification tests**

Create `test/assets/caddy_catalog_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog contains stable Windows amd64 Caddy releases', () async {
    final raw = await File('assets/data/apps.json').readAsString();
    final catalog = jsonDecode(raw) as Map<String, dynamic>;
    final apps = (catalog['apps'] as List).cast<Map<String, dynamic>>();
    final caddy = apps.singleWhere((app) => app['id'] == 'caddy');

    expect(caddy['name'], 'Caddy');
    expect(caddy['category'], 'webserver');
    expect(caddy['group_name'], 'webserver');
    expect(caddy['exec_file'], 'caddy.exe');
    expect(caddy['cli_file'], 'caddy.exe');
    expect(caddy['repo'], 'caddyserver/caddy');
    expect(caddy['versions'], <String, String>{
      '2.11.4':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_windows_amd64.zip',
      '2.11.3':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.3/caddy_2.11.3_windows_amd64.zip',
      '2.11.2':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.2/caddy_2.11.2_windows_amd64.zip',
      '2.11.1':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.1/caddy_2.11.1_windows_amd64.zip',
      '2.11.0':
          'https://github.com/caddyserver/caddy/releases/download/v2.11.0/caddy_2.11.0_windows_amd64.zip',
    });
  });

  test('Caddy icon is bundled and non-empty', () async {
    final icon = File('assets/images/caddy.png');
    expect(await icon.exists(), isTrue);
    expect(await icon.length(), greaterThan(0));
  });
}
```

Append inside the `AppModel - Service Detection` group in `test/features/apps/app_model_test.dart`:

```dart
    test('isService returns true for Caddy webserver category', () {
      final app = AppModel(
        appId: 'caddy',
        name: 'Caddy',
        categories: ['webserver'],
      );

      expect(app.isService, isTrue);
    });
```

- [ ] **Step 2: Run tests and verify the catalog test fails**

Run:

```bash
flutter test test/assets/caddy_catalog_test.dart test/features/apps/app_model_test.dart
```

Expected: catalog test fails because no app with ID `caddy` exists; icon test fails because `assets/images/caddy.png` does not exist. Existing `AppModel` tests pass.

- [ ] **Step 3: Add exact catalog metadata and download the official icon**

Insert before the nginx entry in `assets/data/apps.json`:

```json
    {
      "id": "caddy",
      "name": "Caddy",
      "description": "Fast, extensible web server with a simple configuration",
      "category": "webserver",
      "group_name": "webserver",
      "exec_file": "caddy.exe",
      "cli_file": "caddy.exe",
      "repo": "caddyserver/caddy",
      "versions": {
        "2.11.4": "https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_windows_amd64.zip",
        "2.11.3": "https://github.com/caddyserver/caddy/releases/download/v2.11.3/caddy_2.11.3_windows_amd64.zip",
        "2.11.2": "https://github.com/caddyserver/caddy/releases/download/v2.11.2/caddy_2.11.2_windows_amd64.zip",
        "2.11.1": "https://github.com/caddyserver/caddy/releases/download/v2.11.1/caddy_2.11.1_windows_amd64.zip",
        "2.11.0": "https://github.com/caddyserver/caddy/releases/download/v2.11.0/caddy_2.11.0_windows_amd64.zip"
      }
    },
```

Download the pinned official icon:

```bash
curl -L --fail "https://raw.githubusercontent.com/caddyserver/website/15ac087cfd9c21a53b2ddfa10359fdc63d5ec9b6/src/resources/images/icon-transparent.png" -o assets/images/caddy.png
```

No `pubspec.yaml` change is needed because the whole `assets/images/` directory is already bundled.

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
flutter test test/assets/caddy_catalog_test.dart test/features/apps/app_model_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/data/apps.json assets/images/caddy.png test/assets/caddy_catalog_test.dart test/features/apps/app_model_test.dart
git commit -m "feat: register Caddy web server"
```

---

### Task 2: Model one-to-many web-server conflicts

**Files:**
- Create: `lib/features/apps/domain/app_conflict_policy.dart`
- Create: `test/features/apps/app_conflict_policy_test.dart`
- Modify: `lib/features/apps/presentation/widgets/app_version_modal.dart:8,99-133`

**Interfaces:**
- Consumes: `AppModel.appId`, `AppModel.groupName`, and `AppModel.isInstalled`.
- Produces: `AppConflictPolicy.conflictsFor(AppModel) -> Set<String>` and `AppConflictPolicy.firstInstalledConflict(AppModel, Iterable<AppModel>) -> AppModel?`.

- [ ] **Step 1: Write the failing conflict-policy tests**

Create `test/features/apps/app_conflict_policy_test.dart`:

```dart
import 'package:dev_stack/features/apps/domain/app_conflict_policy.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppModel app(String id, {bool installed = false}) => AppModel(
  appId: id,
  name: id,
  categories: const ['webserver'],
  groupName: id,
  isInstalled: installed,
);

void main() {
  group('AppConflictPolicy', () {
    test('Caddy conflicts with both nginx and Apache', () {
      expect(
        AppConflictPolicy.conflictsFor(app('caddy')),
        equals({'nginx', 'apache'}),
      );
    });

    test('nginx and Apache each conflict with Caddy and one another', () {
      expect(
        AppConflictPolicy.conflictsFor(app('nginx')),
        equals({'apache', 'caddy'}),
      );
      expect(
        AppConflictPolicy.conflictsFor(app('apache')),
        equals({'nginx', 'caddy'}),
      );
    });

    test('finds either installed server conflict for Caddy', () {
      expect(
        AppConflictPolicy.firstInstalledConflict(
          app('caddy'),
          [app('apache', installed: true)],
        )?.appId,
        'apache',
      );
      expect(
        AppConflictPolicy.firstInstalledConflict(
          app('caddy'),
          [app('nginx', installed: true)],
        )?.appId,
        'nginx',
      );
    });

    test('preserves MySQL and MariaDB mutual exclusion', () {
      final mysql = AppModel(
        appId: 'mysql',
        name: 'MySQL',
        categories: const ['database'],
        groupName: 'mysql',
      );
      final maria = AppModel(
        appId: 'mariadb',
        name: 'MariaDB',
        categories: const ['database'],
        groupName: 'mariadb',
        isInstalled: true,
      );

      expect(
        AppConflictPolicy.firstInstalledConflict(mysql, [maria]),
        same(maria),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
flutter test test/features/apps/app_conflict_policy_test.dart
```

Expected: compilation fails because `app_conflict_policy.dart` does not exist.

- [ ] **Step 3: Implement the conflict policy**

Create `lib/features/apps/domain/app_conflict_policy.dart`:

```dart
import 'app_model.dart';

abstract final class AppConflictPolicy {
  static const Map<String, Set<String>> _conflicts = {
    'mysql': {'mariadb'},
    'mariadb': {'mysql'},
    'nginx': {'apache', 'caddy'},
    'apache': {'nginx', 'caddy'},
    'caddy': {'nginx', 'apache'},
  };

  static Set<String> conflictsFor(AppModel app) {
    final appId = app.appId.toLowerCase();
    final groupName = app.groupName?.toLowerCase() ?? '';
    for (final entry in _conflicts.entries) {
      if (appId.contains(entry.key) || groupName.contains(entry.key)) {
        return entry.value;
      }
    }
    return const <String>{};
  }

  static AppModel? firstInstalledConflict(
    AppModel target,
    Iterable<AppModel> apps,
  ) {
    final patterns = conflictsFor(target);
    if (patterns.isEmpty) return null;

    for (final candidate in apps) {
      if (!candidate.isInstalled || candidate.appId == target.appId) continue;
      final id = candidate.appId.toLowerCase();
      final group = candidate.groupName?.toLowerCase() ?? '';
      if (patterns.any(
        (pattern) => id.contains(pattern) || group.contains(pattern),
      )) {
        return candidate;
      }
    }
    return null;
  }
}
```

In `app_version_modal.dart`, import the policy:

```dart
import '../../domain/app_conflict_policy.dart';
```

Replace lines 99-133 with:

```dart
    // Port-sharing web servers and database alternatives are mutually exclusive.
    final conflictingApp = widget.isUpdate
        ? null
        : AppConflictPolicy.firstInstalledConflict(
            widget.app,
            appsAsync.valueOrNull ?? const <AppModel>[],
          );
```

- [ ] **Step 4: Run focused tests and analysis**

Run:

```bash
flutter test test/features/apps/app_conflict_policy_test.dart
flutter analyze lib/features/apps/domain/app_conflict_policy.dart lib/features/apps/presentation/widgets/app_version_modal.dart
```

Expected: tests PASS and analysis reports no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/domain/app_conflict_policy.dart lib/features/apps/presentation/widgets/app_version_modal.dart test/features/apps/app_conflict_policy_test.dart
git commit -m "feat: model Caddy web server conflicts"
```

---

### Task 3: Build testable Caddyfile generators and bind policy

**Files:**
- Create: `lib/core/config/caddy_config_builder.dart`
- Create: `test/core/config/caddy_config_builder_test.dart`
- Modify: `lib/core/config/webserver_bind_policy.dart:3-14`
- Modify: `test/features/settings/webserver_bind_policy_test.dart:10-101`

**Interfaces:**
- Consumes: validated domain/root/proxy strings, bind address, paths, PHP port, and TLS paths.
- Produces: `CaddyConfigBuilder.mainConfig`, `CaddyConfigBuilder.siteConfig`, `CaddyConfigBuilder.phpMyAdminIntegration`, `WebserverBindPolicy.caddyBind`, and `WebserverBindPolicy.caddySiteAddress`.

- [ ] **Step 1: Write failing bind-policy and Caddy builder tests**

Add to the localhost test in `webserver_bind_policy_test.dart`:

```dart
      expect(
        WebserverBindPolicy.caddyBind(allowLanAccess: false),
        '127.0.0.1',
      );
      expect(
        WebserverBindPolicy.caddySiteAddress('example.test', ssl: false),
        'http://example.test',
      );
```

Add to the LAN test:

```dart
      expect(
        WebserverBindPolicy.caddyBind(allowLanAccess: true),
        '0.0.0.0',
      );
      expect(
        WebserverBindPolicy.caddySiteAddress('example.test', ssl: true),
        'https://example.test',
      );
```

Create `test/core/config/caddy_config_builder_test.dart`:

```dart
import 'package:dev_stack/core/config/caddy_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaddyConfigBuilder.mainConfig', () {
    test('disables automatic HTTPS and imports absolute vhost globs', () {
      final config = CaddyConfigBuilder.mainConfig(
        webRoot: r'C:\Ponta\www',
        bindAddress: '127.0.0.1',
        vhostsGlob: r'C:\Ponta\vhosts\caddy\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\caddy\integrations\*.conf',
        localhostAccessLogPath: r'C:\Ponta\logs\localhost\caddy_access.log',
        runtimeErrorLogPath: r'C:\Ponta\logs\caddy_error.log',
      );

      expect(config, contains('auto_https off'));
      expect(config, contains('http://localhost {'));
      expect(config, isNot(contains('https://localhost')));
      expect(
        config,
        contains('import "C:/Ponta/vhosts/caddy/integrations/*.conf"'),
      );
      expect(config, contains('import "C:/Ponta/vhosts/caddy/*.conf"'));
      expect(config, contains('exclude http.log.access'));
      expect(config, contains('C:/Ponta/logs/caddy_error.log'));
    });

    test('uses explicit local certificate for HTTPS localhost', () {
      final config = CaddyConfigBuilder.mainConfig(
        webRoot: r'C:\Ponta\www',
        bindAddress: '0.0.0.0',
        vhostsGlob: r'C:\Ponta\vhosts\caddy\*.conf',
        integrationsGlob: r'C:\Ponta\vhosts\caddy\integrations\*.conf',
        localhostAccessLogPath: r'C:\Ponta\logs\localhost\caddy_access.log',
        runtimeErrorLogPath: r'C:\Ponta\logs\caddy_error.log',
        certPath: r'C:\Ponta\certs\localhost.crt',
        keyPath: r'C:\Ponta\certs\localhost.key',
      );

      expect(config, contains('http://localhost, https://localhost {'));
      expect(config, contains('bind 0.0.0.0'));
      expect(
        config,
        contains(
          'tls "C:/Ponta/certs/localhost.crt" '
          '"C:/Ponta/certs/localhost.key"',
        ),
      );
    });
  });

  group('CaddyConfigBuilder.siteConfig', () {
    test('builds static HTTP site with per-site access log', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'static.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\static',
        siteType: 'static',
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\static.test\caddy_access.log',
      );

      expect(config, startsWith('http://static.test {'));
      expect(config, contains('root * "C:/Sites/static"'));
      expect(config, contains('file_server'));
      expect(config, isNot(contains('php_fastcgi')));
      expect(config, isNot(contains('reverse_proxy')));
    });

    test('builds PHP site with FastCGI port', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'php.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\php',
        siteType: 'php',
        phpPort: 9084,
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\php.test\caddy_access.log',
      );

      expect(config, contains('php_fastcgi 127.0.0.1:9084'));
      expect(config, contains('file_server'));
    });

    test('builds reverse proxy without document-root directives', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'proxy.test',
        bindAddress: '127.0.0.1',
        rootDir: r'C:\Sites\unused',
        siteType: 'proxy',
        proxyTarget: 'http://127.0.0.1:3000',
        useSsl: false,
        accessLogPath: r'C:\Ponta\logs\proxy.test\caddy_access.log',
      );

      expect(config, contains('reverse_proxy http://127.0.0.1:3000'));
      expect(config, isNot(contains('root *')));
      expect(config, isNot(contains('file_server')));
    });

    test('serves explicit HTTP and HTTPS with supplied certificate', () {
      final config = CaddyConfigBuilder.siteConfig(
        domain: 'secure.test',
        bindAddress: '0.0.0.0',
        rootDir: r'C:\Sites\secure',
        siteType: 'static',
        useSsl: true,
        certPath: r'C:\Ponta\certs\secure.test.crt',
        keyPath: r'C:\Ponta\certs\secure.test.key',
        accessLogPath: r'C:\Ponta\logs\secure.test\caddy_access.log',
      );

      expect(config, startsWith('http://secure.test, https://secure.test {'));
      expect(config, contains('bind 0.0.0.0'));
      expect(config, contains('tls "C:/Ponta/certs/secure.test.crt"'));
    });

    test('rejects incomplete type-specific arguments', () {
      expect(
        () => CaddyConfigBuilder.siteConfig(
          domain: 'php.test',
          bindAddress: '127.0.0.1',
          rootDir: r'C:\Sites\php',
          siteType: 'php',
          useSsl: false,
          accessLogPath: r'C:\Ponta\logs\php.test\caddy_access.log',
        ),
        throwsArgumentError,
      );
      expect(
        () => CaddyConfigBuilder.siteConfig(
          domain: 'secure.test',
          bindAddress: '127.0.0.1',
          rootDir: r'C:\Sites\secure',
          siteType: 'static',
          useSsl: true,
          accessLogPath: r'C:\Ponta\logs\secure.test\caddy_access.log',
        ),
        throwsArgumentError,
      );
    });
  });

  test('builds phpMyAdmin route snippet', () {
    final config = CaddyConfigBuilder.phpMyAdminIntegration(
      rootDir: r'C:\Ponta\apps\phpMyAdmin',
      phpPort: 9084,
    );

    expect(config, contains('handle_path /phpmyadmin*'));
    expect(config, contains('root * "C:/Ponta/apps/phpMyAdmin"'));
    expect(config, contains('php_fastcgi 127.0.0.1:9084'));
    expect(config, contains('file_server'));
  });
}
```

- [ ] **Step 2: Run tests and verify compilation fails**

Run:

```bash
flutter test test/features/settings/webserver_bind_policy_test.dart test/core/config/caddy_config_builder_test.dart
```

Expected: compilation fails because Caddy policy methods and `CaddyConfigBuilder` do not exist.

- [ ] **Step 3: Add Caddy bind helpers**

Add to `WebserverBindPolicy` after `nginxListen`:

```dart
  static String caddyBind({required bool allowLanAccess}) =>
      address(allowLanAccess: allowLanAccess);

  static String caddySiteAddress(String domain, {required bool ssl}) =>
      '${ssl ? 'https' : 'http'}://$domain';
```

- [ ] **Step 4: Implement the pure Caddy configuration builder**

Create `lib/core/config/caddy_config_builder.dart`:

```dart
import 'webserver_bind_policy.dart';

abstract final class CaddyConfigBuilder {
  static String _path(String value) => value.replaceAll('\\', '/');

  static String _fileLog(String path, {String indent = '        '}) =>
      '''${indent}output file "${_path(path)}" {
${indent}    roll_size 10MiB
${indent}    roll_keep 5
${indent}    roll_keep_for 720h
$indent}''';

  static String mainConfig({
    required String webRoot,
    required String bindAddress,
    required String vhostsGlob,
    required String integrationsGlob,
    required String localhostAccessLogPath,
    required String runtimeErrorLogPath,
    String? certPath,
    String? keyPath,
  }) {
    if ((certPath == null) != (keyPath == null)) {
      throw ArgumentError('Certificate and key must be provided together');
    }
    final hasTls = certPath != null;
    final addresses = [
      WebserverBindPolicy.caddySiteAddress('localhost', ssl: false),
      if (hasTls)
        WebserverBindPolicy.caddySiteAddress('localhost', ssl: true),
    ].join(', ');
    final tls = hasTls
        ? '\n    tls "${_path(certPath!)}" "${_path(keyPath!)}"'
        : '';

    return '''{
    auto_https off
    log {
${_fileLog(runtimeErrorLogPath, indent: '        ')}
        format console
        level ERROR
        exclude http.log.access
    }
}

$addresses {
    bind $bindAddress$tls
    root * "${_path(webRoot)}"
    file_server
    log {
${_fileLog(localhostAccessLogPath, indent: '        ')}
        format console
    }
    import "${_path(integrationsGlob)}"
}

import "${_path(vhostsGlob)}"
''';
  }

  static String siteConfig({
    required String domain,
    required String bindAddress,
    required String rootDir,
    required String siteType,
    required bool useSsl,
    required String accessLogPath,
    int? phpPort,
    String? proxyTarget,
    String? certPath,
    String? keyPath,
  }) {
    if (!const {'static', 'php', 'proxy'}.contains(siteType)) {
      throw ArgumentError('Unsupported site type: $siteType');
    }
    if (siteType == 'php' && (phpPort == null || phpPort <= 0)) {
      throw ArgumentError('PHP sites require a valid FastCGI port');
    }
    if (siteType == 'proxy' && (proxyTarget == null || proxyTarget.isEmpty)) {
      throw ArgumentError('Proxy sites require a target');
    }
    if (useSsl && (certPath == null || keyPath == null)) {
      throw ArgumentError('SSL sites require a certificate and key');
    }

    final addresses = [
      WebserverBindPolicy.caddySiteAddress(domain, ssl: false),
      if (useSsl) WebserverBindPolicy.caddySiteAddress(domain, ssl: true),
    ].join(', ');
    final tls = useSsl
        ? '\n    tls "${_path(certPath!)}" "${_path(keyPath!)}"'
        : '';

    final handlers = switch (siteType) {
      'proxy' => '    reverse_proxy $proxyTarget',
      'php' => '''    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server''',
      _ => '''    root * "${_path(rootDir)}"
    file_server''',
    };

    return '''$addresses {
    bind $bindAddress$tls
$handlers
    log {
${_fileLog(accessLogPath, indent: '        ')}
        format console
    }
}
''';
  }

  static String phpMyAdminIntegration({
    required String rootDir,
    required int phpPort,
  }) =>
      '''handle_path /phpmyadmin* {
    root * "${_path(rootDir)}"
    php_fastcgi 127.0.0.1:$phpPort
    file_server
}
''';
}
```

- [ ] **Step 5: Format and run focused tests**

Run:

```bash
dart format lib/core/config/caddy_config_builder.dart lib/core/config/webserver_bind_policy.dart test/core/config/caddy_config_builder_test.dart test/features/settings/webserver_bind_policy_test.dart
flutter test test/core/config/caddy_config_builder_test.dart test/features/settings/webserver_bind_policy_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/config/caddy_config_builder.dart lib/core/config/webserver_bind_policy.dart test/core/config/caddy_config_builder_test.dart test/features/settings/webserver_bind_policy_test.dart
git commit -m "feat: add Caddy configuration builders"
```

---

### Task 4: Wire Caddy into installation and phpMyAdmin integration

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart:13-18,200-206,676-756,1036-1054,1362-1451,1453-1517`
- Modify: `lib/features/apps/data/apps_provider.dart:92-108`
- Modify: `lib/features/apps/presentation/widgets/app_settings_modal.dart:15`
- Create: `test/features/apps/caddy_installer_policy_test.dart`

**Interfaces:**
- Consumes: `CaddyConfigBuilder`, `AppConfig`, `sslServiceProvider`, `settingsNotifierProvider`, and `AppInstallerService.phpPortFor`.
- Produces: `<installPath>\Caddyfile`, `vhosts\caddy`, `vhosts\caddy\integrations\phpmyadmin.conf`, and `AppInstallerService.isWebserverApp(AppModel)`.

- [ ] **Step 1: Write the failing installer policy test**

Create `test/features/apps/caddy_installer_policy_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppModel app(String id, {String? group}) => AppModel(
  appId: id,
  name: id,
  categories: const ['webserver'],
  groupName: group,
);

void main() {
  test('installer recognizes Caddy as a managed web server', () {
    expect(AppInstallerService.isWebserverApp(app('caddy', group: 'webserver')), isTrue);
    expect(AppInstallerService.isWebserverApp(app('nginx')), isTrue);
    expect(AppInstallerService.isWebserverApp(app('apache')), isTrue);
    expect(AppInstallerService.isWebserverApp(app('redis', group: 'redis')), isFalse);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
flutter test test/features/apps/caddy_installer_policy_test.dart
```

Expected: compilation fails because `isWebserverApp` is not defined.

- [ ] **Step 3: Add shared filtering and Caddy directory creation**

Import the builder:

```dart
import '../../../core/config/caddy_config_builder.dart';
```

Add inside `AppInstallerService` after the constructor:

```dart
  @visibleForTesting
  static bool isWebserverApp(AppModel app) {
    final id = app.appId.toLowerCase();
    return app.groupName == 'webserver' ||
        id.contains('nginx') ||
        id.contains('apache') ||
        id.contains('caddy');
  }
```

Replace the post-install condition with:

```dart
      if (isWebserverApp(app)) {
        onProgress?.call(0.97, 'Configuring web server...');
        await _configureWebserver(app, installPath, logInfo);
      }
```

In `_configureWebserver`, create Caddy directories alongside nginx/apache:

```dart
    final caddyVhosts = Directory(p.join(AppConfig.vhostsDir, 'caddy'));
    final caddyIntegrations = Directory(
      p.join(caddyVhosts.path, 'integrations'),
    );
    for (final dir in [caddyVhosts, caddyIntegrations]) {
      if (!dir.existsSync()) {
        logInfo('Creating Caddy directory: ${dir.path}');
        await dir.create(recursive: true);
      }
    }

    final logsDir = Directory(AppConfig.logsDir);
    final localhostLogs = Directory(p.join(AppConfig.logsDir, 'localhost'));
    for (final dir in [logsDir, localhostLogs]) {
      if (!dir.existsSync()) await dir.create(recursive: true);
    }
```

- [ ] **Step 4: Generate the main Caddyfile**

Add after the nginx branch and before Apache:

```dart
    } else if (app.appId.toLowerCase().contains('caddy')) {
      final caddyFile = File(p.join(installPath, 'Caddyfile'));
      final certPath = sslNotifier.getSiteCertPath('localhost');
      final keyPath = sslNotifier.getSiteKeyPath('localhost');
      final config = CaddyConfigBuilder.mainConfig(
        webRoot: webRoot,
        bindAddress: bindAddress,
        vhostsGlob: p.join(AppConfig.vhostsDir, 'caddy', '*.conf'),
        integrationsGlob: p.join(
          AppConfig.vhostsDir,
          'caddy',
          'integrations',
          '*.conf',
        ),
        localhostAccessLogPath: p.join(
          AppConfig.logsDir,
          'localhost',
          'caddy_access.log',
        ),
        runtimeErrorLogPath: p.join(AppConfig.logsDir, 'caddy_error.log'),
        certPath: isSslInstalled ? certPath : null,
        keyPath: isSslInstalled ? keyPath : null,
      );
      await caddyFile.writeAsString(config);
      logInfo('Caddyfile generated successfully.');
```

Keep the existing Apache branch as the final `else if`.

- [ ] **Step 5: Include Caddy in reconfiguration and inter-app filtering**

Replace the filter in `reconfigureWebservers` with:

```dart
    final webServers = allApps
        .where((app) => app.isInstalled && isWebserverApp(app))
        .toList();
```

Replace `isWebServer` in `syncInterAppConfigs` with:

```dart
    final isWebServer = isWebserverApp(currentApp);
```

Replace the installed webserver query with:

```dart
      webServers = allApps
          .where((app) => app.isInstalled && isWebserverApp(app))
          .toList();
```

Add to the dispatch loop:

```dart
        } else if (ws.appId.contains('caddy')) {
          await _configurePhpMyAdminInCaddy(ws, phpMyAdmin, bestPhp, log);
```

- [ ] **Step 6: Accept Caddy where any web server is required**

In `apps_provider.dart`, the phpMyAdmin prereq check currently looks at `a.categories.contains('webserver')`, which already includes Caddy. The only hard-coded check is the user-facing error message. Replace the error construction block so the message names Caddy too:

```dart
          if (!hasWebServer || !hasPhp) {
            final error = !hasWebServer
                ? 'Please install Nginx, Apache, or Caddy first.'
                : 'Please install at least one PHP version first.';
            app.addLog('Error: $error');
            throw Exception(error);
          }
```

`app_settings_modal.dart` already returns `webserverConfigFileFor(app)?.path` for `_isWebserver` (Task 7), so no further change is needed there in this task.

Add after `_configurePhpMyAdminInNginx`:

```dart
  Future<void> _configurePhpMyAdminInCaddy(
    AppModel caddy,
    AppModel pma,
    AppModel? php,
    Function(String) log,
  ) async {
    if (caddy.location == null || pma.location == null) return;

    final integrationsDir = Directory(
      p.join(AppConfig.vhostsDir, 'caddy', 'integrations'),
    );
    if (!integrationsDir.existsSync()) {
      await integrationsDir.create(recursive: true);
    }

    var phpPort = 9000;
    if (php != null) {
      phpPort = int.tryParse(php.extraInfo['port']?.toString() ?? '') ??
          AppInstallerService.phpPortFor(php.appId);
    }

    final pmaRoot = _resolvePmaWebRoot(pma.location!);
    final config = CaddyConfigBuilder.phpMyAdminIntegration(
      rootDir: pmaRoot,
      phpPort: phpPort,
    );
    final configFile = File(
      p.join(integrationsDir.path, 'phpmyadmin.conf'),
    );
    await configFile.writeAsString(config);
    log(
      'Created Caddy config for phpMyAdmin at ${configFile.path} '
      '(PHP Port: $phpPort)',
    );
  }
```

- [ ] **Step 8: Run focused and existing PHP-port tests**

Run:

```bash
dart format lib/features/apps/data/app_installer_service.dart lib/features/apps/data/apps_provider.dart test/features/apps/caddy_installer_policy_test.dart
flutter test test/features/apps/caddy_installer_policy_test.dart test/features/apps/php_port_test.dart test/core/config/caddy_config_builder_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart lib/features/apps/data/apps_provider.dart test/features/apps/caddy_installer_policy_test.dart
git commit -m "feat: configure Caddy installations"
```

---

### Task 5: Manage the Caddy process lifecycle

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart:216-367`
- Create: `test/features/apps/caddy_service_policy_test.dart`
- Modify: `test/features/apps/port_conflict_test.dart`

**Interfaces:**
- Consumes: Caddy install directory and executable basename.
- Produces: `AppServiceManager.argumentsForExecutable`, `runsDetachedExecutable`, and `requiredSocketsForExecutable` testable policies; runtime command `caddy.exe run --config <install>\Caddyfile --adapter caddyfile`.

- [ ] **Step 1: Write failing process-policy tests**

Create `test/features/apps/caddy_service_policy_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Caddy service policy', () {
    test('runs Caddy in foreground mode under managed launcher', () {
      expect(AppServiceManager.runsDetachedExecutable('caddy.exe'), isTrue);
      expect(AppServiceManager.runsDetachedExecutable('CADDY.EXE'), isTrue);
    });

    test('passes explicit Caddyfile adapter arguments', () {
      final args = AppServiceManager.argumentsForExecutable(
        'caddy.exe',
        r'C:\Ponta\apps\caddy\2.11.4',
      );

      expect(args, [
        'run',
        '--config',
        p.join(r'C:\Ponta\apps\caddy\2.11.4', 'Caddyfile'),
        '--adapter',
        'caddyfile',
      ]);
    });

    test('preflights HTTP and HTTPS on every interface', () {
      expect(
        AppServiceManager.requiredSocketsForExecutable('caddy.exe'),
        [
          (host: '*', port: 80),
          (host: '*', port: 443),
        ],
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
flutter test test/features/apps/caddy_service_policy_test.dart
```

Expected: compilation fails because the three policy helpers do not exist.

- [ ] **Step 3: Add testable launch-policy helpers**

Add inside `AppServiceManager` near the existing static parsing helpers:

```dart
  @visibleForTesting
  static bool runsDetachedExecutable(String fileName) => const {
    'nginx.exe',
    'httpd.exe',
    'apache.exe',
    'caddy.exe',
  }.contains(fileName.toLowerCase());

  @visibleForTesting
  static List<String> argumentsForExecutable(
    String fileName,
    String workingDir,
  ) {
    if (fileName.toLowerCase() == 'caddy.exe') {
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
    if (fileName.toLowerCase() != 'caddy.exe') return const [];
    return [(host: '*', port: 80), (host: '*', port: 443)];
  }
```

- [ ] **Step 4: Use the helpers in `start()`**

Immediately after determining `fileName`, initialize Caddy arguments:

```dart
      List<String> args = argumentsForExecutable(fileName, workingDir);
```

Remove the earlier duplicate `List<String> args = [];` declaration. Before `_checkPortConflicts`, append Caddy sockets:

```dart
      requiredSockets.addAll(requiredSocketsForExecutable(fileName));

      final runsDetached = runsDetachedExecutable(fileName);
```

Replace the existing hardcoded `runsDetached` expression. Keep `BackgroundProcess.start` and generic stop/restart/dispose code unchanged.

- [ ] **Step 5: Run service and port tests**

Run:

```bash
dart format lib/features/apps/data/app_service_manager.dart test/features/apps/caddy_service_policy_test.dart
flutter test test/features/apps/caddy_service_policy_test.dart test/features/apps/port_conflict_test.dart test/features/apps/service_manager_disposed_test.dart test/features/apps/force_kill_pid_tree_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/apps/data/app_service_manager.dart test/features/apps/caddy_service_policy_test.dart
git commit -m "feat: manage Caddy service lifecycle"
```

---

### Task 6: Generate and manage per-site Caddy vhosts

**Files:**
- Modify: `lib/features/sites/data/sites_provider.dart:14,65-166,563-634,688-867,911-948`
- Create: `test/features/sites/caddy_vhost_paths_test.dart`
- Modify: `test/features/sites/proxy_target_test.dart:32`
- Modify: `test/features/sites/root_dir_test.dart`

**Interfaces:**
- Consumes: `CaddyConfigBuilder.siteConfig`, validated `SiteModel` fields, SSL paths, and LAN-access settings.
- Produces: `SitesNotifier.editableWebserverTypes`, `SitesNotifier.vhostConfigPath`, `vhosts\caddy\<domain>.conf`, Caddy config map entry, and Caddy log map entries.

- [ ] **Step 1: Write failing vhost path/type tests**

Create `test/features/sites/caddy_vhost_paths_test.dart`:

```dart
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Caddy vhost file policy', () {
    test('Caddy is an editable webserver config type', () {
      expect(
        SitesNotifier.editableWebserverTypes,
        equals({'nginx', 'apache', 'caddy'}),
      );
    });

    test('resolves Caddy config inside the managed vhosts directory', () {
      expect(
        SitesNotifier.vhostConfigPath('caddy', 'example.test'),
        p.join(AppConfig.vhostsDir, 'caddy', 'example.test.conf'),
      );
    });

    test('rejects unknown config types and traversal domains', () {
      expect(
        () => SitesNotifier.vhostConfigPath('iis', 'example.test'),
        throwsArgumentError,
      );
      expect(
        () => SitesNotifier.vhostConfigPath('caddy', '../escape'),
        throwsArgumentError,
      );
    });
  });
}
```

In `proxy_target_test.dart`, rename the directive test to mention all supported servers:

```dart
    test('rejects characters that break nginx, Apache, or Caddy directives', () {
```

Keep all existing assertions; braces are already rejected and therefore cover Caddyfile block injection.

- [ ] **Step 2: Run tests and verify the new test fails**

Run:

```bash
flutter test test/features/sites/caddy_vhost_paths_test.dart test/features/sites/proxy_target_test.dart test/features/sites/root_dir_test.dart
```

Expected: compilation fails because `editableWebserverTypes` and `vhostConfigPath` do not exist.

- [ ] **Step 3: Add safe type/path helpers and import the builder**

Import:

```dart
import '../../../core/config/caddy_config_builder.dart';
```

Add near the validator helpers:

```dart
  @visibleForTesting
  static const Set<String> editableWebserverTypes = {
    'nginx',
    'apache',
    'caddy',
  };

  @visibleForTesting
  static String vhostConfigPath(String type, String domain) {
    validateDomain(domain);
    if (!editableWebserverTypes.contains(type)) {
      throw ArgumentError('Unsupported webserver config type: $type');
    }
    return p.join(AppConfig.vhostsDir, type, '$domain.conf');
  }
```

Update validator comments to say nginx/Apache/Caddy and retain the existing character rules.

- [ ] **Step 4: Extend file accessors and logs**

Replace `getConfigs` with:

```dart
  Future<Map<String, String>> getConfigs(SiteModel site) async {
    final result = <String, String>{};
    for (final type in editableWebserverTypes) {
      final file = File(vhostConfigPath(type, site.domain));
      result[type] = await file.exists() ? await file.readAsString() : '';
    }
    return result;
  }
```

Replace the type selection in `saveConfig` with:

```dart
    final file = File(vhostConfigPath(type, site.domain));
```

Extend `getLogs`:

```dart
    final cAccess = File(p.join(logsDir, 'caddy_access.log'));
    final cError = File(p.join(AppConfig.logsDir, 'caddy_error.log'));
```

Add to the returned map:

```dart
      'caddy_access': await readLastLines(cAccess),
      'caddy_error': await readLastLines(cError),
```

- [ ] **Step 5: Generate the Caddy vhost**

Create the Caddy directory beside nginx/apache:

```dart
    final caddyDir = Directory(p.join(AppConfig.vhostsDir, 'caddy'));
    if (!caddyDir.existsSync()) await caddyDir.create(recursive: true);
```

After writing the Apache config, add:

```dart
    // --- 3. Caddy Vhost ---
    final caddyVhostFile = File(vhostConfigPath('caddy', site.domain));
    final certPath = site.useSsl
        ? sslNotifier.getSiteCertPath(site.domain)
        : null;
    final keyPath = site.useSsl
        ? sslNotifier.getSiteKeyPath(site.domain)
        : null;
    final safeTarget = site.siteType == 'proxy'
        ? validateProxyTarget(site.proxyTarget ?? '')
        : null;
    final caddyConfig = CaddyConfigBuilder.siteConfig(
      domain: validateDomain(site.domain),
      bindAddress: WebserverBindPolicy.caddyBind(
        allowLanAccess: allowLanAccess,
      ),
      rootDir: rootDirUnix,
      siteType: site.siteType,
      phpPort: site.phpPort,
      proxyTarget: safeTarget,
      useSsl: site.useSsl,
      certPath: certPath,
      keyPath: keyPath,
      accessLogPath: p.join(logsDir.path, 'caddy_access.log'),
    );
    await caddyVhostFile.writeAsString(caddyConfig);
```

- [ ] **Step 6: Delete Caddy vhosts and restart Caddy**

In `_removeVhostFiles`, delete all managed config types before SSL/log cleanup:

```dart
    for (final type in editableWebserverTypes) {
      final file = File(vhostConfigPath(type, site.domain));
      if (file.existsSync()) await file.delete();
    }
```

Remove the old duplicated nginx/apache delete blocks.

Extend the `restartWebservers()` filter:

```dart
                (a.appId.contains('nginx') ||
                    a.appId.contains('apache') ||
                    a.appId.contains('caddy')),
```

- [ ] **Step 7: Run site and builder tests**

Run:

```bash
dart format lib/features/sites/data/sites_provider.dart test/features/sites/caddy_vhost_paths_test.dart test/features/sites/proxy_target_test.dart
flutter test test/features/sites/caddy_vhost_paths_test.dart test/features/sites/proxy_target_test.dart test/features/sites/root_dir_test.dart test/core/config/caddy_config_builder_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/sites/data/sites_provider.dart test/features/sites/caddy_vhost_paths_test.dart test/features/sites/proxy_target_test.dart
git commit -m "feat: generate Caddy site configurations"
```

---

### Task 7: Expose Caddy config, logs, and visuals in the UI

**Files:**
- Modify: `lib/features/apps/data/webserver_settings_provider.dart:1-44`
- Modify: `lib/features/apps/presentation/widgets/app_settings_modal.dart:15,58-61,196-205,465-471`
- Modify: `lib/features/apps/presentation/widgets/app_version_modal.dart:31-84`
- Modify: `lib/features/apps/presentation/widgets/compact_apps_table.dart:33-109`
- Create: `lib/features/sites/presentation/site_editor_options.dart`
- Modify: `lib/features/sites/presentation/widgets/edit_site_modal.dart:562-565,860-866`
- Modify: `lib/shared/widgets/code_editor/language_for_config.dart:23-27`
- Create: `test/features/apps/webserver_config_path_test.dart`
- Create: `test/features/sites/site_editor_options_test.dart`
- Modify: `test/shared/widgets/code_editor/language_for_config_test.dart:11-77`

**Interfaces:**
- Consumes: Caddy catalog app and site config/log map keys from Task 6.
- Produces: `webserverConfigFileFor(AppModel)`, `siteConfigEditorOptions`, `siteLogOptions`, and Caddyfile plaintext highlighting.

- [ ] **Step 1: Write failing config-path, editor-option, and highlighting tests**

Create `test/features/apps/webserver_config_path_test.dart`:

```dart
import 'package:dev_stack/features/apps/data/webserver_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolves Caddyfile at the Caddy install root', () {
    final app = AppModel(
      appId: 'caddy',
      name: 'Caddy',
      categories: const ['webserver'],
      groupName: 'webserver',
      location: r'C:\Ponta\apps\caddy\2.11.4',
    );

    expect(
      webserverConfigFileFor(app)?.path,
      p.join(r'C:\Ponta\apps\caddy\2.11.4', 'Caddyfile'),
    );
  });
}
```

Create `test/features/sites/site_editor_options_test.dart`:

```dart
import 'package:dev_stack/features/sites/presentation/site_editor_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('site config editor exposes Caddy', () {
    expect(
      siteConfigEditorOptions,
      contains((id: 'caddy', label: 'Caddy')),
    );
  });

  test('site log selector exposes Caddy access and runtime logs', () {
    expect(
      siteLogOptions,
      containsAll([
        (id: 'caddy_access', label: 'Caddy Access'),
        (id: 'caddy_error', label: 'Caddy Runtime'),
      ]),
    );
  });
}
```

Add to `language_for_config_test.dart`:

```dart
    test('maps Caddyfile to plaintext because no Caddy grammar is bundled', () {
      expect(
        languageForConfigPath(r'C:\apps\caddy\Caddyfile'),
        same(langPlaintext),
      );
    });
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
flutter test test/features/apps/webserver_config_path_test.dart test/features/sites/site_editor_options_test.dart test/shared/widgets/code_editor/language_for_config_test.dart
```

Expected: compilation fails because the resolver and options file do not exist; the Caddyfile highlighting assertion fails before the filename mapping is added.

- [ ] **Step 3: Share config path resolution**

In `webserver_settings_provider.dart`, add a top-level resolver before the provider annotation:

```dart
@visibleForTesting
File? webserverConfigFileFor(AppModel app) {
  if (app.location == null) return null;
  final appId = app.appId.toLowerCase();
  final location = app.location!;

  if (appId.contains('nginx')) {
    return File(p.join(location, 'conf', 'nginx.conf'));
  }
  if (appId.contains('caddy')) {
    return File(p.join(location, 'Caddyfile'));
  }
  if (appId.contains('apache')) {
    final nestedPath = p.join(location, 'Apache24', 'conf', 'httpd.conf');
    if (File(nestedPath).existsSync()) return File(nestedPath);
    return File(p.join(location, 'conf', 'httpd.conf'));
  }
  return null;
}
```

Add:

```dart
import 'package:flutter/foundation.dart' show visibleForTesting;
```

Replace `_getConfigFile` with:

```dart
  File? _getConfigFile(AppModel app) => webserverConfigFileFor(app);
```

Import the provider in `app_settings_modal.dart`:

```dart
import '../../data/webserver_settings_provider.dart';
```

Replace the webserver branch in `_getConfigFilePath`:

```dart
    if (_isWebserver) return webserverConfigFileFor(app)?.path;
```

Replace `_configTabLabel` webserver branch — Caddy must come before nginx so the substring test does not match a hypothetical `caddy-nginx` id:

```dart
    if (_isWebserver) {
      final id = widget.app.appId.toLowerCase();
      if (id.contains('caddy')) return 'Caddyfile';
      if (id.contains('nginx')) return 'nginx.conf';
      return 'httpd.conf';
    }
```

- [ ] **Step 4: Add editor options and use them in the site modal**

Create `lib/features/sites/presentation/site_editor_options.dart`:

```dart
const siteConfigEditorOptions = <({String id, String label})>[
  (id: 'nginx', label: 'Nginx'),
  (id: 'apache', label: 'Apache'),
  (id: 'caddy', label: 'Caddy'),
];

const siteLogOptions = <({String id, String label})>[
  (id: 'nginx_access', label: 'Nginx Access'),
  (id: 'nginx_error', label: 'Nginx Error'),
  (id: 'apache_access', label: 'Apache Access'),
  (id: 'apache_error', label: 'Apache Error'),
  (id: 'caddy_access', label: 'Caddy Access'),
  (id: 'caddy_error', label: 'Caddy Runtime'),
];
```

Import it in `edit_site_modal.dart`:

```dart
import '../site_editor_options.dart';
```

Replace the hardcoded config buttons with:

```dart
              for (var i = 0; i < siteConfigEditorOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildTypeButton(
                  siteConfigEditorOptions[i].id,
                  siteConfigEditorOptions[i].label,
                ),
              ],
```

Replace `_buildLogSelect`'s hardcoded map list with a horizontal scroll container that always renders the six chips from `siteLogOptions`:

```dart
  Widget _buildLogSelect() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: siteLogOptions.map((item) {
          final isSelected = _selectedLog == item.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.label),
              selected: isSelected,
              onSelected: (value) {
                if (value) setState(() => _selectedLog = item.id);
              },
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
```

- [ ] **Step 5: Add Caddy highlighting and visual mappings**

In `language_for_config.dart`, add after the nginx/httpd filename mappings:

```dart
  if (name == 'caddyfile') return langPlaintext;
```

In both `app_version_modal.dart::_getIconFileName` and `compact_apps_table.dart::_getIconFileName`, **add Caddy before the nginx case** so the `appId.contains('nginx')` branch does not match a Caddy app id:

```dart
    if (id.contains('caddy')) return 'caddy';
    if (id.contains('nginx')) return 'nginx';
```

In `app_version_modal.dart::_getIconColor`, add Caddy alongside nginx:

```dart
    } else if (widget.app.appId.contains('caddy')) {
      return const Color(0xFF1F8C5B);
    } else if (widget.app.appId.contains('nginx')) {
      return const Color(0xFF009639);
    }
```

In `compact_apps_table.dart::_getIconColor`, add Caddy before the nginx-derived branches:

```dart
    if (appId.contains('caddy')) {
      return const Color(0xFF1F8C5B);
    }
    if (appId.contains('nginx') && appId.contains('waf')) {
      return const Color(0xFF4169E1);
    }
```

In both widgets, add a Caddy fallback icon (`Icons.dns`) to `_getAppIcon` before the generic `Icons.apps` fallback:

```dart
    if (appId.contains('caddy')) return Icons.dns;
```

- [ ] **Step 6: Format, test, and analyze the affected UI**

Run:

```bash
dart format lib/features/apps/data/webserver_settings_provider.dart lib/features/apps/presentation/widgets/app_settings_modal.dart lib/features/apps/presentation/widgets/app_version_modal.dart lib/features/apps/presentation/widgets/compact_apps_table.dart lib/features/sites/presentation/site_editor_options.dart lib/features/sites/presentation/widgets/edit_site_modal.dart lib/shared/widgets/code_editor/language_for_config.dart test/features/apps/webserver_config_path_test.dart test/features/sites/site_editor_options_test.dart test/shared/widgets/code_editor/language_for_config_test.dart
flutter test test/features/apps/webserver_config_path_test.dart test/features/sites/site_editor_options_test.dart test/shared/widgets/code_editor/language_for_config_test.dart test/features/apps/app_conflict_policy_test.dart
flutter analyze
```

Expected: focused tests PASS and analysis reports `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/apps/data/webserver_settings_provider.dart lib/features/apps/presentation/widgets/app_settings_modal.dart lib/features/apps/presentation/widgets/app_version_modal.dart lib/features/apps/presentation/widgets/compact_apps_table.dart lib/features/sites/presentation/site_editor_options.dart lib/features/sites/presentation/widgets/edit_site_modal.dart lib/shared/widgets/code_editor/language_for_config.dart test/features/apps/webserver_config_path_test.dart test/features/sites/site_editor_options_test.dart test/shared/widgets/code_editor/language_for_config_test.dart
git commit -m "feat: expose Caddy settings and site controls"
```

---

### Task 8: Validate real Caddy syntax, align documentation, and run the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-08-14-caddy-webserver-design.md`
- Temporary only (do not commit): `build/caddy-smoke/`

**Interfaces:**
- Consumes: Caddy 2.11.4 Windows amd64 binary and the syntax emitted by `CaddyConfigBuilder`.
- Produces: externally validated Caddyfile syntax, updated design documentation, clean analysis/tests, and a successful Windows debug build.

- [ ] **Step 1: Update the design document with verified details**

Replace the illustrative `2.10.0` catalog entry with the exact five-version map from Task 1. Clarify these statements:

```markdown
- The main Caddyfile imports absolute, forward-slash-normalized globs under
  `AppConfig.vhostsDir`; the vhosts directory is not relative to the Caddy
  installation directory.
- Site access logs are per-domain at `logs/<domain>/caddy_access.log`.
- Caddy runtime/error logs are shared at `logs/caddy_error.log` because Caddy's
  global runtime logger cannot route entries by HTTP hostname.
- The phpMyAdmin integration glob is imported inside the localhost site block,
  so each integration file contains route directives rather than another site
  block.
```

Remove the old statement that Caddy writes a per-site `caddy_error.log` and remove the release-URL verification placeholder.

- [ ] **Step 2: Download Caddy 2.11.4 into a disposable validation directory**

Run from the repository root:

```bash
powershell.exe -NoProfile -Command '$ErrorActionPreference="Stop"; $dir="build/caddy-smoke"; Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; New-Item $dir -ItemType Directory | Out-Null; Invoke-WebRequest "https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_windows_amd64.zip" -OutFile "$dir/caddy.zip"; Expand-Archive "$dir/caddy.zip" -DestinationPath $dir -Force; & "$dir/caddy.exe" version'
```

Expected: output reports Caddy `v2.11.4`.

- [ ] **Step 3: Validate the exact configuration shape with the real Caddy adapter**

Create disposable fixture directories and files through PowerShell:

```bash
powershell.exe -NoProfile -Command '$ErrorActionPreference="Stop"; $dir=(Resolve-Path "build/caddy-smoke").Path; New-Item "$dir/vhosts/integrations" -ItemType Directory -Force | Out-Null; New-Item "$dir/www" -ItemType Directory -Force | Out-Null; New-Item "$dir/logs/localhost" -ItemType Directory -Force | Out-Null; @"
{
    auto_https off
    log {
        output file "$($dir.Replace("\","/"))/logs/caddy_error.log"
        format console
        level ERROR
        exclude http.log.access
    }
}
http://localhost {
    bind 127.0.0.1
    root * "$($dir.Replace("\","/"))/www"
    file_server
    log {
        output file "$($dir.Replace("\","/"))/logs/localhost/caddy_access.log"
        format console
    }
    import "$($dir.Replace("\","/"))/vhosts/integrations/*.conf"
}
import "$($dir.Replace("\","/"))/vhosts/*.conf"
"@ | Set-Content "$dir/Caddyfile" -Encoding utf8; @"
http://example.test {
    bind 127.0.0.1
    root * "$($dir.Replace("\","/"))/www"
    file_server
}
"@ | Set-Content "$dir/vhosts/example.test.conf" -Encoding utf8; & "$dir/caddy.exe" validate --config "$dir/Caddyfile" --adapter caddyfile'
```

Expected: `Valid configuration` and exit code 0. If the adapter rejects syntax, correct `CaddyConfigBuilder` and its expected strings, rerun focused tests, then repeat this command before continuing.

- [ ] **Step 4: Run formatting, the full test suite, analysis, and Windows build**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter analyze
flutter build windows --debug
```

Expected:
- Formatter exits 0 with no changed files.
- All tests pass; the existing Isar-native repository test remains the only allowed skip.
- `flutter analyze` reports `No issues found!`.
- Windows debug build completes successfully under `build/windows/x64/runner/Debug/`.

- [ ] **Step 5: Inspect the final diff for accidental scope growth**

Run:

```bash
git status --short
git diff --stat HEAD~7
git diff --check
```

Expected: only files listed in this plan are changed; `git diff --check` emits no whitespace errors. Do not commit `build/caddy-smoke/` (the build directory is ignored).

- [ ] **Step 6: Commit documentation alignment**

```bash
git add docs/superpowers/specs/2026-08-14-caddy-webserver-design.md
git commit -m "docs: align Caddy design with implementation"
```

- [ ] **Step 7: Request final code review**

Invoke `superpowers:requesting-code-review` against the complete Caddy change set. Address confirmed correctness regressions, rerun Step 4 after fixes, and only then report completion.

## Official References

- Caddy stable releases: `https://api.github.com/repos/caddyserver/caddy/releases?per_page=10`
- Caddy command line (`run`, `reload`, `validate`): `https://caddyserver.com/docs/command-line`
- Caddy `import` directive: `https://caddyserver.com/docs/caddyfile/directives/import`
- Caddy access logging: `https://caddyserver.com/docs/caddyfile/directives/log`
- Caddy global/runtime logging: `https://caddyserver.com/docs/caddyfile/options#log`
- Caddy `php_fastcgi`: `https://caddyserver.com/docs/caddyfile/directives/php_fastcgi`
- Caddy automatic HTTPS behavior: `https://caddyserver.com/docs/automatic-https`
