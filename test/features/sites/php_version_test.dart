import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesNotifier.phpVersionFromAppId', () {
    test('formats a 2-digit version as X.Y', () {
      expect(SitesNotifier.phpVersionFromAppId('php82'), '8.2');
      expect(SitesNotifier.phpVersionFromAppId('php81'), '8.1');
      expect(SitesNotifier.phpVersionFromAppId('php74'), '7.4');
    });

    test('passes through an already-formatted X.Y version', () {
      expect(SitesNotifier.phpVersionFromAppId('php8.2'), '8.2');
    });

    test('handles versions with more than two digits', () {
      expect(SitesNotifier.phpVersionFromAppId('php821'), '8.2.1');
    });

    test('falls back to null when no digits are present', () {
      expect(SitesNotifier.phpVersionFromAppId('php'), isNull);
      expect(SitesNotifier.phpVersionFromAppId(''), isNull);
    });
  });
}
