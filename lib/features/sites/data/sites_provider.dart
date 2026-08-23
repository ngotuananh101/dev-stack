import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/site_model.dart';
import '../domain/batch_models.dart';
import 'package:isar/isar.dart';
import '../../apps/data/apps_provider.dart';
import '../../apps/data/app_installer_service.dart';
import '../../../core/services/ssl_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/caddy_config_builder.dart';
import '../../../core/config/webserver_bind_policy.dart';
import '../../settings/data/settings_provider.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../../core/services/log_service.dart';
import '../../../shared/utils/bounded_runner.dart';

part 'sites_provider.g.dart';

@riverpod
class SitesNotifier extends _$SitesNotifier {
  final _hostsRepo = HostsRepository();

  /// Coalesces overlapping webserver restarts. Without this, a batch create or
  /// a rapid sequence of add/edit/delete calls would spawn several concurrent
  /// `restartService` loops on the same webservers — racing for ports and
  /// thrashing the process tree. The first caller does the work; concurrent
  /// callers await the same future and get the same outcome.
  Completer<void>? _restartCompleter;

  /// Extracts a display version like `8.2` from a PHP app id like `php82`.
  ///
  /// The legacy code used `RegExp(r'\d+').firstMatch(phpAppId)` which yielded
  /// `"82"` — and `site_table.dart` then rendered `PHP 82`. This helper inserts
  /// the dot: a 2-digit run becomes `8.2`, a 3-digit run becomes `8.2.1`,
  /// and an already-dotted run (`php8.2`) is passed through. Returns null when
  /// the id carries no digits.
  @visibleForTesting
  static String? phpVersionFromAppId(String phpAppId) {
    final match = RegExp(r'[\d.]+').firstMatch(phpAppId);
    if (match == null) return null;
    var digits = match.group(0)!;
    if (digits.isEmpty) return null;
    // Already dotted (e.g. "8.2") — normalize away repeated/trailing dots.
    if (digits.contains('.')) {
      return digits
          .replaceAll(RegExp(r'\.+'), '.')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    // Bare digit run: split into major.minor(.patch). PHP app ids in this
    // project are 2-digit (php82, php74) -> "8.2", "7.4". A 3-digit run is
    // treated as major.minor.patch (php821 -> "8.2.1").
    if (digits.length <= 1) return digits;
    if (digits.length == 2) {
      return '${digits[0]}.${digits[1]}';
    }
    final major = digits[0];
    final minor = digits[1];
    final patch = digits.substring(2);
    return '$major.$minor.$patch';
  }

  /// Validates a domain name to prevent config injection and path traversal.
  ///
  /// A domain is used to build vhost/SSL file names (`<domain>.conf`,
  /// `<domain>.crt`, `<domain>.key`) and is interpolated into webserver
  /// directives. It must therefore be a bare hostname: no path separators, no
  /// dots used as a directory component (`..`), no file extension dot-pattern,
  /// and no characters that could break a directive.
  ///
  /// Returns the domain on success; throws [ArgumentError] otherwise. This is
  /// the data-layer guard used at create/batch time AND re-checked whenever a
  /// stored domain is used to derive a file path (e.g. saveConfig/saveSslFile)
  /// — a record that predates validation, or one mutated by another caller,
  /// is re-validated before it can reach the filesystem.
  @visibleForTesting
  static String validateDomain(String domain) {
    if (domain.isEmpty || domain.length > 253) {
      throw ArgumentError('Invalid domain: "$domain"');
    }
    final ok = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$',
    ).hasMatch(domain);
    if (!ok) {
      throw ArgumentError('Invalid domain: "$domain"');
    }
    return domain;
  }

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

