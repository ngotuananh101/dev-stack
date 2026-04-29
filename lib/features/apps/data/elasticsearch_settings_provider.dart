import 'dart:io';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;


part 'elasticsearch_settings_provider.g.dart';

@riverpod
class ElasticsearchSettings extends _$ElasticsearchSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;
    return File(p.join(app.location!, 'config', 'elasticsearch.yml'));
  }

  Future<Map<String, dynamic>> readConfig(AppModel app) async {
    final file = _getConfigFile(app);

    // Default values
    final Map<String, dynamic> config = {
      'cluster.name': 'ponta-cluster',
      'node.name': 'ponta-node-1',
      'network.host': '127.0.0.1',
      'http.port': 9200,
      'discovery.type': 'single-node',
      'xpack.security.enabled': false,
      'ingest.geoip.downloader.enabled': false,
    };

    if (file == null || !await file.exists()) {
      return config;
    }

    try {
      final content = await file.readAsString();

      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          var value = parts.sublist(1).join(':').trim();

          // Remove quotes for strings
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          } else if (value.startsWith("'") && value.endsWith("'")) {
            value = value.substring(1, value.length - 1);
          }

          // Parse boolean/number
          if (value.toLowerCase() == 'true') {
            config[key] = true;
          } else if (value.toLowerCase() == 'false') {
            config[key] = false;
          } else {
            final numValue = num.tryParse(value);
            config[key] = numValue ?? value;
          }
        }
      }
      return config;
    } catch (_) {
      return config;
    }
  }

  Future<void> saveConfig(AppModel app, Map<String, dynamic> config) async {
    final file = _getConfigFile(app);
    if (file == null) return;

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    // Read existing to preserve paths
    final currentConfig = await readConfig(app);
    final mergedConfig = {...currentConfig, ...config};

    final buffer = StringBuffer();
    mergedConfig.forEach((key, value) {
      if (value is String) {
        // Always quote strings in YAML to be safe, especially paths
        buffer.writeln('$key: "$value"');
      } else {
        buffer.writeln('$key: $value');
      }
    });

    await file.writeAsString(buffer.toString());
  }
}
