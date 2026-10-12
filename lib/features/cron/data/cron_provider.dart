import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../domain/cron_job.dart';
import 'cron_scheduler_service.dart';

/// Live list of cron jobs, watched straight from Isar.
final cronJobsProvider = StreamProvider<List<CronJob>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield const <CronJob>[];
    return;
  }
  yield* isar.cronJobs.where().watch(fireImmediately: true);
});

/// The set of job ids with a run in flight, following the scheduler's stream.
final cronRunStateProvider =
    NotifierProvider<CronRunStateNotifier, Set<int>>(CronRunStateNotifier.new);

class CronRunStateNotifier extends Notifier<Set<int>> {
  late CronSchedulerService _scheduler;
  StreamSubscription<int>? _subscription;

  @override
  Set<int> build() {
    _scheduler = ref.watch(cronSchedulerProvider);
    _subscription = _scheduler.statusStream.listen((id) {
      final next = {...state};
      if (_scheduler.isRunning(id)) {
        next.add(id);
      } else {
        next.remove(id);
      }
      state = next;
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const {};
  }
}

/// Persists jobs to Isar, allocating a fresh id for new records.
class CronJobsRepository {
  final Isar isar;
  CronJobsRepository(this.isar);

  static bool isNew(CronJob job) => job.id == 0;

  Future<void> save(CronJob job) async {
    isar.write((_) {
      if (job.id == 0) {
        job.id = isar.cronJobs.autoIncrement();
      }
      isar.cronJobs.put(job);
    });
  }

  Future<void> delete(int id) async {
    isar.write((_) => isar.cronJobs.delete(id));
  }
}

final cronRepositoryProvider = Provider<CronJobsRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) {
    throw StateError('Isar is not open yet');
  }
  return CronJobsRepository(isar);
});
