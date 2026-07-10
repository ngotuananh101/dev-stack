import 'package:dev_stack/core/services/path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PathService.shimPathsFor', () {
    test('returns all three shim paths for simple command', () {
      final paths = PathService.shimPathsFor('C:\\Ponta\\bin', 'node');

      expect(paths.length, equals(3));
      expect(paths[0], equals('C:\\Ponta\\bin\\node.bat'));
      expect(paths[1], equals('C:\\Ponta\\bin\\node.cmd'));
      expect(paths[2], equals('C:\\Ponta\\bin\\node'));
    });

    test('handles command names with hyphens', () {
      final paths = PathService.shimPathsFor('C:\\Ponta\\bin', 'php-cgi');

      expect(paths[0], equals('C:\\Ponta\\bin\\php-cgi.bat'));
      expect(paths[1], equals('C:\\Ponta\\bin\\php-cgi.cmd'));
      expect(paths[2], equals('C:\\Ponta\\bin\\php-cgi'));
    });

    test('handles paths with spaces', () {
      final paths = PathService.shimPathsFor('C:\\Program Files\\bin', 'tool');

      expect(paths[0], equals('C:\\Program Files\\bin\\tool.bat'));
      expect(paths[1], equals('C:\\Program Files\\bin\\tool.cmd'));
      expect(paths[2], equals('C:\\Program Files\\bin\\tool'));
    });

    test('handles forward slash paths', () {
      final paths = PathService.shimPathsFor('C:/Ponta/bin', 'npm');

      // path.join normalizes to backslashes on Windows
      expect(paths[0], contains('npm.bat'));
      expect(paths[1], contains('npm.cmd'));
      expect(paths[2], endsWith('npm'));
    });

    test('handles empty bin directory', () {
      final paths = PathService.shimPathsFor('', 'cmd');

      expect(paths.length, equals(3));
      expect(paths[0], equals('cmd.bat'));
      expect(paths[1], equals('cmd.cmd'));
      expect(paths[2], equals('cmd'));
    });
  });

  group('PathService.windowsBatchShimContent', () {
    test('generates valid batch script with echo off', () {
      final content =
          PathService.windowsBatchShimContent('C:\\Apps\\node\\node.exe');

      expect(content, startsWith('@echo off'));
      expect(content, contains('"C:\\Apps\\node\\node.exe" %*'));
      expect(content, endsWith('exit /b %ERRORLEVEL%\r\n'));
    });

    test('uses CRLF line endings for Windows compatibility', () {
      final content = PathService.windowsBatchShimContent('C:\\test.exe');

      expect(content, contains('\r\n'));
      expect(content.split('\r\n').length, greaterThan(1));
    });

    test('preserves exit code with ERRORLEVEL', () {
      final content = PathService.windowsBatchShimContent('C:\\tool.exe');

      expect(content, contains('exit /b %ERRORLEVEL%'));
    });

    test('forwards all arguments with %*', () {
      final content = PathService.windowsBatchShimContent('C:\\app.exe');

      expect(content, contains('%*'));
    });

    test('quotes target path to handle spaces', () {
      final content = PathService.windowsBatchShimContent(
          'C:\\Program Files\\app\\tool.exe');

      expect(content, contains('"C:\\Program Files\\app\\tool.exe"'));
    });

    test('handles paths with forward slashes', () {
      final content = PathService.windowsBatchShimContent('C:/Apps/node.exe');

      expect(content, contains('"C:/Apps/node.exe"'));
    });
  });

  group('PathService.shellSingleQuote', () {
    test('quotes simple string', () {
      final result = PathService.shellSingleQuote('hello');

      expect(result, equals("'hello'"));
    });

    test('escapes single quote in string', () {
      final result = PathService.shellSingleQuote("it's");

      expect(result, equals("'it'\\''s'"));
    });

    test('escapes multiple single quotes', () {
      final result = PathService.shellSingleQuote("don't can't");

      expect(result, equals("'don'\\''t can'\\''t'"));
    });

    test('handles string with only single quote', () {
      final result = PathService.shellSingleQuote("'");

      expect(result, equals("''\\'''"));
    });

    test('handles empty string', () {
      final result = PathService.shellSingleQuote('');

      expect(result, equals("''"));
    });

    test('handles string with spaces', () {
      final result = PathService.shellSingleQuote('hello world');

      expect(result, equals("'hello world'"));
    });

    test('preserves special characters except single quote', () {
      final result = PathService.shellSingleQuote(r'$HOME/bin/*.sh');

      expect(result, equals(r"'$HOME/bin/*.sh'"));
    });

    test('handles backslashes', () {
      final result = PathService.shellSingleQuote(r'C:\Program Files\app');

      expect(result, equals(r"'C:\Program Files\app'"));
    });

    test('handles consecutive single quotes', () {
      final result = PathService.shellSingleQuote("''");

      expect(result, equals("''\\'''\\'''"));
    });
  });

  group('PathService.shellShimContent', () {
    test('starts with shebang for portability', () {
      final content = PathService.shellShimContent('C:\\Apps\\node.exe');

      expect(content, startsWith('#!/usr/bin/env sh\n'));
    });

    test('uses LF line endings for Unix compatibility', () {
      final content = PathService.shellShimContent('C:\\test.exe');

      expect(content, contains('\n'));
      expect(content, isNot(contains('\r\n')));
    });

    test('converts backslashes to forward slashes', () {
      final content = PathService.shellShimContent('C:\\Apps\\node\\node.exe');

      expect(content, contains('C:/Apps/node/node.exe'));
      expect(content, isNot(contains('C:\\Apps')));
    });

    test('includes WSL detection logic', () {
      final content = PathService.shellShimContent('C:\\tool.exe');

      expect(content, contains('uname -r'));
      expect(content, contains('*microsoft*|*wsl*'));
    });

    test('includes drive letter conversion for WSL', () {
      final content = PathService.shellShimContent('C:\\Apps\\tool.exe');

      expect(content, contains(r'drive=$('));
      expect(content, contains('cut -c1'));
      expect(content, contains('/mnt/'));
    });

    test('handles .cmd and .bat files in WSL', () {
      final content = PathService.shellShimContent('C:\\Scripts\\build.bat');

      expect(content, contains('*.cmd|*.bat'));
      expect(content, contains('cmd.exe /c'));
    });

    test('quotes path to handle spaces and special chars', () {
      final content =
          PathService.shellShimContent('C:\\Program Files\\app\\tool.exe');

      // Should use shell quoting
      expect(content, contains("'C:/Program Files/app/tool.exe'"));
    });

    test('escapes single quotes in path', () {
      final content = PathService.shellShimContent("C:\\app's\\tool.exe");

      // Single quotes should be escaped as '\''
      expect(content, contains("'\\''"));
    });

    test('forwards all arguments with dollar-at', () {
      final content = PathService.shellShimContent('C:\\tool.exe');

      expect(content, contains(r'"$@"'));
    });

    test('uses exec to replace shell process', () {
      final content = PathService.shellShimContent('C:\\tool.exe');

      expect(content, contains('exec'));
      expect(content, contains(r'exec "$target" "$@"'));
    });

    test('handles path with multiple backslashes', () {
      final content =
          PathService.shellShimContent('C:\\Level1\\Level2\\Level3\\tool.exe');

      expect(content, contains('C:/Level1/Level2/Level3/tool.exe'));
      expect(content, isNot(contains('\\\\')));
    });

    test('generates complete valid shell script', () {
      final content = PathService.shellShimContent('C:\\Apps\\node.exe');

      // Check all major components are present
      expect(content, contains('#!/usr/bin/env sh'));
      expect(content, contains('target='));
      expect(content, contains('windows_target='));
      expect(content, contains(r'case "$(uname -r'));
      expect(content, contains(r'exec "$target" "$@"'));
    });

    test('case-insensitively checks for WSL', () {
      final content = PathService.shellShimContent('C:\\tool.exe');

      expect(content, contains('tr A-Z a-z'));
    });

    test('handles paths starting with different drives', () {
      final contentD = PathService.shellShimContent('D:\\Apps\\tool.exe');
      final contentE = PathService.shellShimContent('E:\\Tools\\app.exe');

      expect(contentD, contains('D:/Apps/tool.exe'));
      expect(contentE, contains('E:/Tools/app.exe'));
    });
  });
}
