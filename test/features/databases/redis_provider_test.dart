import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/databases/data/redis_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppModel _app() => AppModel(
  appId: 'redis',
  name: 'Redis',
  categories: const ['database'],
  cliFilePath: '/fake/redis-cli',
);

ProcessResult _ok(String stdout, [String stderr = '']) =>
    ProcessResult(0, 0, stdout, stderr);

String _keyFromArgs(List<String> args) => args.last;

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

  group('Redis.fetchKeys', () {
    late RedisProcessRunner originalRunner;

    setUp(() {
      originalRunner = Redis.processRunner;
    });

    tearDown(() {
      Redis.processRunner = originalRunner;
    });

    test('stops SCAN at 50 unique keys in encounter order', () async {
      final scanCalls = <List<String>>[];
      Redis.processRunner = (exe, args) async {
        if (args.contains('SCAN')) {
          scanCalls.add(List<String>.from(args));
          final cursor = args[3];
          if (cursor == '0') {
            final keys = List.generate(
              30,
              (i) => 'k${i.toString().padLeft(2, '0')}',
            );
            return _ok('7\n${keys.join('\n')}\n');
          }
          if (cursor == '7') {
            // 30 more keys (total 60 unique) plus a duplicate from first page.
            final keys = [
              'k00',
              ...List.generate(
                30,
                (i) => 'k${(i + 30).toString().padLeft(2, '0')}',
              ),
            ];
            return _ok('8\n${keys.join('\n')}\n');
          }
          return _ok('0\n');
        }
        if (args.contains('TYPE')) return _ok('string\n');
        if (args.contains('TTL')) return _ok('-1\n');
        if (args.contains('GET')) return _ok('value:${_keyFromArgs(args)}\n');
        return _ok('');
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(redisProvider.notifier).fetchKeys(_app(), 0);

      // Must stop scanning once 50 unique keys are collected; second page
      // already provided enough, so no third SCAN command should be issued.
      expect(scanCalls, hasLength(2));
      final state = container.read(redisProvider);
      final keys = state.requireValue;
      expect(keys, hasLength(50));
      expect(keys.first.key, 'k00');
      expect(keys.last.key, 'k49');
      expect(keys.map((e) => e.key).toSet(), hasLength(50));
    });

    test(
      'drops stale scan results and avoids launching further scan commands',
      () async {
        final firstScanCompleter = Completer<ProcessResult>();
        var scanCallCount = 0;
        Redis.processRunner = (exe, args) async {
          if (args.contains('SCAN')) {
            scanCallCount++;
            if (scanCallCount == 1) return firstScanCompleter.future;
            if (scanCallCount == 2) {
              return _ok('0\n${List.generate(3, (i) => 'new$i').join('\n')}\n');
            }
            fail('stale fetch must not launch further SCAN commands');
          }
          if (args.contains('TYPE')) return _ok('string\n');
          if (args.contains('TTL')) return _ok('-1\n');
          if (args.contains('GET')) return _ok('v\n');
          return _ok('');
        };

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(redisProvider, (_, _) {});
        final notifier = container.read(redisProvider.notifier);

        final first = notifier.fetchKeys(_app(), 0, query: '*a*');
        await Future<void>.delayed(Duration.zero);
        final second = notifier.fetchKeys(_app(), 0, query: '*b*');

        // First scan command already started; completing it must not trigger
        // another scan/probe cycle for the stale fetch.
        firstScanCompleter.complete(
          _ok('9\n${List.generate(5, (i) => 'old$i').join('\n')}\n'),
        );

        await Future.wait([first, second]);
        final keys = container.read(redisProvider).requireValue;
        expect(keys.map((e) => e.key), ['new0', 'new1', 'new2']);
        expect(scanCallCount, 2);
      },
    );

    test(
      'drops stale probe results and avoids launching further probe commands',
      () async {
        final delayedTypeCompleter = Completer<ProcessResult>();
        var typeCalls = 0;
        var commandsAfterStale = 0;
        var staleFetchActive = true;
        Redis.processRunner = (exe, args) async {
          if (args.contains('SCAN')) {
            if (args[5] == '*a*') {
              return _ok('0\na1\na2\na3\n');
            }
            return _ok('0\nb1\n');
          }
          if (args.contains('TYPE')) {
            typeCalls++;
            final key = args.last;
            if (key == 'a1') return delayedTypeCompleter.future;
            if (key.startsWith('a') && !staleFetchActive) {
              commandsAfterStale++;
            }
            return _ok('string\n');
          }
          if (args.contains('TTL')) {
            if (args.last.startsWith('a') && !staleFetchActive) {
              commandsAfterStale++;
            }
            return _ok('-1\n');
          }
          if (args.contains('GET')) {
            if (args.last.startsWith('a') && !staleFetchActive) {
              commandsAfterStale++;
            }
            return _ok('v\n');
          }
          return _ok('');
        };

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(redisProvider, (_, _) {});
        final notifier = container.read(redisProvider.notifier);

        final first = notifier.fetchKeys(_app(), 0, query: '*a*');
        await Future<void>.delayed(Duration.zero);
        final second = notifier.fetchKeys(_app(), 0, query: '*b*');
        staleFetchActive = false;

        delayedTypeCompleter.complete(_ok('string\n'));
        await Future.wait([first, second]);

        expect(container.read(redisProvider).requireValue.map((e) => e.key), [
          'b1',
        ]);
        // Commands already started for stale probes may finish, but no further
        // stale scan/probe commands should be launched after invalidation.
        expect(commandsAfterStale, 0);
        expect(typeCalls, greaterThanOrEqualTo(2));
      },
    );
  });

  group('redisDbStats', () {
    late RedisProcessRunner originalRunner;

    setUp(() {
      originalRunner = Redis.processRunner;
    });

    tearDown(() {
      Redis.processRunner = originalRunner;
    });

    test('uses the injectable process runner', () async {
      Redis.processRunner = (exe, args) async {
        expect(args, ['INFO', 'keyspace']);
        return _ok('db0:keys=3,expires=0,avg_ttl=0\ndb2:keys=7,expires=1\n');
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final stats = await container.read(redisDbStatsProvider(_app()).future);
      expect(stats, {0: 3, 2: 7});
    });
  });
}
