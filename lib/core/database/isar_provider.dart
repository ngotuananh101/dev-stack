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
      _instance = await Isar.open(
        [
          InstalledAppSchema,
          DatabaseRecordSchema,
          AppSettingsSchema,
          SiteModelSchema,
        ],
        directory: dir.path,
      );
    } catch (e) {
      // Xoá DB cũ nếu lỗi cấu trúc (Schema mismatch)
      final isarFile = File('${dir.path}/default.isar');
      final lockFile = File('${dir.path}/default.isar.lock');
      if (isarFile.existsSync()) isarFile.deleteSync();
      if (lockFile.existsSync()) lockFile.deleteSync();
      
      _instance = await Isar.open(
        [
          InstalledAppSchema,
          DatabaseRecordSchema,
          AppSettingsSchema,
          SiteModelSchema,
        ],
        directory: dir.path,
      );
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
