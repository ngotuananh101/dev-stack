import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/isar_provider.dart';
import '../../../core/security/local_secret_vault.dart';
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

  @visibleForTesting
  static void encryptRecordPassword(
    DatabaseRecord record, {
    LocalSecretVault? vault,
  }) {
    if (record.password.isEmpty) return;
    if (vault != null) {
      record.password = vault.encrypt(record.password);
    }
  }

  @visibleForTesting
  static void decryptRecordPassword(
    DatabaseRecord record, {
    LocalSecretVault? vault,
  }) {
    if (record.password.isEmpty) return;
    if (vault != null) {
      record.password = vault.decrypt(record.password);
    }
  }

  Future<void> fetchByEngine(String engineAppId) async {
    state = const AsyncValue.loading();
    try {
      final isar = await ref.read(isarProvider.future);
      final records = await isar.databaseRecords
          .filter()
          .engineAppIdEqualTo(engineAppId)
          .findAll();

      final vault = await LocalSecretVault.getInstance();
      for (final record in records) {
        decryptRecordPassword(record, vault: vault);
      }

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

    // Reject injection before any value reaches the server: identifiers must
    // match the portable charset, and passwords are escaped for SQL literals.
    validateIdentifier(name, field: 'Database name');
    validateIdentifier(user, field: 'Username');
    final safePassword = escapeSqlPassword(password);

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
        CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$safePassword';
        GRANT ALL PRIVILEGES ON `$name`.* TO '$user'@'%';
        FLUSH PRIVILEGES;
      """;

      final grantRes = await Process.run(cliPath, ['-u', 'root', '-e', sql]);
      if (grantRes.exitCode != 0) {
        // The database was already created on the server; drop it so we don't
        // leave an orphan the app has no record of and the user can't retry
        // cleanly (CREATE DATABASE would then fail with "already exists").
        await _safeDropDatabase(cliPath, name, isPostgres: false);
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
        'CREATE USER "$user" WITH PASSWORD \'$safePassword\'; GRANT ALL PRIVILEGES ON DATABASE "$name" TO "$user";',
      ]);
      if (grantRes.exitCode != 0) {
        // Same orphan-DB concern as MySQL: roll back the created database.
        await _safeDropDatabase(cliPath, name, isPostgres: true);
        throw Exception('Grant error: ${grantRes.stderr}');
      }
    } else {
      throw Exception('Engine ${app.appId} not supported for creation yet');
    }

    // Save to Isar
    final isar = await ref.read(isarProvider.future);
    final vault = await LocalSecretVault.getInstance();
    final encryptedPassword = vault.encrypt(password);

    final record = DatabaseRecord()
      ..name = name
      ..username = user
      ..password = encryptedPassword
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

    validateIdentifier(newUser, field: 'Username');
    final safeNewPassword = escapeSqlPassword(newPassword);
    final isPostgres = app.appId.contains('postgresql');
    final isar = await ref.read(isarProvider.future);

    // If the username actually changed, rename the server-side user BEFORE
    // touching the password. Otherwise the server keeps the old user (with its
    // old password) while Isar stores the new name — a desync that leaves an
    // orphaned account and writes the new password to the wrong user.
    final renameSql = renameUserSql(
      oldUser: record.username,
      newUser: newUser,
      isPostgres: isPostgres,
    );
    if (renameSql != null) {
      if (!isPostgres) {
        final res = await Process.run(cliPath, ['-u', 'root', '-e', renameSql]);
        if (res.exitCode != 0) {
          throw Exception('Rename user error: ${res.stderr}');
        }
      } else {
        final res = await Process.run(cliPath, [
          '-U',
          'postgres',
          '-c',
          renameSql,
        ]);
        if (res.exitCode != 0) {
          throw Exception('Rename user error: ${res.stderr}');
        }
      }
      // The rename committed server-side. Persist the new username to Isar
      // immediately so that, if the password step below fails, the record
      // still matches what the server actually has (renamed user + old
      // password). A rename preserves the password, so the existing stored
      // password stays correct.
      record.username = newUser;
      await isar.writeTxn(() => isar.databaseRecords.put(record));
    }

    // Update user password if changed and engine supports it
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      if (newPassword.isNotEmpty) {
        final sql =
            "ALTER USER '$newUser'@'%' IDENTIFIED BY '$safeNewPassword'; FLUSH PRIVILEGES;";
        final res = await Process.run(cliPath, ['-u', 'root', '-e', sql]);
        if (res.exitCode != 0) {
          // Password not changed on the server — do NOT persist newPassword
          // to Isar; the record keeps the old (still-valid) password.
          throw Exception('Update password error: ${res.stderr}');
        }
      }
    } else if (app.appId.contains('postgresql')) {
      if (newPassword.isNotEmpty) {
        final sql = "ALTER USER \"$newUser\" WITH PASSWORD '$safeNewPassword';";
        final res = await Process.run(cliPath, ['-U', 'postgres', '-c', sql]);
        if (res.exitCode != 0) {
          throw Exception('Update password error: ${res.stderr}');
        }
      }
    }

    // Update Isar record — only fields whose server-side change succeeded.
    // Password is persisted only if the ALTER above ran and succeeded.
    if (newPassword.isNotEmpty) {
      final vault = await LocalSecretVault.getInstance();
      record.password = vault.encrypt(newPassword);
    }
    record.note = newNote;
    await isar.writeTxn(() => isar.databaseRecords.put(record));
    await fetchByEngine(app.appId);
  }

  Future<void> deleteDatabase(AppModel app, DatabaseRecord record) async {
    final cliPath = app.cliFilePath;
    if (cliPath == null) throw Exception('CLI not found');

    // Records may predate validation; re-check before interpolation so a
    // malicious or malformed stored name/username can never reach the server.
    validateIdentifier(record.name, field: 'Database name');
    final username = record.username;
    if (username.isNotEmpty && username != 'root' && username != 'postgres') {
      validateIdentifier(username, field: 'Username');
    }

    // 1. Run CLI Command
    if (app.appId.contains('mysql') || app.appId.contains('mariadb')) {
      // Drop the database first
      final dropRes = await Process.run(cliPath, [
        '-u',
        'root',
        '-e',
        'DROP DATABASE `${record.name}`;',
      ]);
      if (dropFailed(dropRes)) {
        throw Exception(
          'Failed to drop database "${record.name}": ${dropRes.stderr}',
        );
      }

      // Drop the associated user if they only had access to this one database
      if (username.isNotEmpty && username != 'root') {
        await _dropUserIfExclusive(cliPath, username, record.name);
      }
    } else if (app.appId.contains('postgresql')) {
      // Drop the database first
      final dropRes = await Process.run(cliPath, [
        '-U',
        'postgres',
        '-c',
        'DROP DATABASE IF EXISTS "${record.name}";',
      ]);
      if (dropFailed(dropRes)) {
        throw Exception(
          'Failed to drop database "${record.name}": ${dropRes.stderr}',
        );
      }

      // Drop the associated user
      if (username.isNotEmpty && username != 'postgres') {
        await Process.run(cliPath, [
          '-U',
          'postgres',
          '-c',
          'DROP USER IF EXISTS "$username";',
        ]);
      }
    } else if (app.appId.contains('redis')) {
      // Extract DB index from name (e.g., "db0" -> "0"). Strip a leading
      // "db" prefix only, and require a numeric index in [0, 15] so we never
      // pass a garbage token to redis-cli or flush the wrong database.
      final dbIndex = redisDbIndex(record.name);
      if (dbIndex == null) {
        throw Exception(
          'Cannot delete Redis record "${record.name}": name does not encode '
          'a valid database index (db0..db15).',
        );
      }
      final flushRes = await Process.run(cliPath, [
        '-n',
        dbIndex.toString(),
        'FLUSHDB',
      ]);
      if (dropFailed(flushRes)) {
        throw Exception(
          'Failed to flush Redis DB ${record.name}: ${flushRes.stderr}',
        );
      }
    }

    // 2. Remove from Isar
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() => isar.databaseRecords.delete(record.id));
    await fetchByEngine(app.appId);
  }

  /// Best-effort DROP DATABASE used to roll back a database that was created
  /// on the server but whose user/grant step failed in [addDatabase]. Errors
  /// are swallowed (and logged via the thrown context) so the original
  /// failure is what propagates — we only want to avoid leaving an orphan.
  Future<void> _safeDropDatabase(
    String cliPath,
    String name, {
    required bool isPostgres,
  }) async {
    try {
      if (isPostgres) {
        await Process.run(cliPath, [
          '-U',
          'postgres',
          '-c',
          'DROP DATABASE IF EXISTS "$name";',
        ]);
      } else {
        await Process.run(cliPath, [
          '-u',
          'root',
          '-e',
          'DROP DATABASE IF EXISTS `$name`;',
        ]);
      }
    } catch (_) {
      // Best-effort rollback; the original error is what matters.
    }
  }

  /// Drops a MySQL/MariaDB user if they only have GRANT on [dbName] and nothing else.
  Future<void> _dropUserIfExclusive(
    String cliPath,
    String username,
    String dbName,
  ) async {
    validateIdentifier(username, field: 'Username');
    validateIdentifier(dbName, field: 'Database name');
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

    // Check if the only remaining grant is for our database. Use an exact
    // identifier match rather than a substring test: a substring check would
    // wrongly treat a grant on `mydb_archive` as a grant on `mydb`, causing
    // us to drop a user that still has access to another database.
    final onlyThisDb = grants.every((g) => grantIsForDatabase(g, dbName));

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
        // Never surface MySQL system schemas as user-managed databases — they
        // would otherwise appear in the UI and be deletable.
        .where((l) => !mysqlSystemSchemas.contains(l.toLowerCase()))
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

  /// Validates a database name or username before it is interpolated into a
  /// SQL identifier. Accepts only the portable identifier charset (letters,
  /// digits, underscore) and a sane length, so a stray quote or semicolon can
  /// never reach the server. Callers that need `$` should keep it in the
  /// name field's UI validator only — we reject it here to stay MySQL/Postgres
  /// portable and avoid backtick/quote-escaping pitfalls entirely.
  static String validateIdentifier(
    String value, {
    String field = 'Identifier',
  }) {
    if (value.isEmpty) {
      throw ArgumentError('$field must not be empty');
    }
    if (value.length > 63) {
      throw ArgumentError('$field is too long (max 63 characters)');
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(value)) {
      throw ArgumentError(
        '$field may only contain letters, digits, and underscores, and must '
        'start with a letter',
      );
    }
    return value;
  }

  /// Escapes a password for safe interpolation into a single-quoted SQL string
  /// literal (MySQL/MariaDB ``IDENTIFIED BY '...'`` and Postgres ``WITH
  /// PASSWORD '...'``). Doubling the quote is the SQL-standard escape; this
  /// keeps the value inside the literal so it cannot terminate the statement.
  /// Backslashes are also escaped to prevent MySQL's ``\`` escape sequences
  /// from breaking out.
  static String escapeSqlPassword(String value) {
    var escaped = value.replaceAll('\\', '\\\\').replaceAll("'", "''");
    return escaped;
  }

  /// Returns true when a DROP/FLUSH CLI result indicates the server-side
  /// operation did not succeed. Used by [deleteDatabase] to decide whether to
  /// remove the Isar record: we only drop the record when the server actually
  /// dropped the database, otherwise the user would lose tracking of a DB
  /// that still lives on the server.
  @visibleForTesting
  static bool dropFailed(ProcessResult res) => res.exitCode != 0;

  /// Parses a Redis DB index from a record name such as `db0` (-> 0).
  /// Only a leading `db` prefix is stripped (NOT every occurrence, so `dbbody`
  /// is rejected rather than becoming `ody`), and the remainder must be a
  /// non-negative integer in the Redis DB range [0, 15]. Returns null if the
  /// name cannot be parsed, so the caller can refuse to FLUSHDB a garbage
  /// index rather than wiping the wrong database.
  @visibleForTesting
  static int? redisDbIndex(String name) {
    var s = name;
    if (s.toLowerCase().startsWith('db')) {
      s = s.substring(2);
    }
    final idx = int.tryParse(s);
    if (idx == null || idx < 0 || idx > 15) return null;
    return idx;
  }

  /// MySQL/MariaDB system schemas that must never be presented as
  /// user-managed databases (they would be offered for deletion in the UI
  /// otherwise). Unmodifiable so callers can't accidentally mutate it.
  @visibleForTesting
  static final Set<String> mysqlSystemSchemas = const {
    'mysql',
    'sys',
    'information_schema',
    'performance_schema',
  };

  /// Returns true if a `SHOW GRANTS` line grants privileges specifically on
  /// [dbName] (matching the whole identifier, not a substring). Handles both
  /// backtick-quoted (`` `mydb`.* ``) and unquoted (`` mydb.* ``) MySQL output.
  /// A grant on `mydb_archive` is correctly rejected when [dbName] is `mydb`,
  /// which the old `g.contains('`$dbName`')` substring check got wrong.
  @visibleForTesting
  static bool grantIsForDatabase(String grantLine, String dbName) {
    final escaped = RegExp.escape(dbName);
    // `ON <db>.*` where <db> may be wrapped in backticks. Anchored with \b so
    // `mydb` doesn't match inside `mydb_archive`.
    final re = RegExp(
      r'ON\s+`?'
      '$escaped'
      r'`?\s*\.\*',
    );
    return re.hasMatch(grantLine);
  }

  /// Builds the SQL to rename a database user. Returns `null` when
  /// [oldUser] equals [newUser] — in that case there is nothing to rename and
  /// the caller must skip the statement entirely (running RENAME with the same
  /// name is harmless on MySQL but is an error on Postgres, and we want one
  /// code path). Both names are validated as identifiers first, so a stored
  /// username that predates validation can never reach the server here either.
  static String? renameUserSql({
    required String oldUser,
    required String newUser,
    required bool isPostgres,
  }) {
    validateIdentifier(oldUser, field: 'Old username');
    validateIdentifier(newUser, field: 'New username');
    if (oldUser == newUser) return null;
    if (isPostgres) {
      return 'ALTER ROLE "$oldUser" RENAME TO "$newUser";';
    }
    return "RENAME USER '$oldUser'@'%' TO '$newUser'@'%';";
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
