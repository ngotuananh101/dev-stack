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
    } else if (app.appId.contains('postgresql')) {
      actualNames = await _getPostgresNames(cliPath);
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
          // Set default username based on engine
          String defaultUser = 'root';
          if (app.appId.contains('postgresql')) {
            defaultUser = 'postgres';
          }

          final record = DatabaseRecord()
            ..name = name
            ..username = defaultUser
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
    if (cliPath == null || !File(cliPath).existsSync()) {
      throw Exception('CLI not found');
    }

    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      // 1. Create Database
      final createDb = await Process.run(cliPath, [
        '-u',
        'root',
        '-e',
        'CREATE DATABASE `$name`;',
      ]);
      if (createDb.exitCode != 0) {
        throw Exception('Create DB error: ${createDb.stderr}');
      }

      // 2. Create User if not exists and Grant Permissions
      // We use a single command block to handle user logic
      final sql =
          """
        CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$password';
        GRANT ALL PRIVILEGES ON `$name`.* TO '$user'@'%';
        FLUSH PRIVILEGES;
      """;

      final grantRes = await Process.run(cliPath, ['-u', 'root', '-e', sql]);
      if (grantRes.exitCode != 0) {
        throw Exception('Grant error: ${grantRes.stderr}');
      }
    } else if (app.appId.contains('postgresql')) {
      // CREATE DATABASE
      final createDb = await Process.run(cliPath, [
        '-U',
        'postgres',
        '-c',
        'CREATE DATABASE "$name";',
      ]);
      if (createDb.exitCode != 0) {
        throw Exception('Create DB error: ${createDb.stderr}');
      }

      // CREATE USER and GRANT
      final grantRes = await Process.run(cliPath, [
        '-U',
        'postgres',
        '-c',
        'CREATE USER "$user" WITH PASSWORD \'$password\'; GRANT ALL PRIVILEGES ON DATABASE "$name" TO "$user";',
      ]);
      if (grantRes.exitCode != 0) {
        throw Exception('Grant error: ${grantRes.stderr}');
      }
    } else {
      throw Exception('Engine ${app.appId} not supported for creation yet');
    }

    // Save to Isar
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

  Future<void> updateDatabase({
    required AppModel app,
    required DatabaseRecord record,
    required String newUser,
    required String newPassword,
    String? newNote,
  }) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null || !File(cliPath).existsSync()) {
      throw Exception('CLI not found');
    }

    // Update user password if changed and engine supports it
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      if (newPassword.isNotEmpty) {
        final sql =
            "ALTER USER '$newUser'@'%' IDENTIFIED BY '$newPassword'; FLUSH PRIVILEGES;";
        final res = await Process.run(cliPath, ['-u', 'root', '-e', sql]);
        if (res.exitCode != 0) {
          throw Exception('Update password error: ${res.stderr}');
        }
      }
    } else if (app.appId.contains('postgresql')) {
      if (newPassword.isNotEmpty) {
        final sql = "ALTER USER \"$newUser\" WITH PASSWORD '$newPassword';";
        final res = await Process.run(cliPath, ['-U', 'postgres', '-c', sql]);
        if (res.exitCode != 0) {
          throw Exception('Update password error: ${res.stderr}');
        }
      }
    }

    // Update Isar record
    record
      ..username = newUser
      ..password = newPassword
      ..note = newNote;

    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() => isar.databaseRecords.put(record));
    await fetchByEngine(app.appId);
  }

  Future<void> deleteDatabase(AppModel app, DatabaseRecord record) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) throw Exception('CLI not found');

    // 1. Run CLI Command
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      // Drop the database first
      await Process.run(cliPath, [
        '-u',
        'root',
        '-e',
        'DROP DATABASE `${record.name}`;',
      ]);

      // Drop the associated user if they only had access to this one database
      final username = record.username;
      if (username.isNotEmpty && username != 'root') {
        await _dropUserIfExclusive(cliPath, username, record.name);
      }
    } else if (app.appId.contains('postgresql')) {
      // Drop the database first
      await Process.run(cliPath, [
        '-U',
        'postgres',
        '-c',
        'DROP DATABASE IF EXISTS "${record.name}";',
      ]);

      // Drop the associated user
      final username = record.username;
      if (username.isNotEmpty && username != 'postgres') {
        await Process.run(cliPath, [
          '-U',
          'postgres',
          '-c',
          'DROP USER IF EXISTS "$username";',
        ]);
      }
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

  /// Drops a MySQL/MariaDB user if they only have GRANT on [dbName] and nothing else.
  Future<void> _dropUserIfExclusive(
    String cliPath,
    String username,
    String dbName,
  ) async {
    // SHOW GRANTS returns lines like:
    //   GRANT ALL PRIVILEGES ON `mydb`.* TO 'user'@'%'
    //   GRANT USAGE ON *.* TO 'user'@'%'   <- baseline, always present
    final grantsRes = await Process.run(cliPath, [
      '-u',
      'root',
      '-se',
      "SHOW GRANTS FOR '$username'@'%';",
    ]);
    if (grantsRes.exitCode != 0) return; // user may not exist

    final grants = grantsRes.stdout
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        // Exclude the baseline USAGE ON *.* grant that every user has
        .where((l) => !RegExp(r"^GRANT USAGE ON \*\.\*").hasMatch(l))
        .toList();

    // Check if the only remaining grant is for our database
    final onlyThisDb = grants.every(
      (g) => g.contains('`$dbName`') || g.contains("'$dbName'"),
    );

    if (onlyThisDb) {
      await Process.run(cliPath, [
        '-u',
        'root',
        '-e',
        "DROP USER IF EXISTS '$username'@'%'; FLUSH PRIVILEGES;",
      ]);
    }
  }

  Future<List<String>> _getMysqlNames(String cliPath) async {
    final result = await Process.run(cliPath, [
      '-u',
      'root',
      '-e',
      'SHOW DATABASES;',
    ]);
    if (result.exitCode != 0) return [];

    final lines = result.stdout.toString().split('\n');
    return lines
        .skip(1)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
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

  Future<List<String>> _getPostgresNames(String cliPath) async {
    final result = await Process.run(cliPath, [
      '-U', 'postgres',
      '-l', // list databases
      '-t', // tuples only
    ]);
    if (result.exitCode != 0) return [];

    final lines = result.stdout.toString().split('\n');
    return lines
        .map((l) => l.trim().split('|')[0].trim())
        .where((l) => l.isNotEmpty && l != 'template0' && l != 'template1')
        .toList();
  }
}

@riverpod
Future<List<AppModel>> installedDatabaseEngines(Ref ref) async {
  final apps = await ref.watch(appsNotifierProvider.future);
  return apps
      .where(
        (app) =>
            app.isInstalled &&
            app.categories.any((c) => c.toLowerCase() == 'database'),
      )
      .toList();
}
