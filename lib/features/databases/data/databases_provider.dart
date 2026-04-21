import 'dart:io';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../../apps/data/apps_provider.dart';
import '../../apps/domain/app_model.dart';
import '../domain/database_record.dart';

part 'databases_provider.g.dart';

@riverpod
class DatabasesNotifier extends _$DatabasesNotifier {
  @override
  FutureOr<List<DatabaseRecord>> build() {
    return [];
  }

  Future<void> fetchByEngine(String engineAppId) async {
    state = const AsyncValue.loading();
    try {
      final isar = await ref.read(isarProvider.future);
      final records = await isar.databaseRecords
          .filter()
          .engineAppIdEqualTo(engineAppId)
          .findAll();
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncDatabases(AppModel app) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null || !File(cliPath).existsSync()) {
      throw Exception('Database CLI not found at $cliPath');
    }

    List<String> actualNames = [];
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      actualNames = await _getMysqlNames(cliPath);
    } else if (app.appId.contains('mongodb')) {
      actualNames = await _getMongoNames(cliPath);
    } else if (app.appId.contains('redis')) {
      actualNames = await _getRedisNames(cliPath);
    }

    final isar = await ref.read(isarProvider.future);
    final existingRecords = await isar.databaseRecords
        .filter()
        .engineAppIdEqualTo(app.appId)
        .findAll();

    final existingNames = existingRecords.map((e) => e.name).toSet();

    await isar.writeTxn(() async {
      for (final name in actualNames) {
        if (!existingNames.contains(name)) {
          final record = DatabaseRecord()
            ..name = name
            ..username = 'root' // Default for sync
            ..password = ''
            ..engineAppId = app.appId
            ..note = 'Synced from system'
            ..createdAt = DateTime.now();
          await isar.databaseRecords.put(record);
        }
      }
    });

    await fetchByEngine(app.appId);
  }

  Future<void> addDatabase({
    required AppModel app,
    required String name,
    required String user,
    required String password,
    String? note,
  }) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null || !File(cliPath).existsSync()) throw Exception('CLI not found');

    // 1. Run CLI Command
    ProcessResult result;
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      result = await Process.run(cliPath, [
        '-u', 'root',
        '-e', 'CREATE DATABASE `$name`;',
      ]);
    } else {
      throw Exception('Engine ${app.appId} not supported for creation yet');
    }

    if (result.exitCode != 0) {
      throw Exception('CLI Error: ${result.stderr}');
    }

    // 2. Save to Isar
    final isar = await ref.read(isarProvider.future);
    final record = DatabaseRecord()
      ..name = name
      ..username = user
      ..password = password
      ..engineAppId = app.appId
      ..note = note
      ..createdAt = DateTime.now();

    await isar.writeTxn(() => isar.databaseRecords.put(record));
    await fetchByEngine(app.appId);
  }

  Future<void> deleteDatabase(AppModel app, DatabaseRecord record) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) throw Exception('CLI not found');

    // 1. Run CLI Command
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      await Process.run(cliPath, [
        '-u', 'root',
        '-e', 'DROP DATABASE `${record.name}`;',
      ]);
    } else if (app.appId.contains('redis')) {
      // Extract DB index from name (e.g., "db0" -> "0")
      final dbIndex = record.name.replaceAll('db', '');
      await Process.run(cliPath, ['-n', dbIndex, 'FLUSHDB']);
    }

    // 2. Remove from Isar
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() => isar.databaseRecords.delete(record.id));
    await fetchByEngine(app.appId);
  }

  Future<List<String>> _getMysqlNames(String cliPath) async {
    final result = await Process.run(cliPath, ['-u', 'root', '-e', 'SHOW DATABASES;']);
    if (result.exitCode != 0) return [];
    
    final lines = result.stdout.toString().split('\n');
    return lines.skip(1).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  }

  Future<List<String>> _getMongoNames(String cliPath) async {
    // Basic placeholder
    return ['admin', 'config', 'local'];
  }

  Future<List<String>> _getRedisNames(String cliPath) async {
    final result = await Process.run(cliPath, ['INFO', 'keyspace']);
    if (result.exitCode != 0) {
      // If server is not running or other error, return default 0-15
      return List.generate(16, (i) => 'db$i');
    }
    
    final List<String> dbs = [];
    // Standard Redis has 16 DBs, let's just return all of them
    for (int i = 0; i < 16; i++) {
      dbs.add('db$i');
    }
    return dbs;
  }
}

@riverpod
Future<List<AppModel>> installedDatabaseEngines(Ref ref) async {
  final apps = await ref.watch(appsNotifierProvider.future);
  return apps.where((app) => 
    app.isInstalled && 
    app.categories.any((c) => c.toLowerCase() == 'database')
  ).toList();
}
