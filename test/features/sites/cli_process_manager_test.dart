import 'dart:io';
import 'package:dev_stack/features/sites/data/cli_process_manager.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CliProcessManager', () {
    late CliProcessManager manager;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cli_test_');
      manager = CliProcessManager(logsDirectory: tempDir.path);
    });

    tearDown(() async {
      await manager.stopAll();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initial state has no running processes', () {
      expect(manager.isSiteRunning(1), isFalse);
      expect(manager.getSitePid(1), isNull);
      expect(manager.getLogBuffer(1), isEmpty);
    });

    test('startSite runs command and records stdout', () async {
      final site = SiteModel(
        id: 42,
        domain: 'test-app.test',
        rootDir: tempDir.path,
        siteType: 'cli',
        command: Platform.isWindows ? 'echo Hello CLI Test' : 'echo "Hello CLI Test"',
        port: 3000,
      );

      final started = await manager.startSite(site);
      expect(started, isTrue);

      // Wait a moment for output to flush
      await Future.delayed(const Duration(milliseconds: 300));

      final logs = manager.getLogBuffer(42);
      expect(logs.any((l) => l.contains('Hello CLI Test')), isTrue);
    });

    test('circular buffer caps at 1000 lines', () {
      final buffer = CircularLogBuffer(maxLines: 5);
      for (var i = 0; i < 10; i++) {
        buffer.add('Line $i');
      }

      final lines = buffer.lines;
      expect(lines.length, 5);
      expect(lines.first, 'Line 5');
      expect(lines.last, 'Line 9');
    });

    test('stopSite terminates process cleanly', () async {
      final site = SiteModel(
        id: 99,
        domain: 'sleeper.test',
        rootDir: tempDir.path,
        siteType: 'cli',
        command: Platform.isWindows ? 'ping 127.0.0.1 -n 10' : 'sleep 10',
        port: 8080,
      );

      await manager.startSite(site);
      expect(manager.isSiteRunning(99), isTrue);

      final stopped = await manager.stopSite(99);
      expect(stopped, isTrue);
      expect(manager.isSiteRunning(99), isFalse);
    });
  });
}
