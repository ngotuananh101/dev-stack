import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabasesNotifier.validateIdentifier', () {
    test('accepts portable identifiers', () {
      expect(
        DatabasesNotifier.validateIdentifier('my_db', field: 'Database name'),
        'my_db',
      );
      expect(
        DatabasesNotifier.validateIdentifier('shop42', field: 'Username'),
        'shop42',
      );
    });

    test('rejects injection payloads', () {
      expect(
        () =>
            DatabasesNotifier.validateIdentifier("x'; DROP DATABASE mysql; --"),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DatabasesNotifier.validateIdentifier('alice" --'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DatabasesNotifier.validateIdentifier('a;rm -rf'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DatabasesNotifier.validateIdentifier(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects identifiers not starting with a letter', () {
      expect(
        () => DatabasesNotifier.validateIdentifier('1db'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DatabasesNotifier.validateIdentifier('_db'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects overlong identifiers', () {
      expect(
        () => DatabasesNotifier.validateIdentifier('a' * 64),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DatabasesNotifier.escapeSqlPassword', () {
    test('escapes single quotes by doubling them', () {
      expect(DatabasesNotifier.escapeSqlPassword("x'y"), "x''y");
    });

    test('escapes backslashes to avoid MySQL escape sequences', () {
      expect(DatabasesNotifier.escapeSqlPassword(r'a\b'), r'a\\b');
    });

    test('escapes a quote-termination injection payload', () {
      // A password meant to close the literal and inject a statement.
      final payload = "x'; DROP DATABASE mysql; --";
      final escaped = DatabasesNotifier.escapeSqlPassword(payload);
      // The single quote that would terminate the literal is now doubled,
      // so the value stays inside the string literal.
      expect(escaped, "x''; DROP DATABASE mysql; --");
      // No single (unescaped) quote survives: every quote is part of a
      // doubled pair. Replace all doubled quotes and confirm none remain.
      final stripped = escaped.replaceAll("''", '');
      expect(stripped.contains("'"), isFalse);
    });
  });
}
