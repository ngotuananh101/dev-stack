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

    // Check candidate config files (Valkey / Redis Linux & Windows)
    final candidates = [
      p.join(location, 'valkey.conf'),
      p.join(location, 'redis.conf'),
      p.join(location, 'redis.windows.conf'),
    ];

    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) {
        return file;
      }
    }

    // Default fallback
    return File(Platform.isWindows ? candidates[2] : candidates[1]);
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
