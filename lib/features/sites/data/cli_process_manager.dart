import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';
import '../../../core/services/log_service.dart';
import '../domain/site_model.dart';

/// A fixed-capacity, FIFO log buffer that discards the oldest lines once
/// [maxLines] is reached. Keeps the most recent CLI site output in memory
/// without growing without bound.
class CircularLogBuffer {
  final int maxLines;
  final Queue<String> _queue = Queue<String>();

  CircularLogBuffer({this.maxLines = 1000});

  void add(String line) {
    if (_queue.length >= maxLines) {
      _queue.removeFirst();
    }
    _queue.addLast(line);
  }

  void clear() {
    _queue.clear();
  }

  List<String> get lines => _queue.toList();
}

/// Bookkeeping record for a single CLI site process and its output sinks.
///
/// The record is kept alive even after the underlying process exits naturally
/// (so `getLogBuffer` / `getLogStream` still return output). It is only removed
/// from the manager when the site is explicitly stopped or the manager is
/// disposed, at which point the file sink and stream are released.
class ManagedCliProcess {
  final int siteId;
  final String domain;
  final Process process;
  final CircularLogBuffer logBuffer;
  final StreamController<String> streamController;
  final IOSink logFileSink;
  bool running = true;

  ManagedCliProcess({
    required this.siteId,
    required this.domain,
    required this.process,
    required this.logBuffer,
    required this.streamController,
    required this.logFileSink,
  });
}

/// Manages the lifecycle and output of CLI site processes (Node.js, Bun, Deno,
/// etc.).
///
/// Responsibilities:
/// - Start processes with a PATH enriched for common toolchains (NVM, Bun,
///   Deno, Cargo) so commands like `npm` / `deno` resolve even when launched
///   from a desktop context without a login shell.
/// - Terminate the entire process tree (not just the leader): on POSIX the
///   child is started under `setsid` so its pid == its process-group id, making
///   `kill -9 -- -<pid>` address the whole tree (the SDK's `Process.start`
///   exposes no `processGroupId`); on Windows `taskkill /F /T /PID` does the
///   equivalent.
/// - Buffer the most recent output (capped at 1000 lines), teeing every line
///   to an in-memory buffer, a broadcast stream, and a per-site log file.
class CliProcessManager {
  final String? logsDirectory;
  final Map<int, ManagedCliProcess> _processes = {};
  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  CliProcessManager({this.logsDirectory});

  /// Stream of site ids whose running/stopped status just changed.
  Stream<int> get statusStream => _statusController.stream;

  void _notifyStatus(int siteId) {
    if (!_statusController.isClosed) {
      _statusController.add(siteId);
    }
  }

  bool isSiteRunning(int siteId) => _processes[siteId]?.running ?? false;

  int? getSitePid(int siteId) => _processes[siteId]?.process.pid;

  /// Returns the buffered lines for [siteId]. The buffer is retained even after
  /// the process has exited, so logs remain queryable until the site is
  /// explicitly stopped.
  List<String> getLogBuffer(int siteId) =>
      _processes[siteId]?.logBuffer.lines ?? [];

  Stream<String> getLogStream(int siteId) {
    final proc = _processes[siteId];
    if (proc != null) {
      return proc.streamController.stream;
    }
    return const Stream.empty();
  }

  void clearLogs(int siteId) {
    _processes[siteId]?.logBuffer.clear();
  }

  /// Builds a copy of the current environment with common CLI toolchain
  /// directories prepended to [PATH] so that `npm`, `bun`, `deno`, `node`,
  /// etc. resolve even when this desktop process has no login shell.
  Map<String, String> _buildEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final pathSeparator = Platform.isWindows ? ';' : ':';
    final currentPath = env['PATH'] ?? '';

    final extraPaths = <String>[];
    if (Platform.isLinux || Platform.isMacOS) {
      extraPaths.addAll([
        '$home/.nvm/versions/node/current/bin',
        '$home/.bun/bin',
        '$home/.deno/bin',
        '$home/.cargo/bin',
        '/usr/local/bin',
        '/usr/bin',
        '/bin',
      ]);
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      extraPaths.addAll([
        '$appData\\npm',
        '$localAppData\\Programs\\bun',
        '$home\\.deno\\bin',
      ]);
    }

    final validExtras =
        extraPaths.where((path) => Directory(path).existsSync()).toList();
    if (validExtras.isNotEmpty) {
      env['PATH'] =
          '${validExtras.join(pathSeparator)}$pathSeparator$currentPath';
    }

