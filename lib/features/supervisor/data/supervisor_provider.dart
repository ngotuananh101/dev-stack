import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../domain/supervisor_program.dart';
import 'supervisor_manager.dart';

/// Live list of supervised programs, watched straight from Isar.
final supervisorProgramsProvider =
    StreamProvider<List<SupervisorProgram>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield const <SupervisorProgram>[];
    return;
  }
  yield* isar.supervisorPrograms.where().watch(fireImmediately: true);
});

/// Live status per program id, following the manager's broadcast stream.
final supervisorStatusProvider =
    NotifierProvider<SupervisorStatusNotifier, Map<int, SupervisorStatus>>(
  SupervisorStatusNotifier.new,
);

class SupervisorStatusNotifier extends Notifier<Map<int, SupervisorStatus>> {
  late SupervisorManager _manager;
  StreamSubscription<int>? _subscription;

  @override
  Map<int, SupervisorStatus> build() {
    _manager = ref.watch(supervisorManagerProvider);
    _subscription = _manager.statusStream.listen((id) {
      state = {...state, id: _manager.statusOf(id)};
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    // Seed from the manager's current statuses so a program already running
    // when the page first opens (e.g. auto-started at launch) is not shown as
    // stopped before its first status event.
    return _manager.statuses;
  }

  SupervisorStatus statusOf(int programId) =>
      state[programId] ?? _manager.statusOf(programId);
}

/// Persists programs to Isar, allocating a fresh id for new records (Isar Plus
/// treats `id == 0` as a real key, not an auto-increment sentinel).
class SupervisorProgramsRepository {
  final Isar isar;
  SupervisorProgramsRepository(this.isar);

  static bool isNew(SupervisorProgram program) => program.id == 0;

  Future<void> save(SupervisorProgram program) async {
    isar.write((_) {
      if (program.id == 0) {
        program.id = isar.supervisorPrograms.autoIncrement();
      }
      isar.supervisorPrograms.put(program);
    });
  }

  Future<void> delete(int id) async {
    isar.write((_) => isar.supervisorPrograms.delete(id));
  }
}

final supervisorRepositoryProvider = Provider<SupervisorProgramsRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) {
    throw StateError('Isar is not open yet');
  }
  return SupervisorProgramsRepository(isar);
});
