import 'dart:io';

import 'package:dev_stack/features/settings/data/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings.replacePathPrefix', () {
    test('replaces the old prefix when followed by a separator or end', () {
      expect(
        Settings.replacePathPrefix(
          r'C:\Dev\apps\mysql',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevStack\apps\mysql',
      );
      expect(
        Settings.replacePathPrefix(
          r'C:/Dev/apps/mysql',
          r'C:/Dev',
          r'C:/DevStack',
        ),
        r'C:/DevStack/apps/mysql',
      );
    });

    test('replaces when the path equals the prefix exactly', () {
      expect(
        Settings.replacePathPrefix(
          r'C:\Dev',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevStack',
      );
    });

    test('does NOT double-replace when newDir starts with oldDir', () {
      // A path that already contains the NEW dir must not have its prefix
      // re-matched and turned into C:\DevStackStack.
      expect(
        Settings.replacePathPrefix(
          r'C:\DevStack\apps',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevStack\apps',
      );
    });

    test('does NOT touch a sibling path that merely starts with oldDir', () {
      // C:\DevTools is NOT C:\Dev + separator, so it must be left alone.
      expect(
        Settings.replacePathPrefix(
          r'C:\DevTools\bin',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevTools\bin',
      );
    });

    test('replaces multiple occurrences in one string', () {
      expect(
        Settings.replacePathPrefix(
          r'root "C:\Dev\site"; alias "C:\Dev\site2";',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'root "C:\DevStack\site"; alias "C:\DevStack\site2";',
      );
    });
  });

  group('settings migration skips binaries', () {
    test('recognises extensionless executables by name', () {
      expect(Settings.looksLikeBinaryName('php'), isTrue);
      expect(Settings.looksLikeBinaryName('mysqld'), isTrue);
      expect(Settings.looksLikeBinaryName('PHP-FPM'), isTrue);
      expect(Settings.looksLikeBinaryName('php-cgi-ponta-shim'), isFalse);
      expect(Settings.looksLikeBinaryName('mysql-start'), isFalse);
    });

    test('sniffs a NUL byte in the first KB of a file', () async {
      final dir = await Directory.systemTemp.createTemp('settings_bin_test_');
      addTearDown(() => dir.delete(recursive: true));

      final text = File('${dir.path}/shim')
        ..writeAsStringSync('#!/bin/sh\nexec /old/dir/bin/php "\$@"\n');
      final binary = File('${dir.path}/elf')..writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46, 0x00, 0x01]);

      expect(await Settings.looksLikeBinaryFile(text), isFalse,
          reason: 'plain shell shims must still be rewritten');
      expect(await Settings.looksLikeBinaryFile(binary), isTrue);
    });
  });
}
