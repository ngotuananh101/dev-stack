import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import '../../../core/services/log_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/ssl_service.dart';

part 'app_installer_service.g.dart';

@riverpod
AppInstallerService appInstallerService(Ref ref) {
  final logger = ref.read(logServiceProvider);
  return AppInstallerService(logger, ref);
}

typedef InstallationProgressCallback =
    void Function(
      double progress,
      String status, {
      int? downloadedBytes,
      int? totalBytes,
    });
typedef InstallationLogCallback = void Function(String message);

class AppInstallerService {
  final LogService _logger;
  final Ref _ref;
  static const String defaultBaseDir = AppConfig.appsDir;
  final _dio = Dio();

  AppInstallerService(this._logger, this._ref);

  Future<String> install(
    AppModel app,
    String version, {
    InstallationProgressCallback? onProgress,
    InstallationLogCallback? onLog,
  }) async {
    void logInfo(String msg) {
      _logger.info(msg);
      onLog?.call(msg);
    }

    void logError(String msg) {
      _logger.error(msg);
      onLog?.call('ERROR: $msg');
    }

    if (app.appId == 'pyenv') {
      logError(
        'pyenv installation requested but not supported through this flow.',
      );
      throw Exception('pyenv installation is not supported through this flow.');
    }

    final url = app.versionLinks[version];
    if (url == null || url.isEmpty) {
      _logger.error('Download URL for ${app.name} version $version not found.');
      throw Exception('Download URL for version $version not found.');
    }

    final installPath = p.join(defaultBaseDir, app.appId, version);
    final directory = Directory(installPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    // 2. Download
    logInfo('Starting installation for ${app.name} ($version)');
    onProgress?.call(0.1, 'Downloading...');

    final tempFile = File(
      p.join(Directory.systemTemp.path, '${app.appId}_$version.tmp'),
    );

    try {
      await _dio.download(
        url,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total) * 0.7 + 0.1; // 10% to 80%
            onProgress?.call(
              progress,
              'Downloading...',
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      logInfo('Download completed for ${app.name}');
      onProgress?.call(0.8, 'Extracting...');

      final bytes = await tempFile.readAsBytes();
      final extension = p.extension(url).toLowerCase();

      // 3. Extract or Save
      if (extension == '.zip') {
        logInfo('Extracting ZIP for ${app.name}');
        await _extractZip(bytes, installPath, onLog);
      } else if (extension == '.gz' || url.contains('.tar.gz')) {
        logInfo('Extracting TAR.GZ for ${app.name}');
        await _extractTarGz(bytes, installPath, onLog);
      } else {
        final filename = p.basename(url).split('?').first;
        final file = File(p.join(installPath, filename));
        await file.writeAsBytes(bytes);
      }

      // 4. Flatten directory if needed
      await _flattenDirectory(installPath, logInfo);

      // 5. Detect executable and CLI files
      logInfo('Detecting executable and CLI files...');
      final detected = await _detectFiles(
        installPath,
        app.execFile,
        app.cliFile,
        logInfo,
      );
      app.execFilePath = detected['exec'];
      app.cliFilePath = detected['cli'];

      onProgress?.call(1.0, 'Completed');
      logInfo('Successfully installed ${app.name} to $installPath');

      // 5. Post-installation: Initialize database
      if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
        await _initializeDatabase(app, installPath, logInfo);
      }

      // 6. Post-installation: Handle PHP configuration
      if (app.groupName == 'php') {
        final phpIniDev = File(p.join(installPath, 'php.ini-development'));
        final phpIni = File(p.join(installPath, 'php.ini'));

        if (phpIniDev.existsSync() && !phpIni.existsSync()) {
          logInfo('Copying php.ini-development to php.ini...');
          await phpIniDev.copy(phpIni.path);
          logInfo('Successfully created php.ini');
          await _tunePhpIni(phpIni, logInfo);
          await _enableDefaultExtensions(phpIni, installPath, logInfo);
        }
      }

      // 7. Post-installation: Configure Web Servers
      if (app.groupName == 'webserver' ||
          app.appId.contains('nginx') ||
          app.appId.contains('apache')) {
        await _configureWebserver(app, installPath, logInfo);
      }

      // 8. Post-installation: Configure MongoDB
      if (app.appId == 'mongodb') {
        await _configureMongodb(app, installPath, logInfo);
      }

      // 9. Post-installation: Configure phpMyAdmin
      if (app.appId == 'phpMyAdmin') {
        await _configurePhpMyAdmin(installPath, logInfo);
      }

      // Cleanup
      if (tempFile.existsSync()) await tempFile.delete();

      return installPath;
    } catch (e) {
      logError('Installation failed for ${app.name}: $e');
      if (tempFile.existsSync()) await tempFile.delete();
      rethrow;
    }
  }

  Future<void> _extractZip(
    List<int> bytes,
    String targetPath,
    InstallationLogCallback? onLog,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (onLog != null) onLog('Extracting: $filename');
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File(p.join(targetPath, filename));
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory(p.join(targetPath, filename)).create(recursive: true);
      }
    }
  }

  Future<void> _extractTarGz(
    List<int> bytes,
    String targetPath,
    InstallationLogCallback? onLog,
  ) async {
    final tarBytes = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final file in archive) {
      final filename = file.name;
      if (onLog != null) onLog('Extracting: $filename');
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File(p.join(targetPath, filename));
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory(p.join(targetPath, filename)).create(recursive: true);
      }
    }
  }

  Future<void> _flattenDirectory(
    String targetPath,
    Function(String) logInfo,
  ) async {
    final dir = Directory(targetPath);
    if (!dir.existsSync()) return;

    final entities = await dir.list().toList();

    // Check if there is only 1 entity and it's a directory
    if (entities.length == 1 && entities.first is Directory) {
      final subDir = entities.first as Directory;
      logInfo(
        'Detected nested directory: ${p.basename(subDir.path)}. Flattening...',
      );

      final subEntities = await subDir.list().toList();

      for (final entity in subEntities) {
        final newPath = p.join(targetPath, p.basename(entity.path));
        // Using rename might fail across different partitions, but here it's same parent
        await entity.rename(newPath);
      }

      // Delete the now empty nested directory
      await subDir.delete();
      logInfo('Flattening completed.');
    }
  }

  Future<Map<String, String?>> _detectFiles(
    String installPath,
    String? execName,
    String? cliName,
    Function(String) logInfo,
  ) async {
    final result = <String, String?>{'exec': null, 'cli': null};

    if (execName == null && cliName == null) return result;

    final dir = Directory(installPath);
    if (!dir.existsSync()) return result;

    try {
      final entities = await dir.list(recursive: true).toList();

      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path);

          if (execName != null &&
              filename == execName &&
              result['exec'] == null) {
            result['exec'] = entity.path;
            logInfo('Detected executable: ${entity.path}');
          }

          if (cliName != null && filename == cliName && result['cli'] == null) {
            result['cli'] = entity.path;
            logInfo('Detected CLI: ${entity.path}');
          }
        }
      }
    } catch (e) {
      logInfo('Error during file detection: $e');
    }

    return result;
  }

  Future<void> _tunePhpIni(File phpIni, Function(String) logInfo) async {
    if (!phpIni.existsSync()) return;

    logInfo('Tuning php.ini for better performance...');
    String content = await phpIni.readAsString();

    final Map<String, String> replacements = {
      r'^;?\s*max_execution_time\s*=.*': 'max_execution_time = 1800',
      r'^;?\s*max_input_time\s*=.*': 'max_input_time = 3600',
      r'^;?\s*memory_limit\s*=.*': 'memory_limit = 2G',
      r'^;?\s*post_max_size\s*=.*': 'post_max_size = 2G',
      r'^;?\s*upload_max_filesize\s*=.*': 'upload_max_filesize = 512M',
      r'^;?\s*extension_dir\s*=\s*"ext"': 'extension_dir = "ext"',
      r'^;?\s*zend_extension\s*=\s*opcache.*': 'zend_extension = opcache',
      r'^;?\s*opcache\.enable\s*=.*': 'opcache.enable = 1',
      r'^;?\s*opcache\.enable_cli\s*=.*': 'opcache.enable_cli = 1',
      r'^;?\s*opcache\.memory_consumption\s*=.*':
          'opcache.memory_consumption = 128',
      r'^;?\s*opcache\.max_accelerated_files\s*=.*':
          'opcache.max_accelerated_files = 10000',
      r'^;?\s*opcache\.validate_timestamps\s*=.*':
          'opcache.validate_timestamps = 1',
      r'^;?\s*opcache\.revalidate_freq\s*=.*': 'opcache.revalidate_freq = 2',
      r'^;?\s*realpath_cache_size\s*=.*': 'realpath_cache_size = 4096k',
      r'^;?\s*realpath_cache_ttl\s*=.*': 'realpath_cache_ttl = 600',
    };

    for (final entry in replacements.entries) {
      final regExp = RegExp(entry.key, multiLine: true, caseSensitive: false);
      if (regExp.hasMatch(content)) {
        content = content.replaceFirst(regExp, entry.value);
      } else {
        // If not found, append it at the end
        content += '\n${entry.value}';
      }
    }

    await phpIni.writeAsString(content);
    logInfo('php.ini tuning completed.');
  }

  Future<void> _enableDefaultExtensions(
    File phpIni,
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Enabling default extensions (curl, mbstring, pdo, etc.)...');
    String content = await phpIni.readAsString();

    final extensions = [
      'curl',
      'fileinfo',
      'mbstring',
      'pdo_mysql',
      'pdo_sqlite',
      'sqlite3',
      'zip',
      'mysqli',
    ];

    for (final ext in extensions) {
      final dllName = 'php_$ext.dll';
      final extPath = p.join(installPath, 'ext', dllName);

      // Verify the DLL exists before enabling
      if (!File(extPath).existsSync()) {
        logInfo('Skipping $ext: DLL not found at $extPath');
        continue;
      }

      final newLine = 'extension="$extPath"';

      // 1. Remove ANY existing lines for this extension
      final searchRegex = RegExp(
        r'^;?\s*(?:extension|zend_extension)\s*=\s*"?\s*(?:[^"\r\n]*?[\\/])?(?:php_)?' +
            RegExp.escape(ext) +
            r'(?:\.dll)?"?\s*$\r?\n?',
        multiLine: true,
        caseSensitive: false,
      );
      content = content.replaceAll(searchRegex, '');

      // 2. Insert after opcache or append
      final opcacheRegex = RegExp(
        r'^;?\s*zend_extension\s*=\s*"?\s*opcache(?:\.dll)?"?\s*$',
        multiLine: true,
        caseSensitive: false,
      );

      if (opcacheRegex.hasMatch(content)) {
        content = content.replaceFirstMapped(
          opcacheRegex,
          (match) => '${match.group(0)}\n$newLine',
        );
      } else {
        content += '\n$newLine';
      }
    }

    await phpIni.writeAsString(content);
    logInfo('Default extensions enabled successfully.');
  }

  Future<void> _initializeDatabase(
    AppModel app,
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Initializing database system tables...');
    final dataDir = Directory(p.join(installPath, 'data'));
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }

    final binDir = Directory(p.join(installPath, 'bin'));
    if (!binDir.existsSync()) {
      logInfo('Bin directory not found, skipping initialization');
      return;
    }

    String? initExec;
    List<String> args = [];

    if (app.appId.contains('mysql')) {
      initExec = p.join(binDir.path, 'mysqld.exe');
      args = [
        '--initialize-insecure',
        '--console',
        '--datadir=${dataDir.path}',
      ];
    } else if (app.appId.contains('mariadb')) {
      // MariaDB uses mysql_install_db or mariadb-install-db
      final mdbInstall = File(p.join(binDir.path, 'mariadb-install-db.exe'));
      final mysqlInstall = File(p.join(binDir.path, 'mysql_install_db.exe'));

      if (mdbInstall.existsSync()) {
        initExec = mdbInstall.path;
      } else if (mysqlInstall.existsSync()) {
        initExec = mysqlInstall.path;
      }
      args = ['--datadir=${dataDir.path}'];
    }

    if (initExec != null && File(initExec).existsSync()) {
      logInfo('Running: $initExec ${args.join(' ')}');
      try {
        final result = await Process.run(initExec, args);
        if (result.exitCode == 0) {
          logInfo('Database initialized successfully.');
        } else {
          logInfo('Initialization returned non-zero code: ${result.exitCode}');
          logInfo('Output: ${result.stdout}');
          logInfo('Error: ${result.stderr}');
        }
      } catch (e) {
        logInfo('Error during database initialization: $e');
      }
    } else {
      logInfo('Could not find database initialization executable.');
    }
  }

  Future<void> _configureWebserver(
    AppModel app,
    String installPath,
    Function(String) logInfo,
  ) async {
    final wwwDir = Directory(AppConfig.webserverRoot);
    if (!wwwDir.existsSync()) {
      logInfo('Creating webserver root directory: ${wwwDir.path}');
      await wwwDir.create(recursive: true);
    }

    // Add default index.html if empty
    final entities = await wwwDir.list().toList();
    if (entities.isEmpty) {
      final indexHtml = File(p.join(wwwDir.path, 'index.html'));
      await indexHtml.writeAsString('''<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Ponta</title>
    <style>
        body { font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f4f7f6; color: #333; }
        .container { text-align: center; padding: 40px; background: white; border-radius: 12px; shadow: 0 4px 20px rgba(0,0,0,0.08); }
        h1 { color: #007bff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Ponta Web Server</h1>
        <p>This is the default root directory at <code>${wwwDir.path}</code></p>
    </div>
</body>
</html>''');
    }

    final webRoot = AppConfig.webserverRoot.replaceAll('\\', '/');

    final isSslInstalled = _ref.read(sslServiceProvider).value ?? false;
    final sslNotifier = _ref.read(sslServiceProvider.notifier);
    
    if (isSslInstalled) {
      await sslNotifier.generateSiteCert('localhost');
    }

    if (app.appId.contains('nginx')) {
      final confFile = File(p.join(installPath, 'conf', 'nginx.conf'));
      if (confFile.existsSync()) {
        logInfo('Configuring Nginx default root to $webRoot...');
        String content = await confFile.readAsString();

        // Standard Nginx default root replacement
        content = content.replaceFirst(
          RegExp(r'root\s+html;'),
          'root   "$webRoot";',
        );

        // Optimize worker_processes for Nginx
        content = content.replaceFirst(
          RegExp(r'worker_processes\s+\d+;'),
          'worker_processes  auto;',
        );

        // SSL Configuration
        if (isSslInstalled) {
          logInfo('Adding SSL block to Nginx...');
          final certPath = sslNotifier.getSiteCertPath('localhost').replaceAll('\\', '/');
          final keyPath = sslNotifier.getSiteKeyPath('localhost').replaceAll('\\', '/');
          
          final sslBlockMarker = '# Ponta SSL Block';
          final sslBlock = '''
    $sslBlockMarker
    listen       443 ssl;
    ssl_certificate      "$certPath";
    ssl_certificate_key  "$keyPath";

    ssl_session_cache    shared:SSL:1m;
    ssl_session_timeout  5m;

    ssl_ciphers  HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers  on;
''';

          // Remove existing block if any
          final existingRegex = RegExp(r'\s*' + RegExp.escape(sslBlockMarker) + r'.*?ssl_prefer_server_ciphers\s+on;', dotAll: true);
          content = content.replaceAll(existingRegex, '');

          if (content.contains('listen       80;')) {
             content = content.replaceFirst('listen       80;', 'listen       80;\n$sslBlock');
          }
        } else {
          // Remove SSL block if SSL is uninstalled
          final sslBlockMarker = '# Ponta SSL Block';
          final existingRegex = RegExp(r'\s*' + RegExp.escape(sslBlockMarker) + r'.*?ssl_prefer_server_ciphers\s+on;', dotAll: true);
          if (content.contains(sslBlockMarker)) {
            logInfo('Removing SSL block from Nginx...');
            content = content.replaceAll(existingRegex, '');
          }
        }

        await confFile.writeAsString(content);
        logInfo('Nginx configuration updated (root, worker_processes, SSL).');
      }
    } else if (app.appId.contains('apache')) {
      // Apache Lounge zips often contain an 'Apache24' subfolder
      String apacheRoot = installPath;
      File confFile = File(p.join(installPath, 'conf', 'httpd.conf'));

      if (!confFile.existsSync()) {
        final nestedConf = File(
          p.join(installPath, 'Apache24', 'conf', 'httpd.conf'),
        );
        if (nestedConf.existsSync()) {
          confFile = nestedConf;
          apacheRoot = p.join(installPath, 'Apache24');
        }
      }

      if (confFile.existsSync()) {
        logInfo('Configuring Apache paths in ${confFile.path}...');
        String content = await confFile.readAsString();

        final srvRoot = apacheRoot.replaceAll('\\', '/');

        // 1. Fix SRVROOT (Essential for Apache Lounge binaries)
        content = content.replaceFirst(
          RegExp(r'Define\s+SRVROOT\s+".*?"'),
          'Define SRVROOT "$srvRoot"',
        );

        // 2. Replace DocumentRoot
        content = content.replaceFirst(
          RegExp(r'^DocumentRoot\s+.*$', multiLine: true),
          'DocumentRoot "$webRoot"',
        );

        // 3. Replace the corresponding <Directory> block
        content = content.replaceFirst(
          RegExp(r'^<Directory\s+"[^/].*?">', multiLine: true),
          '<Directory "$webRoot">',
        );

        // 4. Ensure permissions for the new root
        content = content.replaceFirst(
          '<Directory "$webRoot">',
          '<Directory "$webRoot">\n    Options Indexes FollowSymLinks\n    AllowOverride All\n    Require all granted',
        );

        // 5. Fix ServerName warning
        if (!content.contains('ServerName localhost')) {
          content = content.replaceFirst(
            RegExp(r'^#?ServerName\s+.*$', multiLine: true),
            'ServerName localhost:80',
          );
        }

        // SSL Configuration for Apache
        final sslVhostMarker = '# Ponta SSL Virtual Host';
        if (isSslInstalled) {
          logInfo('Configuring SSL for Apache...');
          // Enable mod_ssl and socache_shmcb
          content = content.replaceFirst('#LoadModule ssl_module modules/mod_ssl.so', 'LoadModule ssl_module modules/mod_ssl.so');
          content = content.replaceFirst('#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so', 'LoadModule socache_shmcb_module modules/mod_socache_shmcb.so');
          
          if (!content.contains('Listen 443')) {
            content = content.replaceFirst('Listen 80', 'Listen 80\nListen 443');
          }

          final certPath = sslNotifier.getSiteCertPath('localhost').replaceAll('\\', '/');
          final keyPath = sslNotifier.getSiteKeyPath('localhost').replaceAll('\\', '/');
          
          final sslVhost = '''
$sslVhostMarker
<VirtualHost *:443>
    DocumentRoot "$webRoot"
    ServerName localhost:443
    SSLEngine on
    SSLCertificateFile "$certPath"
    SSLCertificateKeyFile "$keyPath"
    <Directory "$webRoot">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
''';
          // Remove existing vhost if any
          final existingRegex = RegExp(r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/VirtualHost>', dotAll: true);
          content = content.replaceAll(existingRegex, '');

          content += '\n$sslVhost\n';
        } else {
          // Remove SSL config if uninstalled
          if (content.contains(sslVhostMarker)) {
            logInfo('Removing SSL config from Apache...');
            final existingRegex = RegExp(r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/VirtualHost>', dotAll: true);
            content = content.replaceAll(existingRegex, '');
            // Optionally disable modules but keep it simple for now
          }
        }

        await confFile.writeAsString(content);
        logInfo(
          'Apache configuration updated (SRVROOT, DocumentRoot, Permissions, SSL).',
        );
      } else {
        logInfo('Warning: Could not find Apache httpd.conf to configure.');
      }
    }
  }

  Future<void> _configureMongodb(
    AppModel app,
    String installPath,
    Function(String) logInfo,
  ) async {
    final binDir = Directory(p.join(installPath, 'bin'));
    final binExists = binDir.existsSync();
    final baseDir = binExists ? binDir.path : installPath;

    // 1. Create data directory
    final dataDir = Directory(p.join(installPath, 'data'));
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
      logInfo('Created MongoDB data directory at ${dataDir.path}');
    }

    // 2. Create default mongod.cfg
    final confFile = File(p.join(baseDir, 'mongod.cfg'));
    if (!confFile.existsSync()) {
      final dbPath = dataDir.path.replaceAll('\\', '/');
      final logPath = p.join(installPath, 'mongod.log').replaceAll('\\', '/');

      final configContent =
          '''
storage:
  dbPath: "$dbPath"

systemLog:
  destination: file
  logAppend: true
  path: "$logPath"

net:
  port: 27017
  bindIp: 127.0.0.1
''';
      await confFile.writeAsString(configContent);
      logInfo('Created MongoDB configuration at ${confFile.path}');
    }
  }

  Future<void> reconfigureWebservers(List<AppModel> allApps, Function(String) logInfo) async {
    final webServers = allApps.where((a) => a.isInstalled && (a.appId.contains('nginx') || a.appId.contains('apache'))).toList();
    
    for (final ws in webServers) {
      if (ws.location != null) {
        logInfo('Reconfiguring ${ws.name} at ${ws.location}...');
        await _configureWebserver(ws, ws.location!, logInfo);
      }
    }
  }

  Future<void> delete(String path) async {
    final directory = Directory(path);
    if (directory.existsSync()) {
      _logger.info('Deleting directory: $path');
      await directory.delete(recursive: true);
    }
  }

  /// Syncs configurations between different apps (e.g., phpMyAdmin with Web Servers)
  Future<void> syncInterAppConfigs(
    AppModel currentApp,
    List<AppModel> allApps, {
    Function(String)? onLog,
  }) async {
    void log(String m) {
      _logger.info(m);
      onLog?.call(m);
    }

    final isPMA = currentApp.appId == 'phpMyAdmin';
    final isWebServer =
        currentApp.appId.contains('nginx') ||
        currentApp.appId.contains('apache');

    if (!isPMA && !isWebServer) return;

    log('Syncing inter-app configurations for ${currentApp.name}...');

    // 1. Identify phpMyAdmin
    AppModel? phpMyAdmin;
    if (isPMA) {
      phpMyAdmin = currentApp;
    } else {
      phpMyAdmin = allApps.firstWhere(
        (a) => a.appId == 'phpMyAdmin' && a.isInstalled,
        orElse: () => currentApp, // Dummy to check if it's really installed
      );
      if (phpMyAdmin.appId != 'phpMyAdmin' || !phpMyAdmin.isInstalled) {
        phpMyAdmin = null;
      }
    }

    if (phpMyAdmin == null) {
      log('phpMyAdmin not installed, skipping web server integration.');
      return;
    }

    // 2. Identify Web Servers to update
    List<AppModel> webServers = [];
    if (isWebServer) {
      webServers = [currentApp];
    } else {
      webServers = allApps
          .where(
            (a) =>
                a.isInstalled &&
                (a.appId.contains('nginx') || a.appId.contains('apache')),
          )
          .toList();
    }

    if (webServers.isEmpty) {
      log('No installed web servers found to configure.');
      return;
    }

    // 3. Find the best PHP version for FastCGI/Nginx (prefer isDefault)
    final phpApps = allApps
        .where((a) => a.isInstalled && a.groupName == 'php')
        .toList();

    // Sort so default is first, then newest
    phpApps.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return b.appId.compareTo(a.appId);
    });

    final bestPhp = phpApps.firstOrNull;

    // Ensure extensions for PMA are enabled in the default PHP
    if (bestPhp != null && bestPhp.location != null) {
      final phpIni = File(p.join(bestPhp.location!, 'php.ini'));
      if (phpIni.existsSync()) {
        log(
          'Ensuring mysqli, mbstring, openssl are enabled in ${bestPhp.name}...',
        );
        await _enableDefaultExtensions(phpIni, bestPhp.location!, log);
      }
    }

    for (final ws in webServers) {
      try {
        if (ws.appId.contains('nginx')) {
          await _configurePhpMyAdminInNginx(ws, phpMyAdmin, bestPhp, log);
        } else if (ws.appId.contains('apache')) {
          await _configurePhpMyAdminInApache(ws, phpMyAdmin, log);
        }
      } catch (e) {
        log('Error configuring ${ws.name}: $e');
      }
    }
  }

  Future<void> _configurePhpMyAdminInNginx(
    AppModel nginx,
    AppModel pma,
    AppModel? php,
    Function(String) log,
  ) async {
    final wsPath = nginx.location;
    final pmaPath = pma.location;
    if (wsPath == null || pmaPath == null) return;

    final confDir = Directory(p.join(wsPath, 'conf', 'ponta_apps'));
    if (!confDir.existsSync()) {
      log('Creating Nginx ponta_apps directory: ${confDir.path}');
      confDir.createSync(recursive: true);
    }

    final pmaConfFile = File(p.join(confDir.path, 'phpmyadmin.conf'));

    // Determine PHP port
    String phpPort = '9000'; // Default
    if (php != null) {
      final versionMatch = RegExp(r'\d+').firstMatch(php.appId);
      if (versionMatch != null) {
        phpPort = '90${versionMatch.group(0)}';
      }
    }

    final pmaWebRoot = _resolvePmaWebRoot(pmaPath);
    final pmaPathUnix = pmaWebRoot.replaceAll('\\', '/');

    final pmaConfig =
        '''
location /phpmyadmin {
    alias "$pmaPathUnix/";
    index index.php;
    try_files \$uri \$uri/ /index.php?\$args;

    location ~ ^/phpmyadmin/(.+\\.php)\$ {
        alias "$pmaPathUnix/\$1";
        fastcgi_pass 127.0.0.1:$phpPort;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
    }
}
''';

    await pmaConfFile.writeAsString(pmaConfig);
    log(
      'Created Nginx config for phpMyAdmin at ${pmaConfFile.path} (PHP Port: $phpPort)',
    );

    // Ensure nginx.conf includes this
    final nginxConf = File(p.join(wsPath, 'conf', 'nginx.conf'));
    if (nginxConf.existsSync()) {
      String content = await nginxConf.readAsString();
      if (!content.contains('ponta_apps/*.conf')) {
        log('Injecting ponta_apps include into nginx.conf...');

        // 1. Try to find the default server block with listen 80
        if (content.contains('listen       80;')) {
          content = content.replaceFirst(
            'listen       80;',
            'listen       80;\n        include ponta_apps/*.conf;',
          );
        } else if (content.contains('server {')) {
          // 2. Fallback to first server block
          content = content.replaceFirst(
            'server {',
            'server {\n        include ponta_apps/*.conf;',
          );
        } else {
          // 3. Last resort: append at the end (might not work well if outside http/server)
          content += '\n# Ponta Apps\ninclude ponta_apps/*.conf;\n';
        }

        await nginxConf.writeAsString(content);
        log('Successfully added include to nginx.conf');
      }
    }
  }

  Future<void> _configurePhpMyAdminInApache(
    AppModel apache,
    AppModel pma,
    Function(String) log,
  ) async {
    final wsPath = apache.location;
    final pmaPath = pma.location;
    if (wsPath == null || pmaPath == null) return;

    // Apache root might be nested in Apache24
    String apacheRoot = wsPath;
    File httpdConf = File(p.join(wsPath, 'conf', 'httpd.conf'));
    if (!httpdConf.existsSync()) {
      final nestedConf = File(p.join(wsPath, 'Apache24', 'conf', 'httpd.conf'));
      if (nestedConf.existsSync()) {
        httpdConf = nestedConf;
        apacheRoot = p.join(wsPath, 'Apache24');
      }
    }

    if (!httpdConf.existsSync()) {
      log('Apache httpd.conf not found, skipping integration.');
      return;
    }

    final confDir = Directory(p.join(apacheRoot, 'conf', 'ponta_apps'));
    if (!confDir.existsSync()) {
      log('Creating Apache ponta_apps directory: ${confDir.path}');
      confDir.createSync(recursive: true);
    }
    final pmaConfFile = File(p.join(confDir.path, 'phpmyadmin.conf'));
    final pmaWebRoot = _resolvePmaWebRoot(pmaPath);
    final pmaPathUnix = pmaWebRoot.replaceAll('\\', '/');

    final pmaConfig =
        '''
# phpMyAdmin Configuration
Alias /phpmyadmin "$pmaPathUnix/"
<Directory "$pmaPathUnix/">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
</Directory>
''';

    await pmaConfFile.writeAsString(pmaConfig);
    log('Created Apache config for phpMyAdmin at ${pmaConfFile.path}');

    // Ensure httpd.conf includes this
    String content = await httpdConf.readAsString();
    if (!content.contains('ponta_apps/*.conf')) {
      log('Injecting ponta_apps include into httpd.conf...');
      // Append at the end of the file
      content += '\n# Ponta Apps Integration\nInclude conf/ponta_apps/*.conf\n';
      await httpdConf.writeAsString(content);
      log('Successfully added include to httpd.conf');
    }
  }

  Future<void> _configurePhpMyAdmin(
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Configuring phpMyAdmin (config.inc.php)...');
    final sampleFile = File(p.join(installPath, 'config.sample.inc.php'));
    final configFile = File(p.join(installPath, 'config.inc.php'));

    if (sampleFile.existsSync() && !configFile.existsSync()) {
      logInfo('Creating config.inc.php from sample...');
      String content = await sampleFile.readAsString();

      // 1. Set Blowfish secret (required for cookies, must be 32 chars)
      final random = DateTime.now().microsecondsSinceEpoch.toString();
      final secret = '${random}ponta_secret_key_for_cookie_32_chars'
          .substring(0, 32);
      content = content.replaceFirstMapped(
        RegExp(r"(\$cfg\['blowfish_secret'\]\s*=\s*').*?(';)"),
        (match) => "${match.group(1)}$secret${match.group(2)}",
      );

      // 2. Set default server to 127.0.0.1
      content = content.replaceFirstMapped(
        RegExp(r"(\$cfg\['Servers'\]\[\$i\]\['host'\]\s*=\s*').*?(';)"),
        (match) => "${match.group(1)}127.0.0.1${match.group(2)}",
      );

      // 3. Allow no password (useful for development)
      if (!content.contains('AllowNoPassword')) {
        content = content.replaceFirst(
          "['host'] = '127.0.0.1';",
          "['host'] = '127.0.0.1';\n\$cfg['Servers'][\$i]['AllowNoPassword'] = true;",
        );
      } else {
        content = content.replaceFirstMapped(
          RegExp(
            r"(\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\]\s*=\s*).*?;",
          ),
          (match) => "${match.group(1)}true;",
        );
      }

      await configFile.writeAsString(content);
      logInfo('phpMyAdmin configuration completed.');
    }
  }

  /// Resolves the correct web root for phpMyAdmin by checking for common subdirectories
  String _resolvePmaWebRoot(String pmaPath) {
    // 1. Check if index.php is already in the root
    if (File(p.join(pmaPath, 'index.php')).existsSync()) {
      return pmaPath;
    }

    // 2. Check for 'latest' folder (common in some setups)
    final latestDir = Directory(p.join(pmaPath, 'latest'));
    if (latestDir.existsSync() &&
        File(p.join(latestDir.path, 'index.php')).existsSync()) {
      return latestDir.path;
    }

    // 3. Check for any subdirectory that contains index.php (e.g. phpMyAdmin-x.y.z-all-languages)
    try {
      final dir = Directory(pmaPath);
      if (dir.existsSync()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            if (File(p.join(entity.path, 'index.php')).existsSync()) {
              return entity.path;
            }
          }
        }
      }
    } catch (_) {
      // Ignore errors during directory listing
    }

    return pmaPath; // Fallback to original path
  }
}
