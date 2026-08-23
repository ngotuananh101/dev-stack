// test/features/system/system_info_os_label_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/system/data/system_info_provider.dart';

void main() {
  group('collectPlatformInfo', () {
    test('labels Windows and requests systeminfo', () async {
      String? ran;
      final r = await SystemInfoNotifier.collectPlatformInfo(
        isWindows: true,
        run: (exe, args) async {
          ran = exe;
          return ProcessResult(0, 0, 'win-output', '');
        },
      );
      expect(ran, equals('systeminfo'));
      expect(r.rawOutput, equals('win-output'));
      expect(r.frameworkLabel, equals('Flutter (Windows)'));
    });

    test('falls back to uname -a on Linux', () async {
      String? ran;
      final r = await SystemInfoNotifier.collectPlatformInfo(
        isWindows: false,
        run: (exe, args) async {
          ran = exe;
          return ProcessResult(0, 0, 'Linux box 6.8.0 x86_64', '');
        },
      );
      expect(ran, equals('uname'));
      expect(r.rawOutput, contains('6.8.0'));
      expect(r.frameworkLabel, equals('Flutter (Linux)'));
    });
  });
}
