import 'dart:async';

import 'package:dev_stack/features/cron/data/cron_scheduler_service.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disposing while a run is in flight does not crash the scheduler',
      () async {
    final gate = Completer<void>();
    final job = CronJob(
      id: 1,
      name: 'job1',
      schedule: '* * * * *',
      command: 'echo hi',
      enabled: true,
    );

    final errors = <Object>[];
    var now = DateTime(2026, 10, 12, 8, 30);
    late CronSchedulerService scheduler;
    await runZonedGuarded(
      () async {
        scheduler = CronSchedulerService(
          clock: () => now,
          loadJobs: () async => [job],
          updateJob: (_) async {},
          runner: (_) async {
            await gate.future;
            return const CronRunResult(exitCode: 0, output: 'ok');
          },
        );

        await scheduler.tick();
        // Advance a minute so the seeded next run becomes due and starts.
        now = DateTime(2026, 10, 12, 8, 31);
        scheduler.tick();
        await Future<void>.delayed(Duration.zero);
      },
      (error, stack) => errors.add(error),
    );

    // Dispose while the runner is still blocked: the history entry the run
    // writes its result into is wiped underneath it.
    scheduler.dispose();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(errors, isEmpty,
        reason: 'the in-flight run must not throw after dispose');
  });
}
