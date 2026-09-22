import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sites.validateRootDir', () {
    test('accepts plain Windows paths', () {
      expect(
        Sites.validateRootDir(r'C:\Projects\my-site'),
        r'C:\Projects\my-site',
      );
      expect(Sites.validateRootDir('D:/web/site'), 'D:/web/site');
    });

    test('rejects a double-quote that would break out of the directive', () {
      expect(
        () => Sites.validateRootDir(
          r'C:\x" \n location /secrets { alias /; \n #',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects newlines and control characters', () {
      expect(
        () => Sites.validateRootDir('C:\\x\nbad'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Sites.validateRootDir('C:\\x\rbad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty path', () {
      expect(
        () => Sites.validateRootDir(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects overlong path', () {
      expect(
        () => Sites.validateRootDir('C:\\${'a' * 300}'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
