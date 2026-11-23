import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/cron/data/cron_scheduler_service.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String? _isarLibraryPath() {
  final libName = Platform.isWindows
      ? 'isar_plus.dll'
      : (Platform.isLinux ? 'libisar_plus.so' : null);
  if (libName == null) return null;

  final pubCache =
      Platform.environment['PUB_CACHE'] ??
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

void main() {
  final libraryPath = _isarLibraryPath();

  group('CronSchedulerService Isar persistence', () {
    late Directory tempDir;
    late Isar isar;
    late CronSchedulerService scheduler;
    var now = DateTime(2026, 10, 12, 8, 30);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cron_isar_');
      Isar.initialize(libraryPath);
      isar = Isar.open(
        schemas: [CronJobSchema],
        directory: tempDir.path,
        name: 'cron_isar_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      now = DateTime(2026, 10, 12, 8, 30);
    });

    tearDown(() {
      scheduler.dispose();
      isar.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    CronJob seedJob({
      int id = 1,
      String name = 'job1',
      String schedule = '* * * * *',
      String command = 'echo hi',
      String workingDir = '/tmp/work',
      bool enabled = true,
    }) {
      final job = CronJob(
        id: id,
        name: name,
        schedule: schedule,
        command: command,
        workingDir: workingDir,
        enabled: enabled,
      );
      isar.write((_) => isar.cronJobs.put(job));
      return job;
    }

    Future<void> startDueRun({
      required Completer<void> gate,
      CronRunResult result = const CronRunResult(exitCode: 0, output: 'ok'),
    }) async {
      scheduler = CronSchedulerService(
        isar: isar,
        clock: () => now,
        runner: (_) async {
          await gate.future;
          return result;
        },
      );
      await scheduler.tick(); // seed next run
      now = DateTime(2026, 10, 12, 8, 31);
      await scheduler.tick(); // fire
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.isRunning(1), isTrue);
    }

    test(
      'preserves edits made while a run is in flight',
      () async {
        seedJob();
        final gate = Completer<void>();
        await startDueRun(gate: gate);

        // Edit non-run fields while the run is in progress.
        final edited = isar.cronJobs.get(1)!;
        edited
          ..name = 'edited-name'
          ..schedule = '*/5 * * * *'
          ..command = 'echo edited'
          ..workingDir = '/tmp/edited'
          ..enabled = false;
        isar.write((_) => isar.cronJobs.put(edited));

        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final stored = isar.cronJobs.get(1);
        expect(stored, isNotNull);
        expect(stored!.name, 'edited-name');
        expect(stored.schedule, '*/5 * * * *');
        expect(stored.command, 'echo edited');
        expect(stored.workingDir, '/tmp/edited');
        expect(stored.enabled, isFalse);
        expect(stored.lastStatus, 'success');
        expect(stored.lastExitCode, 0);
        expect(stored.lastRunAt, DateTime(2026, 10, 12, 8, 31));
      },
      skip: libraryPath == null ? 'Isar native library not available' : null,
    );

    test(
      'does not resurrect a job deleted between start and finish',
      () async {
        seedJob();
        final gate = Completer<void>();
        await startDueRun(gate: gate);

        isar.write((_) => isar.cronJobs.delete(1));
        expect(isar.cronJobs.get(1), isNull);

        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          isar.cronJobs.get(1),
          isNull,
          reason: 'completing a deleted job must not reinsert a stale snapshot',
        );
      },
      skip: libraryPath == null ? 'Isar native library not available' : null,
    );

    test(
      'retires history when deletion is observed at completion',
      () async {
        seedJob();
        final gate = Completer<void>();
        await startDueRun(gate: gate);
        expect(scheduler.historyFor(1), isNotEmpty);

        // Delete without running another tick so cleanup is observed only when
        // the in-flight run persists its result.
        isar.write((_) => isar.cronJobs.delete(1));

        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          scheduler.historyFor(1),
          isEmpty,
          reason: 'deleted job history must not be retained or repopulated',
        );
      },
      skip: libraryPath == null ? 'Isar native library not available' : null,
    );

    test(
      'does not resurrect or keep history when deleted before start persists',
      () async {
        seedJob();
        final gate = Completer<void>();
        final started = Completer<void>();
        scheduler = CronSchedulerService(
          isar: isar,
          clock: () => now,
          runner: (_) async {
            started.complete();
            await gate.future;
            return const CronRunResult(exitCode: 0, output: 'ok');
          },
        );
        await scheduler.tick();
        now = DateTime(2026, 10, 12, 8, 31);

        // Remove the job after it is loaded as due but before the run persists
        // its "running" state.
        isar.write((_) => isar.cronJobs.delete(1));
        await scheduler.tick();
        await Future<void>.delayed(Duration.zero);

        expect(scheduler.isRunning(1), isFalse);
        expect(started.isCompleted, isFalse);
        expect(isar.cronJobs.get(1), isNull);
        expect(scheduler.historyFor(1), isEmpty);

        // Unblock in case of regression where runner started; should be no-op.
        if (!gate.isCompleted) gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(isar.cronJobs.get(1), isNull);
        expect(scheduler.historyFor(1), isEmpty);
      },
      skip: libraryPath == null ? 'Isar native library not available' : null,
    );

    test(
      'tick retires history for deleted jobs',
      () async {
        seedJob();
        scheduler = CronSchedulerService(
          isar: isar,
          clock: () => now,
          runner: (_) async => const CronRunResult(exitCode: 0, output: 'ok'),
        );

        await scheduler.runNow(isar.cronJobs.get(1)!);
        expect(scheduler.historyFor(1), hasLength(1));

        isar.write((_) => isar.cronJobs.delete(1));
        await scheduler.tick();

        expect(scheduler.historyFor(1), isEmpty);
      },
      skip: libraryPath == null ? 'Isar native library not available' : null,
    );
  });
}
