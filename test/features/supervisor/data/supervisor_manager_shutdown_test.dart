import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable stand-in for a spawned process.
class _FakeProcess implements SupervisedProcess {
  @override
  final int pid;
  final _exit = Completer<int>();
  _FakeProcess(this.pid);

  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

void main() {
  late Directory tempDir;
  late List<_FakeProcess> spawned;

  SupervisorProgram program({int restartDelaySeconds = 30}) => SupervisorProgram(
        id: 1,
        name: 'Queue',
        command: 'php artisan queue:work',
        workingDir: tempDir.path,
        autoRestart: true,
        maxRestarts: 5,
        restartWindowSeconds: 60,
        restartDelaySeconds: restartDelaySeconds,
        enabled: true,
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sup_shut_');
    spawned = [];
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a watchdog parked in its backoff is released by the shutdown',
      () async {
    final manager = SupervisorManager(
      logsDirectory: tempDir.path,
      spawner: (p) async {
        final proc = _FakeProcess(100 + spawned.length);
        spawned.add(proc);
        return proc;
      },
      treeKiller: (_) async {},
      // A backoff that never ends on its own: only the shutdown can release it.
      delay: (_) => Completer<void>().future,
    );

    await manager.start(program());
    // Crash the process: the watchdog parks in the backoff.
    spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(manager.statusOf(1), SupervisorStatus.restarting);

    manager.shutdown();

    // The parked backoff must be released right away: a watchdog still
    // waiting out a 60-second backoff keeps the app's shutdown waiting, and
    // the program must not be respawned while the app is going down.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(manager.statusOf(1), SupervisorStatus.stopped,
        reason: 'the parked backoff must be released by the shutdown');
    expect(spawned.length, 1,
        reason: 'a program must not be respawned after the shutdown');
  });

  test('shutdown kills the process trees synchronously', () async {
    final killed = <int>[];
    final manager = SupervisorManager(
      logsDirectory: tempDir.path,
      spawner: (p) async {
        final proc = _FakeProcess(100 + spawned.length);
        spawned.add(proc);
        return proc;
      },
      treeKillerSync: killed.add,
    );

    await manager.start(program());
    manager.shutdown();

    // The kill must have been sent before shutdown returned: an app that is
    // torn down right after would otherwise leave the child running.
    expect(killed, [100]);
    expect(manager.isRunning(1), isFalse);
  });
}
