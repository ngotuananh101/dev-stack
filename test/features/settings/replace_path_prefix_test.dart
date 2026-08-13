import 'package:dev_stack/features/settings/data/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsNotifier.replacePathPrefix', () {
    test('replaces the old prefix when followed by a separator or end', () {
      expect(
        SettingsNotifier.replacePathPrefix(
          r'C:\Dev\apps\mysql',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevStack\apps\mysql',
      );
      expect(
        SettingsNotifier.replacePathPrefix(
          r'C:/Dev/apps/mysql',
          r'C:/Dev',
          r'C:/DevStack',
        ),
        r'C:/DevStack/apps/mysql',
      );
    });

    test('replaces when the path equals the prefix exactly', () {
      expect(
        SettingsNotifier.replacePathPrefix(
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
        SettingsNotifier.replacePathPrefix(
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
        SettingsNotifier.replacePathPrefix(
          r'C:\DevTools\bin',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'C:\DevTools\bin',
      );
    });

    test('replaces multiple occurrences in one string', () {
      expect(
        SettingsNotifier.replacePathPrefix(
          r'root "C:\Dev\site"; alias "C:\Dev\site2";',
          r'C:\Dev',
          r'C:\DevStack',
        ),
        r'root "C:\DevStack\site"; alias "C:\DevStack\site2";',
      );
    });
  });
}
