import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sites.phpVersionFromAppId', () {
    test('formats a 2-digit version as X.Y', () {
      expect(Sites.phpVersionFromAppId('php82'), '8.2');
      expect(Sites.phpVersionFromAppId('php81'), '8.1');
      expect(Sites.phpVersionFromAppId('php74'), '7.4');
    });

    test('passes through an already-formatted X.Y version', () {
      expect(Sites.phpVersionFromAppId('php8.2'), '8.2');
    });

    test('handles versions with more than two digits', () {
      expect(Sites.phpVersionFromAppId('php821'), '8.2.1');
    });

    test('falls back to null when no digits are present', () {
      expect(Sites.phpVersionFromAppId('php'), isNull);
      expect(Sites.phpVersionFromAppId(''), isNull);
    });
  });
}
