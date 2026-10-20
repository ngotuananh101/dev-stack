import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
          : '${Platform.environment['HOME']}/.pub-cache');
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!hosted.existsSync()) return null;

  for (final entry in hosted.listSync()) {
    if (entry is! Directory) continue;
    if (!entry.path.contains('isar_plus_flutter_libs-')) continue;
    final candidate = File(
      '${entry.path}/${Platform.isWindows ? 'windows' : 'linux'}/$libName',
    );
    if (candidate.existsSync()) return candidate.path;
  }
  return null;
}

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
  final libraryPath = _isarLibraryPath();

  test(
    'a program disabled during the backoff wait is not respawned',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('sup_cfg_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      Isar.initialize(libraryPath);
      final isar = Isar.open(
        schemas: [SupervisorProgramSchema],
        directory: tempDir.path,
        name: 'sup_cfg_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(isar.close);

      final spawner = _FakeSpawner();
      final backoff = Completer<void>();
      final manager = SupervisorManager(
        logsDirectory: tempDir.path,
        isar: isar,
        spawner: spawner.spawn,
        treeKiller: (_) async {},
        // Hold the watchdog in its backoff until the test says so.
        delay: (_) => backoff.future,
      );
      addTearDown(() async {
        if (!backoff.isCompleted) backoff.complete();
        await manager.stopAll();
      });

      final program = SupervisorProgram(
        id: 1,
        name: 'Queue',
        command: 'php artisan queue:work',
        workingDir: tempDir.path,
        autoRestart: true,
        maxRestarts: 5,
        restartWindowSeconds: 60,
        restartDelaySeconds: 30,
        enabled: true,
      );
      isar.write((isar) => isar.supervisorPrograms.put(program));

      await manager.start(program);
      expect(spawner.spawned.length, 1);

      // The process crashes: the watchdog reads the config (enabled) and enters
      // the backoff wait.
      spawner.spawned.first.exit(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // The user disables the program while the watchdog waits.
      final stored = isar.supervisorPrograms.get(program.id)!;
      stored.enabled = false;
      isar.write((isar) => isar.supervisorPrograms.put(stored));

      backoff.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The watchdog must re-read the config: a program the user just disabled
      // must not be respawned with the stale snapshot.
      expect(spawner.spawned.length, 1,
          reason: 'the disabled program must not be respawned');
    },
    skip: libraryPath == null ? 'Isar native library not available' : false,
  );
}
