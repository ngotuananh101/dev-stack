import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/apps/domain/installed_app.dart';
import '../../features/databases/domain/database_record.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/sites/domain/site_model.dart';

part 'isar_provider.g.dart';

class IsarInstance {
  static Isar? _instance;

  static Future<Isar> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final dir = await getApplicationSupportDirectory();

    try {
      _instance = await Isar.open([
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

      _instance = await Isar.open([
        InstalledAppSchema,
        DatabaseRecordSchema,
        AppSettingsSchema,
        SiteModelSchema,
      ], directory: dir.path);
    }
    return _instance!;
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  return await IsarInstance.getInstance();
}
