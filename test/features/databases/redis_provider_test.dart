import 'package:dev_stack/features/databases/data/redis_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Redis key probing', () {
    test('caps how many keys are probed per fetch', () {
      // Each probe is 2–4 `redis-cli` invocations; an unbounded probe list
      // spawns thousands of processes on a large database.
      expect(Redis.maxProbedKeys, greaterThan(0));
      expect(Redis.maxProbedKeys, lessThanOrEqualTo(100));
    });
  });

  group('Redis.formatTtl', () {
    test('reports the Redis sentinel values', () {
      expect(Redis.formatTtl(-1), 'No limit');
      expect(Redis.formatTtl(-2), 'Expired');
    });

    test('formats seconds, minutes and hours', () {
      expect(Redis.formatTtl(45), '45s');
      expect(Redis.formatTtl(90), '1m 30s');
      expect(Redis.formatTtl(3661), '1h 1m 1s');
    });
  });
}
