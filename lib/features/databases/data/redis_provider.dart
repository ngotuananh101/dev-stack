import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/redis_key.dart';
import '../../apps/domain/app_model.dart';

part 'redis_provider.g.dart';

@riverpod
class RedisNotifier extends _$RedisNotifier {
  @override
  FutureOr<List<RedisKey>> build() {
    return [];
  }

  Future<void> fetchKeys(AppModel app, int dbIndex, {String query = '*'}) async {
    state = const AsyncValue.loading();
    try {
      final cliPath = app.cliFilePath;
      if (cliPath == null) throw Exception('Redis CLI not found');

      // 1. Get all keys
      final result = await Process.run(cliPath, ['-n', dbIndex.toString(), 'KEYS', query.isEmpty ? '*' : query]);
      if (result.exitCode != 0) {
        state = const AsyncValue.data([]);
        return;
      }

      final keys = result.stdout.toString().split('\n').where((s) => s.trim().isNotEmpty).toList();
      final List<RedisKey> redisKeys = [];

      // 2. Get details for each key (Limit to first 100 for performance)
      for (final key in keys.take(100)) {
        final typeRes = await Process.run(cliPath, ['-n', dbIndex.toString(), 'TYPE', key]);
        final type = typeRes.stdout.toString().trim();

        final ttlRes = await Process.run(cliPath, ['-n', dbIndex.toString(), 'TTL', key]);
        final ttlSeconds = int.tryParse(ttlRes.stdout.toString().trim()) ?? -1;
        final ttlDisplay = _formatTTL(ttlSeconds);

        String value = '';
        int length = 0;

        if (type == 'string') {
          final valRes = await Process.run(cliPath, ['-n', dbIndex.toString(), 'GET', key]);
          value = valRes.stdout.toString().trim();
          length = value.length;
        } else {
          value = '[$type data]';
          // Getting length for other types would require more commands (LLEN, HLEN, etc.)
        }

        redisKeys.add(RedisKey(
          key: key,
          value: value,
          type: type,
          length: length,
          ttl: ttlDisplay,
        ));
      }

      state = AsyncValue.data(redisKeys);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String _formatTTL(int seconds) {
    if (seconds == -1) return 'No limit';
    if (seconds == -2) return 'Expired';
    
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> deleteKey(AppModel app, int dbIndex, String key) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return;
    await Process.run(cliPath, ['-n', dbIndex.toString(), 'DEL', key]);
    await fetchKeys(app, dbIndex);
  }

  Future<void> clearDb(AppModel app, int dbIndex) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) return;
    await Process.run(cliPath, ['-n', dbIndex.toString(), 'FLUSHDB']);
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
    if (line.startsWith('db')) {
      // Example: db0:keys=56,expires=0,avg_ttl=0
      final parts = line.split(':');
      final dbIndex = int.tryParse(parts[0].replaceFirst('db', '')) ?? 0;
      final keyCount = int.tryParse(parts[1].split(',')[0].split('=')[1]) ?? 0;
      stats[dbIndex] = keyCount;
    }
  }
  return stats;
}
