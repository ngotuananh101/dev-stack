import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesNotifier.validateDomain', () {
    test('accepts a well-formed domain', () {
      expect(SitesNotifier.validateDomain('example.test'), 'example.test');
      expect(SitesNotifier.validateDomain('my-site.local'), 'my-site.local');
      expect(SitesNotifier.validateDomain('a.b.c'), 'a.b.c');
    });

    test('rejects empty and overlong', () {
      expect(() => SitesNotifier.validateDomain(''), throwsArgumentError);
      expect(
        () => SitesNotifier.validateDomain('a' * 260),
        throwsArgumentError,
      );
    });

    test('rejects path-traversal and separator characters', () {
      expect(() => SitesNotifier.validateDomain('../etc'), throwsArgumentError);
      expect(() => SitesNotifier.validateDomain('a/b'), throwsArgumentError);
      expect(() => SitesNotifier.validateDomain('a\\b'), throwsArgumentError);
    });

    test('rejects domains with dots-only or leading/trailing dash', () {
      expect(() => SitesNotifier.validateDomain('..'), throwsArgumentError);
      expect(() => SitesNotifier.validateDomain('-bad'), throwsArgumentError);
      expect(() => SitesNotifier.validateDomain('bad-'), throwsArgumentError);
    });
  });
}
