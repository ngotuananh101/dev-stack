import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../../../core/config/app_config.dart';
import '../../../core/services/background_process.dart';
import '../domain/app_model.dart';

part 'webserver_settings_provider.g.dart';

File? webserverConfigFileFor(AppModel app, {bool? isLinux}) {
  if (app.location == null) return null;
  final appId = app.appId.toLowerCase();
  final location = app.location!;
  final onLinux = isLinux ?? Platform.isLinux;

  if (appId.contains('nginx')) {
    return File(p.join(location, 'conf', 'nginx.conf'));
  }
  if (appId.contains('caddy')) {
    return File(p.join(location, 'Caddyfile'));
  }
  if (appId.contains('apache')) {
    if (onLinux) {
      final isolatedConf =
          File(p.join(AppConfig.vhostsDir, 'apache', 'httpd.conf'));
      if (isolatedConf.existsSync()) return isolatedConf;
      return File(p.join(location, 'conf', 'httpd.conf'));
    }
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
    await BackgroundProcess.writeStringElevated(file.path, content);
  }
}
