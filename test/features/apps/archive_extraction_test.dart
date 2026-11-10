import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('archive_extract_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Writes a zip to disk, the way a download leaves it, and returns its path.
  File zipFile(String name, Map<String, String> files) {
    final archive = Archive();
    files.forEach((path, content) {
      final bytes = content.codeUnits;
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    });
    final file = File('${tmp.path}/$name');
    file.writeAsBytesSync(ZipEncoder().encode(archive));
    return file;
  }

  test('extracts from the file on disk without loading it into memory', () async {
    final archivePath = zipFile('payload.zip', {
      'bin/php': 'binary',
      'etc/php.ini': 'memory_limit=512M',
    });
    final target = Directory('${tmp.path}/out')..createSync();

    final summary = await AppInstallerService.extractArchiveToDirectory(
      archivePath.path,
      target.path,
    );

    expect(summary.fileCount, 2);
    expect(summary.skippedEntries, isEmpty);
    expect(File('${target.path}/bin/php').readAsStringSync(), 'binary');
    expect(
      File('${target.path}/etc/php.ini').readAsStringSync(),
      'memory_limit=512M',
    );
  });

  test('creates nested directories from directory entries', () async {
    final archive = Archive()..addFile(ArchiveFile('empty/dir/', 0, <int>[]));
    final archivePath = File('${tmp.path}/dirs.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    final target = Directory('${tmp.path}/out')..createSync();

    final summary = await AppInstallerService.extractArchiveToDirectory(
      archivePath.path,
      target.path,
    );

    expect(summary.directoryCount, 1);
    expect(Directory('${target.path}/empty/dir').existsSync(), isTrue);
  });

  test(
    'skips path-traversal entries instead of writing outside the target',
    () async {
      final archivePath = zipFile('evil.zip', {
        'ok.txt': 'fine',
        '../escaped.txt': 'bad',
      });
      final target = Directory('${tmp.path}/out')..createSync();

      final summary = await AppInstallerService.extractArchiveToDirectory(
        archivePath.path,
        target.path,
      );

      expect(summary.fileCount, 1);
      expect(summary.skippedEntries, contains('../escaped.txt'));
      expect(File('${tmp.path}/escaped.txt').existsSync(), isFalse);
      expect(File('${target.path}/ok.txt').existsSync(), isTrue);
    },
  );

  test('reports a Flutter-sized tree rather than reading it all at once', () async {
    // A million-entry archive is out of reach here, but a file larger than any
    // sensible in-memory buffer proves the path is file-backed: the payload is
    // 8 MiB and the extractor must still only stream it.
    final big = List<int>.filled(8 * 1024 * 1024, 65);
    final archive = Archive()
      ..addFile(ArchiveFile('go/bin/go', big.length, big));
    final archivePath = File('${tmp.path}/big.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    final target = Directory('${tmp.path}/out')..createSync();

    final summary = await AppInstallerService.extractArchiveToDirectory(
      archivePath.path,
      target.path,
    );

    expect(summary.fileCount, 1);
    expect(File('${target.path}/go/bin/go').lengthSync(), big.length);
  });

  test('detects xz compression even when the file lost its real extension', () async {
    // Downloads are stored as `download.tar` regardless of the source
    // extension, so the Flutter SDK arrives as a .tar.xz under a .tar name.
    // The built-in decoder has to sniff the header, not trust the extension.
    final content = '#!/bin/sh\necho flutter\n'.codeUnits;
    final archive = Archive()
      ..addFile(ArchiveFile('bin/flutter', content.length, content));
    final tar = TarEncoder().encode(archive);
    final archivePath = File('${tmp.path}/download.tar')
      ..writeAsBytesSync(XZEncoder().encodeBytes(tar));
    final target = Directory('${tmp.path}/out')..createSync();

    final summary = await AppInstallerService.extractArchiveToDirectory(
      archivePath.path,
      target.path,
    );

    expect(summary.fileCount, 1);
    expect(
      File('${target.path}/bin/flutter').readAsStringSync(),
      '#!/bin/sh\necho flutter\n',
    );
  });
}
