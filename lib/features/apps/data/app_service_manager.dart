import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import 'app_installer_service.dart';
import '../../../core/services/background_process.dart';
import '../../../core/services/log_service.dart';
import '../../../core/config/app_config.dart';

part 'app_service_manager.g.dart';

@Riverpod(keepAlive: true)
AppServiceManager appServiceManager(Ref ref) {
  final logger = ref.read(logServiceProvider);
  final manager = AppServiceManager(logger);
  ref.onDispose(() => unawaited(manager.dispose()));
  return manager;
}

class AppServiceManager {
  final LogService _logger;
  final Map<String, ManagedBackgroundProcess> _processes = {};
  final Map<String, AppModel> _activeApps = {};
  final Map<String, List<StreamSubscription<String>>> _logSubscriptions = {};

  /// Set true by [dispose]. Once disposed, late-firing process-exit callbacks
  /// must NOT touch the shared maps or invoke caller-supplied status callbacks
  /// (which typically capture widget state that is already torn down), or they
  /// cause use-after-dispose errors / orphaned notifications.
  bool _disposed = false;

  /// Abstraction over [Process.run] so [forceKillPid] / [forceKillByNames]
  /// can be tested without spawning real `taskkill` calls. Defaults to the
  /// real implementation in [BackgroundProcess.run].
  final Future<List<String>> Function(String, List<String>)? _runProcess;

  /// Injectable host check (defaults to [Platform.isWindows]) so the
  /// Windows-only kill paths can be exercised in tests on any host.
  final bool Function() _isWindows;

  AppServiceManager(
    this._logger, {
    Future<List<String>> Function(String, List<String>)? runProcess,
    bool Function()? platformIsWindows,
  }) : _runProcess = runProcess,
       _isWindows = platformIsWindows ?? (() => Platform.isWindows);

  /// Runs an executable via the injected runner (tests) or [BackgroundProcess.run]
  /// (production). Returns stdout lines.
  Future<List<String>> _run(String exec, List<String> args) async {
    final runner = _runProcess;
    if (runner != null) return runner(exec, args);
    final result = await BackgroundProcess.run(exec, args);
    final out = result.stdout?.toString() ?? '';
    return const LineSplitter().convert(out);
  }

