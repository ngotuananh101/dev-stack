import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/site_model.dart';
import 'package:isar/isar.dart';
import '../../apps/data/apps_provider.dart';
import '../../../core/services/ssl_service.dart';
import '../../../core/config/app_config.dart';
import '../../hosts/data/hosts_repository.dart';

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
    required String phpAppId,
    required bool useSsl,
  }) async {
    final isar = await ref.read(isarProvider.future);
    
    // Handle static sites
    final isStatic = phpAppId == 'static';
    final versionMatch = RegExp(r'\d+').firstMatch(phpAppId);
    final phpVersion = isStatic ? 'static' : (versionMatch?.group(0) ?? '82');
    final phpPort = isStatic ? 0 : int.parse('90$phpVersion');

    final site = SiteModel(
      domain: domain,
      rootDir: rootDir,
      phpVersion: phpVersion,
      phpPort: phpPort,
      useSsl: useSsl,
      createdAt: DateTime.now(),
    );

    await isar.writeTxn(() async {
      await isar.siteModels.put(site);
    });

    if (useSsl) {
      await ref.read(sslServiceProvider.notifier).generateSiteCert(domain);
    }

    // Generate Vhost files
    await _generateVhostFiles(site);

    // Update hosts file
    await _updateHostsFile();

    // Refresh state
    state = AsyncValue.data(await isar.siteModels.where().sortByCreatedAtDesc().findAll());

    // Restart webservers to apply changes
    await _restartWebservers();
  }

  Future<void> updateSite({
    required int id,
    required String domain,
    required String rootDir,
    required String phpAppId,
    required bool useSsl,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final oldSite = await isar.siteModels.get(id);
    if (oldSite == null) return;

    // Remove old vhost files if domain changed
    if (oldSite.domain != domain) {
      await _removeVhostFiles(oldSite);
    }

    final isStatic = phpAppId == 'static';
    final versionMatch = RegExp(r'\d+').firstMatch(phpAppId);
    final phpVersion = isStatic ? 'static' : (versionMatch?.group(0) ?? '82');
    final phpPort = isStatic ? 0 : int.parse('90$phpVersion');

    final updatedSite = SiteModel(
      id: id,
      domain: domain,
      rootDir: rootDir,
      phpVersion: phpVersion,
      phpPort: phpPort,
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
    state = AsyncValue.data(await isar.siteModels.where().sortByCreatedAtDesc().findAll());

    // Restart webservers to apply changes
    await _restartWebservers();
  }

  Future<void> deleteSite(int id) async {
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
      
      state = AsyncValue.data(await isar.siteModels.where().sortByCreatedAtDesc().findAll());
      
      // Restart webservers
      await _restartWebservers();
    }
  }

  // --- File Management for Edit Modal ---

  Future<Map<String, String>> getConfigs(SiteModel site) async {
    final nginxFile = File(p.join(AppConfig.vhostsDir, 'nginx', '${site.domain}.conf'));
    final apacheFile = File(p.join(AppConfig.vhostsDir, 'apache', '${site.domain}.conf'));

    return {
      'nginx': await nginxFile.exists() ? await nginxFile.readAsString() : '',
      'apache': await apacheFile.exists() ? await apacheFile.readAsString() : '',
    };
  }

  Future<void> saveConfig(SiteModel site, String type, String content) async {
    final dir = type == 'nginx' ? 'nginx' : 'apache';
    final file = File(p.join(AppConfig.vhostsDir, dir, '${site.domain}.conf'));
    await file.writeAsString(content);
    await _restartWebservers();
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
    final path = type == 'cert' ? sslNotifier.getSiteCertPath(site.domain) : sslNotifier.getSiteKeyPath(site.domain);
    await File(path).writeAsString(content);
    await _restartWebservers();
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
    await _restartWebservers();
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

    if (hostsContent.contains(startMarker) && hostsContent.contains(endMarker)) {
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

    // 1. Nginx Vhost
    final nginxVhostFile = File(p.join(nginxDir.path, '${site.domain}.conf'));
    String nginxConfig = '''
server {
    listen 80;
    server_name ${site.domain};
    root "$rootDirUnix";
    index index.php index.html;

    access_log "$logsPathUnix/nginx_access.log";
    error_log "$logsPathUnix/nginx_error.log";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
''';

    if (site.phpVersion != 'static') {
      nginxConfig += '''
    location ~ \\.php\$ {
        fastcgi_pass 127.0.0.1:${site.phpPort};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
''';
    }

    nginxConfig += '}\n';

    if (site.useSsl) {
      final certPath = sslNotifier.getSiteCertPath(site.domain).replaceAll('\\', '/');
      final keyPath = sslNotifier.getSiteKeyPath(site.domain).replaceAll('\\', '/');
      
      nginxConfig += '''
server {
    listen 443 ssl;
    server_name ${site.domain};
    root "$rootDirUnix";
    index index.php index.html;

    ssl_certificate      "$certPath";
    ssl_certificate_key  "$keyPath";

    ssl_session_cache    shared:SSL:1m;
    ssl_session_timeout  5m;
    ssl_ciphers  HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers  on;

    access_log "$logsPathUnix/nginx_access.log";
    error_log "$logsPathUnix/nginx_error.log";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
''';

      if (site.phpVersion != 'static') {
        nginxConfig += '''
    location ~ \\.php\$ {
        fastcgi_pass 127.0.0.1:${site.phpPort};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
''';
      }
      nginxConfig += '}\n';
    }
    await nginxVhostFile.writeAsString(nginxConfig);

    // 2. Apache Vhost
    final apacheVhostFile = File(p.join(apacheDir.path, '${site.domain}.conf'));
    String apacheConfig = '''
<VirtualHost *:80>
    ServerName ${site.domain}
    DocumentRoot "$rootDirUnix"

    CustomLog "$logsPathUnix/apache_access.log" combined
    ErrorLog "$logsPathUnix/apache_error.log"

    <Directory "$rootDirUnix">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
''';

    if (site.phpVersion != 'static') {
      apacheConfig += '''
    <FilesMatch \\.php\$>
        SetHandler "proxy:fcgi://127.0.0.1:${site.phpPort}"
    </FilesMatch>
''';
    }

    apacheConfig += '</VirtualHost>\n';

    if (site.useSsl) {
      final certPath = sslNotifier.getSiteCertPath(site.domain).replaceAll('\\', '/');
      final keyPath = sslNotifier.getSiteKeyPath(site.domain).replaceAll('\\', '/');
      
      apacheConfig += '''
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName ${site.domain}
    DocumentRoot "$rootDirUnix"
    SSLEngine on
    SSLCertificateFile "$certPath"
    SSLCertificateKeyFile "$keyPath"

    CustomLog "$logsPathUnix/apache_access.log" combined
    ErrorLog "$logsPathUnix/apache_error.log"

    <Directory "$rootDirUnix">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
''';

      if (site.phpVersion != 'static') {
        apacheConfig += '''
    <FilesMatch \\.php\$>
        SetHandler "proxy:fcgi://127.0.0.1:${site.phpPort}"
    </FilesMatch>
''';
      }
      apacheConfig += '</VirtualHost>\n</IfModule>\n';
    }
    await apacheVhostFile.writeAsString(apacheConfig);
  }

  Future<void> _removeVhostFiles(SiteModel site) async {
    final nginxVhostFile = File(p.join(AppConfig.vhostsDir, 'nginx', '${site.domain}.conf'));
    if (nginxVhostFile.existsSync()) await nginxVhostFile.delete();
    
    final apacheVhostFile = File(p.join(AppConfig.vhostsDir, 'apache', '${site.domain}.conf'));
    if (apacheVhostFile.existsSync()) await apacheVhostFile.delete();

    // Remove SSL directory
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final certDir = Directory(sslNotifier.getSiteCertDir(site.domain));
    if (certDir.existsSync()) await certDir.delete(recursive: true);

    // Remove logs directory
    final logsDir = Directory(p.join(AppConfig.baseDir, 'logs', site.domain));
    if (logsDir.existsSync()) await logsDir.delete(recursive: true);
  }

  Future<void> _restartWebservers() async {
    final appsNotifier = ref.read(appsNotifierProvider.notifier);
    final apps = ref.read(appsNotifierProvider).value ?? [];
    
    final webservers = apps.where((a) => a.isInstalled && (a.appId.contains('nginx') || a.appId.contains('apache'))).toList();
    
    for (final ws in webservers) {
      await appsNotifier.restartService(ws);
    }
  }
}
