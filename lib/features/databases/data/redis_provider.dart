import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/utils/bounded_runner.dart';
import '../../apps/domain/app_model.dart';
import '../domain/redis_key.dart';

part 'redis_provider.g.dart';

@riverpod
class Redis extends _$Redis {
  bool _isDisposed = false;

  /// Identity of the most recent [fetchKeys] call. A response from an older
  /// call is dropped instead of painting stale keys under a newer filter.
  int _fetchGeneration = 0;

  /// How many keys get their type/TTL/value probed. Each probe is a few
  /// `redis-cli` subprocesses, so this caps both latency and process churn.
  @visibleForTesting
  static const int maxProbedKeys = 50;

  /// Keys are probed concurrently: every key needs 2–4 sequential `redis-cli`
  /// invocations, so doing them one key at a time meant up to 200 process
  /// spawns in series before the table could render.
  static const int _probeConcurrency = 8;

  @override
  FutureOr<List<RedisKey>> build() {
    ref.onDispose(() => _isDisposed = true);
    return [];
  }

  Future<void> fetchKeys(AppModel app, int dbIndex, {String query = '*'}) async {
    if (_isDisposed) return;
    final generation = ++_fetchGeneration;

    state = const AsyncValue.loading();

    final newState = await AsyncValue.guard(() async {
      final cliPath = app.cliFilePath;
      if (cliPath == null) throw Exception('Redis CLI not found');

      final keys = await _listKeys(cliPath, dbIndex, query);
      final probed = keys.take(maxProbedKeys).toList();

      final results = await runBounded<dynamic, RedisKey?>(
        probed,
        _probeConcurrency,
        (key, _) => _describeKey(cliPath, dbIndex, key),
      );
      return results.whereType<RedisKey>().toList();
    });

    // A newer fetch started while this one was running: its result wins.
    if (_isDisposed || generation != _fetchGeneration) return;
    state = newState;
  }

  /// Lists keys with `SCAN` rather than `KEYS`.
  ///
  /// `KEYS` walks the entire keyspace while holding the server: on a database
  /// with hundreds of thousands of keys it blocks every other client for
  /// seconds. `SCAN` is incremental. The loop is bounded so a huge keyspace
  /// still returns promptly.
  static const int _scanPageSize = 500;
  static const int _maxScanIterations = 20;

  Future<List<String>> _listKeys(
    String cliPath,
    int dbIndex,
    String query,
  ) async {
    final pattern = query.isEmpty ? '*' : query;
    final keys = <String>[];
    final seen = <String>{};
    var cursor = '0';
    for (var i = 0; i < _maxScanIterations; i++) {
      final result = await Process.run(cliPath, [
        '-n',
        dbIndex.toString(),
        'SCAN',
        cursor,
        'MATCH',
        pattern,
        'COUNT',
        _scanPageSize.toString(),
      ]);
      if (result.exitCode != 0) {
        throw Exception(
          'Could not connect to Redis. Please ensure the service is running.\n'
          '${result.stderr}',
        );
      }
      final lines = result.stdout
          .toString()
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (lines.isEmpty) break;
      cursor = lines.first;
      for (final key in lines.skip(1)) {
        if (seen.add(key)) keys.add(key);
      }
      if (cursor == '0') break;
    }
    return keys;
  }

