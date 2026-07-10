import 'package:dev_stack/features/sites/domain/site_domain_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDomainFromTemplate', () {
    test('replaces [site-name] placeholder', () {
      expect(resolveDomainFromTemplate('[site-name].test', 'blog'), 'blog.test');
    });

    test('replaces {name} placeholder', () {
      expect(resolveDomainFromTemplate('{name}.local', 'shop'), 'shop.local');
    });

    test('replaces {site-name} placeholder', () {
      expect(resolveDomainFromTemplate('{site-name}.dev', 'api'), 'api.dev');
    });

    test('returns template unchanged when no placeholder', () {
      expect(resolveDomainFromTemplate('fixed.test', 'blog'), 'fixed.test');
    });

    test('replaces all occurrences of the matched placeholder', () {
      expect(
        resolveDomainFromTemplate('[site-name].[site-name].test', 'x'),
        'x.x.test',
      );
    });
  });
}
