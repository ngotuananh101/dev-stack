import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Name Validation Regex', () {
    final validRegex = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

    test('accepts valid database names', () {
      expect(validRegex.hasMatch('my_db'), isTrue);
      expect(validRegex.hasMatch('app2_database'), isTrue);
      expect(validRegex.hasMatch('db'), isTrue);
    });

    test('rejects digits as first char or invalid characters', () {
      expect(validRegex.hasMatch('123db'), isFalse);
      expect(validRegex.hasMatch('db\$name'), isFalse);
      expect(validRegex.hasMatch('my-db'), isFalse);
    });
  });
}
