import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../domain/app_model.dart';

class AppsRepository {
  final Isar isar;

  AppsRepository(this.isar);

  Future<List<AppModel>> getAll() async {
    try {
      // 1. Load fresh data from apps.json
      final String response = await rootBundle.loadString('assets/data/apps.json');
      final data = json.decode(response);
      final List appsJson = data['apps'];

      // 2. Load all from Isar to merge state
      final isarApps = await isar.appModels.where().findAll();
      final isarMap = {for (var a in isarApps) a.appId: a};

      // 3. Map JSON to AppModel and merge state
      return appsJson.map((json) {
        final appId = json['id'];
        final existing = isarMap[appId];
        
        // Handle categories: can be String or List<String>
        List<String> categories = [];
        if (json['category'] is String) {
          categories = [json['category']];
        } else if (json['category'] is List) {
          categories = List<String>.from(json['category']);
        }

        final versionsMap = json['versions'] as Map<String, dynamic>? ?? {};
        final versionKeys = versionsMap.keys.toList();

        if (existing != null) {
          // Update definition from JSON, keep state from Isar
          existing.name = json['name'];
          existing.description = json['description'];
          existing.developer = json['developer'] ?? 'official';
          existing.categories = categories;
          existing.groupName = json['group_name'];
          existing.execFile = json['exec_file'];
          existing.cliFile = json['cli_file'];
          existing.versions = versionKeys.isNotEmpty ? versionKeys : ['latest'];
          existing.versionLinksJson = jsonEncode(versionsMap);
          return existing;
        } else {
          // Create new with default state
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
          );
        }
      }).toList();
    } catch (e) {
      print('Error loading apps from JSON: $e');
      // Fallback to Isar only if JSON fails
      return await isar.appModels.where().findAll();
    }
  }

  Future<void> importInitialData() async {
    // We now load dynamically in getAll(), but we still want to ensure
    // that basic state is persisted if we want to change anything.
    // For now, getAll() handles the heavy lifting.
  }

  Future<void> save(AppModel app) async {
    await isar.writeTxn(() async {
      await isar.appModels.put(app);
    });
  }

  Future<void> delete(Id id) async {
    await isar.writeTxn(() async {
      await isar.appModels.delete(id);
    });
  }
}
