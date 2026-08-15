import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../domain/app_model.dart';

part 'webserver_settings_provider.g.dart';

File? webserverConfigFileFor(AppModel app) {
  if (app.location == null) return null;
  final appId = app.appId.toLowerCase();
  final location = app.location!;

  if (appId.contains('nginx')) {
    return File(p.join(location, 'conf', 'nginx.conf'));
  }
  if (appId.contains('caddy')) {
    return File(p.join(location, 'Caddyfile'));
  }
  if (appId.contains('apache')) {
    final nestedPath = p.join(location, 'Apache24', 'conf', 'httpd.conf');
    if (File(nestedPath).existsSync()) return File(nestedPath);
    return File(p.join(location, 'conf', 'httpd.conf'));
  }
  return null;
}

@riverpod
class WebserverSettings extends _$WebserverSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) => webserverConfigFileFor(app);

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
