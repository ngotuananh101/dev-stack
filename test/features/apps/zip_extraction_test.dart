import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zip_extract_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  List<int> buildZip(Map<String, String> files) {
    final archive = Archive();
    files.forEach((path, content) {
      final bytes = content.codeUnits;
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });
    return ZipEncoder().encode(archive);
  }

  test('extracts files and reports counts', () {
    final bytes = buildZip({
      'bin/php': 'binary',
      'etc/php.ini': 'memory_limit=512M',
    });

    final summary = AppInstallerService.extractZipToDirectory(bytes, tmp.path);

    expect(summary.fileCount, 2);
    expect(summary.skippedEntries, isEmpty);
    expect(File('${tmp.path}/bin/php').readAsStringSync(), 'binary');
    expect(
      File('${tmp.path}/etc/php.ini').readAsStringSync(),
      'memory_limit=512M',
    );
  });

  test('creates nested directories from directory entries', () {
    final archive = Archive()
      ..addFile(ArchiveFile('empty/dir/', 0, <int>[]));
    final summary = AppInstallerService.extractZipToDirectory(
      ZipEncoder().encode(archive),
      tmp.path,
    );

    expect(summary.directoryCount, 1);
    expect(Directory('${tmp.path}/empty/dir').existsSync(), isTrue);
  });

  test('skips path-traversal entries instead of writing outside the target',
      () {
    final bytes = buildZip({
      'ok.txt': 'fine',
      '../escaped.txt': 'bad',
    });

    final summary = AppInstallerService.extractZipToDirectory(bytes, tmp.path);

    expect(summary.fileCount, 1);
    expect(summary.skippedEntries, contains('../escaped.txt'));
    expect(File('${tmp.path}/../escaped.txt').existsSync(), isFalse);
    expect(File('${tmp.path}/ok.txt').existsSync(), isTrue);
  });
}
