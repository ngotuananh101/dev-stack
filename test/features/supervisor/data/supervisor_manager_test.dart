import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable stand-in for a spawned process. The test drives its exit
/// code explicitly, so watchdog behaviour is deterministic.
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

class _FakeSpawner {
  final List<_FakeProcess> spawned = [];
  int _nextPid = 100;

  Future<SupervisedProcess> spawn(SupervisorProgram program) async {
    final p = _FakeProcess(_nextPid++);
    spawned.add(p);
    return p;
  }
}

void main() {
  late Directory tempDir;
  late _FakeSpawner spawner;
  late List<int> killedPids;
  late SupervisorManager manager;

  SupervisorProgram program({
    int maxRestarts = 5,
    bool autoRestart = true,
    bool enabled = true,
    int restartDelaySeconds = 0,
  }) =>
      SupervisorProgram(
        id: 1,
        name: 'Queue',
        command: 'php artisan queue:work',
        workingDir: tempDir.path,
        autoRestart: autoRestart,
        maxRestarts: maxRestarts,
        restartWindowSeconds: 60,
        restartDelaySeconds: restartDelaySeconds,
        enabled: enabled,
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sup_test_');
    spawner = _FakeSpawner();
    killedPids = [];
    manager = SupervisorManager(
      logsDirectory: tempDir.path,
      spawner: spawner.spawn,
      treeKiller: (pid) async => killedPids.add(pid),
      // Zero-delay backoff keeps the watchdog tests instant.
      delay: (_) async {},
    );
  });

  tearDown(() async {
    await manager.stopAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('start spawns once and reports running with a pid', () async {
    expect(await manager.start(program()), isTrue);
    expect(manager.isRunning(1), isTrue);
    expect(manager.getPid(1), 100);
    expect(manager.statusOf(1), SupervisorStatus.running);
    expect(spawner.spawned.length, 1);
  });

  test('a crash with autoRestart respawns the program', () async {
    await manager.start(program());
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 2);
    expect(manager.statusOf(1), SupervisorStatus.running);
    expect(manager.isRunning(1), isTrue);
  });

  test('an explicit stop does not restart', () async {
    await manager.start(program());
    await manager.stop(1);
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 1);
    expect(manager.statusOf(1), SupervisorStatus.stopped);
    expect(manager.isRunning(1), isFalse);
    expect(killedPids, [100]);
  });

  test('autoRestart=false settles at stopped on crash', () async {
    await manager.start(program(autoRestart: false));
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 1);
    expect(manager.statusOf(1), SupervisorStatus.stopped);
  });

  test('a disabled program never starts', () async {
    expect(await manager.start(program(enabled: false)), isFalse);
    expect(spawner.spawned, isEmpty);
  });

  test('exceeding maxRestarts gives up with fatal', () async {
    await manager.start(program(maxRestarts: 2));
    // Crash the initial process and every respawn until the watchdog gives up.
    for (var i = 0; i < 4; i++) {
      if (i < spawner.spawned.length) {
        spawner.spawned[i].exit(1);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(manager.statusOf(1), SupervisorStatus.fatal);
    // 1 initial + 2 allowed restarts = 3 spawns, then it stops spawning.
    expect(spawner.spawned.length, 3);
  });

  test('statusStream emits the program id on change', () async {
    final seen = <int>[];
    final sub = manager.statusStream.listen(seen.add);
    await manager.start(program());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(seen, contains(1));
  });

  test('statuses exposes the current status of every known program', () async {
    expect(manager.statuses, isEmpty);
    await manager.start(program());
    expect(manager.statuses[1], SupervisorStatus.running);
  });

  group('backoff (M8)', () {
    test('delays follow 2, 4, 8, ... and cap at 60 s', () async {
      final recorded = <Duration>[];
      final localSpawner = _FakeSpawner();
      final local = SupervisorManager(
        logsDirectory: tempDir.path,
        spawner: localSpawner.spawn,
        treeKiller: (_) async {},
        delay: (d) async => recorded.add(d),
      );
      addTearDown(() => local.stopAll());

      // Base 2 s, maxRestarts high enough that the cap is reached before the
      // watchdog gives up.
      await local.start(program(maxRestarts: 20, restartDelaySeconds: 2));

      // Crash each spawned process in turn, letting the (instant) delay run.
      for (var i = 0; i < 6; i++) {
        if (i < localSpawner.spawned.length) {
          localSpawner.spawned[i].exit(1);
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(
        recorded.map((d) => d.inSeconds).toList(),
        [2, 4, 8, 16, 32, 60],
      );
    });
  });

  group('stale exit guard (M10)', () {
    test('a backoff-waiting exit does not clobber a newer process', () async {
      final gate = Completer<void>();
      final localSpawner = _FakeSpawner();
      final local = SupervisorManager(
        logsDirectory: tempDir.path,
        spawner: localSpawner.spawn,
        treeKiller: (_) async {},
        delay: (_) => gate.future,
      );
      addTearDown(local.stopAll);

      await local.start(program(restartDelaySeconds: 1));
      // Crash the first process; the watchdog parks in the backoff delay.
      localSpawner.spawned[0].exit(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(local.statusOf(1), SupervisorStatus.restarting);

      // The user restarts: a new process replaces the parked one.
      await local.restart(program(restartDelaySeconds: 1));
      expect(local.statusOf(1), SupervisorStatus.running);
      final pid = local.getPid(1);

      // Release the old backoff: it must neither respawn nor mark the new
      // process stopped.
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(local.statusOf(1), SupervisorStatus.running);
      expect(local.getPid(1), pid);
      expect(localSpawner.spawned.length, 2);
    });
  });

  group('real spawner (C2)', () {
    test('starts a program with an empty working directory', () async {
      // No `spawner:` injection: this exercises `_defaultSpawn`. Before the fix
      // `Process.start(..., workingDirectory: '')` threw
      // `ProcessException: No such file or directory`.
      final local = SupervisorManager(logsDirectory: tempDir.path);
      addTearDown(local.stopAll);

      final p = SupervisorProgram(
        id: 3,
        name: 'empty-workdir',
        command: 'sleep 30',
        workingDir: '', // the form default
      );

      final started = await local.start(p);
      expect(started, isTrue);
      expect(local.statusOf(3), isNot(SupervisorStatus.fatal));
      // The spawn must not have failed with a ProcessException.
      expect(local.isRunning(3), isTrue);

      await local.stop(3);
      expect(local.isRunning(3), isFalse);
    });
  });
}
