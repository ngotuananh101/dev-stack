import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/apps/domain/installed_app.dart';
import '../../features/databases/domain/database_record.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/sites/domain/site_model.dart';

part 'isar_provider.g.dart';

class IsarInstance {
  static Isar? _instance;
  static Completer<Isar>? _openCompleter;

  static Future<Isar> getInstance({
    @visibleForTesting Future<Isar> Function()? opener,
  }) async {
    if (_instance != null && _instance!.isOpen) {
      return _instance!;
    }

    if (_openCompleter != null) {
      return await _openCompleter!.future;
    }

    final completer = Completer<Isar>();
    _openCompleter = completer;

    try {
      final isar = opener != null ? await opener() : await _openDatabase();
      _instance = isar;
      completer.complete(isar);
      return isar;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _openCompleter = null;
    }
  }

  static Future<Isar> _openDatabase() async {
    final dir = await getApplicationSupportDirectory();

    try {
      return await Isar.open([
        InstalledAppSchema,
        DatabaseRecordSchema,
        AppSettingsSchema,
        SiteModelSchema,
      ], directory: dir.path);
    } catch (e) {
      // Only reset for schema mismatch or corruption errors.
      // Other errors (file lock, disk full, etc.) should propagate.
      final message = e.toString().toLowerCase();
      final isSchemaOrCorruption =
          message.contains('schema') ||
          message.contains('corrupt') ||
          message.contains('migration') ||
          message.contains('incompatible');

      if (!isSchemaOrCorruption) {
        // ignore: avoid_print
        print('[Isar] Database open failed (not schema/corruption): $e');
        rethrow;
      }

      // Backup and delete DB on schema mismatch or corruption
      final isarFile = File('${dir.path}/default.isar');
      final lockFile = File('${dir.path}/default.isar.lock');

      // Create backup before deleting
      if (isarFile.existsSync()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        try {
          isarFile.copySync('${dir.path}/default.isar.bak.$timestamp');
        } catch (_) {}
        isarFile.deleteSync();
      }
      if (lockFile.existsSync()) lockFile.deleteSync();

      // ignore: avoid_print
      print('[Isar] Database reset due to schema/corruption error: $e');

      return await Isar.open([
        InstalledAppSchema,
        DatabaseRecordSchema,
        AppSettingsSchema,
        SiteModelSchema,
      ], directory: dir.path);
    }
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
    _openCompleter = null;
  }
}

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  return await IsarInstance.getInstance();
}
