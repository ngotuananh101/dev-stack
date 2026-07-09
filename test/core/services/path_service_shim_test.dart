import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService shim helpers', () {
    test('shimPathsFor returns bat, cmd, and extensionless paths', () {
      final paths = PathService.shimPathsFor(r'C:\Ponta\bin', 'node');

      expect(paths, [
        r'C:\Ponta\bin\node.bat',
        r'C:\Ponta\bin\node.cmd',
        r'C:\Ponta\bin\node',
      ]);
    });

    test('windowsBatchShimContent forwards args and exit code', () {
      final content = PathService.windowsBatchShimContent(
        r'C:\Ponta\apps\nodejs\node.exe',
      );

      expect(content, contains('@echo off'));
      expect(content, contains(r'"C:\Ponta\apps\nodejs\node.exe" %*'));
      expect(content, contains('exit /b %ERRORLEVEL%'));
    });

    test('shellShimContent uses Windows slash path and execs args', () {
      final content = PathService.shellShimContent(
        r'C:\Ponta\apps\nodejs\node.exe',
      );

      expect(content, startsWith('#!/usr/bin/env sh\n'));
      expect(content, isNot(contains('\r\n')));
      expect(content, contains("target='C:/Ponta/apps/nodejs/node.exe'"));
      expect(content, contains(r'target="/mnt/$drive/$rest"'));
      expect(content, contains(r'exec "$target" "$@"'));
    });

    test('shellShimContent runs cmd targets through cmd.exe on WSL', () {
      final content = PathService.shellShimContent(
        r'C:\Ponta\apps\nodejs\npm.CMD',
      );

      expect(
        content,
        contains("windows_target='C:/Ponta/apps/nodejs/npm.CMD'"),
      );
      expect(
        content,
        contains(r'*.cmd|*.bat) exec cmd.exe /c "$windows_target" "$@" ;;'),
      );
    });

    test('shim content is distinct per shell family', () {
      final target = r'C:\Ponta\apps\php\php.exe';
      final windowsContent = PathService.windowsBatchShimContent(target);
      final shellContent = PathService.shellShimContent(target);

      expect(windowsContent, contains('%*'));
      expect(shellContent, contains(r'"$@"'));
      expect(windowsContent, isNot(equals(shellContent)));
    });

    test('shimPathsFor covers remove targets for every generated shim', () {
      final paths = PathService.shimPathsFor(r'C:\Ponta\bin', 'composer');

      expect(paths.map((path) => path.split('\\').last), [
        'composer.bat',
        'composer.cmd',
        'composer',
      ]);
    });
  });
}