    return env;
  }

  Future<bool> startSite(SiteModel site) async {
    if (site.command == null || site.command!.trim().isEmpty) {
      throw ArgumentError('Site start command cannot be empty');
    }
    if (isSiteRunning(site.id)) {
      return true;
    }

    // A previous process for this site may have exited naturally and is still
    // tracked (so its logs remain queryable). Release its file/stream resources
    // before starting a fresh process to avoid leaking the old sink.
    if (_processes.containsKey(site.id)) {
      await _removeSite(site.id);
    }

    final workDir = Directory(site.rootDir);
    if (!workDir.existsSync()) {
      throw StateError('Root directory does not exist: ${site.rootDir}');
    }

    final logBase = logsDirectory ?? p.join(AppConfig.baseDir, 'logs');
    final siteLogDir = Directory(p.join(logBase, site.domain));
    if (!siteLogDir.existsSync()) {
      siteLogDir.createSync(recursive: true);
    }
    final logFile = File(p.join(siteLogDir.path, 'cli_app.log'));
    final sink = logFile.openWrite(mode: FileMode.append);

    final logBuffer = CircularLogBuffer();
    final streamController = StreamController<String>.broadcast();

    final env = _buildEnvironment();
    Process process;

    try {
      if (Platform.isWindows) {
        process = await Process.start(
          'cmd.exe',
          ['/c', site.command!],
          workingDirectory: site.rootDir,
          environment: env,
        );
      } else {
        // Run under `setsid` so the child becomes the leader of a new
        // session/process group (pid == pgid). This makes `kill -9 -- -<pid>`
        // in [_killProcessTree] address the whole tree instead of just the
        // leader, giving real process-tree termination. The SDK's
        // Process.start exposes no process-group option, so setsid is the
        // portable enabler of the spec'd `kill -9 -- -<pid>`.
        try {
          process = await Process.start(
            'setsid',
            ['/bin/sh', '-c', site.command!],
            workingDirectory: site.rootDir,
            environment: env,
          );
        } catch (_) {
          // setsid missing (extremely unlikely on a real Unix): fall back to a
          // plain shell; process-tree grouping won't be available but the
          // leader is still tracked.
          process = await Process.start(
            '/bin/sh',
            ['-c', site.command!],
            workingDirectory: site.rootDir,
            environment: env,
          );
        }
      }
    } catch (e) {
      await sink.flush();
      await sink.close();
      AppLogger.error('Failed to start CLI site ${site.domain}: $e');
      rethrow;
    }

    final managed = ManagedCliProcess(
      siteId: site.id,
      domain: site.domain,
      process: process,
      logBuffer: logBuffer,
      streamController: streamController,
      logFileSink: sink,
    );

    _processes[site.id] = managed;
    _notifyStatus(site.id);
    unawaited(
      AppLogger.info(
        'Started CLI site ${site.domain} (port ${site.port})',
      ),
    );

    void handleLine(String line) {
      logBuffer.add(line);
      if (!streamController.isClosed) {
        streamController.add(line);
      }
      // Best-effort file write: the sink may already be closing/closed when the
      // process exits and stopSite runs cleanup concurrently.
      try {
        sink.writeln('[${DateTime.now().toIso8601String()}] $line');
      } catch (_) {
        // Sink is closed; the in-memory buffer/stream still hold the line.
      }
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((err) => handleLine('[ERROR] $err'));

    // On natural exit the process is marked not-running but its log buffer and
    // stream are retained (do NOT remove/close here) so prior output stays
    // queryable. Explicit cleanup happens in stopSite / _removeSite.
    process.exitCode.then((code) {
      handleLine('[Process exited with code $code]');
      managed.running = false;
      _notifyStatus(site.id);
      unawaited(
        AppLogger.warning(
          'CLI site ${site.domain} (id ${site.id}) exited with code $code',
        ),
      );
    });

    return true;
  }

  Future<bool> stopSite(int siteId) async {
    final managed = _processes[siteId];
    if (managed == null) return false;

    final pid = managed.process.pid;
    await _killProcessTree(pid);
    await _removeSite(siteId);
    _notifyStatus(siteId);
    unawaited(AppLogger.info('Stopped CLI site (id $siteId)'));
    return true;
  }

  Future<bool> restartSite(SiteModel site) async {
    if (isSiteRunning(site.id)) {
      await stopSite(site.id);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return startSite(site);
  }

  /// Terminates the entire process tree rooted at [pid]. On POSIX the child is
  /// started as its own process group leader (via `setsid`), so a negative pid
  /// signals the whole tree; a direct (positive) kill is used as a fallback. On
  /// Windows `taskkill /F /T /PID` does the equivalent.
  Future<void> _killProcessTree(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
      } else {
        await Process.run('kill', ['-TERM', '-$pid']);
        await Future.delayed(const Duration(milliseconds: 300));
        await Process.run('kill', ['-9', '-$pid']);
        // Direct fallback in case the group signal missed (e.g. child is no
        // longer a process-group leader).
        await Process.run('kill', ['-9', pid.toString()]);
      }
    } catch (_) {
      // Best-effort tree kill; try a direct kill as last resort.
      try {
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
        } else {
          await Process.run('kill', ['-9', pid.toString()]);
        }
      } catch (_) {
        // Swallow — the process may already be gone.
      }
    }
  }

  /// Removes per-site state and releases file/stream resources. Safe to call
  /// more than once for the same [siteId] (the second+ calls are no-ops).
  Future<void> _removeSite(int siteId) async {
    final managed = _processes.remove(siteId);
    if (managed == null) return;
    managed.running = false;
    try {
      await managed.logFileSink.flush();
      await managed.logFileSink.close();
    } catch (_) {
      // File already closed/removed; best-effort.
    }
    try {
      if (!managed.streamController.isClosed) {
        await managed.streamController.close();
      }
    } catch (_) {
      // Already closed, ignore.
    }
  }

  Future<void> stopAll() async {
    final ids = _processes.keys.toList();
    for (final id in ids) {
      await stopSite(id);
    }
  }

  void dispose() {
    // Best-effort: stop running processes; don't block shutdown on it.
    unawaited(stopAll());
    if (!_statusController.isClosed) {
      _statusController.close();
    }
  }
}

final cliProcessManagerProvider = Provider<CliProcessManager>((ref) {
  final manager = CliProcessManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
