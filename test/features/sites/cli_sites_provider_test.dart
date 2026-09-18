import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SitesProvider CLI Validation', () {
    test('validateCliPort throws on null or out of range ports', () {
      expect(() => validateCliPort(null), throwsArgumentError);
      expect(() => validateCliPort(0), throwsArgumentError);
      expect(() => validateCliPort(65536), throwsArgumentError);
      expect(() => validateCliPort(-1), throwsArgumentError);
      expect(validateCliPort(3000), 3000);
      expect(validateCliPort(8080), 8080);
    });

    test('validateCliCommand throws on empty or invalid commands', () {
      expect(() => validateCliCommand(''), throwsArgumentError);
      expect(() => validateCliCommand('   '), throwsArgumentError);
      expect(validateCliCommand('npm run dev'), 'npm run dev');
    });

    test('validateCliCommand trims surrounding whitespace', () {
      expect(validateCliCommand('  npm start  '), 'npm start');
    });
  });
}
