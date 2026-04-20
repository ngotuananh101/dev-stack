import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../domain/app_model.dart';

part 'webserver_settings_provider.g.dart';

@riverpod
class WebserverSettings extends _$WebserverSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;

    if (app.appId.contains('nginx')) {
      return File(p.join(app.location!, 'conf', 'nginx.conf'));
    } else if (app.appId.contains('apache')) {
      // Handle both standard and Apache24 structure
      final stdPath = p.join(app.location!, 'conf', 'httpd.conf');
      final nestedPath = p.join(app.location!, 'Apache24', 'conf', 'httpd.conf');

      if (File(nestedPath).existsSync()) {
        return File(nestedPath);
      }
      return File(stdPath);
    }
    return null;
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
