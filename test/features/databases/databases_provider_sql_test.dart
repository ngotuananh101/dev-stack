import 'dart:io';
import 'package:dev_stack/features/apps/domain/app_model.dart';
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

  group('DatabasesNotifier.postgresCliArgs', () {
    test('prepends -h /tmp on Linux', () {
      final args = DatabasesNotifier.postgresCliArgs(
        ['-U', 'postgres', '-l'],
        isLinux: true,
      );
      expect(args, ['-h', '/tmp', '-U', 'postgres', '-l']);
    });

    test('preserves arguments as-is on non-Linux', () {
      final args = DatabasesNotifier.postgresCliArgs(
        ['-U', 'postgres', '-l'],
        isLinux: false,
      );
      expect(args, ['-U', 'postgres', '-l']);
    });
  });


  group('DatabasesNotifier.readPostgresPassword', () {
    test('reads password from a sibling postgres-password.txt', () async {
      final tmp = await Directory.systemTemp.createTemp('pg-pw-');
      final binDir = Directory('${tmp.path}/install/bin')..createSync(recursive: true);
      final cliPath = '${binDir.path}/psql';
      File('${tmp.path}/install/postgres-password.txt')
          .writeAsStringSync('s3cr3t\n');

      final app = AppModel(appId: 'postgresql', name: 'PostgreSQL', categories: ['database'], installedVersion: '16.4');
      final pwd = await DatabasesNotifier.readPostgresPassword(cliPath, app);
      expect(pwd, 's3cr3t');
      await tmp.delete(recursive: true);
    });

    test('returns empty string when no password file exists', () async {
      final tmp = await Directory.systemTemp.createTemp('pg-pw-none-');
      final cliPath = '${tmp.path}/psql';
      final app = AppModel(appId: 'postgresql', name: 'PostgreSQL', categories: ['database'], installedVersion: '16.4');
      final pwd = await DatabasesNotifier.readPostgresPassword(cliPath, app);
      expect(pwd, '');
      await tmp.delete(recursive: true);
    });
  });
}
