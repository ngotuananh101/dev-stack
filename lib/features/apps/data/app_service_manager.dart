import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import '../../../core/services/log_service.dart';
import '../../../core/config/app_config.dart';

part 'app_service_manager.g.dart';

@Riverpod(keepAlive: true)
AppServiceManager appServiceManager(Ref ref) {
  final logger = ref.read(logServiceProvider);
  return AppServiceManager(logger);
}

class AppServiceManager {
  final LogService _logger;
  final Map<String, Process> _processes = {};
  final Map<String, AppModel> _activeApps = {};

  AppServiceManager(this._logger);

  bool isRunning(String appId) => _processes.containsKey(appId);

  void syncAppState(AppModel newApp) {
    if (_activeApps.containsKey(newApp.appId)) {
      final oldApp = _activeApps[newApp.appId]!;
      newApp.serviceStatus = oldApp.serviceStatus;
      newApp.servicePid = oldApp.servicePid;
      newApp.serviceLogs = oldApp.serviceLogs;
      _activeApps[newApp.appId] = newApp;
    }
  }

  Future<void> start(AppModel app, {VoidCallback? onStatusChange}) async {
    if (isRunning(app.appId)) return;
    if (app.execFilePath == null) throw Exception('Executable path not found');

    final exeFile = File(app.execFilePath!);
    if (!exeFile.existsSync()) {
      throw Exception('Executable file does not exist');
    }

    _logger.info('Starting service: ${app.name} (${app.appId})');
    app.serviceStatus = 'starting';

    try {
      final workingDir = exeFile.parent.path;

      // Specific arguments for certain apps
      List<String> args = [];
      String execPath = app.execFilePath!;
      final fileName = exeFile.path
          .split(Platform.pathSeparator)
          .last
          .toLowerCase();

      Map<String, String>? env;
      if (fileName == 'php-cgi.exe' || fileName == 'php.exe') {
        // Dynamic port based on version or extraInfo: php82 -> 9082
        String port = app.extraInfo['port']?.toString() ?? '';
        if (port.isEmpty) {
          port = '9000';
          final versionMatch = RegExp(r'\d+').firstMatch(app.appId);
          if (versionMatch != null) {
            port = '90${versionMatch.group(0)}';
          }
        }
        
        final bindAddress = app.extraInfo['bind_address']?.toString() ?? '0.0.0.0';

        if (fileName == 'php-cgi.exe') {
          args = ['-b', '$bindAddress:$port'];
        } else {
          args = ['-S', '$bindAddress:$port'];
        }
      } else if (fileName == 'redis-server.exe') {
        final confFile = File(p.join(workingDir, 'redis.windows.conf'));
        if (confFile.existsSync()) {
          args = [confFile.path];
        }
      } else if (fileName == 'mysqld.exe' || fileName == 'mariadbd.exe') {
        // Force output to console for capturing logs
        final version = app.installedVersion ?? 'unknown';
        final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
        args = [
          '--console',
          '--datadir=${dataDir.replaceAll('\\', '/')}',
        ];
      } else if (fileName == 'mongod.exe') {
        // Look for mongod.cfg in the same directory as mongod.exe or its parent
        final confFile = File(p.join(workingDir, 'mongod.cfg'));
        if (confFile.existsSync()) {
          args = ['--config', confFile.path];
        } else {
          // Try parent directory
          final parentConf = File(
            p.join(Directory(workingDir).parent.path, 'mongod.cfg'),
          );
          if (parentConf.existsSync()) {
            args = ['--config', parentConf.path];
          }
        }
      } else if (fileName == 'rustfs.exe') {
        final dataDir = p.join(AppConfig.dataDir, 'rustfs');
        final confFile = File(p.join(dataDir, 'config.json'));

        String address = ':9000';
        String consoleAddress = ':9001';
        String accessKey = 'rustfsadmin';
        String secretKey = 'rustfsadmin';
        bool consoleEnable = true;

        if (confFile.existsSync()) {
          try {
            final config = json.decode(confFile.readAsStringSync());
            address = config['address'] ?? address;
            consoleAddress = config['console_address'] ?? consoleAddress;
            accessKey = config['access_key'] ?? accessKey;
            secretKey = config['secret_key'] ?? secretKey;
            consoleEnable = config['console_enable'] ?? consoleEnable;
          } catch (_) {}
        }

        args = [
          'server',
          dataDir,
          if (consoleEnable) '--console-enable',
          '--address',
          address,
          '--console-address',
          consoleAddress,
          '--access-key',
          accessKey,
          '--secret-key',
          secretKey,
        ];
      } else if (fileName == 'meilisearch.exe') {
        final confFile = File(p.join(workingDir, 'config.toml'));
        if (confFile.existsSync()) {
          args = ['--config-file-path', confFile.path];
        }
        
        // Ensure db-path is set to our managed data directory if not in config
        // Actually, Meilisearch defaults to ./data.ms, better to be explicit or let config handle it.
        // For now, if config exists, we use it. If not, we might want to pass --db-path.
      } else if (fileName == 'elasticsearch.bat') {
        // No special environment or args needed anymore as we edit the config in the app dir
        // but still point data to our managed data dir inside the yml.
      }

      final process = await Process.start(
        execPath,
        args,
        workingDirectory: workingDir,
        environment: env,
        mode: ProcessStartMode.normal,
      );

      _processes[app.appId] = process;
      _activeApps[app.appId] = app;
      app.servicePid = process.pid;
      app.serviceStatus = 'running';
      app.serviceLogs = []; // Clear old logs on start

      final startLog =
          'Service started (PID: ${process.pid}) with command $execPath ${args.join(' ')}';
      app.addServiceLog(startLog);
      AppLogger.info('[${app.name}] $startLog');

      onStatusChange?.call();

      // Listen for exit
      process.exitCode.then((code) {
        final activeApp = _activeApps[app.appId];
        _logger.info('Service ${app.name} exited with code $code');
        AppLogger.info('[${app.name}] Exited with code $code');
        _processes.remove(app.appId);
        _activeApps.remove(app.appId);
        if (activeApp != null) {
          activeApp.serviceStatus = 'stopped';
          activeApp.servicePid = null;
        }
        onStatusChange?.call();
      });

      // Handle output
      process.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            final cleanLine = line.trim();
            _activeApps[app.appId]?.addServiceLog(cleanLine);
            AppLogger.info('[${app.name}] $cleanLine');
            onStatusChange?.call();
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            final cleanLine = line.trim();
            String prefix = 'LOG';
            if (cleanLine.contains('[ERROR]')) {
              prefix = 'ERROR';
            } else if (cleanLine.contains('[Warning]')) {
              prefix = 'WARN';
            } else if (cleanLine.contains('[System]') ||
                cleanLine.contains('[Note]')) {
              prefix = 'INFO';
            }

            _activeApps[app.appId]?.addServiceLog('[$prefix] $cleanLine');
            AppLogger.info('[${app.name}] $prefix: $cleanLine');
            onStatusChange?.call();
          }
        }
      });
    } catch (e) {
      _logger.error('Failed to start service ${app.name}: $e');
      AppLogger.error('[${app.name}] CRITICAL ERROR: $e');
      app.serviceStatus = 'stopped';
      rethrow;
    }
  }

  Future<void> stop(AppModel app) async {
    _logger.info('Stopping service: ${app.name}');
    app.serviceStatus = 'stopping';

    final process = _processes[app.appId];
    if (process != null) {
      if (Platform.isWindows) {
        // Dùng /T để giết toàn bộ cây tiến trình (tránh sót worker processes)
        await Process.run('taskkill', [
          '/F',
          '/T',
          '/PID',
          process.pid.toString(),
        ]);
      } else {
        process.kill();
      }

      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    _processes.remove(app.appId);
    final activeApp = _activeApps[app.appId] ?? app;
    activeApp.serviceStatus = 'stopped';
    activeApp.servicePid = null;
    _activeApps.remove(app.appId);
  }

  Future<void> restart(AppModel app, {VoidCallback? onStatusChange}) async {
    await stop(app);
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Give it a moment to release ports
    await start(app, onStatusChange: onStatusChange);
  }

  Future<void> forceKillByNames(List<String> names) async {
    if (!Platform.isWindows) return;

    for (final name in names) {
      if (name.trim().isEmpty) continue;

      // Ensure it has .exe extension if missing
      String taskName = name;
      if (!taskName.toLowerCase().endsWith('.exe')) {
        taskName += '.exe';
      }

      _logger.info('Force killing processes by name: $taskName');
      try {
        // /F - force, /IM - image name, /T - child processes
        await Process.run('taskkill', ['/F', '/IM', taskName, '/T']);
      } catch (e) {
        _logger.warning('Failed to kill task $taskName: $e');
      }
    }
  }
}
