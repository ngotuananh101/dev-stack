import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../domain/app_model.dart';

part 'redis_settings_provider.g.dart';

@riverpod
class RedisSettings extends _$RedisSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;

    final location = app.location!;
    
    // Redis on Windows often uses redis.windows.conf or redis.conf
    final winPath = p.join(location, 'redis.windows.conf');
    final stdPath = p.join(location, 'redis.conf');

    if (File(winPath).existsSync()) {
      return File(winPath);
    }
    return File(stdPath);
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
