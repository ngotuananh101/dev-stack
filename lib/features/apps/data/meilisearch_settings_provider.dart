import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

part 'meilisearch_settings_provider.g.dart';

@riverpod
class MeilisearchSettings extends _$MeilisearchSettings {
  @override
  void build() {}

  File _getConfigFile() {
    return File(p.join(AppConfig.dataDir, 'meilisearch', 'config.toml'));
  }

  Future<Map<String, dynamic>> readConfig() async {
    final file = _getConfigFile();
    if (!await file.exists()) {
      final defaultConfig = {
        'http_addr': '127.0.0.1:7700',
        'master_key': 'meilisearch_master_key',
        'env': 'development',
        'no_analytics': true,
        'db_path': p.join(AppConfig.dataDir, 'meilisearch', 'data.ms').replaceAll('\\', '/'),
      };
      await saveConfig(defaultConfig);
      return defaultConfig;
    }

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> config = {
        'http_addr': '127.0.0.1:7700',
        'master_key': 'meilisearch_master_key',
        'env': 'development',
        'no_analytics': true,
        'db_path': p.join(AppConfig.dataDir, 'meilisearch', 'data.ms').replaceAll('\\', '/'),
      };
      
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
      return {};
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = _getConfigFile();
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
