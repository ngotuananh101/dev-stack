import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInstallerService.isSafeTarEntry', () {
    test('allows safe relative entry paths', () {
      expect(AppInstallerService.isSafeTarEntry('bin/nginx'), isTrue);
      expect(AppInstallerService.isSafeTarEntry('conf/nginx.conf'), isTrue);
      expect(AppInstallerService.isSafeTarEntry('./nginx'), isTrue);
      expect(AppInstallerService.isSafeTarEntry('lib/x86_64/libssl.so'), isTrue);
      expect(AppInstallerService.isSafeTarEntry('app.exe'), isTrue);
      expect(AppInstallerService.isSafeTarEntry(r'bin\app.exe'), isTrue);
      expect(AppInstallerService.isSafeTarEntry('a/b/c/d/e.txt'), isTrue);
    });

    test('rejects empty or whitespace entry paths', () {
      expect(AppInstallerService.isSafeTarEntry(''), isFalse);
      expect(AppInstallerService.isSafeTarEntry('   '), isFalse);
      expect(AppInstallerService.isSafeTarEntry('\t\n'), isFalse);
    });

    test('rejects absolute paths with leading slash or backslash', () {
      expect(AppInstallerService.isSafeTarEntry('/etc/passwd'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('/bin/sh'), isFalse);
      expect(AppInstallerService.isSafeTarEntry(r'\Windows\System32\cmd.exe'), isFalse);
      expect(AppInstallerService.isSafeTarEntry(r'\Users\Admin'), isFalse);
    });

    test('rejects drive letter paths', () {
      expect(AppInstallerService.isSafeTarEntry('C:/Windows/System32'), isFalse);
      expect(AppInstallerService.isSafeTarEntry(r'C:\Windows\System32'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('D:app.exe'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('c:/foo'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('Z:/evil'), isFalse);
    });

    test('rejects traversal paths containing parent directory segment (..)', () {
      expect(AppInstallerService.isSafeTarEntry('../evil.sh'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('../../etc/shadow'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('foo/../../bar'), isFalse);
      expect(AppInstallerService.isSafeTarEntry(r'..\evil.bat'), isFalse);
      expect(AppInstallerService.isSafeTarEntry(r'foo\..\..\bar'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('foo/bar/../..'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('foo/bar/..'), isFalse);
      expect(AppInstallerService.isSafeTarEntry('..'), isFalse);
    });
  });

  group('AppInstallerService.validateTarEntries', () {
    test('returns true when all entries are safe', () {
      final entries = ['bin/node', 'lib/node_modules/npm', 'include/node/node.h'];
      expect(AppInstallerService.validateTarEntries(entries), isTrue);
    });

    test('returns false when any entry is unsafe', () {
      final entries = ['bin/node', '../../etc/passwd', 'lib/node_modules/npm'];
      expect(AppInstallerService.validateTarEntries(entries), isFalse);
    });

    test('returns false for empty list', () {
      expect(AppInstallerService.validateTarEntries([]), isFalse);
    });
  });

  group('AppInstallerService tar archive inspection and extraction validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tar_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('listTarEntries returns entry paths for valid tar', () async {
      File('${tempDir.path}/hello.txt').writeAsStringSync('hello');
      final tarFile = File('${tempDir.path}/test.tar');
      final proc = await Process.run('tar', ['-cf', tarFile.path, '-C', tempDir.path, 'hello.txt']);
      expect(proc.exitCode, 0);

      final entries = await AppInstallerService.listTarEntries(tarFile.path);
      expect(entries.contains('hello.txt'), isTrue);
      expect(AppInstallerService.validateTarEntries(entries), isTrue);
    });

    test('validates unsafe archive containing path traversal entries', () async {
      // Create a tar archive with an unsafe path using Archive library
      final archive = Archive();
      archive.addFile(ArchiveFile('../../evil.txt', 4, [1, 2, 3, 4]));
      final tarBytes = TarEncoder().encode(archive);
      final tarFile = File('${tempDir.path}/evil.tar')..writeAsBytesSync(tarBytes);

      final entries = await AppInstallerService.listTarEntries(tarFile.path);
      expect(entries.any((e) => e.contains('..')), isTrue);
      expect(AppInstallerService.validateTarEntries(entries), isFalse);
    });

    test('installFromTar rejects archive with path traversal and throws Security error', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('../../evil.txt', 4, [1, 2, 3, 4]));
      final tarBytes = TarEncoder().encode(archive);
      final tarFile = File('${tempDir.path}/evil.tar')..writeAsBytesSync(tarBytes);

      final service = AppInstallerService(LogService(), _FakeRef());
      final app = AppModel(
        appId: 'test_node',
        name: 'NodeJS Test',
        categories: ['runtime'],
        description: 'Test node',
      );

      final destDir = Directory('${tempDir.path}/dest');

      expect(
        () => service.installFromTarForTesting(
          app: app,
          tempFile: tarFile,
          installPath: destDir.path,
          logInfo: (_) {},
          logError: (_) {},
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Security error') &&
              e.toString().contains('path traversal attempt')),
        ),
      );
    });
  });
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

