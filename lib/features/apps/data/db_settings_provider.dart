import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_model.dart';

part 'db_settings_provider.g.dart';

@riverpod
class DbSettings extends _$DbSettings {
  @override
  void build() {}

  File? _getMyIni(AppModel app) {
    if (app.location == null) return null;
    
    final isMariaDb = app.groupName == 'mariadb' || 
                      app.appId.toLowerCase().contains('mariadb');
    
    // MariaDB puts my.ini in data directory
    if (isMariaDb) {
      return File('${app.location}${Platform.pathSeparator}data${Platform.pathSeparator}my.ini');
    }
    
    // MySQL (and others) usually put it in the root directory
    return File('${app.location}${Platform.pathSeparator}my.ini');
  }

  Future<String> readConfig(AppModel app) async {
    final file = _getMyIni(app);
    if (file == null || !await file.exists()) return '';
    return await file.readAsString();
  }

  Future<void> saveConfig(AppModel app, String content) async {
    final file = _getMyIni(app);
    if (file == null) return;
    await file.writeAsString(content);
  }
}