  /// Validates domain name to prevent config injection
  bool _isValidDomain(String domain) {
    try {
      validateDomain(domain);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Validates and clamps PHP port to valid range
  int _safePhpPort(String? phpAppId) {
    if (phpAppId == null) return 9000;
    return AppInstallerService.phpPortFor(phpAppId);
  }

  /// Validates a proxy target before it is interpolated into nginx
  /// ``proxy_pass`` / Apache ``ProxyPass`` / Caddy ``reverse_proxy``. The value
  /// must be a syntactically valid http(s) URL and must not contain any
  /// character that could terminate or branch a webserver directive (newline,
  /// semicolon, braces, control chars). This is the data-layer guard; the UI
  /// validator is a convenience only — a stored value from before validation,
  /// or any other caller, is re-checked here and again at config-generation time.
  static String validateProxyTarget(String value) {
    if (value.isEmpty) {
      throw ArgumentError('Proxy target must not be empty');
    }
    // No whitespace/control or directive-breaking characters may appear.
    // Allowed: visible ASCII (0x21..0x7E) minus the nginx/Apache/Caddy
    // metacharacters ';', '{', '}'.
    final ok =
        RegExp(r'^[\x21-\x7E]+$').hasMatch(value) &&
        !value.contains(RegExp(r'[;{}\x00-\x1F\x7F]'));
    if (!ok) {
      throw ArgumentError(
        'Proxy target contains illegal characters (whitespace, control, '
        '";", "{", or "}")',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError('Proxy target must be a valid URL with a host');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError(
        'Proxy target scheme must be http or https (got "$scheme")',
      );
    }
    return value;
  }

  /// Validates a site root directory before it is interpolated into nginx
  /// ``root "..."`` / Apache ``DocumentRoot "..."`` / Caddy ``root * "..."``.
  /// A double quote, newline, or other control character could terminate the
  /// quoted directive and inject a new webserver directive, so they are
  /// rejected here at the data layer (the UI's existsSync check is a
  /// convenience only). Windows MAX_PATH is 260; we cap at 248 to leave room
  /// for appended segments.
  static String validateRootDir(String value) {
    if (value.isEmpty) {
      throw ArgumentError('Root directory must not be empty');
    }
    if (value.length > 248) {
      throw ArgumentError('Root directory path is too long (max 248)');
    }
    // Reject any character that could break out of the double-quoted
    // directive: double-quote, backtick, or any control char (newline, CR,
    // tab, NUL, ...).
    if (value.contains(RegExp(r'["`\x00-\x1F\x7F]'))) {
      throw ArgumentError(
        'Root directory contains illegal characters (quotes, backtick, or '
        'control characters)',
      );
    }
    return value;
  }

  @override
  Future<List<SiteModel>> build() async {
    final isar = await ref.watch(isarProvider.future);
    return isar.siteModels.where().sortByCreatedAtDesc().findAll();
  }

  Future<void> addSite({
    required String domain,
    required String rootDir,
    required String siteType,
    String? phpAppId,
    String? proxyTarget,
    required bool useSsl,
    bool restartWebserver = true,
  }) async {
    if (!_isValidDomain(domain)) {
      throw ArgumentError('Invalid domain name: $domain');
    }

    // rootDir is interpolated into a double-quoted webserver directive; reject
    // any character that could break out of it before it reaches storage or a
    // generated vhost file.
    validateRootDir(rootDir);

    if (siteType == 'proxy') {
      // proxyTarget is interpolated into webserver config; validate before it
      // reaches storage or a generated vhost file.
      validateProxyTarget(proxyTarget ?? '');
    }

    final isar = await ref.read(isarProvider.future);

    String? phpVersion;
    int? phpPort;

    if (siteType == 'php' && phpAppId != null) {
      phpVersion = phpVersionFromAppId(phpAppId) ?? '82';
      phpPort = _safePhpPort(phpAppId);
    }

    final site = SiteModel(
      domain: domain,
      rootDir: rootDir,
      siteType: siteType,
      phpVersion: phpVersion,
      phpPort: phpPort,
      proxyTarget: proxyTarget,
      useSsl: useSsl,
      createdAt: DateTime.now(),
    );

    await isar.writeTxn(() async {
      await isar.siteModels.put(site);
    });

    try {
      if (useSsl) {
        await _generateSslWithRetry(site);
      }

      // Generate Vhost files
      await _generateVhostFiles(site);
    } catch (e) {
      // The site row was already persisted, but its vhost/cert generation
      // failed — rolling back the row keeps the DB in sync with the
      // filesystem so the user can retry cleanly instead of being left with
      // an orphaned record that has no vhost file.
      await isar.writeTxn(() => isar.siteModels.delete(site.id));
      rethrow;
    }

    await _finalize(restartWebserver: restartWebserver);
  }

  /// Generates the SSL cert for [site]; retries once immediately if the cert or
  /// key file is missing after mkcert returns. Disables SSL on the site (and
  /// persists that) if generation still fails.
  Future<void> _generateSslWithRetry(SiteModel site) async {
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final logger = ref.read(logServiceProvider);
    final isar = await ref.read(isarProvider.future);

    bool certPresent() {
      final certFile = File(sslNotifier.getSiteCertPath(site.domain));
      final keyFile = File(sslNotifier.getSiteKeyPath(site.domain));
      return certFile.existsSync() && keyFile.existsSync();
    }

    await sslNotifier.generateSiteCert(site.domain);
    if (!certPresent()) {
      logger.warning(
        'Certificate missing for ${site.domain}, retrying once...',
      );
      await sslNotifier.generateSiteCert(site.domain, force: true);
    }

    if (!certPresent()) {
      logger.error('Failed to generate SSL for ${site.domain}, disabling SSL');
      site.useSsl = false;
      await isar.writeTxn(() async {
        await isar.siteModels.put(site);
      });
    }
  }

  /// Creates many sites efficiently: persists all new sites in one transaction,
  /// then generates SSL + vhost files in bounded parallel, then finalizes once
  /// (hosts write + state refresh + single webserver restart). Duplicate domains
  /// (already in DB or within [specs]) are skipped. Honors [cancel].
  Future<BatchResult> addSitesBatch(
    List<BatchSiteSpec> specs, {
    void Function(BatchProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final logger = ref.read(logServiceProvider);

    // Determine which specs are new (skip duplicates by domain).
    final existingDomains = (await isar.siteModels.where().findAll())
        .map((s) => s.domain)
        .toSet();
    final seen = <String>{};
    final toCreate = <SiteModel>[];
    var skipped = 0;

    for (final spec in specs) {
      if (!_isValidDomain(spec.domain) ||
          existingDomains.contains(spec.domain) ||
          !seen.add(spec.domain)) {
        skipped++;
        continue;
      }

      // Batch create does not support proxy sites: a proxy site needs a
      // per-site proxyTarget (and validateProxyTarget on it), and
      // BatchSiteSpec carries none. Rather than persist a proxy row with a
      // null target that would then fail vhost generation and orphan itself,
      // skip proxy specs explicitly so the caller sees them as skipped.
      if (spec.siteType == 'proxy') {
        skipped++;
        continue;
      }

      // rootDir is interpolated into webserver config; skip specs whose root
      // would break out of the quoted directive rather than persisting them.
      try {
        validateRootDir(spec.rootDir);
      } catch (_) {
        skipped++;
        continue;
      }

      String? phpVersion;
      int? phpPort;
      if (spec.siteType == 'php' && spec.phpAppId != null) {
        phpVersion = phpVersionFromAppId(spec.phpAppId!) ?? '82';
        phpPort = _safePhpPort(spec.phpAppId);
      }

      toCreate.add(
        SiteModel(
          domain: spec.domain,
          rootDir: spec.rootDir,
          siteType: spec.siteType,
          phpVersion: phpVersion,
          phpPort: phpPort,
          useSsl: spec.useSsl,
          createdAt: DateTime.now(),
        ),
      );
    }

    // Persist all new sites in one transaction.
    if (toCreate.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.siteModels.putAll(toCreate);
      });
    }

    // Fan out SSL + vhost generation (bounded).
    final total = toCreate.length;
    var completed = 0;
    final failed = <String>[];

    await runBounded<SiteModel, void>(toCreate, 8, (site, index) async {
      try {
        if (site.useSsl) {
          await _generateSslWithRetry(site);
        }
        await _generateVhostFiles(site);
      } catch (e) {
        logger.error('Batch create failed for ${site.domain}: $e');
        failed.add(site.domain);
      } finally {
        completed++;
        onProgress?.call(
          BatchProgress(
            current: completed,
            total: total,
            currentLabel: site.domain,
            phase: BatchPhase.processing,
          ),
        );
      }
    }, cancel: cancel);

    // Finalize once (even on cancel — reflect what was actually created).
    onProgress?.call(
      BatchProgress(
        current: completed,
        total: total,
        currentLabel: '',
        phase: BatchPhase.finalizing,
      ),
    );
    await _finalize();

    return BatchResult(
      succeeded: completed - failed.length,
      skipped: skipped,
      failed: failed,
      cancelled: cancel?.isCancelled ?? false,
    );
  }

  Future<void> updateSite({
    required int id,
    required String domain,
    required String rootDir,
    required String siteType,
    String? phpAppId,
    String? proxyTarget,
    required bool useSsl,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final oldSite = await isar.siteModels.get(id);
    if (oldSite == null) return;

    if (siteType == 'proxy') {
      validateProxyTarget(proxyTarget ?? '');
    }
    validateRootDir(rootDir);

    // Remove old vhost files if domain changed
    if (oldSite.domain != domain) {
      await _removeVhostFiles(oldSite);
    }

    String? phpVersion;
    int? phpPort;

    if (siteType == 'php' && phpAppId != null) {
      phpVersion = phpVersionFromAppId(phpAppId) ?? '82';
      phpPort = _safePhpPort(phpAppId);
    }

    final updatedSite = SiteModel(
      id: id,
      domain: domain,
      rootDir: rootDir,
      siteType: siteType,
      phpVersion: phpVersion,
      phpPort: phpPort,
      proxyTarget: proxyTarget,
      useSsl: useSsl,
      createdAt: oldSite.createdAt,
    );

    await isar.writeTxn(() async {
      await isar.siteModels.put(updatedSite);
    });

    if (useSsl) {
      await ref.read(sslServiceProvider.notifier).generateSiteCert(domain);
    } else if (oldSite.useSsl && oldSite.domain == domain) {
      // SSL was toggled off and the domain didn't change (a domain change is
      // already handled by _removeVhostFiles above). Clean up the stale cert
      // files for the current domain so they don't linger or get reused when
      // SSL is later re-enabled.
      try {
        final sslNotifier = ref.read(sslServiceProvider.notifier);
        final certDir = Directory(sslNotifier.getSiteCertDir(domain));
        if (certDir.existsSync()) await certDir.delete(recursive: true);
      } catch (e) {
        ref
            .read(logServiceProvider)
            .warning('Could not remove SSL cert for $domain: $e');
      }
    }

    // Generate/Update Vhost files
    await _generateVhostFiles(updatedSite);

    await _finalize();
  }

  Future<void> deleteSite(int id, {bool restartWebserver = true}) async {
    final isar = await ref.read(isarProvider.future);
    final site = await isar.siteModels.get(id);

    if (site != null) {
      // Delete the DB row FIRST so a locked log/cert file can never block the
      // deletion: the site always disappears from the app, and a leftover
      // file is benign (cleared on a later regen or manually). The previous
      // order (files → DB) could leave the site fully in place — row +
      // routing hosts entry — when a file delete threw.
      await isar.writeTxn(() async {
        await isar.siteModels.delete(id);
      });

      try {
        await _removeVhostFiles(site);
      } catch (e) {
        ref
            .read(logServiceProvider)
            .warning(
              'Site $id deleted but some vhost/cert/log files could '
              'not be removed (they may be in use): $e',
            );
      }

      await _finalize(restartWebserver: restartWebserver);
    }
  }

  /// Deletes many sites efficiently: removes vhost/ssl/logs files in bounded
  /// parallel, deletes all rows in one transaction, then finalizes once.
  /// Honors [cancel] (already-deleted sites stay deleted).
  Future<BatchResult> deleteSitesBatch(
    List<int> ids, {
    void Function(BatchProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final logger = ref.read(logServiceProvider);

    final sites = <SiteModel>[];
    for (final id in ids) {
      final site = await isar.siteModels.get(id);
      if (site != null) sites.add(site);
    }

    final total = sites.length;
    var completed = 0;
    final failed = <String>[];
    final removedIds = <int>[];

    await runBounded<SiteModel, void>(sites, 8, (site, index) async {
      try {
        await _removeVhostFiles(site);
        removedIds.add(site.id);
      } catch (e) {
        logger.error('Batch delete failed for ${site.domain}: $e');
        failed.add(site.domain);
      } finally {
        completed++;
        onProgress?.call(
          BatchProgress(
            current: completed,
            total: total,
            currentLabel: site.domain,
            phase: BatchPhase.processing,
          ),
        );
      }
    }, cancel: cancel);

    // Delete DB rows for successfully removed sites in one transaction.
    if (removedIds.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.siteModels.deleteAll(removedIds);
      });
    }

    onProgress?.call(
      BatchProgress(
        current: completed,
        total: total,
        currentLabel: '',
        phase: BatchPhase.finalizing,
      ),
    );
    await _finalize();

    return BatchResult(
      succeeded: removedIds.length,
      skipped: 0,
      failed: failed,
      cancelled: cancel?.isCancelled ?? false,
    );
  }

  // --- File Management for Edit Modal ---

  Future<Map<String, String>> getConfigs(SiteModel site) async {
    final result = <String, String>{};
    for (final type in editableWebserverTypes) {
      final file = File(vhostConfigPath(type, site.domain));
      result[type] = await file.exists() ? await file.readAsString() : '';
    }
    return result;
  }

  Future<void> saveConfig(SiteModel site, String type, String content) async {
    // Re-validate the stored domain before it reaches the filesystem: a stale
    // or externally-mutated record must not escape the vhosts dir via a
    // traversal-shaped domain. The content is user-authored config by design.
    final file = File(vhostConfigPath(type, site.domain));
    await file.writeAsString(content);
    await restartWebservers();
  }

  Future<Map<String, String>> getSslFiles(SiteModel site) async {
    validateDomain(site.domain);
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final certFile = File(sslNotifier.getSiteCertPath(site.domain));
    final keyFile = File(sslNotifier.getSiteKeyPath(site.domain));

    return {
      'cert': await certFile.exists() ? await certFile.readAsString() : '',
      'key': await keyFile.exists() ? await keyFile.readAsString() : '',
    };
  }

  Future<void> saveSslFile(SiteModel site, String type, String content) async {
    validateDomain(site.domain);
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final path = type == 'cert'
        ? sslNotifier.getSiteCertPath(site.domain)
        : sslNotifier.getSiteKeyPath(site.domain);
    await File(path).writeAsString(content);
    await restartWebservers();
  }

  Future<Map<String, String>> getLogs(SiteModel site) async {
    validateDomain(site.domain);
    final logsDir = p.join(AppConfig.baseDir, 'logs', site.domain);

    final nAccess = File(p.join(logsDir, 'nginx_access.log'));
    final nError = File(p.join(logsDir, 'nginx_error.log'));
    final aAccess = File(p.join(logsDir, 'apache_access.log'));
    final aError = File(p.join(logsDir, 'apache_error.log'));
    final cAccess = File(p.join(logsDir, 'caddy_access.log'));
    final cError = File(p.join(AppConfig.logsDir, 'caddy_error.log'));

    Future<String> readLastLines(File file, [int lines = 100]) async {
      if (!await file.exists()) return 'Log file not found';
      final content = await file.readAsLines();
      if (content.length <= lines) return content.join('\n');
      return content.sublist(content.length - lines).join('\n');
    }

    return {
      'nginx_access': await readLastLines(nAccess),
      'nginx_error': await readLastLines(nError),
      'apache_access': await readLastLines(aAccess),
      'apache_error': await readLastLines(aError),
      'caddy_access': await readLastLines(cAccess),
      'caddy_error': await readLastLines(cError),
    };
  }

  Future<void> regenerateSsl(SiteModel site) async {
    await ref
        .read(sslServiceProvider.notifier)
        .generateSiteCert(site.domain, force: true);
    await restartWebservers();
  }

  /// Shared finalization run once after site changes: rewrite the hosts file,
  /// refresh provider state from the DB, and restart webservers.
  Future<void> _finalize({bool restartWebserver = true}) async {
    final isar = await ref.read(isarProvider.future);
    final hostsOk = await _updateHostsFile();
    if (!hostsOk) {
      // Don't throw — batch paths must keep going so partial work still takes
      // effect. But surface the failure loudly so the user knows their domains
      // won't resolve until the hosts file is written (e.g. UAC was declined).
      ref
          .read(logServiceProvider)
          .error(
            'Failed to update the Windows hosts file (UAC declined or not admin?). '
            'Sites were created but their domains will not resolve until this is '
            'fixed. Re-run the operation as admin or approve the UAC prompt.',
          );
    }
    state = AsyncValue.data(
      await isar.siteModels.where().sortByCreatedAtDesc().findAll(),
    );
    if (restartWebserver) {
      await restartWebservers();
    }
  }

  Future<bool> _updateHostsFile() async {
    final isar = await ref.read(isarProvider.future);
    final allSites = await isar.siteModels.where().findAll();

    String hostsContent = await _hostsRepo.readHostsRaw();
    const startMarker = '# [PONTA-START]';
    const endMarker = '# [PONTA-END]';

    final domainLines = allSites.map((s) => '127.0.0.1 ${s.domain}').toList();

    hostsContent = HostsRepository.replacePontaBlock(
      hostsContent,
      startMarker,
      endMarker,
      domainLines,
    );

    // Propagate the write result so callers can surface a failure instead of
    // silently creating sites whose domains won't resolve.
    return _hostsRepo.saveHostsRaw(hostsContent);
  }

  Future<void> _generateVhostFiles(SiteModel site) async {
    // Re-validate stored rootDir: records may predate the data-layer guard, so
    // a stored path with a quote/newline can never reach a vhost directive.
    validateRootDir(site.rootDir);
    final rootDirUnix = site.rootDir.replaceAll('\\', '/');
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final settings = await ref.read(settingsNotifierProvider.future);
    final allowLanAccess = settings.allowLanAccess;

    // Ensure directories exist
    final nginxDir = Directory(p.join(AppConfig.vhostsDir, 'nginx'));
    if (!nginxDir.existsSync()) await nginxDir.create(recursive: true);

    final apacheDir = Directory(p.join(AppConfig.vhostsDir, 'apache'));
    if (!apacheDir.existsSync()) await apacheDir.create(recursive: true);

    final caddyDir = Directory(p.join(AppConfig.vhostsDir, 'caddy'));
    if (!caddyDir.existsSync()) await caddyDir.create(recursive: true);

    // Ensure logs directory exists
    final logsDir = Directory(p.join(AppConfig.baseDir, 'logs', site.domain));
    if (!logsDir.existsSync()) await logsDir.create(recursive: true);
    final logsPathUnix = logsDir.path.replaceAll('\\', '/');

    // --- 1. Nginx Vhost ---
    final nginxVhostFile = File(p.join(nginxDir.path, '${site.domain}.conf'));

    String buildNginxServer(int port, {bool ssl = false}) {
      final listen = WebserverBindPolicy.nginxListen(
        port,
        allowLanAccess: allowLanAccess,
        ssl: ssl,
      );
      String config = 'server {\n';
      config += '    listen $listen;\n';
      config += '    server_name ${site.domain};\n';
      config += '\n';
      config += '    client_max_body_size 512M;\n';
      config += '    send_timeout 1800;\n';
      config += '    proxy_read_timeout 1800;\n';

      if (site.siteType != 'proxy') {
        config += '    root "$rootDirUnix";\n';
        config += '    index index.php index.html;\n';
      }

      if (ssl) {
        final certPath = sslNotifier
            .getSiteCertPath(site.domain)
            .replaceAll('\\', '/');
        final keyPath = sslNotifier
            .getSiteKeyPath(site.domain)
            .replaceAll('\\', '/');
        config += '\n';
        config += '    ssl_certificate      "$certPath";\n';
        config += '    ssl_certificate_key  "$keyPath";\n';
        config += '    ssl_session_cache    shared:SSL:1m;\n';
        config += '    ssl_session_timeout  5m;\n';
        config += '    ssl_ciphers  HIGH:!aNULL:!MD5;\n';
        config += '    ssl_prefer_server_ciphers  on;\n';
      }

      config += '\n';
      config += '    access_log "$logsPathUnix/nginx_access.log";\n';
      config += '    error_log "$logsPathUnix/nginx_error.log";\n';
      config += '\n';

      if (site.siteType == 'proxy') {
        // Re-validate stored value: records may predate the data-layer guard.
        final safeTarget = validateProxyTarget(site.proxyTarget ?? '');
        config += '    location / {\n';
        config += '        proxy_pass $safeTarget;\n';
        config += '        proxy_set_header Host \$host;\n';
        config += '        proxy_set_header X-Real-IP \$remote_addr;\n';
        config +=
            '        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n';
        config += '        proxy_set_header X-Forwarded-Proto \$scheme;\n';
        config += '    }\n';
      } else {
        config += '    location / {\n';
        config += '        try_files \$uri \$uri/ /index.php?\$query_string;\n';
        config += '    }\n';

        if (site.siteType == 'php') {
          config += '\n';
          config += '    location ~ \\.php\$ {\n';
          config += '        fastcgi_pass 127.0.0.1:${site.phpPort};\n';
          config += '        fastcgi_index index.php;\n';
          config += '        include fastcgi_params;\n';
          config +=
              '        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n';
          config += '        fastcgi_read_timeout 1800;\n';
          config += '    }\n';
        }
      }

      config += '}\n';
      return config;
    }

    String nginxConfig = buildNginxServer(80);
    if (site.useSsl) {
      nginxConfig += '\n${buildNginxServer(443, ssl: true)}';
    }
    await nginxVhostFile.writeAsString(nginxConfig);

    // --- 2. Apache Vhost ---
    final apacheVhostFile = File(p.join(apacheDir.path, '${site.domain}.conf'));

    String buildApacheServer(int port, {bool ssl = false}) {
      final virtualHost = WebserverBindPolicy.apacheVirtualHost(
        port,
        allowLanAccess: allowLanAccess,
      );
      String config = '<VirtualHost $virtualHost>\n';
      config += '    ServerName ${site.domain}\n';

      if (site.siteType != 'proxy') {
        config += '    DocumentRoot "$rootDirUnix"\n';
      }

      if (ssl) {
        final certPath = sslNotifier
            .getSiteCertPath(site.domain)
            .replaceAll('\\', '/');
        final keyPath = sslNotifier
            .getSiteKeyPath(site.domain)
            .replaceAll('\\', '/');
        config += '    SSLEngine on\n';
        config += '    SSLCertificateFile "$certPath"\n';
        config += '    SSLCertificateKeyFile "$keyPath"\n';
      }

      config += '\n';
      config += '    CustomLog "$logsPathUnix/apache_access.log" combined\n';
      config += '    ErrorLog "$logsPathUnix/apache_error.log"\n';
      config += '\n';

      if (site.siteType == 'proxy') {
        // Re-validate stored value: records may predate the data-layer guard.
        final safeTarget = validateProxyTarget(site.proxyTarget ?? '');
        config += '    ProxyPreserveHost On\n';
        config += '    ProxyPass / $safeTarget/\n';
        config += '    ProxyPassReverse / $safeTarget/\n';
      } else {
        config += '    <Directory "$rootDirUnix">\n';
        config += '        Options Indexes FollowSymLinks\n';
        config += '        AllowOverride All\n';
        config += '        Require all granted\n';
        config += '    </Directory>\n';

        if (site.siteType == 'php') {
          config += '\n';
          config += '    <FilesMatch \\.php\$>\n';
          config +=
              '        SetHandler "proxy:fcgi://127.0.0.1:${site.phpPort}"\n';
          config += '    </FilesMatch>\n';
        }
      }

      config += '</VirtualHost>\n';
      return config;
    }

    String apacheConfig = buildApacheServer(80);
    if (site.useSsl) {
      apacheConfig += '\n<IfModule mod_ssl.c>\n';
      apacheConfig += buildApacheServer(443, ssl: true);
      apacheConfig += '</IfModule>\n';
    }
    await apacheVhostFile.writeAsString(apacheConfig);

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
  }

  Future<void> _removeVhostFiles(SiteModel site) async {
    for (final type in editableWebserverTypes) {
      final file = File(vhostConfigPath(type, site.domain));
      if (file.existsSync()) await file.delete();
    }

    // Remove SSL directory
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final certDir = Directory(sslNotifier.getSiteCertDir(site.domain));
    if (certDir.existsSync()) await certDir.delete(recursive: true);

    // Remove logs directory
    final logsDir = Directory(p.join(AppConfig.baseDir, 'logs', site.domain));
    if (logsDir.existsSync()) await logsDir.delete(recursive: true);
  }

  /// Rewrites every generated site vhost using the current settings and then
  /// restarts installed webservers once. Used when the LAN bind policy changes.
  Future<void> regenerateAllVhosts({bool restartWebserver = true}) async {
    final isar = await ref.read(isarProvider.future);
    final logger = ref.read(logServiceProvider);
    final sites = await isar.siteModels.where().findAll();

    // One bad site (e.g. a stale proxy target that no longer passes
    // validateProxyTarget) must not abort regeneration for every other site.
    // Collect failures, keep going, and restart webservers for the work that
    // succeeded.
    final failed = <String>[];
    for (final site in sites) {
      try {
        await _generateVhostFiles(site);
      } catch (e) {
        failed.add(site.domain);
        logger.error('Failed to regenerate vhost for ${site.domain}: $e');
      }
    }
    if (failed.isNotEmpty) {
      logger.warning(
        'regenerateAllVhosts skipped ${failed.length} site(s) due to errors: '
        '${failed.join(', ')}',
      );
    }

    if (restartWebserver) {
      await restartWebservers();
    }
  }

  Future<void> restartWebservers() async {
    // Coalesce overlapping calls: if a restart is already in flight, wait for
    // it instead of starting a second concurrent loop over the same servers.
    final existing = _restartCompleter;
    if (existing != null) {
      await existing.future;
      return;
    }
    final completer = _restartCompleter = Completer<void>();
    try {
      final appsNotifier = ref.read(appsNotifierProvider.notifier);
      final apps = ref.read(appsNotifierProvider).value ?? [];

      final webservers = apps
          .where(
            (a) =>
                a.isInstalled &&
                (a.appId.contains('nginx') ||
                    a.appId.contains('apache') ||
                    a.appId.contains('caddy')),
          )
          .toList();

      for (final ws in webservers) {
        // rethrowOnError so a failed reload can't masquerade as success —
        // config changes would otherwise silently not take effect.
        await appsNotifier.restartService(ws, rethrowOnError: true);
      }
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      // Only clear once the future has resolved so callers that arrived during
      // the run got the same result; a fresh call after this point starts new.
      if (identical(_restartCompleter, completer)) {
        _restartCompleter = null;
      }
    }
  }
}
