import 'dart:io';
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PathService Linux profile helpers', () {
    test('linuxProfileExportLine formats export PATH command correctly', () {
      expect(
        PathService.linuxProfileExportLine('/home/user/.ponta/bin'),
        equals(r'export PATH="/home/user/.ponta/bin:$PATH"'),
      );
      expect(
        PathService.linuxProfileExportLine('/opt/ponta/bin'),
        equals(r'export PATH="/opt/ponta/bin:$PATH"'),
      );
    });

    test('isBinInProfileContent detects binDir presence and handles comments', () {
      const binDir = '/home/user/.ponta/bin';

      expect(PathService.isBinInProfileContent('', binDir), isFalse);
      expect(
        PathService.isBinInProfileContent(
          r'export PATH="/usr/local/bin:$PATH"' '\n',
          binDir,
        ),
        isFalse,
      );
      expect(
        PathService.isBinInProfileContent(
          r'# export PATH="/home/user/.ponta/bin:$PATH"' '\n',
          binDir,
        ),
        isFalse,
      );
      expect(
        PathService.isBinInProfileContent(
          r'export PATH="/home/user/.ponta/bin:$PATH"' '\n',
          binDir,
        ),
        isTrue,
      );
      expect(
        PathService.isBinInProfileContent(
          r'some_command' '\n' r'PATH="$PATH:/home/user/.ponta/bin"' '\n',
          binDir,
        ),
        isTrue,
      );
    });

    test('linuxShellProfilePaths returns standard profile list', () {
      final paths = PathService.linuxShellProfilePaths('/home/testuser');
      expect(paths, [
        p.join('/home/testuser', '.bashrc'),
        p.join('/home/testuser', '.zshrc'),
        p.join('/home/testuser', '.profile'),
      ]);
    });
  });

  group('PathService.shimPathsFor Linux vs Windows', () {
    test('returns single binary path on Linux', () {
      final paths = PathService.shimPathsFor(
        '/home/user/.ponta/bin',
        'node',
        isLinux: true,
      );
      expect(paths, equals([p.join('/home/user/.ponta/bin', 'node')]));
    });

    test('returns bat, cmd, and extensionless paths on Windows', () {
      final paths = PathService.shimPathsFor(
        r'C:\Ponta\bin',
        'node',
        isLinux: false,
      );
      expect(paths, equals([
        p.join(r'C:\Ponta\bin', 'node.bat'),
        p.join(r'C:\Ponta\bin', 'node.cmd'),
        p.join(r'C:\Ponta\bin', 'node'),
      ]));
    });
  });

  group('PathService Linux profile update and symlinks', () {
    late Directory tempDir;
    late PathService pathService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ponta_path_linux_test_');
      pathService = PathService(LogService());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('ensureLinuxProfilePath appends export line to existing profiles', () async {
      final bashrc = File(p.join(tempDir.path, '.bashrc'));
      await bashrc.writeAsString('# bashrc header\nalias ll="ls -la"\n');

      final zshrc = File(p.join(tempDir.path, '.zshrc'));
      await zshrc.writeAsString('# zshrc header\n');

      const testBinDir = '/home/test/.ponta/bin';
      await pathService.ensureLinuxProfilePath(
        homeDir: tempDir.path,
        binDirOverride: testBinDir,
      );

      final updatedBashrc = await bashrc.readAsString();
      expect(
        updatedBashrc,
        contains('export PATH="/home/test/.ponta/bin:\$PATH"'),
      );

      final updatedZshrc = await zshrc.readAsString();
      expect(
        updatedZshrc,
        contains('export PATH="/home/test/.ponta/bin:\$PATH"'),
      );

      // Re-running should not duplicate the line
      await pathService.ensureLinuxProfilePath(
        homeDir: tempDir.path,
        binDirOverride: testBinDir,
      );
      final count = RegExp(
        RegExp.escape('export PATH="/home/test/.ponta/bin:\$PATH"'),
      ).allMatches(await bashrc.readAsString()).length;
      expect(count, equals(1));
    });

    test('ensureLinuxProfilePath creates .profile if no profiles exist', () async {
      const testBinDir = '/home/test/.ponta/bin';
      await pathService.ensureLinuxProfilePath(
        homeDir: tempDir.path,
        binDirOverride: testBinDir,
      );

      final profile = File(p.join(tempDir.path, '.profile'));
      expect(profile.existsSync(), isTrue);
      expect(
        await profile.readAsString(),
        equals('export PATH="/home/test/.ponta/bin:\$PATH"\n'),
      );
    });

    test('createLinuxSymlinkOrShim creates a link or fallback wrapper file', () async {
      final binDir = Directory(p.join(tempDir.path, 'bin'))..createSync(recursive: true);
      final targetFile = File(p.join(tempDir.path, 'node'))..writeAsStringSync('binary content');

      await PathService.createLinuxSymlinkOrShim(
        binDir.path,
        'node',
        targetFile.path,
      );

      final createdPath = p.join(binDir.path, 'node');
      final type = FileSystemEntity.typeSync(createdPath, followLinks: false);
      expect(
        type == FileSystemEntityType.link || type == FileSystemEntityType.file,
        isTrue,
      );
    });
  });
}
