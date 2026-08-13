import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesNotifier.validateRootDir', () {
    test('accepts plain Windows paths', () {
      expect(
        SitesNotifier.validateRootDir(r'C:\Projects\my-site'),
        r'C:\Projects\my-site',
      );
      expect(SitesNotifier.validateRootDir('D:/web/site'), 'D:/web/site');
    });

    test('rejects a double-quote that would break out of the directive', () {
      expect(
        () => SitesNotifier.validateRootDir(
          r'C:\x" \n location /secrets { alias /; \n #',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects newlines and control characters', () {
      expect(
        () => SitesNotifier.validateRootDir('C:\\x\nbad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SitesNotifier.validateRootDir('C:\\x\rbad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty path', () {
      expect(
        () => SitesNotifier.validateRootDir(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects overlong path', () {
      expect(
        () => SitesNotifier.validateRootDir('C:\\${'a' * 300}'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
