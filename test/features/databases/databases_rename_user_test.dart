import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabasesNotifier.renameUserSql', () {
    test('MySQL/MariaDB: emits RENAME USER with quoted identifiers', () {
      final sql = DatabasesNotifier.renameUserSql(
        oldUser: 'alice',
        newUser: 'bob',
        isPostgres: false,
      );
      expect(sql, "RENAME USER 'alice'@'%' TO 'bob'@'%';");
    });

    test('Postgres: emits ALTER ROLE RENAME TO', () {
      final sql = DatabasesNotifier.renameUserSql(
        oldUser: 'alice',
        newUser: 'bob',
        isPostgres: true,
      );
      expect(sql, 'ALTER ROLE "alice" RENAME TO "bob";');
    });

    test('rejects empty or non-identifier names', () {
      expect(
        () => DatabasesNotifier.renameUserSql(
          oldUser: '',
          newUser: 'bob',
          isPostgres: false,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DatabasesNotifier.renameUserSql(
          oldUser: 'alice',
          newUser: "x'; DROP USER root",
          isPostgres: false,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns null sentinel when old == new (no rename needed)', () {
      // When the username is unchanged there is nothing to rename; callers
      // must skip the RENAME statement. We express that as a null return.
      final sql = DatabasesNotifier.renameUserSql(
        oldUser: 'alice',
        newUser: 'alice',
        isPostgres: false,
      );
      expect(sql, isNull);
    });
  });
}
