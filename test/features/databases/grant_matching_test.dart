import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Databases.mysqlSystemSchemas', () {
    test('contains the four MySQL system schemas', () {
      expect(Databases.mysqlSystemSchemas, contains('mysql'));
      expect(Databases.mysqlSystemSchemas, contains('sys'));
      expect(
        Databases.mysqlSystemSchemas,
        contains('information_schema'),
      );
      expect(
        Databases.mysqlSystemSchemas,
        contains('performance_schema'),
      );
    });

    test('is unmodifiable', () {
      expect(
        () => Databases.mysqlSystemSchemas.add('x'),
        throwsA(isA<Error>()),
      );
    });
  });

  group('Databases.grantIsForDatabase', () {
    test('matches a backticked db grant exactly', () {
      expect(
        Databases.grantIsForDatabase(
          "GRANT ALL PRIVILEGES ON `mydb`.* TO 'user'@'%'",
          'mydb',
        ),
        isTrue,
      );
    });

    test('matches an unquoted db grant exactly', () {
      expect(
        Databases.grantIsForDatabase(
          "GRANT ALL PRIVILEGES ON mydb.* TO 'user'@'%'",
          'mydb',
        ),
        isTrue,
      );
    });

    test(
      'does NOT match a superstring database name (mydb vs mydb_archive)',
      () {
        // A grant on `mydb_archive` must not be treated as a grant on `mydb`.
        expect(
          Databases.grantIsForDatabase(
            "GRANT ALL PRIVILEGES ON `mydb_archive`.* TO 'user'@'%'",
            'mydb',
          ),
          isFalse,
        );
        expect(
          Databases.grantIsForDatabase(
            "GRANT ALL PRIVILEGES ON mydb_archive.* TO 'user'@'%'",
            'mydb',
          ),
          isFalse,
        );
      },
    );

    test('does NOT match an unrelated grant', () {
      expect(
        Databases.grantIsForDatabase(
          "GRANT ALL PRIVILEGES ON `other`.* TO 'user'@'%'",
          'mydb',
        ),
        isFalse,
      );
    });
  });
}
