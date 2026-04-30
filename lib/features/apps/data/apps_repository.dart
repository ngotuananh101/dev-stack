import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../domain/app_model.dart';
import '../domain/installed_app.dart';

class AppsRepository {
  final Isar isar;

  AppsRepository(this.isar);

  Future<List<AppModel>> getAll() async {
    try {
      // 1. Load marketplace data
      String response;
      final supportDir = await getApplicationSupportDirectory();
      final localFile = File(p.join(supportDir.path, 'apps.json'));

      if (await localFile.exists()) {
        debugPrint('Loading apps from local storage: ${localFile.path}');
        response = await localFile.readAsString();
      } else {
        debugPrint('Loading apps from assets bundle');
        response = await rootBundle.loadString('assets/data/apps.json');
      }

      final data = json.decode(response);
      final List appsJson = data['apps'];

      // 2. Load installed apps from Isar
      final installedApps = await isar.installedApps.where().findAll();
      final installedMap = {for (var a in installedApps) a.appId: a};

      // 3. Merge definitions with installation state
      return appsJson.map((json) {
        final appId = json['id'];
        final installed = installedMap[appId];
        
        List<String> categories = [];
        if (json['category'] is String) {
          categories = [json['category']];
        } else if (json['category'] is List) {
          categories = List<String>.from(json['category']);
        }

        final versionsMap = json['versions'] as Map<String, dynamic>? ?? {};
        final versionKeys = versionsMap.keys.toList();

        return AppModel(
          appId: appId,
          name: json['name'],
          description: json['description'],
          categories: categories,
          groupName: json['group_name'],
          execFile: json['exec_file'],
          cliFile: json['cli_file'],
          versions: versionKeys.isNotEmpty ? versionKeys : ['latest'],
          versionLinksJson: jsonEncode(versionsMap),
          defaultUsername: json['default_username'],
          defaultPassword: json['default_password'],
          // Merge state from DB
          isInstalled: installed != null,
          location: installed?.location,
          status: installed?.status ?? 'not_installed',
          installedVersion: installed?.version,
          installedAt: installed?.installedAt,
          execFilePath: installed?.execFilePath,
          cliFilePath: installed?.cliFilePath,
          isAddedToPath: installed?.addedToPath ?? false,
          autoStartService: installed?.autoStartService ?? false,
          isDefault: installed?.isDefault ?? false,
        );
      }).toList().cast<AppModel>();
    } catch (e, stack) {
      debugPrint('Error loading apps: $e\n$stack');
      
      // If it's a RangeError or corruption, try to delete local cache to force a fresh load next time
      if (e is RangeError || e.toString().contains('RangeError')) {
        try {
          final supportDir = await getApplicationSupportDirectory();
          final localFile = File(p.join(supportDir.path, 'apps.json'));
          if (await localFile.exists()) {
            await localFile.delete();
            debugPrint('Deleted corrupted apps.json');
          }
        } catch (err) {
          debugPrint('Failed to delete corrupted apps.json: $err');
        }
      }
      
      rethrow; // Rethrow so the UI can show the error
    }
  }

  Future<void> importInitialData() async {
    // This is where we "clear" the old DB or perform initialization
    // For a clean start as requested:
    try {
      await isar.writeTxn(() async {
        // Clear collections if needed, but the user wants to start fresh
        // Isar will use the new schema automatically since we registered it
      });
    } catch (e) {
      debugPrint('Error in importInitialData: $e');
    }
  }

  Future<void> save(AppModel app) async {
    await isar.writeTxn(() async {
      final installed = InstalledApp(
        appId: app.appId,
        appName: app.name,
        location: app.location ?? '',
        status: app.status ?? 'not_installed',
        version: app.installedVersion,
        installedAt: app.installedAt ?? DateTime.now(),
        execFilePath: app.execFilePath,
        cliFilePath: app.cliFilePath,
        addedToPath: app.isAddedToPath,
        autoStartService: app.autoStartService,
        groupName: app.groupName,
        isDefault: app.isDefault,
      );
      await isar.installedApps.put(installed);
    });
  }

  Future<void> setDefaultPhp(String appId) async {
    await isar.writeTxn(() async {
      // 1. Find the target app
      final target = await isar.installedApps.filter().appIdEqualTo(appId).findFirst();
      if (target == null) return;

      // 2. Unset all other apps in the same group (e.g., PHP versions)
      if (target.groupName != null) {
        final groupApps = await isar.installedApps.filter().groupNameEqualTo(target.groupName).findAll();
        for (final app in groupApps) {
          if (app.appId != appId && app.isDefault) {
            app.isDefault = false;
            await isar.installedApps.put(app);
          }
        }
      }

      // 3. Set target as default
      target.isDefault = true;
      await isar.installedApps.put(target);
    });
  }
  Future<void> delete(String appId) async {
    await isar.writeTxn(() async {
      await isar.installedApps.filter().appIdEqualTo(appId).deleteAll();
    });
  }

  Future<void> updateAppListFromUrl(String url) async {
    try {
      final dio = Dio();
      final response = await dio.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        final jsonString = data is String ? data : jsonEncode(data);
        
        // Save to local support directory for runtime persistence
        final supportDir = await getApplicationSupportDirectory();
        final localFile = File(p.join(supportDir.path, 'apps.json'));
        await localFile.writeAsString(jsonString);
        
        // Also try to update the source file if in dev mode
        try {
          // This is a heuristic to find the project root during development
          final currentDir = Directory.current.path;
          final projectFile = File(p.join(currentDir, 'assets', 'data', 'apps.json'));
          if (await projectFile.exists()) {
            await projectFile.writeAsString(jsonString);
            debugPrint('Successfully updated project source file: ${projectFile.path}');
          }
        } catch (e) {
          debugPrint('Could not update source file (expected in production): $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating app list: $e');
      rethrow;
    }
  }
}
