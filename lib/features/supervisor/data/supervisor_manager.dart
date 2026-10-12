import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:path/path.dart' as p;

import '../../../core/config/app_config.dart';
import '../../../core/database/isar_provider.dart';
import '../../../core/services/log_service.dart';
import '../../sites/data/cli_process_manager.dart' show CircularLogBuffer;
import '../domain/supervisor_program.dart';
import '../domain/supervisor_status.dart';

export '../domain/supervisor_status.dart';

/// A spawned supervised process. Abstracted so tests can drive its exit code
/// without spawning anything real.
abstract class SupervisedProcess {
  int get pid;
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
}

class _RealSupervisedProcess implements SupervisedProcess {
  final Process _process;
  _RealSupervisedProcess(this._process);

  @override
  int get pid => _process.pid;
  @override
  Stream<List<int>> get stdout => _process.stdout;
  @override
  Stream<List<int>> get stderr => _process.stderr;
  @override
  Future<int> get exitCode => _process.exitCode;
}

/// Spawns a program's command. The default implementation mirrors
/// `CliProcessManager` (setsid on POSIX, cmd.exe on Windows).
typedef SupervisorSpawner = Future<SupervisedProcess> Function(
  SupervisorProgram program,
);

/// Terminates an entire process tree rooted at [pid].
typedef SupervisorTreeKiller = Future<void> Function(int pid);

/// Sleeps for [duration]. Injected so tests can run the backoff instantly.
typedef SupervisorDelay = Future<void> Function(Duration duration);

/// Bookkeeping for one supervised process and its output sinks.
class ManagedSupervisorProcess {
  final int programId;
  final SupervisedProcess process;
  final CircularLogBuffer logBuffer;
  final StreamController<String> streamController;
  final IOSink logFileSink;
  bool running = true;

  /// Set by [SupervisorManager.stop] / [stopAll] / [dispose] so the exit
  /// handler can tell a deliberate stop from a crash.
  bool explicitlyStopped = false;

  ManagedSupervisorProcess({
    required this.programId,
    required this.process,
    required this.logBuffer,
    required this.streamController,
    required this.logFileSink,
  });
}