  String _generateSecret({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  bool isRunning(String appId) {
    if (_processes.containsKey(appId)) return true;
    final active = _activeApps[appId];
    return active != null && active.serviceStatus == 'running';
  }

  /// Tears down all in-memory state for [appId] after its process has exited
  /// (or is being stopped): removes the process + log subscriptions, marks the
  /// app stopped, and notifies the caller. Returns true if cleanup ran.
  ///
  /// Returns false (no-op) when the manager has been disposed — a late exit
  /// callback firing after teardown must not touch the (now-empty) maps or
  /// invoke the caller's [onStatusChange], which likely captures dead widget
  /// state.
  bool _finalizeExit({
    required String appId,
    AppModel? activeApp,
    VoidCallback? onStatusChange,
  }) {
    if (_disposed) return false;
    _processes.remove(appId);
    final subscriptions = _logSubscriptions.remove(appId);
    // Subscription cancellation is async; the caller awaits it where needed.
    // Here we only synchronously drop the reference.
    if (subscriptions != null) {
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    }
    _activeApps.remove(appId);
    if (activeApp != null) {
      activeApp.serviceStatus = 'stopped';
      activeApp.servicePid = null;
    }
    onStatusChange?.call();
    return true;
  }

  /// Test-only entry around [_finalizeExit] so the disposed-guard can be
  /// exercised without spawning a real process.
  @visibleForTesting
  bool finalizeExitForTest({
    required String appId,
    required AppModel activeApp,
    required VoidCallback onStatusChange,
  }) {
    _activeApps[appId] = activeApp;
    activeApp.servicePid = 1;
    activeApp.serviceStatus = 'running';
    return _finalizeExit(
      appId: appId,
      activeApp: activeApp,
      onStatusChange: onStatusChange,
    );
  }

  /// Test-only setter for the disposed flag.
  @visibleForTesting
  void markDisposedForTest() => _disposed = true;

  /// Parses a `host:port` string (e.g. `127.0.0.1:9000`) into a record, or
  /// returns null if it doesn't carry a usable port.
  @visibleForTesting
  static ({String host, int port})? parseHostPort(String address) {
    final idx = address.lastIndexOf(':');
    if (idx <= 0 || idx == address.length - 1) return null;
    final port = int.tryParse(address.substring(idx + 1));
    if (port == null || port <= 0 || port > 65535) return null;
    var host = address.substring(0, idx);
    if (host.isEmpty) return null;
    // Strip IPv6 brackets for the netstat comparison.
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    return (host: host, port: port);
  }

  /// Runs `netstat -ano` and throws a descriptive [Exception] if any of the
  /// [requiredSockets] is already held by a listening process. Best-effort:
  /// if netstat cannot be run, the conflict check is skipped (the start
  /// attempt proceeds as before) rather than blocking every service.
  Future<void> _checkPortConflicts(
    List<({String host, int port})> requiredSockets,
    String appName,
  ) async {
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
    for (final s in requiredSockets) {
      if (portIsHeld(host: s.host, port: s.port, listeningSockets: sockets)) {
        throw Exception(
          'Port ${s.port} on ${s.host} is already in use by another process. '
          'Stop that process or change the port for $appName before starting.',
        );
      }
    }
  }

  /// Parses `ss -tulpn` stdout into listening `host:port` sockets. A literal
  /// `*:port` local address expands to BOTH IPv4 (`0.0.0.0:port`) and IPv6
  /// (`[::]:port`) wildcards so it matches any required bind host.
  @visibleForTesting
  static Set<String> parseListeningSocketsLinux(String ssOutput) {
    final result = <String>{};
    for (final raw in ssOutput.split('\n')) {
      final tokens = raw.trim().split(RegExp(r'\s+'));
      final listenIdx = tokens.indexOf('LISTEN');
      if (listenIdx == -1 || tokens.length <= listenIdx + 3) continue;
      final local = tokens[listenIdx + 3];
      final idx = local.lastIndexOf(':');
      if (idx <= 0) continue;
      var host = local.substring(0, idx);
      final port = local.substring(idx + 1);
      if (int.tryParse(port) == null) continue;
      if (host == '*') {
        result
          ..add('0.0.0.0:$port')
          ..add('[::]:$port');
      } else {
        result.add(local);
      }
    }
    return result;
  }

  /// Parses the stdout of Windows `netstat -ano` into the set of
  /// `host:port` sockets currently in the LISTENING state. IPv6 sockets are
  /// kept in their `[::]:port` form. Non-LISTENING rows are ignored.
  @visibleForTesting
  static Set<String> parseListeningSockets(String netstatOutput) {
    final result = <String>{};
    for (final raw in netstatOutput.split('\n')) {
      final line = raw.trim();
      if (!line.contains('TCP')) continue;
      if (!line.contains('LISTENING')) continue;
      // Columns are whitespace-separated; Local Address is the 2nd token.
      final tokens = line.split(RegExp(r'\s+'));
      if (tokens.length < 2) continue;
      final local = tokens[1];
      if (local.contains(':')) result.add(local);
    }
    return result;
  }

  /// Returns true if [port] on [host] is already taken by a listening socket.
  /// A wildcard bind (`0.0.0.0:port` or `[::]:port`) covers any host, so it
  /// also counts as holding `127.0.0.1:port`.
  @visibleForTesting
  static bool portIsHeld({
    required String host,
    required int port,
    required Set<String> listeningSockets,
  }) {
    final exact = '$host:$port';
    final wildcardV4 = '0.0.0.0:$port';
    final wildcardV6 = '[::]:$port';
    return listeningSockets.contains(exact) ||
        listeningSockets.contains(wildcardV4) ||
        listeningSockets.contains(wildcardV6);
  }

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
    final name = normalizeExecutableName(fileName);
    if (name == 'caddy') {
      return [
        'run',
        '--config',
        p.join(workingDir, 'Caddyfile'),
        '--adapter',
        'caddyfile',
      ];
    }
    if (name == 'nginx') {
      final prefix = workingDir.replaceAll('\\', '/');
      final conf = p.join(workingDir, 'conf', 'nginx.conf').replaceAll('\\', '/');
      return ['-p', '$prefix/', '-c', conf];
    }
    return <String>[];
  }

  @visibleForTesting
  static List<({String host, int port})> requiredSocketsForExecutable(
    String fileName,
  ) {
    final name = normalizeExecutableName(fileName);
    if (name != 'caddy' && name != 'nginx' && name != 'httpd' && name != 'apache') {
      return const [];
    }
    return [(host: '*', port: 80), (host: '*', port: 443)];
  }

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

    // Special handling for package_manager PHP (uses systemctl for PHP-FPM)
    if (app.installMethod == 'package_manager' && app.groupName == 'php') {
      await _startPhpFpmViaSystemctl(app, onStatusChange: onStatusChange);
      return;
    }

    if (app.execFilePath == null) throw Exception('Executable path not found');

    final exeFile = File(app.execFilePath!);
    if (!exeFile.existsSync()) {
      throw Exception('Executable file does not exist');
    }

    _logger.info('Starting service: ${app.name} (${app.appId})');
    app.serviceStatus = 'starting';

    try {
      final workingDir = exeFile.parent.path;
      String execPath = app.execFilePath!;
      final fileName = normalizeExecutableName(
        exeFile.path.split(Platform.pathSeparator).last,
      );

      // Specific arguments for certain apps
      List<String> args = argumentsForExecutable(fileName, workingDir);

      // Sockets this service will try to bind, for a pre-flight conflict check.
      final requiredSockets = <({String host, int port})>[];

      Map<String, String>? env;
      if (fileName == 'php-cgi' || fileName == 'php') {
        // Dynamic port based on version or extraInfo: php82 -> 9082
        String port = app.extraInfo['port']?.toString() ?? '';
        if (port.isEmpty) {
          port = AppInstallerService.phpPortFor(app.appId).toString();
        }

        final bindAddress =
            app.extraInfo['bind_address']?.toString() ?? '127.0.0.1';

        requiredSockets.add((host: bindAddress, port: int.tryParse(port) ?? 0));

        if (fileName == 'php-cgi') {
          args = ['-b', '$bindAddress:$port'];
        } else {
          args = ['-S', '$bindAddress:$port'];
        }
      } else if (fileName == 'redis-server' || fileName == 'valkey-server') {
        final candidates = [
          p.join(workingDir, 'valkey.conf'),
          p.join(workingDir, 'redis.conf'),
          p.join(workingDir, 'redis.windows.conf'),
        ];
        for (final confPath in candidates) {
          final confFile = File(confPath);
          if (confFile.existsSync()) {
            args = [confFile.path];
            break;
          }
        }
      } else if (fileName == 'mysqld' || fileName == 'mariadbd') {
        // Force output to console for capturing logs
        final version = app.installedVersion ?? 'unknown';
        final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
        args = ['--console', '--datadir=${dataDir.replaceAll('\\', '/')}'];
      } else if (fileName == 'mongod') {
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
      } else if (fileName == 'rustfs') {
        final dataDir = p.join(AppConfig.dataDir, 'rustfs');
        final confFile = File(p.join(dataDir, 'config.json'));

        String address = '127.0.0.1:9000';
        String consoleAddress = '127.0.0.1:9001';
        String accessKey = '';
        String secretKey = '';
        bool consoleEnable = true;

        if (confFile.existsSync()) {
          try {
            final config = json.decode(confFile.readAsStringSync());
            address = config['address'] ?? address;
            consoleAddress = config['console_address'] ?? consoleAddress;
            accessKey = config['access_key'] ?? accessKey;
            secretKey = config['secret_key'] ?? secretKey;
            consoleEnable = config['console_enable'] ?? consoleEnable;
          } catch (e) {
            _logger.warning('Failed to parse RustFS config: $e');
          }
        }

        if (accessKey.isEmpty || secretKey.isEmpty) {
          accessKey = _generateSecret(length: 18);
          secretKey = _generateSecret(length: 32);
          if (!confFile.parent.existsSync()) {
            confFile.parent.createSync(recursive: true);
          }
          confFile.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert({
              'address': address,
              'console_address': consoleAddress,
              'access_key': accessKey,
              'secret_key': secretKey,
              'console_enable': consoleEnable,
            }),
          );
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

        for (final addr in [address, consoleAddress]) {
          final parsed = parseHostPort(addr);
          if (parsed != null) requiredSockets.add(parsed);
        }
      } else if (fileName == 'meilisearch') {
        final confFile = File(p.join(workingDir, 'config.toml'));
        if (confFile.existsSync()) {
          args = ['--config-file-path', confFile.path];
        }

        // Ensure db-path is set to our managed data directory if not in config
        // Actually, Meilisearch defaults to ./data.ms, better to be explicit or let config handle it.
        // For now, if config exists, we use it. If not, we might want to pass --db-path.
      } else if (fileName == 'elasticsearch') {
        // No special environment or args needed anymore as we edit the config in the app dir
        // but still point data to our managed data dir inside the yml.
      } else if (fileName == 'postgres') {
        final version = app.installedVersion ?? 'unknown';
        final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
        args = ['-D', dataDir];
      }

      requiredSockets.addAll(requiredSocketsForExecutable(fileName));

      final runsDetached = runsDetachedExecutable(fileName);

      // Pre-flight: fail fast with a clear message if a required port is taken,
      // instead of spawning a process that dies silently on bind.
      await _checkPortConflicts(requiredSockets, app.name);

      final process = runsDetached
          ? await BackgroundProcess.start(
              execPath,
              args,
              workingDirectory: workingDir,
              environment: env,
            )
          : ManagedBackgroundProcess.wrap(
              await Process.start(
                execPath,
                args,
                workingDirectory: workingDir,
                environment: env,
                mode: ProcessStartMode.normal,
              ),
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

      // Listen for exit for both hidden webservers and normal services.
      process.exitCode.then((code) async {
        final activeApp = _activeApps[app.appId];
        _logger.info('Service ${app.name} exited with code $code');
        AppLogger.info('[${app.name}] Exited with code $code');
        // Guarded: if dispose() already tore the manager down, a late exit
        // must be a no-op rather than poking dead state/callbacks.
        _finalizeExit(
          appId: app.appId,
          activeApp: activeApp,
          onStatusChange: onStatusChange,
        );
      });

      if (!runsDetached) {
        final stdoutSubscription = process.stdout
            .transform(utf8.decoder)
            .listen((data) {
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

        final stderrSubscription = process.stderr
            .transform(utf8.decoder)
            .listen((data) {
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
        _logSubscriptions[app.appId] = [stdoutSubscription, stderrSubscription];
      }
    } catch (e) {
      _logger.error('Failed to start service ${app.name}: $e');
      AppLogger.error('[${app.name}] CRITICAL ERROR: $e');
      app.serviceStatus = 'stopped';
      rethrow;
    }
  }

  Future<void> stop(AppModel app) async {
    if (_disposed) return;
    _logger.info('Stopping service: ${app.name}');
    app.serviceStatus = 'stopping';

    // Special handling for package_manager PHP (uses systemctl for PHP-FPM)
    if (app.installMethod == 'package_manager' && app.groupName == 'php') {
      await _stopPhpFpmViaSystemctl(app);
      return;
    }

    try {
      final process = _processes[app.appId];
      if (process != null) {
        try {
          await BackgroundProcess.stopManaged(process);
        } catch (e) {
          // Kill failed (process already gone, access denied, ...). Don't let
          // that strand the service in 'stopping' — fall through to cleanup.
          _logger.warning('Kill failed for ${app.name}: $e');
        }

        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    } finally {
      // Drop the process from the map BEFORE finalizing so the (possibly
      // already-fired) exit handler's _finalizeExit sees nothing to double-do.
      _processes.remove(app.appId);
      final subscriptions = _logSubscriptions.remove(app.appId);
      if (subscriptions != null) {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      }
      final activeApp = _activeApps[app.appId] ?? app;
      activeApp.serviceStatus = 'stopped';
      activeApp.servicePid = null;
      _activeApps.remove(app.appId);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final subscriptions in _logSubscriptions.values) {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }
    _logSubscriptions.clear();

    // Kill each managed process by its *real* child PID via stopManaged, not
    // just the wscript host — otherwise detached webservers (nginx/apache)
    // survive dispose and keep holding their ports.
    for (final process in _processes.values) {
      try {
        await BackgroundProcess.stopManaged(process);
      } catch (_) {
        // Best-effort during teardown.
        process.kill();
      }
    }
    _processes.clear();
    _activeApps.clear();
  }

  Future<void> restart(AppModel app, {VoidCallback? onStatusChange}) async {
    await stop(app);
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Give it a moment to release ports
    await start(app, onStatusChange: onStatusChange);
  }

  /// Force-kills a *specific, known* PID rather than every process that shares
  /// an image name. This is what update/uninstall should call: it avoids the
  /// collateral damage of `taskkill /IM php.exe`, which would kill any other
  /// process running under that generic executable name.
  Future<void> forceKillPid(
    String appId,
    int pid, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isWindows,
  }) async {
    if (pid <= 0) {
      _logger.warning('No PID recorded for $appId; skipping force kill.');
      return;
    }
    _logger.info('Force killing PID $pid for $appId');

    final effectiveRunner = runProcess ?? (String exec, List<String> args) async {
      if (_runProcess != null) {
        final lines = await _runProcess(exec, args);
        return ProcessResult(pid, 0, lines.join('\n'), '');
      }
      return BackgroundProcess.run(exec, args);
    };

    final onWindows = isWindows ?? Platform.isWindows;
    if (!onWindows) {
      bool needFallback = false;
      try {
        final res = await effectiveRunner('kill', ['-9', '--', '-$pid']);
        if (res.exitCode != 0) {
          needFallback = true;
        }
      } catch (e) {
        needFallback = true;
      }

      if (needFallback) {
        try {
          await effectiveRunner('kill', ['-9', '$pid']);
        } catch (e) {
          _logger.warning('Failed to kill PID $pid: $e');
        }
      }
      return;
    }

    if (isWindows ?? _isWindows()) {
      try {
        await effectiveRunner('taskkill', ['/F', '/T', '/PID', pid.toString()]);
      } catch (e) {
        _logger.warning('Failed to kill PID $pid: $e');
      }
    }
  }

  Future<void> forceKillByNames(List<String> names) async {
    if (!Platform.isWindows) {
      for (final name in names) {
        final normalized = normalizeExecutableName(name.trim());
        if (normalized.isEmpty) continue;
        _logger.info('Force killing processes by name: $normalized');
        try {
          await _run('pkill', ['-9', '-x', normalized]);
        } catch (e) {
          _logger.warning('Failed to kill task $normalized: $e');
        }
      }
      return;
    }

    if (!_isWindows()) return;

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
        await _run('taskkill', ['/F', '/IM', taskName, '/T']);
      } catch (e) {
        _logger.warning('Failed to kill task $taskName: $e');
      }
    }
  }

  /// Start PHP-FPM service via systemctl for package_manager installed PHP
  Future<void> _startPhpFpmViaSystemctl(
    AppModel app, {
    VoidCallback? onStatusChange,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isLinux,
  }) async {
    final onLinux = isLinux ?? Platform.isLinux;
    if (!onLinux) {
      throw Exception('systemctl is only available on Linux');
    }

    final runner = runProcess ?? Process.run;

    _logger.info('Starting PHP-FPM via systemctl: ${app.name}');
    app.serviceStatus = 'starting';
    app.addServiceLog('Starting PHP-FPM service...');

    try {
      // Determine service name from app version (php82 -> php8.2-fpm)
      final serviceName = _phpFpmServiceName(app.appId);
      app.addServiceLog('Service name: $serviceName');

      // Start the service (try user service first, then system fallback)
      bool userStartSucceeded = false;
      String lastError = '';
      try {
        final userResult = await runner('systemctl', ['--user', 'start', serviceName]);
        if (userResult.exitCode == 0) {
          userStartSucceeded = true;
        } else {
          lastError = userResult.stderr.toString().trim();
          _logger.warning('systemctl --user start failed: $lastError');
        }
      } catch (e) {
        lastError = e.toString();
        _logger.warning('systemctl --user start threw exception: $e');
      }

      bool systemStartSucceeded = false;
      if (!userStartSucceeded) {
        try {
          final sysResult = await runner('systemctl', ['start', serviceName]);
          if (sysResult.exitCode == 0) {
            systemStartSucceeded = true;
          } else {
            lastError = sysResult.stderr.toString().trim();
            _logger.warning('systemctl start failed: $lastError');
          }
        } catch (e) {
          lastError = e.toString();
          _logger.warning('systemctl start threw exception: $e');
        }
      }

      if (!userStartSucceeded && !systemStartSucceeded) {
        app.addServiceLog('Failed to start: $lastError');
        throw Exception('Failed to start $serviceName: $lastError');
      }

      final isUserScope = userStartSucceeded;
      final scopePrefix = isUserScope ? ['--user'] : <String>[];

      // Liveness probe: verify service is actually active
      final activeResult = await runner('systemctl', [...scopePrefix, 'is-active', serviceName]);
      final activeStatus = activeResult.stdout.toString().trim();
      if (activeStatus != 'active') {
        throw Exception('Service $serviceName failed liveness probe (status: $activeStatus)');
      }

      app.addServiceLog('Service started successfully');

      // Get service PID
      final pidResult = await runner(
        'systemctl',
        [...scopePrefix, 'show', '--property=MainPID', '--value', serviceName],
      );

      if (pidResult.exitCode == 0) {
        final pidStr = pidResult.stdout.toString().trim();
        final pid = int.tryParse(pidStr);
        if (pid != null && pid > 0) {
          app.servicePid = pid;
          app.addServiceLog('PID: $pid');
        }
      }

      app.serviceStatus = 'running';
      _activeApps[app.appId] = app;
      onStatusChange?.call();

    } catch (e) {
      _logger.error('Failed to start PHP-FPM via systemctl: $e');
      app.addServiceLog('Error: $e');
      app.serviceStatus = 'stopped';
      app.servicePid = null;
      _activeApps.remove(app.appId);
      rethrow;
    }
  }

  /// Stop PHP-FPM service via systemctl for package_manager installed PHP
  Future<void> _stopPhpFpmViaSystemctl(
    AppModel app, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isLinux,
  }) async {
    final onLinux = isLinux ?? Platform.isLinux;
    if (!onLinux) return;

    final runner = runProcess ?? Process.run;

    _logger.info('Stopping PHP-FPM via systemctl: ${app.name}');
    app.serviceStatus = 'stopping';
    app.addServiceLog('Stopping PHP-FPM service...');

    try {
      final serviceName = _phpFpmServiceName(app.appId);

      // Stop the service (try user service first, then system fallback)
      bool userStopOk = false;
      try {
        final userResult = await runner('systemctl', ['--user', 'stop', serviceName]);
        if (userResult.exitCode == 0) {
          userStopOk = true;
        }
      } catch (_) {}

      if (!userStopOk) {
        final sysResult = await runner('systemctl', ['stop', serviceName]);
        if (sysResult.exitCode != 0) {
          app.addServiceLog('Warning: ${sysResult.stderr}');
        } else {
          app.addServiceLog('Service stopped successfully');
        }
      } else {
        app.addServiceLog('Service stopped successfully');
      }

    } catch (e) {
      _logger.warning('Failed to stop PHP-FPM via systemctl: $e');
      app.addServiceLog('Warning: $e');
    } finally {
      app.serviceStatus = 'stopped';
      app.servicePid = null;
      _activeApps.remove(app.appId);
    }
  }

  /// Check whether PHP-FPM service is currently active via systemctl
  Future<bool> isPhpFpmRunningViaSystemctl(
    AppModel app, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isLinux,
  }) async {
    final onLinux = isLinux ?? Platform.isLinux;
    if (!onLinux) return false;

    final runner = runProcess ?? Process.run;
    final serviceName = _phpFpmServiceName(app.appId);

    try {
      // Check user service first
      final userResult = await runner('systemctl', ['--user', 'is-active', serviceName]);
      if (userResult.exitCode == 0 && userResult.stdout.toString().trim() == 'active') {
        return true;
      }
    } catch (_) {}

    try {
      // Check system service fallback
      final sysResult = await runner('systemctl', ['is-active', serviceName]);
      if (sysResult.exitCode == 0 && sysResult.stdout.toString().trim() == 'active') {
        return true;
      }
    } catch (_) {}

    return false;
  }

  @visibleForTesting
  Future<void> startPhpFpmViaSystemctlForTesting(
    AppModel app, {
    VoidCallback? onStatusChange,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isLinux,
  }) => _startPhpFpmViaSystemctl(
    app,
    onStatusChange: onStatusChange,
    runProcess: runProcess,
    isLinux: isLinux,
  );

  @visibleForTesting
  Future<void> stopPhpFpmViaSystemctlForTesting(
    AppModel app, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isLinux,
  }) => _stopPhpFpmViaSystemctl(
    app,
    runProcess: runProcess,
    isLinux: isLinux,
  );

  @visibleForTesting
  String phpFpmServiceNameForTesting(String appId) => _phpFpmServiceName(appId);

  /// Get PHP-FPM service name from app ID (php82 -> php8.2-fpm)
  String _phpFpmServiceName(String appId) {
    // php82 -> 82 -> 8.2
    final version = appId.replaceAll('php', '');
    if (version.length >= 2) {
      final major = version.substring(0, 1);
      final minor = version.substring(1);
      return 'php$major.$minor-fpm';
    }
    return 'php-fpm'; // fallback
  }
}
