import 'dart:io';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';

part 'rustfs_settings_provider.g.dart';

@riverpod
class RustFSSettings extends _$RustFSSettings {
  @override
  void build() {}

  File _getConfigFile() {
    return File(p.join(AppConfig.dataDir, 'rustfs', 'config.json'));
  }

  Future<Map<String, dynamic>> readConfig() async {
    final file = _getConfigFile();
    if (!await file.exists()) {
      return {
        'address': ':9000',
        'console_address': ':9001',
        'access_key': 'rustfsadmin',
        'secret_key': 'rustfsadmin',
        'console_enable': true,
      };
    }
    try {
      final content = await file.readAsString();
      return json.decode(content);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = _getConfigFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(json.encode(config));
  }
}
