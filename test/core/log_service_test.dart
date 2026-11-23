import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LogService.logsOlderThan', () {
    test('keeps files within the retention window', () {
      final today = DateTime(2026, 8, 13);
      final recent = [
        DateTime(2026, 8, 13),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 1),
      ];
      final stale = LogService.logsOlderThan(
        recent,
        today: today,
        retentionDays: 30,
      );
      expect(stale, isEmpty);
    });

    test('flags files older than the retention window', () {
      final today = DateTime(2026, 8, 13);
      final dates = [
        DateTime(2026, 8, 13), // today — keep
        DateTime(2026, 7, 13), // exactly 31 days — stale
        DateTime(2026, 6, 1), // older — stale
      ];
      final stale = LogService.logsOlderThan(
        dates,
        today: today,
        retentionDays: 30,
      );
      expect(stale.length, 2);
      expect(stale, contains(DateTime(2026, 7, 13)));
      expect(stale, contains(DateTime(2026, 6, 1)));
    });
  });

  group('LogService retention scan throttling', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('log_service_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File staleLogFile() => File(p.join(tempDir.path, '2020-01-01.log'));

    test('first write prunes stale logs', () async {
      staleLogFile().writeAsStringSync('old');
      var now = DateTime(2026, 8, 13, 10);
      final service = LogService(logDir: tempDir.path, now: () => now);

      await service.info('first');

      expect(staleLogFile().existsSync(), isFalse);
      expect(File(p.join(tempDir.path, '2026-08-13.log')).existsSync(), isTrue);
    });

    test(
      'adjacent writes skip rescanning and next eligible window prunes',
      () async {
        staleLogFile().writeAsStringSync('old');
        var now = DateTime(2026, 8, 13, 10);
        final service = LogService(logDir: tempDir.path, now: () => now);

        await service.info('first');
        expect(
          staleLogFile().existsSync(),
          isFalse,
          reason: 'first write must still prune',
        );

        staleLogFile().writeAsStringSync('old again');
        expect(staleLogFile().existsSync(), isTrue);

        now = DateTime(2026, 8, 13, 11);
        await service.info('second');
        expect(
          staleLogFile().existsSync(),
          isTrue,
          reason: 'adjacent write in same window must skip retention scan',
        );

        now = DateTime(2026, 8, 14, 9);
        await service.info('third');
        expect(
          staleLogFile().existsSync(),
          isFalse,
          reason: 'next eligible window must prune stale logs',
        );
      },
    );

    test(
      'default directory follows config changes and prunes the new path',
      () async {
        final originalBaseDir = AppConfig.baseDir;
        addTearDown(() => AppConfig.initialize(baseDir: originalBaseDir));
        AppConfig.initialize(baseDir: p.join(tempDir.path, 'first'));
        final service = LogService(now: () => DateTime(2026, 8, 13, 10));
        await service.info('first directory');

        AppConfig.initialize(baseDir: p.join(tempDir.path, 'second'));
        final secondLogs = Directory(AppConfig.logsDir)
          ..createSync(recursive: true);
        final stale = File(p.join(secondLogs.path, '2020-01-01.log'))
          ..writeAsStringSync('stale');
        await service.info('second directory');

        expect(stale.existsSync(), isFalse);
        expect(await service.getLogsForDate(DateTime(2026, 8, 13)), [
          contains('second directory'),
        ]);
        expect(
          File(
            p.join(tempDir.path, 'first', 'logs', '2026-08-13.log'),
          ).readAsStringSync(),
          isNot(contains('second directory')),
        );
      },
    );

    test('retains rollover/size cap semantics', () async {
      var now = DateTime(2026, 8, 13, 10);
      final service = LogService(logDir: tempDir.path, now: () => now);
      final logFile = File(p.join(tempDir.path, '2026-08-13.log'));
      logFile.writeAsBytesSync(
        List<int>.filled(LogService.maxLogFileBytes + 1, 65),
      );

      await service.info('after cap');

      expect(logFile.existsSync(), isTrue);
      final content = logFile.readAsStringSync();
      expect(content, contains('after cap'));
      expect(content.length, lessThan(LogService.maxLogFileBytes));
    });
  });
}
