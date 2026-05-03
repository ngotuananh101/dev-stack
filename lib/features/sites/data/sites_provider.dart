import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/site_model.dart';
import 'package:isar/isar.dart';
import '../../apps/data/apps_provider.dart';
import '../../../core/services/ssl_service.dart';
import '../../../core/config/app_config.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../../core/services/log_service.dart';

part 'sites_provider.g.dart';

@riverpod
class SitesNotifier extends _$SitesNotifier {
  final _hostsRepo = HostsRepository();

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
    final isar = await ref.read(isarProvider.future);

    String? phpVersion;
    int? phpPort;

    if (siteType == 'php' && phpAppId != null) {
      final versionMatch = RegExp(r'\d+').firstMatch(phpAppId);
      phpVersion = versionMatch?.group(0) ?? '82';
      phpPort = int.parse('90$phpVersion');
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

    if (useSsl) {
      final sslNotifier = ref.read(sslServiceProvider.notifier);
      final logger = ref.read(logServiceProvider);
      bool certGenerated = false;
      
      for (int i = 0; i < 3; i++) {
        await sslNotifier.generateSiteCert(domain);
        final certFile = File(sslNotifier.getSiteCertPath(domain));
        final keyFile = File(sslNotifier.getSiteKeyPath(domain));
        
        if (certFile.existsSync() && keyFile.existsSync()) {
          certGenerated = true;
          break;
        } else {
          logger.warning('Certificate generation failed for $domain, retrying... (${i + 1}/3)');
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!certGenerated) {
        logger.error('Failed to generate SSL after 3 retries, disabling SSL for $domain');
        site.useSsl = false;
        await isar.writeTxn(() async {
          await isar.siteModels.put(site);
        });
      }
    }

    // Generate Vhost files
    await _generateVhostFiles(site);

    // Update hosts file
    await _updateHostsFile();

    // Refresh state
    state = AsyncValue.data(
      await isar.siteModels.where().sortByCreatedAtDesc().findAll(),
    );

    if (restartWebserver) {
      // Restart webservers to apply changes
      await restartWebservers();
    }
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

    // Remove old vhost files if domain changed
    if (oldSite.domain != domain) {
      await _removeVhostFiles(oldSite);
    }

    String? phpVersion;
    int? phpPort;

    if (siteType == 'php' && phpAppId != null) {
      final versionMatch = RegExp(r'\d+').firstMatch(phpAppId);
      phpVersion = versionMatch?.group(0) ?? '82';
      phpPort = int.parse('90$phpVersion');
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
    }

    // Generate/Update Vhost files
    await _generateVhostFiles(updatedSite);

    // Update hosts file
    await _updateHostsFile();

    // Refresh state
    state = AsyncValue.data(
      await isar.siteModels.where().sortByCreatedAtDesc().findAll(),
    );

    // Restart webservers to apply changes
    await restartWebservers();
  }

  Future<void> deleteSite(int id, {bool restartWebserver = true}) async {
    final isar = await ref.read(isarProvider.future);
    final site = await isar.siteModels.get(id);

    if (site != null) {
      // Remove Vhost files
      await _removeVhostFiles(site);

      await isar.writeTxn(() async {
        await isar.siteModels.delete(id);
      });

      // Update hosts file
      await _updateHostsFile();

      state = AsyncValue.data(
        await isar.siteModels.where().sortByCreatedAtDesc().findAll(),
      );

      if (restartWebserver) {
        // Restart webservers
        await restartWebservers();
      }
    }
  }

  // --- File Management for Edit Modal ---

  Future<Map<String, String>> getConfigs(SiteModel site) async {
    final nginxFile = File(
      p.join(AppConfig.vhostsDir, 'nginx', '${site.domain}.conf'),
    );
    final apacheFile = File(
      p.join(AppConfig.vhostsDir, 'apache', '${site.domain}.conf'),
    );

    return {
      'nginx': await nginxFile.exists() ? await nginxFile.readAsString() : '',
      'apache': await apacheFile.exists()
          ? await apacheFile.readAsString()
          : '',
    };
  }

  Future<void> saveConfig(SiteModel site, String type, String content) async {
    final dir = type == 'nginx' ? 'nginx' : 'apache';
    final file = File(p.join(AppConfig.vhostsDir, dir, '${site.domain}.conf'));
    await file.writeAsString(content);
    await restartWebservers();
  }

  Future<Map<String, String>> getSslFiles(SiteModel site) async {
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final certFile = File(sslNotifier.getSiteCertPath(site.domain));
    final keyFile = File(sslNotifier.getSiteKeyPath(site.domain));

    return {
      'cert': await certFile.exists() ? await certFile.readAsString() : '',
      'key': await keyFile.exists() ? await keyFile.readAsString() : '',
    };
  }

  Future<void> saveSslFile(SiteModel site, String type, String content) async {
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final path = type == 'cert'
        ? sslNotifier.getSiteCertPath(site.domain)
        : sslNotifier.getSiteKeyPath(site.domain);
    await File(path).writeAsString(content);
    await restartWebservers();
  }

  Future<Map<String, String>> getLogs(SiteModel site) async {
    final logsDir = p.join(AppConfig.baseDir, 'logs', site.domain);

    final nAccess = File(p.join(logsDir, 'nginx_access.log'));
    final nError = File(p.join(logsDir, 'nginx_error.log'));
    final aAccess = File(p.join(logsDir, 'apache_access.log'));
    final aError = File(p.join(logsDir, 'apache_error.log'));

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
    };
  }