  Future<RedisKey?> _describeKey(String cliPath, int dbIndex, String key) async {
    final typeResult = await Process.run(cliPath, [
      '-n',
      dbIndex.toString(),
      'TYPE',
      key,
    ]);
    final type = typeResult.stdout.toString().trim();

    final ttlResult = await Process.run(cliPath, [
      '-n',
      dbIndex.toString(),
      'TTL',
      key,
    ]);
    final ttlSeconds = int.tryParse(ttlResult.stdout.toString().trim()) ?? -1;

    String value = '';
    int length = 0;
    switch (type) {
      case 'string':
        final valResult = await Process.run(cliPath, [
          '-n',
          dbIndex.toString(),
          'GET',
          key,
        ]);
        value = valResult.stdout.toString().trim();
        length = value.length;
      case 'list':
        length = await _scalarInt(cliPath, dbIndex, 'LLEN', key);
        value = '[list data]';
        break;
      case 'set':
        length = await _scalarInt(cliPath, dbIndex, 'SCARD', key);
        value = '[set data]';
        break;
      case 'hash':
        length = await _scalarInt(cliPath, dbIndex, 'HLEN', key);
        value = '[hash data]';
        break;
      case 'zset':
        length = await _scalarInt(cliPath, dbIndex, 'ZCARD', key);
        value = '[zset data]';
        break;
      default:
        value = '[$type data]';
    }

    return RedisKey(
      key: key,
      value: value,
      type: type,
      length: length,
      ttl: formatTtl(ttlSeconds),
      rawTtl: ttlSeconds,
    );
  }

  Future<int> _scalarInt(
    String cliPath,
    int dbIndex,
    String command,
    String key,
  ) async {
    final result = await Process.run(cliPath, [
      '-n',
      dbIndex.toString(),
      command,
      key,
    ]);
    return int.tryParse(result.stdout.toString().trim()) ?? 0;
  }

  @visibleForTesting
  static String formatTtl(int seconds) {
    if (seconds == -1) return 'No limit';
    if (seconds == -2) return 'Expired';

    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Persists the dataset in the background.
  ///
  /// This used to be `SAVE`, which is synchronous: it forks and blocks the
  /// Redis server until the RDB snapshot is written, so every SET/DEL/FLUSHDB
  /// from this UI froze the database for the duration of the dump (and once
  /// more per operation when several ran back to back). `BGSAVE` returns
  /// immediately and lets the server finish the snapshot on its own.
  Future<void> _persistInBackground(String cliPath, int dbIndex) async {
    try {
      await Process.run(cliPath, ['-n', dbIndex.toString(), 'BGSAVE']);
    } catch (_) {
      // Best-effort: the server's own save policy still applies.
    }
  }

  Future<bool> checkKeyExists(AppModel app, int dbIndex, String key) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return false;
    final result = await Process.run(
        cliPath, ['-n', dbIndex.toString(), 'EXISTS', key]);
    return result.stdout.toString().trim() == '1';
  }

  Future<void> setKey(AppModel app, int dbIndex, String key, String value,
      {int? ttl}) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return;
    await Process.run(cliPath, ['-n', dbIndex.toString(), 'SET', key, value]);
    if (ttl != null && ttl > 0) {
      await Process.run(
          cliPath, ['-n', dbIndex.toString(), 'EXPIRE', key, ttl.toString()]);
    }
    await _persistInBackground(cliPath, dbIndex);
    await fetchKeys(app, dbIndex);
  }

  Future<void> deleteKey(AppModel app, int dbIndex, String key) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return;
    await Process.run(cliPath, ['-n', dbIndex.toString(), 'DEL', key]);
    await _persistInBackground(cliPath, dbIndex);
    await fetchKeys(app, dbIndex);
  }

  Future<void> clearDb(AppModel app, int dbIndex) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return;
    await Process.run(cliPath, ['-n', dbIndex.toString(), 'FLUSHDB']);
    await _persistInBackground(cliPath, dbIndex);
    await fetchKeys(app, dbIndex);
  }
}

@riverpod
Future<Map<int, int>> redisDbStats(Ref ref, AppModel app) async {
  final cliPath = app.cliFilePath;
  if (cliPath == null) return {};

  final result = await Process.run(cliPath, ['INFO', 'keyspace']);
  if (result.exitCode != 0) return {};

  final stats = <int, int>{};
  final lines = result.stdout.toString().split('\n');
  for (final line in lines) {
    if (!line.startsWith('db')) continue;
    final parts = line.split(':');
    if (parts.length < 2) continue;
    final dbIndex = int.tryParse(parts[0].replaceFirst('db', '')) ?? 0;
    final keyCountField = parts[1].split(',').first;
    final keyCount = int.tryParse(keyCountField.split('=').last) ?? 0;
    stats[dbIndex] = keyCount;
  }
  return stats;
}
