import 'dart:io';

import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppInstallerService.buildTarExtractArgs', () {
    test('produces correct arguments with stripComponents: true', () {
      final args = AppInstallerService.buildTarExtractArgs(
        '/tmp/archive.tar.gz',
        '/opt/ponta/apps/nodejs/25.9.0',
        stripComponents: true,
      );
      expect(args, [
        '-xf',
        '/tmp/archive.tar.gz',
        '-C',
        '/opt/ponta/apps/nodejs/25.9.0',
        '--strip-components=1',
      ]);
    });

    test('produces correct arguments with stripComponents: false', () {
      final args = AppInstallerService.buildTarExtractArgs(
        '/tmp/archive.tar.gz',
        '/opt/ponta/apps/nodejs/25.9.0',
        stripComponents: false,
      );
      expect(args, [
        '-xf',
        '/tmp/archive.tar.gz',
        '-C',
        '/opt/ponta/apps/nodejs/25.9.0',
      ]);
    });

    test('defaults stripComponents to false', () {
      final args = AppInstallerService.buildTarExtractArgs(
        'archive.tar.xz',
        '/dest',
      );
      expect(args, ['-xf', 'archive.tar.xz', '-C', '/dest']);
    });
  });

  group('AppInstallerService.isTarArchive', () {
    test('detects all supported tar archive formats', () {
      expect(
        AppInstallerService.isTarArchive('https://example.com/node.tar.gz'),
        isTrue,
      );
      expect(
        AppInstallerService.isTarArchive('https://example.com/node.tar.xz'),
        isTrue,
      );
      expect(
        AppInstallerService.isTarArchive('https://example.com/app.tgz'),
        isTrue,
      );
      expect(
        AppInstallerService.isTarArchive('https://example.com/app.tar.bz2'),
        isTrue,
      );
      expect(
        AppInstallerService.isTarArchive('https://example.com/package.tar'),
        isTrue,
      );
      expect(AppInstallerService.isTarArchive('/local/path/file.tar.gz'), isTrue);
      expect(AppInstallerService.isTarArchive('/local/path/file.tar.xz'), isTrue);
      expect(AppInstallerService.isTarArchive('/local/path/file.tgz'), isTrue);
      expect(AppInstallerService.isTarArchive('/local/path/file.tar.bz2'), isTrue);
      expect(AppInstallerService.isTarArchive('/local/path/file.tar'), isTrue);
    });

    test('handles uppercase and mixed case extensions', () {
      expect(AppInstallerService.isTarArchive('PACKAGE.TAR.GZ'), isTrue);
      expect(AppInstallerService.isTarArchive('App.Tar.Xz'), isTrue);
      expect(AppInstallerService.isTarArchive('archive.TGZ'), isTrue);
      expect(AppInstallerService.isTarArchive('bundle.TAR.BZ2'), isTrue);
      expect(AppInstallerService.isTarArchive('dist.TAR'), isTrue);
    });

    test('handles URLs with query parameters and fragments', () {
      expect(
        AppInstallerService.isTarArchive(
          'https://example.com/node.tar.gz?token=abc&download=1#section',
        ),
        isTrue,
      );
      expect(
        AppInstallerService.isTarArchive(
          'https://example.com/archive.tar.xz?version=2.0',
        ),
        isTrue,
      );
    });

    test('returns false for non-tar archives', () {
      expect(AppInstallerService.isTarArchive('https://example.com/app.zip'), isFalse);
      expect(AppInstallerService.isTarArchive('https://example.com/setup.exe'), isFalse);
      expect(AppInstallerService.isTarArchive('https://example.com/app.dmg'), isFalse);
      expect(AppInstallerService.isTarArchive('https://example.com/app.7z'), isFalse);
      expect(AppInstallerService.isTarArchive('https://example.com/tar.txt'), isFalse);
      expect(AppInstallerService.isTarArchive('https://example.com/avatar.png'), isFalse);
      expect(AppInstallerService.isTarArchive(''), isFalse);
    });

    test('detects actual Node.js URLs from catalog', () {
      const nodeUrl =
          'https://nodejs.org/dist/v25.9.0/node-v25.9.0-linux-x64.tar.gz';
      expect(AppInstallerService.isTarArchive(nodeUrl), isTrue);
    });
  });

  group('AppInstallerService.ensureLinuxPermissions', () {
    test('invokes chmod -R 755 on target path', () async {
      String? executedExecutable;
      List<String>? executedArgs;

      await AppInstallerService.ensureLinuxPermissions(
        '/opt/ponta/apps/nodejs/25.9.0',
        runProcess: (exec, args) async {
          executedExecutable = exec;
          executedArgs = args;
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(executedExecutable, 'chmod');
      expect(executedArgs, ['-R', '755', '/opt/ponta/apps/nodejs/25.9.0']);
    });

    test('gracefully handles chmod failure without throwing', () async {
      await expectLater(
        AppInstallerService.ensureLinuxPermissions(
          '/nonexistent/path',
          runProcess: (exec, args) async {
            throw const ProcessException('chmod', ['-R', '755', '/nonexistent/path'], 'Operation not permitted');
          },
        ),
        completes,
      );
    });
  });
}
