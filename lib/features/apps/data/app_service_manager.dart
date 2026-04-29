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

  AppServiceManager(this._logger);

  bool isRunning(String appId) => _processes.containsKey(appId);

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

      if (fileName == 'php-cgi.exe' || fileName == 'php.exe') {
        // Dynamic port based on version: php82 -> 9082
        String port = '9000';
        final versionMatch = RegExp(r'\d+').firstMatch(app.appId);
        if (versionMatch != null) {
          port = '90${versionMatch.group(0)}';
        }

        if (fileName == 'php-cgi.exe') {
          args = ['-b', '127.0.0.1:$port'];
        } else {
          args = ['-S', '127.0.0.1:$port'];
        }
      } else if (fileName == 'redis-server.exe') {
        // Force bind to 127.0.0.1 to avoid common bind errors on Windows
        args = ['--bind', '127.0.0.1'];

        // Optional: Support custom port if 6379 is busy (later improvement)
        // args.addAll(['--port', '6379']);
      } else if (fileName == 'mysqld.exe' || fileName == 'mariadbd.exe') {
        // Force output to console for capturing logs
        args = ['--console'];
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
        final dataDir = p.join(AppConfig.dataDir, 'meilisearch');
        final confFile = File(p.join(dataDir, 'config.toml'));
        if (confFile.existsSync()) {
          args = ['--config-file-path', confFile.path];
        }
        
        // Ensure db-path is set to our managed data directory if not in config
        // Actually, Meilisearch defaults to ./data.ms, better to be explicit or let config handle it.
        // For now, if config exists, we use it. If not, we might want to pass --db-path.
      } else if (fileName == 'elasticsearch.bat') {
        final esDataDir = p.join(AppConfig.dataDir, 'elasticsearch');
        final confFile = File(p.join(esDataDir, 'elasticsearch.yml'));
        if (confFile.existsSync()) {
          // Elasticsearch 8.x can take config file path via -E path.conf
          args = ['-E', 'path.conf=$esDataDir'];
        }
      }

      final process = await Process.start(
        execPath,
        args,
        workingDirectory: workingDir,
        mode: ProcessStartMode.normal,
      );

      _processes[app.appId] = process;
      app.servicePid = process.pid;
      app.serviceStatus = 'running';
      app.serviceLogs = []; // Clear old logs on start

      final startLog =
          'Service started (PID: ${process.pid}) with command $execPath ${args.join(' ')}';
      app.addServiceLog(startLog);
      debugPrint('[${app.name}] $startLog');

      onStatusChange?.call();

      // Listen for exit
      process.exitCode.then((code) {
        _logger.info('Service ${app.name} exited with code $code');
        debugPrint('[${app.name}] Exited with code $code');
        _processes.remove(app.appId);
        app.serviceStatus = 'stopped';
        app.servicePid = null;
        onStatusChange?.call();
      });

      // Handle output
      process.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            final cleanLine = line.trim();
            app.addServiceLog(cleanLine);
            debugPrint('[${app.name}] $cleanLine');
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

            app.addServiceLog('[$prefix] $cleanLine');
            debugPrint('[${app.name}] $prefix: $cleanLine');
            onStatusChange?.call();
          }
        }
      });
    } catch (e) {
      _logger.error('Failed to start service ${app.name}: $e');
      debugPrint('[${app.name}] CRITICAL ERROR: $e');
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
    app.serviceStatus = 'stopped';
    app.servicePid = null;
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
