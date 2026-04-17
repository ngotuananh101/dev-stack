import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../domain/app_model.dart';

class AppsRepository {
  final Isar isar;

  AppsRepository(this.isar);

  Future<List<AppModel>> getAll() async {
    return await isar.appModels.where().findAll();
  }

  Future<void> importInitialData() async {
    try {
      // Check if data is already imported
      final count = await isar.appModels.count();
      if (count > 0) return;

      final String response = await rootBundle.loadString('assets/data/apps.json');
      final data = json.decode(response);
      final List appsJson = data['apps'];

      final apps = appsJson.map((json) {
        // Handle categories: can be String or List<String>
        List<String> categories = [];
        if (json['category'] is String) {
          categories = [json['category']];
        } else if (json['category'] is List) {
          categories = List<String>.from(json['category']);
        }

        return AppModel(
          appId: json['id'],
          name: json['name'],
          description: json['description'],
          developer: json['developer'] ?? 'official',
          categories: categories,
          groupName: json['group_name'],
          execFile: json['exec_file'],
          cliFile: json['cli_file'],
          versions: json['versions'] != null
              ? List<String>.from(json['versions'])
              : ['latest'],
          selectedVersion: json['selectedVersion'],
          price: json['price']?.toDouble(),
          expireDate: json['expireDate'],
          location: json['location'],
          status: json['status'],
          displayOnDashboard: json['displayOnDashboard'] ?? false,
          isInstalled: json['isInstalled'] ?? false,
        );
      }).toList();

      await isar.writeTxn(() async {
        await isar.appModels.putAll(apps);
      });
    } catch (e) {
      print('Error importing initial apps: $e');
    }
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
