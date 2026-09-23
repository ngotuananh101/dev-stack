import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sites.validateDomain', () {
    test('accepts a well-formed domain', () {
      expect(Sites.validateDomain('example.test'), 'example.test');
      expect(Sites.validateDomain('my-site.local'), 'my-site.local');
      expect(Sites.validateDomain('a.b.c'), 'a.b.c');
    });

    test('rejects empty and overlong', () {
      expect(() => Sites.validateDomain(''), throwsArgumentError);
      expect(
        () => Sites.validateDomain('a' * 260),
        throwsArgumentError,
      );
    });

    test('rejects path-traversal and separator characters', () {
      expect(() => Sites.validateDomain('../etc'), throwsArgumentError);
      expect(() => Sites.validateDomain('a/b'), throwsArgumentError);
      expect(() => Sites.validateDomain('a\\b'), throwsArgumentError);
    });

    test('rejects domains with dots-only or leading/trailing dash', () {
      expect(() => Sites.validateDomain('..'), throwsArgumentError);
      expect(() => Sites.validateDomain('-bad'), throwsArgumentError);
      expect(() => Sites.validateDomain('bad-'), throwsArgumentError);
    });
  });
}
