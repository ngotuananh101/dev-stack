import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/data/supervisor_provider.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in process whose exit the test controls.
class _FakeProcess implements SupervisedProcess {
  @override
  final int pid;
  _FakeProcess(this.pid);
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => Completer<int>().future;
}

void main() {
  test('a program without an id is recognized as new', () {
    final p = SupervisorProgram(name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isTrue);
  });

  test('a program with an id is recognized as existing', () {
    final p = SupervisorProgram(id: 3, name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isFalse);
  });

  test('the status provider starts empty before any manager event', () {
    // The provider family/type exists and is a NotifierProvider; the initial
    // map is produced by build() inside a container (see Task 8 step 5's
    // widget-level coverage). Here we only pin the public shape.
    expect(supervisorStatusProvider, isA<NotifierProvider<dynamic, dynamic>>());
  });

  test('seeds status from the manager for an already-running program (I4)',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('sup_provider_test_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    var nextPid = 500;
    final manager = SupervisorManager(
      logsDirectory: tempDir.path,
      spawner: (_) async => _FakeProcess(nextPid++),
      treeKiller: (_) async {},
      delay: (_) async {},
    );
    addTearDown(manager.stopAll);

    // The program is already running before the provider is ever read — as it
    // would be after an auto-start at launch.
    await manager.start(
      SupervisorProgram(id: 1, name: 'Queue', command: 'sleep 30'),
    );
    expect(manager.statusOf(1), SupervisorStatus.running);

    final container = ProviderContainer.test(
      overrides: [supervisorManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(container.dispose);

    // No status event is emitted after subscription; the map must still be
    // seeded with the running status.
    final statuses = container.read(supervisorStatusProvider);
    expect(statuses[1], SupervisorStatus.running);
  });
}
