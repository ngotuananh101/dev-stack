import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as p;
import '../domain/app_model.dart';

part 'mongodb_settings_provider.g.dart';

@riverpod
class MongodbSettings extends _$MongodbSettings {
  @override
  void build() {}

  File? _getConfigFile(AppModel app) {
    if (app.location == null) return null;

    final location = app.location!;
    
    // MongoDB on Windows often uses bin/mongod.cfg or mongod.cfg (sometimes .conf)
    final binPath = p.join(location, 'bin', 'mongod.cfg');
    final rootPath = p.join(location, 'mongod.cfg');
    final rootConfPath = p.join(location, 'mongod.conf');

    if (File(binPath).existsSync()) return File(binPath);
    if (File(rootPath).existsSync()) return File(rootPath);
    return File(rootConfPath);
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
