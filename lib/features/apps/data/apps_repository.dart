import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../domain/app_model.dart';
import '../domain/installed_app.dart';

class AppsRepository {
  final Isar isar;

  AppsRepository(this.isar);

  Future<List<AppModel>> getAll() async {
    try {
      // 1. Load marketplace data from apps.json
      final String response = await rootBundle.loadString('assets/data/apps.json');
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
          developer: json['developer'] ?? 'official',
          categories: categories,
          groupName: json['group_name'],
          execFile: json['exec_file'],
          cliFile: json['cli_file'],
          versions: versionKeys.isNotEmpty ? versionKeys : ['latest'],
          versionLinksJson: jsonEncode(versionsMap),
          // Merge state from DB
          isInstalled: installed != null,
          location: installed?.location,
          status: installed?.status ?? 'not_installed',
          installedVersion: installed?.version,
          installedAt: installed?.installedAt,
        );
      }).toList();
    } catch (e) {
      print('Error loading apps: $e');
      return [];
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
      print('Error in importInitialData: $e');
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
      );
      await isar.installedApps.put(installed);
    });
  }

  Future<void> delete(String appId) async {
    await isar.writeTxn(() async {
      await isar.installedApps.filter().appIdEqualTo(appId).deleteAll();
    });
  }
}
