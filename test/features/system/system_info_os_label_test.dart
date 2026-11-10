// test/features/system/system_info_os_label_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/features/system/data/linux_system_probe.dart';
import 'package:dev_stack/features/system/data/system_info_provider.dart';

void main() {
  group('collectPlatformInfo', () {
    test('labels Windows and requests systeminfo', () async {
      String? ran;
      final r = await SystemInfoState.collectPlatformInfo(
        isWindows: true,
        run: (exe, args) async {
          ran = exe;
          return ProcessResult(0, 0, 'win-output', '');
        },
      );
      expect(ran, equals('systeminfo'));
      expect(r.rawOutput, equals('win-output'));
      expect(r.operatingSystem, equals('Windows'));
    });

    test('asks the probe for its structured report on Linux', () async {
      final probe = LinuxSystemProbe(
        run: (exe, args) async => switch (exe) {
          'uname' => '6.17.8',
          _ => null,
        },
        readFile: (path) => null,
        environment: const {},
      );

      final r = await SystemInfoState.collectPlatformInfo(
        isWindows: false,
        linuxProbe: probe,
      );

      expect(r.rawOutput, contains('[OS]'));
      expect(r.rawOutput, contains('6.17.8'));
      expect(r.operatingSystem, equals('Linux'));
    });
  });

  group('collectRawOutput', () {
    test('Windows keeps the verbatim systeminfo dump', () async {
      final raw = await SystemInfoState.collectRawOutput(
        isWindows: true,
        run: (exe, args) async => ProcessResult(0, 0, 'Host Name: PONTA\n', ''),
      );

      expect(raw, equals('Host Name: PONTA\n'));
    });

    test('Linux asks the probe for its structured report', () async {
      final probe = LinuxSystemProbe(
        run: (exe, args) async => null,
        readFile: (path) => path == '/etc/os-release'
            ? 'PRETTY_NAME="Fedora Linux 44"\n'
            : null,
        environment: const {},
      );

      final raw = await SystemInfoState.collectRawOutput(
        isWindows: false,
        linuxProbe: probe,
      );

      expect(raw, contains('[OS]'));
      expect(raw, contains('Fedora Linux 44'));
      expect(raw, isNot(contains('uname -a')));
    });
  });
}
