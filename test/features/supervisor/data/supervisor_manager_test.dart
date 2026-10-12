import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
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
  }) =>
      SupervisorProgram(
        id: 1,
        name: 'Queue',
        command: 'php artisan queue:work',
        workingDir: tempDir.path,
        autoRestart: autoRestart,
        maxRestarts: maxRestarts,
        restartWindowSeconds: 60,
        restartDelaySeconds: 0,
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
}
