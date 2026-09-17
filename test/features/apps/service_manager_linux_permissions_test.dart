import 'dart:io';

import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_service_manager.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ponta_svc_perm_test_');
    AppConfig.initialize(baseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AppServiceManager Linux executable permissions pre-flight check', () {
    test('enforces chmod u+x before starting service on Linux', () async {
      final binFile = File(p.join(tempDir.path, 'nginx'))..createSync();
      final recorded = <List<String>>[];

      final manager = AppServiceManager(
        AppLogger,
        platformIsLinux: () => true,
        runProcess: (exec, args) async {
          recorded.add([exec, ...args]);
          return <String>[];
        },
      );

      final app = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        categories: const ['Web Server'],
        status: 'installed',
        installedVersion: '1.25.0',
        execFilePath: binFile.path,
      );

      try {
        await manager.start(app);
      } catch (_) {
        // Process spawning might fail on dummy file; we are asserting the preflight check.
      }

      final chmodCalls = recorded.where((call) => call.first == 'chmod').toList();
      expect(chmodCalls, isNotEmpty);
      expect(chmodCalls.first, equals(['chmod', 'u+x', binFile.path]));
    });

    test('skips chmod u+x pre-flight check on non-Linux platforms', () async {
      final binFile = File(p.join(tempDir.path, 'nginx'))..createSync();
      final recorded = <List<String>>[];

      final manager = AppServiceManager(
        AppLogger,
        platformIsLinux: () => false,
        runProcess: (exec, args) async {
          recorded.add([exec, ...args]);
          return <String>[];
        },
      );

      final app = AppModel(
        appId: 'nginx',
        name: 'Nginx',
        categories: const ['Web Server'],
        status: 'installed',
        installedVersion: '1.25.0',
        execFilePath: binFile.path,
      );

      try {
        await manager.start(app);
      } catch (_) {
        // Process spawning might fail on dummy file; we are asserting the preflight check.
      }

      final chmodCalls = recorded.where((call) => call.first == 'chmod').toList();
      expect(chmodCalls, isEmpty);
    });
  });
}
