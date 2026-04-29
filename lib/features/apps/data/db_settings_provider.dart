import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

part 'db_settings_provider.g.dart';

@riverpod
class DbSettings extends _$DbSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;

    final id = app.appId.toLowerCase();
    if (id == 'phpmyadmin') {
      return File(
        '${app.location}${Platform.pathSeparator}config.inc.php',
      );
    }

    final isMariaDb =
        app.groupName == 'mariadb' || id.contains('mariadb');

    // MariaDB/MySQL put my.ini in the managed data directory
    if (isMariaDb || id.contains('mysql')) {
      final version = app.installedVersion ?? 'unknown';
      final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
      return File(p.join(dataDir, 'my.ini'));
    }

    final isPostgresql =
        app.groupName == 'postgresql' ||
        app.appId.toLowerCase().contains('postgresql');

    // PostgreSQL puts postgresql.conf in data directory
    if (isPostgresql) {
      final version = app.installedVersion ?? 'unknown';
      final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
      return File(p.join(dataDir, 'postgresql.conf'));
    }

    // Default fallback
    return File(p.join(app.location!, 'my.ini'));
  }

  Future<String> readConfig(AppModel app) async {
    final file = _getConfigFile(app);
    if (file == null || !await file.exists()) return '';
    return await file.readAsString();
  }

  Future<void> saveConfig(AppModel app, String content) async {
    final file = _getConfigFile(app);
    if (file == null) return;
    await file.writeAsString(content);
  }
}
