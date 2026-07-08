import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../domain/app_model.dart';
import '../../../core/config/app_config.dart';

part 'meilisearch_settings_provider.g.dart';

@riverpod
class MeilisearchSettings extends _$MeilisearchSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;
    return File(p.join(app.location!, 'config.toml'));
  }

  Future<Map<String, dynamic>> readConfig(AppModel app) async {
    final file = _getConfigFile(app);

    // Default values
    final defaultConfig = {
      'http_addr': '127.0.0.1:7700',
      'master_key': '',
      'env': 'development',
      'no_analytics': true,
      'db_path': p
          .join(AppConfig.dataDir, 'meilisearch', 'data.ms')
          .replaceAll('\\', '/'),
    };

    if (file == null || !await file.exists()) {
      return defaultConfig;
    }

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> config = Map.from(defaultConfig);

      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          var value = parts.sublist(1).join('=').trim();

          // Remove quotes for strings
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          } else if (value.startsWith("'") && value.endsWith("'")) {
            value = value.substring(1, value.length - 1);
          }

          // Parse boolean/number
          if (value == 'true') {
            config[key] = true;
          } else if (value == 'false') {
            config[key] = false;
          } else {
            final numValue = num.tryParse(value);
            config[key] = numValue ?? value;
          }
        }
      }
      return config;
    } catch (_) {
      return defaultConfig;
    }
  }

  Future<void> saveConfig(AppModel app, Map<String, dynamic> config) async {
    final file = _getConfigFile(app);
    if (file == null) return;

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final buffer = StringBuffer();
    config.forEach((key, value) {
      if (value is String) {
        buffer.writeln('$key = "$value"');
      } else {
        buffer.writeln('$key = $value');
      }
    });

    await file.writeAsString(buffer.toString());
  }
}
