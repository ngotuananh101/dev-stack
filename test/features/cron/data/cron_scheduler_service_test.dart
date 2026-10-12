import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/cron/data/cron_scheduler_service.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late List<CronJob> jobs;
  late List<CronJob> persisted;
  late List<String> ranCommands;
  late Completer<void>? gate;
  late CronSchedulerService scheduler;

  CronJob job({
    int id = 1,
    String schedule = '* * * * *',
    bool enabled = true,
    String command = 'echo hi',
  }) =>
      CronJob(
        id: id,
        name: 'job$id',
        schedule: schedule,
        command: command,
        enabled: enabled,
      );

  setUp(() {
    now = DateTime(2026, 10, 12, 8, 30);
    jobs = [job()];
    persisted = [];
    ranCommands = [];
    gate = null;
    scheduler = CronSchedulerService(
      clock: () => now,
      loadJobs: () async => jobs,
      updateJob: (j) async => persisted.add(j),
      runner: (j) async {
        ranCommands.add(j.command);
        if (gate != null) await gate!.future;
        return const CronRunResult(exitCode: 0, output: 'ok');
      },
    );
  });

  tearDown(() => scheduler.dispose());

  test('a due job fires once and advances its next run', () async {
    // First tick seeds the next run; nothing fires yet.
    await scheduler.tick();
    expect(ranCommands, isEmpty);

    // Advance one minute so the seeded next-run is due.
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    // tick() fires the run without awaiting it, so drain its microtasks first.
    await Future<void>.delayed(Duration.zero);
    expect(ranCommands, ['echo hi']);

    // A second tick at the same instant must not re-fire.
    await scheduler.tick();
    expect(ranCommands.length, 1);
  });

  test('a not-due job does not fire', () async {
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 30, 45); // still inside the same minute
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('a disabled job is skipped', () async {
    jobs = [job(enabled: false)];
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 9, 0);
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('an invalid schedule is skipped', () async {
    jobs = [job(schedule: 'nonsense')];
    now = DateTime(2026, 10, 12, 9, 0);
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('a run persists its status and exit code', () async {
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    await Future<void>.delayed(Duration.zero);

    expect(persisted, isNotEmpty);
    expect(persisted.last.lastStatus, 'success');
    expect(persisted.last.lastExitCode, 0);
  });

  test('a failing command is recorded as failed', () async {
    scheduler = CronSchedulerService(
      clock: () => now,
      loadJobs: () async => jobs,
      updateJob: (j) async => persisted.add(j),
      runner: (j) async => const CronRunResult(exitCode: 2, output: 'boom'),
    );
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    await Future<void>.delayed(Duration.zero);

    expect(persisted.last.lastStatus, 'failed');
    expect(persisted.last.lastExitCode, 2);
  });

  test('an in-flight run is never overlapped', () async {
    gate = Completer<void>();
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick(); // starts, blocks on the gate
    expect(scheduler.isRunning(1), isTrue);

    now = DateTime(2026, 10, 12, 8, 32);
    await scheduler.tick(); // must skip: still running
    expect(ranCommands.length, 1);

    gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.isRunning(1), isFalse);
  });

  test('runNow ignores the schedule', () async {
    await scheduler.runNow(jobs.first);
    expect(ranCommands, ['echo hi']);
  });

  test('history is capped at 20 records, newest first', () async {
    // Advance the injected clock between runs: a fixed clock would give every
    // record the same startedAt, so "newest first" could not be observed.
    for (var i = 0; i < 25; i++) {
      now = DateTime(2026, 10, 12, 8, 30).add(Duration(minutes: i));
      await scheduler.runNow(jobs.first);
    }
    final history = scheduler.historyFor(1);
    expect(history.length, 20);
    expect(history.first.startedAt.isAfter(history.last.startedAt), isTrue);
  });

  test('statusStream emits the job id on run start', () async {
    final seen = <int>[];
    final sub = scheduler.statusStream.listen(seen.add);
    await scheduler.runNow(jobs.first);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(seen, contains(1));
  });

  group('real runner (C1)', () {
    test('runs a command with arguments through a shell', () async {
      // No `runner:` injection: this exercises `_defaultRunner`. Before the fix
      // it passed the whole command as the executable with `runInShell: true`,
      // so `echo cron-ok` was looked up as a program literally named
      // "echo cron-ok" and exited 127.
      final real = CronSchedulerService(
        clock: () => now,
        loadJobs: () async => jobs,
        updateJob: (j) async => persisted.add(j),
      );
      addTearDown(real.dispose);

      final job = CronJob(
        id: 7,
        name: 'real',
        schedule: '* * * * *',
        command: 'echo cron-ok',
      );
      await real.runNow(job);

      final record = real.historyFor(7).first;
      expect(record.exitCode, 0);
      expect(record.output, contains('cron-ok'));
    });

    test('caps combined output with a truncation marker', () async {
      final real = CronSchedulerService(
        clock: () => now,
        loadJobs: () async => const <CronJob>[],
        updateJob: (_) async {},
      );
      addTearDown(real.dispose);

      // Emit far more than the cap (POSIX only; Windows has no `head`).
      final job = CronJob(
        id: 8,
        name: 'noisy',
        schedule: '* * * * *',
        command: Platform.isWindows
            ? 'for /L %i in (1,1,5000) do @echo 0123456789'
            : 'yes 0123456789 | head -n 5000',
      );
      await real.runNow(job);

      final record = real.historyFor(8).first;
      expect(record.exitCode, 0);
      expect(record.output.length,
          lessThanOrEqualTo(CronSchedulerService.maxOutputChars + 32));
      expect(record.output, endsWith('[output truncated]'));
    });
  });

  group('schedule edits (I3)', () {
    test('a changed schedule takes effect on the next tick', () async {
      jobs = [job(schedule: '@daily')];
      await scheduler.tick(); // seed @daily (next run is tomorrow)
      expect(ranCommands, isEmpty);

      // The user edits the schedule to "every minute"; the following tick must
      // re-seed from the new expression instead of keeping tomorrow's run.
      jobs = [job(schedule: '* * * * *')];
      await scheduler.tick();
      expect(ranCommands, isEmpty); // now 08:30; next run is 08:31

      now = DateTime(2026, 10, 12, 8, 31);
      await scheduler.tick();
      await Future<void>.delayed(Duration.zero);

      expect(ranCommands, ['echo hi']);
    });

    test('an unsatisfiable schedule can recover once edited', () async {
      // Feb 30 can never match; before the fix its `null` next-run was cached
      // permanently and editing it did nothing.
      jobs = [job(schedule: '0 0 30 2 *')];
      now = DateTime(2026, 10, 12, 9, 0);
      await scheduler.tick();
      expect(ranCommands, isEmpty);

      jobs = [job(schedule: '* * * * *')];
      await scheduler.tick(); // re-seed from the new expression
      expect(ranCommands, isEmpty);

      now = DateTime(2026, 10, 12, 9, 1);
      await scheduler.tick();
      await Future<void>.delayed(Duration.zero);

      expect(ranCommands, ['echo hi']);
    });
  });
}