final supervisorManagerProvider = Provider<SupervisorManager>((ref) {
  final manager = SupervisorManager(
    // Late-bound on purpose. The database opens asynchronously, so a snapshot
    // taken here would be null forever; and `ref.watch(isarProvider)` would
    // rebuild the manager the moment the DB lands, reaping any process already
    // started. Resolving at call time keeps one manager for the app's life.
    isarResolver: () => ref.read(isarProvider).value,
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Keeps arbitrary long-running processes alive, restarting them when they
/// crash unless the user asked them to stop.
///
/// Mirrors `CliProcessManager` for spawn/tee/status, and adds a watchdog:
/// on a crash it restarts after an exponential backoff, up to [maxRestarts]
/// within a rolling window, then gives up and reports `fatal`.
class SupervisorManager {
  final String? logsDirectory;
  final Isar? Function() _isarResolver;
  final SupervisorSpawner _spawner;
  final SupervisorTreeKiller _treeKiller;
  final SupervisorDelay _delay;

  final Map<int, ManagedSupervisorProcess> _processes = {};
  final Map<int, SupervisorStatus> _statuses = {};
  final Map<int, List<DateTime>> _restartTimes = {};
  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  /// [isar] pins a fixed database (tests); [isarResolver] resolves one lazily
  /// (production), so a manager created before the async open still sees it.
  SupervisorManager({
    this.logsDirectory,
    Isar? isar,
    Isar? Function()? isarResolver,
    SupervisorSpawner? spawner,
    SupervisorTreeKiller? treeKiller,
    SupervisorDelay? delay,
  })  : _isarResolver = isarResolver ?? (isar != null ? () => isar : () => null),
        _spawner = spawner ?? _defaultSpawn,
        _treeKiller = treeKiller ?? _defaultTreeKill,
        _delay = delay ?? Future<void>.delayed;

  Isar? get _isar => _isarResolver();

  Stream<int> get statusStream => _statusController.stream;

  void _notifyStatus(int programId) {
    if (!_statusController.isClosed) _statusController.add(programId);
  }

  SupervisorStatus statusOf(int programId) =>
      _statuses[programId] ?? SupervisorStatus.stopped;

  bool isRunning(int programId) => _processes[programId]?.running ?? false;

  int? getPid(int programId) => _processes[programId]?.process.pid;

  List<String> getLogBuffer(int programId) =>
      _processes[programId]?.logBuffer.lines ?? [];

  Stream<String> getLogStream(int programId) =>
      _processes[programId]?.streamController.stream ?? const Stream.empty();

  void clearLogs(int programId) => _processes[programId]?.logBuffer.clear();

  static Map<String, String> _buildEnvironment(SupervisorProgram program) {
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(program.envVars());
    return env;
  }

  static Future<SupervisedProcess> _defaultSpawn(
    SupervisorProgram program,
  ) async {
    if (Platform.isWindows) {
      return _RealSupervisedProcess(await Process.start(
        'cmd.exe',
        ['/c', program.command],
        workingDirectory: program.workingDir,
        environment: _buildEnvironment(program),
      ));
    }
    try {
      // setsid makes the child its own process-group leader (pid == pgid), so
      // `kill -9 -- -<pid>` addresses the whole tree.
      return _RealSupervisedProcess(await Process.start(
        'setsid',
        ['/bin/sh', '-c', program.command],
        workingDirectory: program.workingDir,
        environment: _buildEnvironment(program),
      ));
    } catch (_) {
      return _RealSupervisedProcess(await Process.start(
        '/bin/sh',
        ['-c', program.command],
        workingDirectory: program.workingDir,
        environment: _buildEnvironment(program),
      ));
    }
  }

  static Future<void> _defaultTreeKill(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
      } else {
        await Process.run('kill', ['-TERM', '-$pid']);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await Process.run('kill', ['-9', '-$pid']);
        await Process.run('kill', ['-9', '$pid']);
      }
    } catch (_) {
      // Best-effort: the process may already be gone.
    }
  }

  /// Starts [program]. Returns `false` when the program is disabled or its
  /// command is empty; returns `true` when it is already running.
  ///
  /// [isRestart] is internal: a watchdog respawn keeps the rolling restart
  /// window, while a user-initiated start resets it.
  Future<bool> start(SupervisorProgram program, {bool isRestart = false}) async {
    if (!program.enabled) return false;
    if (program.command.trim().isEmpty) return false;
    if (isRunning(program.id)) return true;

    final workDir = Directory(program.workingDir);
    if (program.workingDir.isNotEmpty && !workDir.existsSync()) {
      throw StateError('Working directory does not exist: ${program.workingDir}');
    }

    if (_processes.containsKey(program.id)) {
      await _remove(program.id);
    }

    _statuses[program.id] = SupervisorStatus.starting;
    _notifyStatus(program.id);

    final logBase = logsDirectory ?? p.join(AppConfig.baseDir, 'logs');
    final logDir = Directory(p.join(logBase, 'supervisor'));
    if (!logDir.existsSync()) logDir.createSync(recursive: true);
    final sink = File(p.join(logDir.path, '${program.name}.log'))
        .openWrite(mode: FileMode.append);

    final buffer = CircularLogBuffer();
    final controller = StreamController<String>.broadcast();

    SupervisedProcess process;
    try {
      process = await _spawner(program);
    } catch (e) {
      await sink.flush();
      await sink.close();
      _statuses[program.id] = SupervisorStatus.fatal;
      _notifyStatus(program.id);
      AppLogger.error('Failed to start supervised program ${program.name}: $e');
      return false;
    }

    final managed = ManagedSupervisorProcess(
      programId: program.id,
      process: process,
      logBuffer: buffer,
      streamController: controller,
      logFileSink: sink,
    );
    _processes[program.id] = managed;

    void handleLine(String line) {
      buffer.add(line);
      if (!controller.isClosed) controller.add(line);
      try {
        sink.writeln('[${DateTime.now().toIso8601String()}] $line');
      } catch (_) {
        // Sink already closed; the in-memory buffer still holds the line.
      }
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((e) => handleLine('[ERROR] $e'));

    process.exitCode.then(
      (code) => unawaited(_handleExit(program, managed, code)),
      onError: (_) => unawaited(_handleExit(program, managed, null)),
    );

    _statuses[program.id] = SupervisorStatus.running;
    _notifyStatus(program.id);
    if (!isRestart) {
      _restartTimes.remove(program.id);
    }
    return true;
  }

  /// Watchdog: decide whether to respawn after [managed]'s process exited.
  Future<void> _handleExit(
    SupervisorProgram program,
    ManagedSupervisorProcess managed,
    int? code,
  ) async {
    managed.running = false;
    final line = code == null
        ? '[Process exited unexpectedly]'
        : '[Process exited with code $code]';
    managed.logBuffer.add(line);
    if (!managed.streamController.isClosed) managed.streamController.add(line);

    // A deliberate stop settles at stopped and never restarts.
    if (managed.explicitlyStopped) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }

    if (!program.enabled || !program.autoRestart) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }

    final now = DateTime.now();
    final times = _restartTimes.putIfAbsent(program.id, () => []);
    final windowStart =
        now.subtract(Duration(seconds: program.restartWindowSeconds));
    times.removeWhere((t) => t.isBefore(windowStart));
    times.add(now);

    if (times.length > program.maxRestarts) {
      _statuses[program.id] = SupervisorStatus.fatal;
      final msg =
          'Exceeded max restarts (${program.maxRestarts}) in '
          '${program.restartWindowSeconds}s — giving up';
      managed.logBuffer.add(msg);
      if (!managed.streamController.isClosed) managed.streamController.add(msg);
      _notifyStatus(program.id);
      return;
    }

    // Exponential backoff: base * 2^(attempt-1), capped at 60 s.
    final attempt = times.length > 10 ? 10 : times.length;
    var seconds = program.restartDelaySeconds * (1 << (attempt - 1));
    if (seconds > 60) seconds = 60;
    if (seconds < 0) seconds = 0;

    _statuses[program.id] = SupervisorStatus.restarting;
    _notifyStatus(program.id);

    if (seconds > 0) {
      await _delay(Duration(seconds: seconds));
    }
    // The program may have been stopped or disabled while we waited.
    if (managed.explicitlyStopped || !program.enabled) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }
    await start(program, isRestart: true);
  }

  Future<bool> stop(int programId) async {
    final managed = _processes[programId];
    if (managed == null) {
      _statuses[programId] = SupervisorStatus.stopped;
      _notifyStatus(programId);
      return false;
    }
    managed.explicitlyStopped = true;
    _statuses[programId] = SupervisorStatus.stopping;
    _notifyStatus(programId);
    await _treeKiller(managed.process.pid);
    await _remove(programId);
    _restartTimes.remove(programId);
    _statuses[programId] = SupervisorStatus.stopped;
    _notifyStatus(programId);
    return true;
  }

  Future<bool> restart(SupervisorProgram program) async {
    await stop(program.id);
    return start(program);
  }

  /// Starts every enabled program stored in Isar.
  Future<void> startAll() async {
    final isar = _isar;
    if (isar == null) return;
    final programs = isar.supervisorPrograms.where().findAll();
    for (final program in programs) {
      if (!program.enabled) continue;
      try {
        await start(program);
      } catch (e) {
        AppLogger.error('Failed to start ${program.name}: $e');
      }
    }
  }

  /// Starts only the programs marked `autoStart` (used on app launch).
  Future<void> startAutoStart() async {
    final isar = _isar;
    if (isar == null) return;
    final programs = isar.supervisorPrograms
        .where()
        .autoStartEqualTo(true)
        .enabledEqualTo(true)
        .findAll();
    for (final program in programs) {
      try {
        await start(program);
      } catch (e) {
        AppLogger.error('Auto-start failed for ${program.name}: $e');
      }
    }
  }

  Future<void> stopAll() async {
    final ids = _processes.keys.toList();
    for (final id in ids) {
      await stop(id);
    }
  }

  Future<void> _remove(int programId) async {
    final managed = _processes.remove(programId);
    if (managed == null) return;
    managed.running = false;
    try {
      await managed.logFileSink.flush();
      await managed.logFileSink.close();
    } catch (_) {
      // Already closed.
    }
    try {
      if (!managed.streamController.isClosed) {
        await managed.streamController.close();
      }
    } catch (_) {
      // Already closed.
    }
  }

  void dispose() {
    for (final managed in _processes.values) {
      managed.explicitlyStopped = true;
    }
    unawaited(stopAll());
    if (!_statusController.isClosed) _statusController.close();
  }
}