  Future<void> regenerateSsl(SiteModel site) async {
    await ref.read(sslServiceProvider.notifier).generateSiteCert(site.domain);
    await restartWebservers();
  }

  Future<void> _updateHostsFile() async {
    final isar = await ref.read(isarProvider.future);
    final allSites = await isar.siteModels.where().findAll();

    String hostsContent = await _hostsRepo.readHostsRaw();
    const startMarker = '# [PONTA-START]';
    const endMarker = '# [PONTA-END]';

    // Generate new lines
    final newLines = [
      startMarker,
      ...allSites.map((s) => '127.0.0.1 ${s.domain}'),
      endMarker,
    ];
    final newBlock = newLines.join('\n');

    if (hostsContent.contains(startMarker) &&
        hostsContent.contains(endMarker)) {
      // Replace existing block
      final startIndex = hostsContent.indexOf(startMarker);
      final endIndex = hostsContent.indexOf(endMarker) + endMarker.length;

      hostsContent = hostsContent.replaceRange(startIndex, endIndex, newBlock);
    } else {
      // Append new block
      hostsContent = '${hostsContent.trim()}\n\n$newBlock\n';
    }

    await _hostsRepo.saveHostsRaw(hostsContent);
  }

  Future<void> _generateVhostFiles(SiteModel site) async {
    final rootDirUnix = site.rootDir.replaceAll('\\', '/');
    final sslNotifier = ref.read(sslServiceProvider.notifier);

    // Ensure directories exist
    final nginxDir = Directory(p.join(AppConfig.vhostsDir, 'nginx'));
    if (!nginxDir.existsSync()) await nginxDir.create(recursive: true);

    final apacheDir = Directory(p.join(AppConfig.vhostsDir, 'apache'));
    if (!apacheDir.existsSync()) await apacheDir.create(recursive: true);

    // Ensure logs directory exists
    final logsDir = Directory(p.join(AppConfig.baseDir, 'logs', site.domain));
    if (!logsDir.existsSync()) await logsDir.create(recursive: true);
    final logsPathUnix = logsDir.path.replaceAll('\\', '/');

    // --- 1. Nginx Vhost ---
    final nginxVhostFile = File(p.join(nginxDir.path, '${site.domain}.conf'));

    String buildNginxServer(int port, {bool ssl = false}) {
      String config = 'server {\n';
      config += '    listen $port${ssl ? " ssl" : ""};\n';
      config += '    server_name ${site.domain};\n';

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
        config += '    location / {\n';
        config += '        proxy_pass ${site.proxyTarget};\n';
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
      String config = '<VirtualHost *:$port>\n';
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
        config += '    ProxyPreserveHost On\n';
        config += '    ProxyPass / ${site.proxyTarget}/\n';
        config += '    ProxyPassReverse / ${site.proxyTarget}/\n';
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
  }

  Future<void> _removeVhostFiles(SiteModel site) async {
    final nginxVhostFile = File(
      p.join(AppConfig.vhostsDir, 'nginx', '${site.domain}.conf'),
    );
    if (nginxVhostFile.existsSync()) await nginxVhostFile.delete();

    final apacheVhostFile = File(
      p.join(AppConfig.vhostsDir, 'apache', '${site.domain}.conf'),
    );
    if (apacheVhostFile.existsSync()) await apacheVhostFile.delete();

    // Remove SSL directory
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final certDir = Directory(sslNotifier.getSiteCertDir(site.domain));
    if (certDir.existsSync()) await certDir.delete(recursive: true);

    // Remove logs directory
    final logsDir = Directory(p.join(AppConfig.baseDir, 'logs', site.domain));
    if (logsDir.existsSync()) await logsDir.delete(recursive: true);
  }

  Future<void> restartWebservers() async {
    final appsNotifier = ref.read(appsNotifierProvider.notifier);
    final apps = ref.read(appsNotifierProvider).value ?? [];

    final webservers = apps
        .where(
          (a) =>
              a.isInstalled &&
              (a.appId.contains('nginx') || a.appId.contains('apache')),
        )
        .toList();

    for (final ws in webservers) {
      await appsNotifier.restartService(ws);
    }
  }
}
