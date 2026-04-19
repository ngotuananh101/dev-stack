import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import '../../../core/services/log_service.dart';

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
    if (!exeFile.existsSync()) throw Exception('Executable file does not exist');

    _logger.info('Starting service: ${app.name} (${app.appId})');
    app.serviceStatus = 'starting';

    try {
      final workingDir = exeFile.parent.path;
      
      // Specific arguments for certain apps
      List<String> args = [];
      String execPath = app.execFilePath!;
      final fileName = exeFile.path.split(Platform.pathSeparator).last.toLowerCase();
      
      if (fileName == 'php-cgi.exe') {
        args = ['-b', '127.0.0.1:9000'];
      } else if (fileName == 'php.exe') {
        args = ['-S', '127.0.0.1:9000'];
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
      app.addServiceLog('Service started (PID: ${process.pid})');
      onStatusChange?.call();

      // Listen for exit
      process.exitCode.then((code) {
        _logger.info('Service ${app.name} exited with code $code');
        app.addServiceLog('Service exited with code $code');
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
            app.addServiceLog(line.trim());
            onStatusChange?.call();
          }
        }
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            app.addServiceLog('[ERROR] ${line.trim()}');
            onStatusChange?.call();
          }
        }
      });

    } catch (e) {
      _logger.error('Failed to start service ${app.name}: $e');
      app.serviceStatus = 'stopped';
      rethrow;
    }
  }

  Future<void> stop(AppModel app) async {
    if (!isRunning(app.appId)) return;

    _logger.info('Stopping service: ${app.name}');
    app.serviceStatus = 'stopping';

    final process = _processes[app.appId];
    if (process != null) {
      // Try graceful kill
      final success = process.kill();
      if (!success) {
        _logger.warning('Failed to kill process gracefully, trying force kill...');
        // On Windows, taskkill might be better for some apps
        await Process.run('taskkill', ['/F', '/PID', process.pid.toString()]);
      }
    }

    _processes.remove(app.appId);
    app.serviceStatus = 'stopped';
    app.servicePid = null;
  }

  Future<void> restart(AppModel app) async {
    await stop(app);
    await start(app);
  }
}
