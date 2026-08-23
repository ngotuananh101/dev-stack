import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dev_stack/features/apps/data/app_installer_service.dart';

void main() {
  group('resolveDbTool', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('dbinit_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('prefers the .exe variant when present (Windows layout)', () {
      Directory(p.join(tmp.path, 'bin')).createSync();
      File(p.join(tmp.path, 'bin', 'initdb.exe')).writeAsStringSync('');
      final got = AppInstallerService.resolveDbTool(tmp.path, 'initdb');
      expect(got, endsWith('initdb.exe'));
      expect(File(got).existsSync(), isTrue);
    });

    test('falls back to the extensionless ELF (Linux layout)', () {
      Directory(p.join(tmp.path, 'bin')).createSync();
      File(p.join(tmp.path, 'bin', 'initdb')).writeAsStringSync('');
      final got = AppInstallerService.resolveDbTool(tmp.path, 'initdb');
      expect(p.basename(got), equals('initdb'));
    });
  });
}
