// test/features/settings/settings_default_basedir_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_stack/core/config/app_config.dart';
import 'package:dev_stack/features/settings/domain/app_settings.dart';

void main() {
  group('Default baseDir assignment', () {
    test('defaultBaseDir matches platform expectation', () {
      final expected = AppConfig.defaultBaseDir;
      expect(expected.isNotEmpty, isTrue);
    });

    test('initial settings factory uses dynamic platform default', () {
      final settings = AppSettings()..baseDir = AppConfig.defaultBaseDir;
      expect(settings.baseDir, equals(AppConfig.defaultBaseDir));
    });
  });
}
