import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import '../../../core/services/log_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/caddy_config_builder.dart';
import '../../../core/config/webserver_bind_policy.dart';
import '../../../core/services/ssl_service.dart';
import '../../../core/services/path_service.dart';
import '../../settings/data/settings_provider.dart';

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
  static String get defaultBaseDir => AppConfig.appsDir;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  AppInstallerService(this._logger, this._ref);

  @visibleForTesting
  static bool isWebserverApp(AppModel app) {
    final id = app.appId.toLowerCase();
    return app.groupName == 'webserver' ||
        id.contains('nginx') ||
        id.contains('apache') ||
        id.contains('caddy');
  }

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

  @visibleForTesting
  static List<String> buildTarExtractArgs(
    String archivePath,
    String destDir, {
    bool stripComponents = false,
  }) {
    return [
      '-xf',
      archivePath,
      '-C',
      destDir,
      if (stripComponents) '--strip-components=1',
    ];
  }

  @visibleForTesting
  static bool isTarArchive(String urlOrPath) {
    if (urlOrPath.isEmpty) return false;
    final uri = Uri.tryParse(urlOrPath);
    final path = (uri != null && uri.path.isNotEmpty) ? uri.path : urlOrPath;
    final lower = path.toLowerCase();
    return lower.endsWith('.tar.gz') ||
        lower.endsWith('.tar.xz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar');
  }

  /// True when [urlOrPath] is a Zonky embedded-postgres-binaries jar: a zip
  /// wrapper whose payload is a single `.txz` holding the actual PG install.
  @visibleForTesting
  static bool isZonkyPgJar(String urlOrPath) {
    final lower = urlOrPath.toLowerCase();
    return lower.endsWith('.jar') && lower.contains('embedded-postgres-binaries');
  }

  @visibleForTesting
  static Future<void> ensureLinuxPermissions(
    String targetPath, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    Function(String)? logInfo,
  }) async {
    final runner = runProcess ?? Process.run;
    try {
      final res = await runner('chmod', ['-R', '755', targetPath]);
      if (res.exitCode != 0) {
        logInfo?.call('chmod returned code ${res.exitCode}: ${res.stderr}');
      }
    } catch (e) {
      logInfo?.call('Warning: Could not set permissions on $targetPath: $e');
    }
  }

  String _generateSecret({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

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

    final tempDir = await Directory.systemTemp.createTemp(
      'ponta-${app.appId}-',
    );
    final tempFile = File(p.join(tempDir.path, 'download$downloadExt'));

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
      onProgress?.call(0.8, 'Download completed');

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
        logInfo('Extracting tar archive for ${app.name}');
        onProgress?.call(0.82, 'Extracting...');
        await Directory(installPath).create(recursive: true);
        final args = buildTarExtractArgs(tempFile.path, installPath);
        final result = await Process.run('tar', args);
        if (result.exitCode != 0) {
          logError('Tar extraction failed (exit code ${result.exitCode}): ${result.stderr}');
          throw Exception('Tar extraction failed: ${result.stderr}');
        }
        if (Platform.isLinux) {
          await ensureLinuxPermissions(installPath, logInfo: logInfo);
        }
        onProgress?.call(0.9, 'Extracted');
      } else if (isZip) {
        logInfo('Extracting ZIP for ${app.name}');
        onProgress?.call(0.82, 'Extracting...');
        final bytes = await tempFile.readAsBytes();
        await _extractZip(bytes, installPath, onLog);
        if (Platform.isLinux) {
          await ensureLinuxPermissions(installPath, logInfo: logInfo);
        }
        onProgress?.call(0.9, 'Extracted');
      } else if (isExe) {
        logInfo('Handling executable binary for ${app.name}');
        onProgress?.call(0.85, 'Moving binary...');

        // Use the specified exec_file name if available, otherwise keep original
        final fileName = app.execFile ?? p.basename(uri.path);
        final targetFile = File(p.join(installPath, fileName));

        logInfo('Copying binary to: ${targetFile.path}');
        await tempFile.copy(targetFile.path);
        if (Platform.isLinux) {
          await ensureLinuxPermissions(installPath, logInfo: logInfo);
        }
        onProgress?.call(0.9, 'Binary ready');
      } else {
        // Fallback for other formats or if extension is missing
        // For now, assume ZIP if unknown to maintain backward compatibility
        logInfo(
          'Format $extension not explicitly handled, attempting ZIP extraction...',
        );
        try {
          onProgress?.call(0.82, 'Extracting...');
          final bytes = await tempFile.readAsBytes();
          await _extractZip(bytes, installPath, onLog);
          if (Platform.isLinux) {
            await ensureLinuxPermissions(installPath, logInfo: logInfo);
          }
          onProgress?.call(0.9, 'Extracted');
        } catch (e) {
          logError('Failed to extract as ZIP: $e');
          rethrow;
        }
      }

      // 4. Flatten directory if needed
      onProgress?.call(0.92, 'Preparing files...');
      await _flattenDirectory(installPath, logInfo);

      // 5. Detect executable and CLI files
      logInfo('Detecting executable and CLI files...');
      onProgress?.call(0.94, 'Detecting files...');
      final detected = await _detectFiles(
        installPath,
        app.execFile,
        app.cliFile,
        logInfo,
      );
      app.execFilePath = detected['exec'];
      app.cliFilePath = detected['cli'];

      logInfo('Successfully installed ${app.name} to $installPath');

      // 5. Post-installation: Initialize database
      if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
        onProgress?.call(0.96, 'Initializing database...');
        await _initializeDatabase(app, version, installPath, logInfo);
      }

      // 5b. Post-installation: Initialize PostgreSQL
      if (app.appId.contains('postgresql')) {
        onProgress?.call(0.96, 'Initializing PostgreSQL...');
        await _initializePostgresql(app, version, installPath, logInfo);
      }

      // 6. Post-installation: Handle PHP configuration
      if (app.groupName == 'php') {
        onProgress?.call(0.97, 'Configuring PHP...');
        final phpIniDev = File(p.join(installPath, 'php.ini-development'));
        final phpIni = File(p.join(installPath, 'php.ini'));

        if (phpIniDev.existsSync() && !phpIni.existsSync()) {
          logInfo('Copying php.ini-development to php.ini...');
          await phpIniDev.copy(phpIni.path);
          logInfo('Successfully created php.ini');
          await _tunePhpIni(phpIni, logInfo);
          await _enableDefaultExtensions(phpIni, installPath, logInfo);
        }

        // Install Composer if not already installed
        onProgress?.call(0.98, 'Installing Composer...');
        await _installComposer(logInfo);
      }

      // 7. Post-installation: Configure Web Servers
      if (isWebserverApp(app)) {
        onProgress?.call(0.97, 'Configuring web server...');
        await _configureWebserver(app, installPath, logInfo);
      }

      // 8. Post-installation: Configure MongoDB
      if (app.appId == 'mongodb') {
        onProgress?.call(0.97, 'Configuring MongoDB...');
        await _configureMongodb(app, installPath, logInfo);
      }

      // 10. Post-installation: Configure Meilisearch
      if (app.appId == 'meilisearch') {
        onProgress?.call(0.97, 'Configuring Meilisearch...');
        await _configureMeilisearch(installPath, logInfo);
      }

      // 11. Post-installation: Configure Elasticsearch
      if (app.appId == 'elasticsearch') {
        onProgress?.call(0.97, 'Configuring Elasticsearch...');
        await _configureElasticsearch(installPath, logInfo);
      }

      // 9. Post-installation: Configure phpMyAdmin
      if (app.appId == 'phpMyAdmin') {
        onProgress?.call(0.97, 'Configuring phpMyAdmin...');
        await _configurePhpMyAdmin(installPath, logInfo);
      }

      // 10. Post-installation: Configure pyenv
      if (app.appId == 'pyenv') {
        onProgress?.call(0.97, 'Configuring pyenv...');
        await _configurePyenv(installPath, logInfo);
      }

      // 11. Post-installation: Configure RustFS
      if (app.appId == 'rustfs') {
        onProgress?.call(0.97, 'Configuring RustFS...');
        await _configureRustFS(app, installPath, logInfo);
      }

      onProgress?.call(1.0, 'Completed');
      return installPath;
    } catch (e) {
      logError('Installation failed for ${app.name}: $e');
      rethrow;
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

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

  Future<void> _extractZip(
    List<int> bytes,
    String targetPath,
    InstallationLogCallback? onLog,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final canonicalTarget = p.canonicalize(targetPath);
    final targetPrefix = canonicalTarget.endsWith(p.separator)
        ? canonicalTarget
        : '$canonicalTarget${p.separator}';
    for (final file in archive) {
      final filename = file.name;
      // Path traversal protection: reject absolute paths and ".." segments.
      final parts = p.split(filename);
      if (p.isAbsolute(filename) || parts.contains('..')) {
        if (onLog != null) onLog('Skipping unsafe entry: $filename');
        continue;
      }
      final destPath = p.canonicalize(p.join(targetPath, filename));
      if (destPath != canonicalTarget && !destPath.startsWith(targetPrefix)) {
        if (onLog != null) onLog('Skipping entry outside target: $filename');
        continue;
      }
      if (onLog != null) onLog('Extracting: $filename');
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File(destPath);
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory(destPath).create(recursive: true);
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
        try {
          await entity.rename(newPath);
        } catch (e) {
          logInfo('Warning: Could not move ${entity.path}: $e');
        }
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

    // Extract cacert.pem from assets to a stable location
    final certsDir = Directory(AppConfig.certsDir);
    if (!certsDir.existsSync()) {
      certsDir.createSync(recursive: true);
    }
    final cacertPath = p.join(AppConfig.certsDir, 'cacert.pem');
    try {
      final cacertData = await rootBundle.load('assets/data/cacert.pem');
      await File(cacertPath).writeAsBytes(cacertData.buffer.asUint8List());
      logInfo('Extracted cacert.pem to $cacertPath');
    } catch (e) {
      logInfo('Warning: Could not extract cacert.pem: $e');
    }

    // Use forward slashes for php.ini paths (Windows accepts both)
    final cacertPathNormalized = cacertPath.replaceAll(r'\', '/');

    final Map<String, String> replacements = {
      r'^;?\s*max_execution_time\s*=.*': 'max_execution_time = 1800',
      r'^;?\s*max_input_time\s*=.*': 'max_input_time = 3600',
      r'^;?\s*memory_limit\s*=.*': 'memory_limit = 2G',
      r'^;?\s*post_max_size\s*=.*': 'post_max_size = 2G',
      r'^;?\s*upload_max_filesize\s*=.*': 'upload_max_filesize = 512M',
      r'^;?\s*extension_dir\s*=\s*"ext"': 'extension_dir = "ext"',
      r'^;?\s*realpath_cache_size\s*=.*': 'realpath_cache_size = 4096k',
      r'^;?\s*realpath_cache_ttl\s*=.*': 'realpath_cache_ttl = 600',
      r'^;?\s*openssl\.cafile\s*=.*':
          'openssl.cafile = "$cacertPathNormalized"',
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
      'openssl',
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
    String version,
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Initializing database system tables...');
    final dataDir = Directory(
      p.join(AppConfig.dataDir, '${app.appId}-$version'),
    );
    if (dataDir.existsSync() && dataDir.listSync().isNotEmpty) {
      logInfo(
        'Data directory already contains data, skipping initialization to '
        'avoid overwriting it: ${dataDir.path}',
      );
      return;
    }
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }

    final binDir = Directory(p.join(installPath, 'bin'));
    if (!binDir.existsSync()) {
      throw Exception(
        'Database bin directory not found at $binDir; cannot initialize.',
      );
    }

    String? initExec;
    List<String> args = [];

    if (app.appId.contains('mysql')) {
      initExec = resolveDbTool(installPath, 'mysqld');
      args = [
        '--initialize-insecure',
        '--console',
        '--datadir=${dataDir.path}',
      ];
    } else if (app.appId.contains('mariadb')) {
      // MariaDB uses mysql_install_db or mariadb-install-db
      final mdbInstall = File(resolveDbTool(installPath, 'mariadb-install-db'));
      final mysqlInstall = File(resolveDbTool(installPath, 'mysql_install_db'));

      if (mdbInstall.existsSync()) {
        initExec = mdbInstall.path;
      } else if (mysqlInstall.existsSync()) {
        initExec = mysqlInstall.path;
      }
      args = [
        '--datadir=${dataDir.path}',
        if (Platform.isLinux) '--basedir=$installPath',
      ];
    }

    if (initExec != null && File(initExec).existsSync()) {
      logInfo('Running: $initExec ${args.join(' ')}');
      try {
        final result = await Process.run(initExec, args);
        if (result.exitCode == 0) {
          logInfo('Database initialized successfully.');
        } else {
          // A non-zero init exit means the data directory is NOT initialized.
          // Surface this as a failure rather than letting install() report
          // success — otherwise the app is marked "installed" but the engine
          // can never start (empty/corrupt data dir) with a cryptic later error
          // and no record that init failed.
          logInfo('Initialization returned non-zero code: ${result.exitCode}');
          logInfo('Output: ${result.stdout}');
          logInfo('Error: ${result.stderr}');
          throw Exception(
            'Database initialization failed (exit code ${result.exitCode}): '
            '${result.stderr}',
          );
        }
      } catch (e) {
        // Re-throw the Exception we just built; for any other Process error,
        // wrap it so the install surfaces a clear failure rather than
        // silently leaving an uninitialized data directory.
        logInfo('Error during database initialization: $e');
        if (e is Exception) {
          rethrow;
        }
        throw Exception('Database initialization failed: $e');
      }
    } else {
      // No init executable means we cannot set up a working data dir — fail
      // loudly instead of marking the engine installed-but-broken.
      throw Exception(
        'Database initialization executable not found in $binDir',
      );
    }
  }

  Future<void> _initializePostgresql(
    AppModel app,
    String version,
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Initializing PostgreSQL database cluster...');
    final dataDir = Directory(
      p.join(AppConfig.dataDir, '${app.appId}-$version'),
    );
    if (dataDir.existsSync() && dataDir.listSync().isNotEmpty) {
      logInfo(
        'Data directory already contains a cluster, skipping initdb to '
        'avoid overwriting it: ${dataDir.path}',
      );
      return;
    }
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }

    final binDir = Directory(p.join(installPath, 'bin'));
    if (!binDir.existsSync()) {
      throw Exception(
        'PostgreSQL bin directory not found at $binDir; cannot initialize.',
      );
    }

    final initdbPath = resolveDbTool(installPath, 'initdb');
    if (!File(initdbPath).existsSync()) {
      throw Exception(
        'initdb not found at $initdbPath; cannot initialize the cluster.',
      );
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

    logInfo('Running: $initdbPath ${args.join(' ')}');
    try {
      final result = await Process.run(initdbPath, args);
      if (result.exitCode == 0) {
        logInfo('PostgreSQL database cluster initialized successfully.');

        // Allow connections from any IP
        try {
          final confFile = File(p.join(dataDir.path, 'postgresql.conf'));
          if (confFile.existsSync()) {
            var content = await confFile.readAsString();
            content = content.replaceAll(
              RegExp(r"^#?listen_addresses\s*=\s*'.*?'", multiLine: true),
              "listen_addresses = '*'",
            );
            await confFile.writeAsString(content);
            logInfo('Updated PostgreSQL listen_addresses to *');
          }

          final hbaFile = File(p.join(dataDir.path, 'pg_hba.conf'));
          if (hbaFile.existsSync()) {
            var content = await hbaFile.readAsString();
            if (!content.contains('127.0.0.1/32')) {
              content +=
                  '\nhost    all             all             127.0.0.1/32            scram-sha-256\n';
              await hbaFile.writeAsString(content);
              logInfo(
                'Updated pg_hba.conf to allow localhost connections only',
              );
            }
          }
        } catch (e) {
          logInfo(
            'Warning: Could not update PostgreSQL config for remote access: $e',
          );
        }
      } else {
        logInfo('Initialization returned non-zero code: ${result.exitCode}');
        logInfo('Output: ${result.stdout}');
        logInfo('Error: ${result.stderr}');
        throw Exception(
          'PostgreSQL initialization failed (exit code ${result.exitCode}): '
          '${result.stderr}',
        );
      }
    } catch (e) {
      logInfo('Error during PostgreSQL initialization: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('PostgreSQL initialization failed: $e');
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

    // Create vhosts directories
    final nginxVhosts = Directory(p.join(AppConfig.vhostsDir, 'nginx'));
    if (!nginxVhosts.existsSync()) {
      logInfo('Creating Nginx vhosts directory: ${nginxVhosts.path}');
      await nginxVhosts.create(recursive: true);
    }
    final apacheVhosts = Directory(p.join(AppConfig.vhostsDir, 'apache'));
    if (!apacheVhosts.existsSync()) {
      logInfo('Creating Apache vhosts directory: ${apacheVhosts.path}');
      await apacheVhosts.create(recursive: true);
    }

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

    // Add default index.html
    final indexHtml = File(p.join(wwwDir.path, 'index.html'));
    await indexHtml.writeAsString('''<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Ponta</title>
    <style>
        body { font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f4f7f6; color: #333; }
        .container { text-align: center; padding: 40px; background: white; border-radius: 12px; shadow: 0 4px 20px rgba(0,0,0,0.08); }
        h1 { color: #007bff; }
        code { background: #f4f7f6; padding: 2px 4px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Ponta Web Server</h1>
        <p>Web server: <code>${app.name}</code></p>
        <p>Root directory: <code>${wwwDir.path}</code></p>
    </div>
</body>
</html>''');

    final webRoot = AppConfig.webserverRoot.replaceAll('\\', '/');

    final isSslInstalled = _ref.read(sslServiceProvider).value ?? false;
    final sslNotifier = _ref.read(sslServiceProvider.notifier);
    final settings = await _ref.read(settingsNotifierProvider.future);
    final allowLanAccess = settings.allowLanAccess;
    final bindAddress = WebserverBindPolicy.address(
      allowLanAccess: allowLanAccess,
    );

    if (isSslInstalled) {
      await sslNotifier.generateSiteCert('localhost');
    }

    if (app.appId.contains('nginx')) {
      final confFile = File(p.join(installPath, 'conf', 'nginx.conf'));
      logInfo('Generating fresh Nginx configuration...');

      final certPath = sslNotifier
          .getSiteCertPath('localhost')
          .replaceAll('\\', '/');
      final keyPath = sslNotifier
          .getSiteKeyPath('localhost')
          .replaceAll('\\', '/');
      final cleanWebRoot = webRoot.replaceAll('\\', '/');

      final nginxConfig = _getNginxConfigTemplate(
        webRoot: cleanWebRoot,
        isSslInstalled: isSslInstalled,
        certPath: certPath,
        keyPath: keyPath,
        allowLanAccess: allowLanAccess,
      );

      await confFile.writeAsString(nginxConfig);
      logInfo('Nginx configuration generated successfully.');
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

        // 5. Bind only to localhost by default. LAN access must be explicitly
        // enabled in Settings. Normalize old wildcard/duplicate directives too.
        content = WebserverBindPolicy.normalizeApacheListeners(
          content,
          allowLanAccess: allowLanAccess,
          includeSsl: isSslInstalled,
        );

        // 6. Fix ServerName warning
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

          // Enable mod_ssl and socache_shmcb using flexible regex
          content = content.replaceFirst(
            RegExp(r'#\s*LoadModule\s+ssl_module\s+modules/mod_ssl.so'),
            'LoadModule ssl_module modules/mod_ssl.so',
          );
          content = content.replaceFirst(
            RegExp(
              r'#\s*LoadModule\s+socache_shmcb_module\s+modules/mod_socache_shmcb.so',
            ),
            'LoadModule socache_shmcb_module modules/mod_socache_shmcb.so',
          );

          // Enable proxy modules for PHP-CGI
          content = content.replaceFirst(
            RegExp(r'#\s*LoadModule\s+proxy_module\s+modules/mod_proxy.so'),
            'LoadModule proxy_module modules/mod_proxy.so',
          );
          content = content.replaceFirst(
            RegExp(
              r'#\s*LoadModule\s+proxy_fcgi_module\s+modules/mod_proxy_fcgi.so',
            ),
            'LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so',
          );

          final certPath = sslNotifier
              .getSiteCertPath('localhost')
              .replaceAll('\\', '/');
          final keyPath = sslNotifier
              .getSiteKeyPath('localhost')
              .replaceAll('\\', '/');

          final sslVhost =
              '''
$sslVhostMarker
<IfModule mod_ssl.c>
<VirtualHost $bindAddress:443>
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
</IfModule>
''';
          // Remove existing vhost if any
          final existingRegex = RegExp(
            r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/IfModule>',
            dotAll: true,
          );
          content = content.replaceAll(existingRegex, '');

          content += '\n$sslVhost\n';
        } else {
          // Remove SSL config if uninstalled
          if (content.contains(sslVhostMarker)) {
            logInfo('Removing SSL config from Apache...');
            final existingRegex = RegExp(
              r'\s*' + RegExp.escape(sslVhostMarker) + r'.*?<\/IfModule>',
              dotAll: true,
            );
            content = content.replaceAll(existingRegex, '');
            // Optionally disable modules but keep it simple for now
          }
        }

        await confFile.writeAsString(content);
        logInfo(
          'Apache configuration updated (SRVROOT, DocumentRoot, Permissions, SSL).',
        );

        // Include global vhosts
        String httpdContent = await confFile.readAsString();
        final vhostsPath = p
            .join(AppConfig.vhostsDir, 'apache', '*.conf')
            .replaceAll('\\', '/');
        if (!httpdContent.contains('IncludeOptional "$vhostsPath"')) {
          logInfo('Adding global vhosts include to Apache...');
          httpdContent += '\n# Global Vhosts\nIncludeOptional "$vhostsPath"\n';
          await confFile.writeAsString(httpdContent);
        }
      } else {
        logInfo('Warning: Could not find Apache httpd.conf to configure.');
      }
    }
  }

  String _getNginxConfigTemplate({
    required String webRoot,
    required bool isSslInstalled,
    required String certPath,
    required String keyPath,
    required bool allowLanAccess,
  }) {
    final httpListen = WebserverBindPolicy.nginxListen(
      80,
      allowLanAccess: allowLanAccess,
    );
    final httpsListen = WebserverBindPolicy.nginxListen(
      443,
      allowLanAccess: allowLanAccess,
      ssl: true,
    );
    String sslBlock = '';
    if (isSslInstalled) {
      sslBlock =
          '''
    # HTTPS server
    server {
        listen       $httpsListen;
        server_name  localhost;
        root         "$webRoot";

        ssl_certificate      "$certPath";
        ssl_certificate_key  "$keyPath";

        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;

        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;

        location / {
            index  index.html index.htm index.php;
        }

        # Global Integrations
        include "${p.join(AppConfig.vhostsDir, 'nginx', 'integrations', '*.conf').replaceAll('\\', '/')}";
    }''';
    }

    return '''
worker_processes  auto;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # HTTP server
    server {
        listen       $httpListen;
        server_name  localhost;
        root         "$webRoot";

        location / {
            index  index.html index.htm index.php;
        }

        # Global Integrations
        include "${p.join(AppConfig.vhostsDir, 'nginx', 'integrations', '*.conf').replaceAll('\\', '/')}";
    }

$sslBlock

    # Global Vhosts
    include "${p.join(AppConfig.vhostsDir, 'nginx', '*.conf').replaceAll('\\', '/')}";
}
''';
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
security:
  authorization: enabled
''';
      await confFile.writeAsString(configContent);
      logInfo('Created MongoDB configuration at ${confFile.path}');
    }
  }

  Future<void> reconfigureWebservers(
    List<AppModel> allApps,
    Function(String) logInfo,
  ) async {
    final webServers = allApps
        .where((app) => app.isInstalled && isWebserverApp(app))
        .toList();

    for (final ws in webServers) {
      if (ws.location != null) {
        logInfo('Reconfiguring ${ws.name} at ${ws.location}...');
        await _configureWebserver(ws, ws.location!, logInfo);
      }
    }
  }

  /// Fault-injection hooks for data carry-over. Tests set these to exercise
  /// failure paths that are impractical to trigger for real (cross-volume
  /// renames, a full disk mid-copy). Always null in production.
  @visibleForTesting
  static void Function()? debugRenameFailure;

  @visibleForTesting
  static void Function()? debugCopyFailure;

  /// Recursively deletes [directory], retrying on Windows "Access is denied
  /// (errno 5)" with a short backoff. Even after a process tree is killed,
  /// Windows can hold a DLL/file handle for a few hundred ms; a single
  /// `delete(recursive: true)` then fails and aborts an entire version swap.
  /// Retrying lets the OS release the lingering handle instead of surfacing
  /// a hard failure to the user.
  ///
  /// Only Access Denied is retried — other errors (disk full, path not found,
  /// permission policy) are surfaced immediately since retrying won't help.
  ///
  /// [attemptDelete] is overridable purely for tests; production leaves it null
  /// and the real `Directory.delete(recursive: true)` is used.
  Future<void> _deleteRecursiveWithRetries(
    Directory directory, {
    int maxAttempts = 5,
    Duration delayBetweenAttempts = const Duration(milliseconds: 300),
    Future<void> Function(Directory)? attemptDelete,
  }) async {
    final deleter = attemptDelete ?? (d) => d.delete(recursive: true);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await deleter(directory);
        return;
      } catch (e) {
        if (attempt == maxAttempts || !_isAccessDenied(e)) rethrow;
        _logger.warning(
          'Delete attempt $attempt/$maxAttempts for ${directory.path} failed '
          'with Access Denied (errno 5); retrying in '
          '${delayBetweenAttempts.inMilliseconds}ms. ($e)',
        );
        await Future<void>.delayed(delayBetweenAttempts);
      }
    }
  }

  /// True when [error] represents a Windows Access Denied (errno 5) on delete.
  /// We match both [PathAccessException] (thrown by `Directory.delete`) and a
  /// raw [FileSystemException] carrying the OS errno, since the surface type
  /// can vary across Dart SDK patch levels.
  bool _isAccessDenied(Object error) {
    int? errno;
    String message = '';
    OSError? osError;
    if (error is PathAccessException) {
      osError = error.osError;
      errno = osError?.errorCode;
      message = error.message;
    } else if (error is FileSystemException) {
      osError = error.osError;
      errno = osError?.errorCode;
      message = error.message;
    }
    if (errno == 5) return true;
    final m = message.toLowerCase();
    return m.contains('access is denied') || m.contains('access denied');
  }

  /// Test seam for [_deleteRecursiveWithRetries]. Lets a test inject the
  /// actual delete behavior (to simulate a transient lock that releases after
  /// one failure) without touching the real filesystem inside the retry loop.
  @visibleForTesting
  Future<void> deleteDirectoryWithRetriesForTest(
    Directory directory, {
    required Future<void> Function(Directory) attemptDelete,
    int maxAttempts = 5,
    Duration delayBetweenAttempts = const Duration(milliseconds: 300),
  }) => _deleteRecursiveWithRetries(
    directory,
    maxAttempts: maxAttempts,
    delayBetweenAttempts: delayBetweenAttempts,
    attemptDelete: attemptDelete,
  );

  /// True when [appId] keeps its data in a version-keyed directory
  /// (`<dataDir>/<appId>-<version>`) that must be carried across a version swap.
  static bool hasVersionedDataDir(String appId) =>
      appId.contains('mysql') ||
      appId.contains('mariadb') ||
      appId.contains('postgresql');

  /// Resolves the FastCGI port a PHP binary listens on.
  ///
  /// Only matches the exact `php<MAJOR><MINOR>` naming convention used by the
  /// app catalog (e.g. ``php82`` -> 9082). Anything else (``php8``, ``php8.2``,
  /// or an unknown appId) falls back to the safe default ``9000`` — never an
  /// arbitrary number extracted from the id with a greedy ``\d+`` match, which
  /// silently produced wrong ports for non-conforming ids.
  static int phpPortFor(String appId) {
    final match = RegExp(r'^php(\d)(\d)$').firstMatch(appId);
    if (match == null) return 9000;
    final major = int.tryParse(match.group(1)!);
    final minor = int.tryParse(match.group(2)!);
    if (major == null || minor == null) return 9000;
    final port = int.parse('90$major$minor');
    return (port >= 1024 && port <= 65535) ? port : 9000;
  }

  /// Moves the version-keyed data directory from [oldVersion] to [newVersion]
  /// so an updated engine keeps the user's existing databases.
  ///
  /// Does nothing when the app has no versioned data dir, when the source is
  /// missing, or when a non-empty destination already exists. Returns true when
  /// data was carried over.
  Future<bool> carryOverDataDir(
    String appId,
    String? oldVersion,
    String newVersion,
    Function(String) logInfo,
  ) async {
    if (!hasVersionedDataDir(appId)) return false;
    if (oldVersion == null || oldVersion == newVersion) return false;

    final oldDataDir = Directory(
      p.join(AppConfig.dataDir, '$appId-$oldVersion'),
    );
    final newDataDir = Directory(
      p.join(AppConfig.dataDir, '$appId-$newVersion'),
    );

    // PostgreSQL stores its catalog version in the cluster, so a data dir built
    // by PG15 cannot be opened by PG16 (the new initdb already ran). Carrying it
    // over would leave the engine unable to start instead of losing data, which
    // is strictly worse for the user. Gate carry-over on the same major version:
    // read the old cluster's `PG_VERSION`, compare to the new binary's major.
    if (appId.contains('postgresql')) {
      final pgVersionFile = File(p.join(oldDataDir.path, 'PG_VERSION'));
      if (pgVersionFile.existsSync()) {
        final oldMajor = int.tryParse(
          (await pgVersionFile.readAsString()).trim(),
        );
        final newMajor = int.tryParse(newVersion.split('.').first);
        if (oldMajor != null && newMajor != null && oldMajor != newMajor) {
          logInfo(
            'PostgreSQL major version changed (PG$oldMajor -> PG$newMajor); '
            'not carrying the data directory. The old cluster at '
            '${oldDataDir.path} is left intact; initdb will create a fresh '
            'PG$newMajor cluster. Use pg_upgrade to migrate the data.',
          );
          return false;
        }
      }
    }

    if (!oldDataDir.existsSync() || oldDataDir.listSync().isEmpty) return false;
    if (newDataDir.existsSync() && newDataDir.listSync().isNotEmpty) {
      logInfo(
        'Data directory for $newVersion already exists, keeping it and leaving '
        '${oldDataDir.path} untouched.',
      );
      return false;
    }

    logInfo('Carrying over data: ${oldDataDir.path} -> ${newDataDir.path}');
    try {
      if (newDataDir.existsSync()) await newDataDir.delete();
      debugRenameFailure?.call();
      await oldDataDir.rename(newDataDir.path);
      logInfo('Data directory carried over to $newVersion.');
      return true;
    } catch (e) {
      // Cross-volume or locked file: fall back to copy, keeping the original
      // intact so a failure never destroys the user's data.
      logInfo('Rename failed ($e), falling back to copy...');
      try {
        await _copyDirectory(oldDataDir, newDataDir);
        logInfo(
          'Data copied to $newVersion. Original kept at ${oldDataDir.path}.',
        );
        return true;
      } catch (e2) {
        // A half-copied directory looks "already initialized" to the engine
        // setup, so the update would silently start on truncated data. Remove
        // it and let the caller abort; the original is still intact.
        logInfo('ERROR: Could not carry over data directory: $e2');
        if (newDataDir.existsSync()) {
          try {
            await newDataDir.delete(recursive: true);
            logInfo('Removed the incomplete copy at ${newDataDir.path}.');
          } catch (e3) {
            logInfo('ERROR: Could not remove the incomplete copy: $e3');
          }
        }
        rethrow;
      }
    }
  }

  /// Restores a data directory carried to [newVersion] after an update fails.
  ///
  /// If carry-over used rename, the new directory is moved back. If it used
  /// copy, the original still exists and only the temporary new copy is removed.
  Future<void> rollbackCarriedDataDir(
    String appId,
    String? oldVersion,
    String newVersion,
    Function(String) logInfo,
  ) async {
    if (!hasVersionedDataDir(appId)) return;
    if (oldVersion == null || oldVersion == newVersion) return;

    final oldDataDir = Directory(
      p.join(AppConfig.dataDir, '$appId-$oldVersion'),
    );
    final newDataDir = Directory(
      p.join(AppConfig.dataDir, '$appId-$newVersion'),
    );
    if (!newDataDir.existsSync()) return;

    if (oldDataDir.existsSync()) {
      logInfo('Removing copied data for failed update: ${newDataDir.path}');
      await newDataDir.delete(recursive: true);
      return;
    }

    logInfo(
      'Restoring data for $oldVersion after failed update: '
      '${newDataDir.path} -> ${oldDataDir.path}',
    );
    await newDataDir.rename(oldDataDir.path);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      await destination.create(recursive: true);
    }
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
        debugCopyFailure?.call();
      }
    }
  }

  /// Removes the install directory at [path].
  ///
  /// Data directories (database clusters, search indexes, object storage) are
  /// only removed when [deleteData] is true. Pass false when replacing one
  /// version with another so the user's data survives the swap.
  Future<void> delete(
    String path,
    String appId,
    String? version, {
    bool deleteData = true,
  }) async {
    final directory = Directory(path);
    if (directory.existsSync()) {
      _logger.info('Deleting directory: $path');
      await _deleteRecursiveWithRetries(directory);
    }

    if (!deleteData) {
      _logger.info('Preserving data directories for $appId (version swap)');
      return;
    }

    // Delete data directory for databases
    if (version != null && hasVersionedDataDir(appId)) {
      final dataDir = Directory(p.join(AppConfig.dataDir, '$appId-$version'));
      if (dataDir.existsSync()) {
        _logger.info('Deleting data directory: ${dataDir.path}');
        await dataDir.delete(recursive: true);
      }
    }

    // Delete data directory for Meilisearch
    if (appId == 'meilisearch') {
      final dataDir = Directory(p.join(AppConfig.dataDir, 'meilisearch'));
      if (dataDir.existsSync()) {
        _logger.info('Deleting Meilisearch data directory: ${dataDir.path}');
        await dataDir.delete(recursive: true);
      }
    }

    // Delete data directory for RustFS
    if (appId == 'rustfs') {
      final dataDir = Directory(p.join(AppConfig.dataDir, 'rustfs'));
      if (dataDir.existsSync()) {
        _logger.info('Deleting RustFS data directory: ${dataDir.path}');
        await dataDir.delete(recursive: true);
      }
    }

    // Delete data directory for Elasticsearch
    if (appId == 'elasticsearch') {
      final dataDir = Directory(p.join(AppConfig.dataDir, 'elasticsearch'));
      if (dataDir.existsSync()) {
        _logger.info('Deleting Elasticsearch data directory: ${dataDir.path}');
        await dataDir.delete(recursive: true);
      }
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
    final isWebServer = isWebserverApp(currentApp);

    if (!isPMA && !isWebServer) return;

    log('Syncing inter-app configurations for ${currentApp.name}...');

    // 1. Identify phpMyAdmin
    AppModel? phpMyAdmin;
    if (isPMA) {
      phpMyAdmin = currentApp;
    } else {
      phpMyAdmin = allApps
          .where((a) => a.appId == 'phpMyAdmin' && a.isInstalled)
          .firstOrNull;
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
          .where((app) => app.isInstalled && isWebserverApp(app))
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
        } else if (ws.appId.contains('caddy')) {
          await _configurePhpMyAdminInCaddy(ws, phpMyAdmin, bestPhp, log);
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

    final nginxVhostsDir = Directory(
      p.join(AppConfig.vhostsDir, 'nginx', 'integrations'),
    );
    if (!nginxVhostsDir.existsSync()) {
      await nginxVhostsDir.create(recursive: true);
    }

    // Cleanup legacy config if exists
    final legacyConf = File(
      p.join(AppConfig.vhostsDir, 'nginx', 'phpmyadmin.conf'),
    );
    if (legacyConf.existsSync()) {
      await legacyConf.delete();
      log('Removed legacy phpmyadmin.conf from vhosts root');
    }

    final pmaConfFile = File(p.join(nginxVhostsDir.path, 'phpmyadmin.conf'));

    // Determine PHP port
    String phpPort = '9000'; // Default
    if (php != null) {
      final customPort = php.extraInfo['port']?.toString() ?? '';
      if (customPort.isNotEmpty) {
        phpPort = customPort;
      } else {
        phpPort = AppInstallerService.phpPortFor(php.appId).toString();
      }
    }

    final pmaWebRoot = _resolvePmaWebRoot(pmaPath);
    final pmaPathUnix = pmaWebRoot.replaceAll('\\', '/');

    final pmaConfig =
        '''
# phpMyAdmin Integration
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
  }

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
      phpPort =
          int.tryParse(php.extraInfo['port']?.toString() ?? '') ??
          AppInstallerService.phpPortFor(php.appId);
    }

    final pmaRoot = _resolvePmaWebRoot(pma.location!);
    final config = CaddyConfigBuilder.phpMyAdminIntegration(
      rootDir: pmaRoot,
      phpPort: phpPort,
    );
    final configFile = File(p.join(integrationsDir.path, 'phpmyadmin.conf'));
    await configFile.writeAsString(config);
    log(
      'Created Caddy config for phpMyAdmin at ${configFile.path} '
      '(PHP Port: $phpPort)',
    );
  }

  Future<void> _configurePhpMyAdminInApache(
    AppModel apache,
    AppModel pma,
    Function(String) log,
  ) async {
    final wsPath = apache.location;
    final pmaPath = pma.location;
    if (wsPath == null || pmaPath == null) return;

    final apacheVhostsDir = Directory(p.join(AppConfig.vhostsDir, 'apache'));
    if (!apacheVhostsDir.existsSync()) {
      await apacheVhostsDir.create(recursive: true);
    }

    final pmaConfFile = File(p.join(apacheVhostsDir.path, 'phpmyadmin.conf'));
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
      final secret = '${random}ponta_secret_key_for_cookie_32_chars'.substring(
        0,
        32,
      );
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

  Future<void> _configurePyenv(
    String installPath,
    Function(String) logInfo,
  ) async {
    if (Platform.isWindows) {
      logInfo('Configuring pyenv-win environment variables and PATH...');

      final pathService = _ref.read(pathServiceProvider);
      final pyenvWinDir = p.join(installPath, 'pyenv-win');

      // Check if pyenv-win directory exists
      if (!Directory(pyenvWinDir).existsSync()) {
        logInfo(
          'Warning: pyenv-win directory not found at $pyenvWinDir. Skipping detailed config.',
        );
        return;
      }

      final binDir = p.join(pyenvWinDir, 'bin');
      final shimsDir = p.join(pyenvWinDir, 'shims');

      // Set environment variables
      await pathService.setUserEnvVar('PYENV', pyenvWinDir);
      await pathService.setUserEnvVar('PYENV_HOME', pyenvWinDir);
      await pathService.setUserEnvVar('PYENV_ROOT', pyenvWinDir);

      // Add to PATH
      await pathService.addRawPathToUserPath(binDir);
      await pathService.addRawPathToUserPath(shimsDir);

      logInfo(
        'pyenv-win configuration completed. Please restart your terminal/IDE to apply changes.',
      );
      return;
    }

    // Linux: real pyenv (github.com/pyenv/pyenv) — the master.zip layout is
    // bin/pyenv + libexec/pyenv-* directly under installPath (no pyenv-win/
    // nesting); shims activate via `pyenv init` in the shell rc.
    final pathService = _ref.read(pathServiceProvider);
    await pathService.setUserEnvVar('PYENV_ROOT', installPath);
    await pathService.addRawPathToUserPath(p.join(installPath, 'bin'));
    await pathService.addRawPathToUserPath(p.join(installPath, 'shims'));
    logInfo(
      'pyenv configured. Add `eval "\$(pyenv init -)"` to your shell rc '
      'for full shim activation.',
    );
  }

  Future<void> cleanupPyenv(
    String installPath,
    Function(String) logInfo,
  ) async {
    if (Platform.isWindows) {
      logInfo('Cleaning up pyenv-win environment variables and PATH...');

      final pathService = _ref.read(pathServiceProvider);
      final pyenvWinDir = p.join(installPath, 'pyenv-win');
      final binDir = p.join(pyenvWinDir, 'bin');
      final shimsDir = p.join(pyenvWinDir, 'shims');

      // Remove environment variables
      await pathService.removeUserEnvVar('PYENV');
      await pathService.removeUserEnvVar('PYENV_HOME');
      await pathService.removeUserEnvVar('PYENV_ROOT');

      // Remove from PATH
      await pathService.removeRawPathFromUserPath(binDir);
      await pathService.removeRawPathFromUserPath(shimsDir);

      logInfo('pyenv-win cleanup completed.');
      return;
    }

    logInfo('Cleaning up pyenv environment variables and PATH...');
    final pathService = _ref.read(pathServiceProvider);
    await pathService.removeUserEnvVar('PYENV_ROOT');
    await pathService.removeRawPathFromUserPath(p.join(installPath, 'bin'));
    await pathService.removeRawPathFromUserPath(p.join(installPath, 'shims'));
    logInfo('pyenv cleanup completed.');
  }

  Future<void> _configureRustFS(
    AppModel app,
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo('Configuring RustFS storage directory...');
    final dataDir = Directory(p.join(AppConfig.dataDir, 'rustfs'));
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
      logInfo('Created RustFS storage directory at ${dataDir.path}');
    }

    // Default configuration can be done via environment or arguments,
    // so here we just ensure the data path exists.
  }

  Future<void> _configureMeilisearch(
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo(
      'Configuring Meilisearch (Hybrid: Config in App, Data in Ponta Data)...',
    );
    final dataDir = Directory(p.join(AppConfig.dataDir, 'meilisearch'));
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }

    final confFile = File(p.join(installPath, 'config.toml'));
    if (!confFile.existsSync()) {
      final buffer = StringBuffer();
      buffer.writeln(
        '# ======================== Ponta Managed Configuration =========================',
      );
      buffer.writeln('http_addr = "127.0.0.1:7700"');
      buffer.writeln('master_key = "${_generateSecret()}"');
      buffer.writeln('env = "development"');
      buffer.writeln('no_analytics = true');
      buffer.writeln(
        'db_path = "${p.join(dataDir.path, 'data.ms').replaceAll('\\', '/')}"',
      );

      await confFile.writeAsString(buffer.toString());
      logInfo('Applied managed configuration to ${confFile.path}');
    }
  }

  Future<void> _configureElasticsearch(
    String installPath,
    Function(String) logInfo,
  ) async {
    logInfo(
      'Configuring Elasticsearch (Hybrid: Config in App, Data in Ponta Data)...',
    );
    final esDataDir = Directory(p.join(AppConfig.dataDir, 'elasticsearch'));
    final dataPath = Directory(p.join(esDataDir.path, 'data'));
    final logsPath = Directory(p.join(esDataDir.path, 'logs'));

    if (!esDataDir.existsSync()) await esDataDir.create(recursive: true);
    if (!dataPath.existsSync()) await dataPath.create(recursive: true);
    if (!logsPath.existsSync()) await logsPath.create(recursive: true);

    // Edit config directly in the installPath/config directory
    final confFile = File(p.join(installPath, 'config', 'elasticsearch.yml'));

    if (confFile.existsSync()) {
      final buffer = StringBuffer();
      buffer.writeln(
        '# ======================== Ponta Managed Configuration =========================',
      );
      buffer.writeln('cluster.name: "ponta-cluster"');
      buffer.writeln('node.name: "ponta-node-1"');
      buffer.writeln('network.host: 127.0.0.1');
      buffer.writeln('http.port: 9200');
      buffer.writeln('discovery.type: single-node');
      buffer.writeln('xpack.security.enabled: true');
      buffer.writeln('ingest.geoip.downloader.enabled: false');

      // Points data and logs to the managed Ponta data directory
      buffer.writeln('path.data: "${dataPath.path.replaceAll('\\', '/')}"');
      buffer.writeln('path.logs: "${logsPath.path.replaceAll('\\', '/')}"');

      await confFile.writeAsString(buffer.toString());
      logInfo('Applied managed configuration to ${confFile.path}');
    }
  }

  /// Downloads composer.phar and creates cross-shell composer wrappers in Ponta bin directory.
  /// The wrapper uses `php` from PATH, so it will use whichever PHP version
  /// the user has added to PATH or the default PHP.
  Future<void> _installComposer(Function(String) logInfo) async {
    final composerPhar = File(p.join(PathService.binDir, 'composer.phar'));
    final composerShimPaths = PathService.shimPathsFor(
      PathService.binDir,
      'composer',
    );

    // Skip download if already installed, but still remove legacy PowerShell shim
    // and ensure Composer global bin is on PATH.
    if (composerPhar.existsSync() &&
        composerShimPaths.every((path) => File(path).existsSync())) {
      final legacyPowerShellShim = File(
        p.join(PathService.binDir, 'composer.ps1'),
      );
      if (legacyPowerShellShim.existsSync()) {
        await legacyPowerShellShim.delete();
      }
      await _ensureComposerGlobalBinInPath(logInfo);
      logInfo('Composer already installed, skipping download.');
      return;
    }

    logInfo('Installing Composer...');

    // Ensure bin directory exists
    final binDir = Directory(PathService.binDir);
    if (!binDir.existsSync()) {
      await binDir.create(recursive: true);
    }

    try {
      if (composerPhar.existsSync()) {
        logInfo('composer.phar exists, repairing Composer wrappers...');
        await _writeComposerWrappers(logInfo);
        await _ensureComposerGlobalBinInPath(logInfo);
        return;
      }

      // Download composer.phar
      logInfo('Downloading composer.phar...');
      await _dio.download(
        'https://getcomposer.org/download/latest-stable/composer.phar',
        composerPhar.path,
      );
      logInfo('composer.phar downloaded to ${composerPhar.path}');

      await _writeComposerWrappers(logInfo);

      await _ensureComposerGlobalBinInPath(logInfo);

      logInfo('Composer installed successfully.');
    } catch (e) {
      logInfo('Warning: Failed to install Composer: $e');
      // Non-fatal: PHP installation should still succeed even if Composer fails
    }
  }

  /// Per-user Composer global bin directory for global packages.
  @visibleForTesting
  static String composerGlobalBinDir({
    bool? isWindows,
    String? home,
    String? appData,
  }) {
    final windows = isWindows ?? Platform.isWindows;
    final context = windows ? p.windows : p.posix;
    if (windows) {
      final dir = appData ?? Platform.environment['APPDATA'];
      if (dir == null || dir.isEmpty) return '';
      return context.join(dir, 'Composer', 'vendor', 'bin');
    }
    final homeDir = home ?? Platform.environment['HOME'] ?? '';
    if (homeDir.isEmpty) return '';
    return context.join(homeDir, '.config', 'composer', 'vendor', 'bin');
  }

  Future<void> _ensureComposerGlobalBinInPath(Function(String) logInfo) async {
    final pathService = _ref.read(pathServiceProvider);
    await pathService.ensurePontaBinInPath();

    final composerBinPath = composerGlobalBinDir();
    if (composerBinPath.isEmpty) return;
    await pathService.addRawPathToUserPath(composerBinPath);
    logInfo('Added Composer global bin directory to PATH: $composerBinPath');
  }

  Future<void> _writeComposerWrappers(Function(String) logInfo) async {
    final batContent =
        '@echo off\r\nphp "%~dp0composer.phar" %*\r\nexit /b %ERRORLEVEL%\r\n';
    await File(
      p.join(PathService.binDir, 'composer.bat'),
    ).writeAsString(batContent);
    await File(
      p.join(PathService.binDir, 'composer.cmd'),
    ).writeAsString(batContent);
    await File(p.join(PathService.binDir, 'composer')).writeAsString(
      '#!/usr/bin/env sh\n'
      r'script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)'
      '\n'
      r'composer_phar="$script_dir/composer.phar"'
      '\n'
      r'case "$(uname -r 2>/dev/null | tr A-Z a-z)" in'
      '\n'
      '  *microsoft*|*wsl*)\n'
      r'    case "$composer_phar" in'
      '\n'
      r'      /mnt/*) drive=$(printf "%s" "$composer_phar" | cut -d/ -f3 | tr A-Z a-z); rest=$(printf "%s" "$composer_phar" | cut -d/ -f4-); composer_phar="$drive:/$rest" ;;'
      '\n'
      r'    esac'
      '\n'
      '    ;;\n'
      'esac\n'
      r'exec php "$composer_phar" "$@"'
      '\n',
    );
    if (Platform.isLinux) {
      final shim = File(p.join(PathService.binDir, 'composer'));
      if (shim.existsSync()) {
        await Process.run('chmod', ['755', shim.path]);
      }
    }
    final legacyPowerShellShim = File(
      p.join(PathService.binDir, 'composer.ps1'),
    );
    if (legacyPowerShellShim.existsSync()) {
      await legacyPowerShellShim.delete();
    }
    logInfo('Created cross-shell composer wrappers in ${PathService.binDir}');
  }

  /// Removes composer.phar and cross-shell Composer wrappers from Ponta bin directory.
  /// Call this when the last PHP version is uninstalled.
  Future<void> uninstallComposer() async {
    final composerPhar = File(p.join(PathService.binDir, 'composer.phar'));
    final composerShimPaths = [
      ...PathService.shimPathsFor(PathService.binDir, 'composer'),
      p.join(PathService.binDir, 'composer.ps1'),
    ];

    if (composerPhar.existsSync()) {
      await composerPhar.delete();
      _logger.info('Removed composer.phar');
    }
    for (final path in composerShimPaths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _logger.info('Removed Composer wrappers');
  }
}
