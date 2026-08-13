import 'dart:io';

import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabasesNotifier.dropFailed', () {
    test('non-zero exit code is a failure', () {
      final res = ProcessResult(1, 1, '', 'ERROR 1010: database in use');
      expect(DatabasesNotifier.dropFailed(res), isTrue);
    });

    test('zero exit code is success (keep going, remove the record)', () {
      final res = ProcessResult(1, 0, 'Query OK', '');
      expect(DatabasesNotifier.dropFailed(res), isFalse);
    });

    test('empty stderr with non-zero code still counts as failure', () {
      final res = ProcessResult(1, 2, '', '');
      expect(DatabasesNotifier.dropFailed(res), isTrue);
    });
  });

  group('DatabasesNotifier.redisDbIndex', () {
    test('parses db0..db15', () {
      expect(DatabasesNotifier.redisDbIndex('db0'), 0);
      expect(DatabasesNotifier.redisDbIndex('db15'), 15);
    });

    test('strips only a leading db prefix (not every occurrence)', () {
      // "dbbody" must NOT become "ody"; it must be rejected entirely.
      expect(DatabasesNotifier.redisDbIndex('dbbody'), isNull);
      // A name where "db" appears mid-string without the prefix is rejected.
      expect(DatabasesNotifier.redisDbIndex('mydb0'), isNull);
    });

    test('rejects out-of-range and non-numeric', () {
      expect(DatabasesNotifier.redisDbIndex('db16'), isNull);
      expect(DatabasesNotifier.redisDbIndex('db-1'), isNull);
      expect(DatabasesNotifier.redisDbIndex('dbabc'), isNull);
      expect(DatabasesNotifier.redisDbIndex(''), isNull);
    });
  });
}
