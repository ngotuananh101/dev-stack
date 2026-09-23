import 'dart:io';

import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Databases.dropFailed', () {
    test('non-zero exit code is a failure', () {
      final res = ProcessResult(1, 1, '', 'ERROR 1010: database in use');
      expect(Databases.dropFailed(res), isTrue);
    });

    test('zero exit code is success (keep going, remove the record)', () {
      final res = ProcessResult(1, 0, 'Query OK', '');
      expect(Databases.dropFailed(res), isFalse);
    });

    test('empty stderr with non-zero code still counts as failure', () {
      final res = ProcessResult(1, 2, '', '');
      expect(Databases.dropFailed(res), isTrue);
    });
  });

  group('Databases.redisDbIndex', () {
    test('parses db0..db15', () {
      expect(Databases.redisDbIndex('db0'), 0);
      expect(Databases.redisDbIndex('db15'), 15);
    });

    test('strips only a leading db prefix (not every occurrence)', () {
      // "dbbody" must NOT become "ody"; it must be rejected entirely.
      expect(Databases.redisDbIndex('dbbody'), isNull);
      // A name where "db" appears mid-string without the prefix is rejected.
      expect(Databases.redisDbIndex('mydb0'), isNull);
    });

    test('rejects out-of-range and non-numeric', () {
      expect(Databases.redisDbIndex('db16'), isNull);
      expect(Databases.redisDbIndex('db-1'), isNull);
      expect(Databases.redisDbIndex('dbabc'), isNull);
      expect(Databases.redisDbIndex(''), isNull);
    });
  });
}
