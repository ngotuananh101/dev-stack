import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../../../core/database/isar_provider.dart';
import '../../apps/domain/installed_app.dart';
import '../../sites/domain/site_model.dart';
import '../domain/app_settings.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    final isar = await ref.watch(isarProvider.future);
    
    try {
      final settings = await isar.appSettings.where().findFirst();
      
      if (settings == null) {
        // Initialize default settings
        final defaultSettings = AppSettings();
        await isar.writeTxn(() async {
          await isar.appSettings.put(defaultSettings);
        });
        return defaultSettings;
      }
      
      return settings;
    } catch (e) {
      debugPrint('Error reading AppSettings, resetting to default: $e');
      // If reading fails (e.g. RangeError due to schema mismatch), clear and reset
      await isar.writeTxn(() async {
        await isar.appSettings.clear();
        final defaultSettings = AppSettings();
        await isar.appSettings.put(defaultSettings);
        return defaultSettings;
      });
      return AppSettings();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      await isar.appSettings.put(newSettings);
    });
    state = AsyncData(newSettings);
  }

  /// Migrate all data from oldDir to newDir:
  /// 1. Copy all files recursively
  /// 2. Rewrite paths inside config files (.conf, .cfg, .ini, .bat, etc.)
  /// 3. Update absolute paths stored in Isar DB (InstalledApp, SiteModel)
  /// 4. Update Windows User PATH environment variable
  Future<bool> migrateBaseDir(String oldDir, String newDir) async {
    try {
      final source = Directory(oldDir);
      final target = Directory(newDir);

      if (!source.existsSync()) {
        debugPrint('Source directory does not exist: $oldDir');
        return false;
      }

      if (!target.existsSync()) {
        await target.create(recursive: true);
      }

      // Step 1: Copy all files
      debugPrint('Migration Step 1/4: Copying files...');
      await _copyDirectory(source, target);

      // Step 2: Rewrite paths in config files
      debugPrint('Migration Step 2/4: Rewriting config file paths...');
      await _rewriteConfigPaths(target, oldDir, newDir);

      // Step 3: Update paths in Isar database
      debugPrint('Migration Step 3/4: Updating database records...');
      await _rewriteDbPaths(oldDir, newDir);

      // Step 4: Update Windows User PATH
      debugPrint('Migration Step 4/4: Updating Windows PATH...');
      await _rewriteWindowsPath(oldDir, newDir);

      debugPrint('Migration completed successfully.');
      return true;
    } catch (e) {
      debugPrint('Migration failed: $e');
      return false;
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list(recursive: false)) {
      final newPath = '${target.path}\\${entity.uri.pathSegments.last}';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(newPath);
        if (!newDir.existsSync()) {
          await newDir.create(recursive: true);
        }
        await _copyDirectory(entity, newDir);
      }
    }
  }

  /// Config file extensions that may contain hardcoded paths.
  static const _configExtensions = [
    '.conf',  // nginx, apache vhosts
    '.cfg',   // mongod.cfg
    '.ini',   // php.ini
    '.bat',   // shim scripts in bin/
    '.html',  // index.html with paths
    '.yaml',  // possible config files
    '.yml',   // possible config files
  ];

  /// Scan all config files in [dir] and replace old paths with new paths.
  /// Handles both Windows backslash and Unix forward-slash path formats.
  Future<void> _rewriteConfigPaths(
    Directory dir,
    String oldDir,
    String newDir,
  ) async {
    // Prepare both backslash and forward-slash variants
    final oldBackslash = oldDir;                              // C:\Ponta
    final newBackslash = newDir;                              // D:\MyStack
    final oldForwardSlash = oldDir.replaceAll('\\', '/');     // C:/Ponta
    final newForwardSlash = newDir.replaceAll('\\', '/');     // D:/MyStack

    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;

      final ext = entity.path.substring(
        entity.path.lastIndexOf('.') == -1
            ? entity.path.length
            : entity.path.lastIndexOf('.'),
      ).toLowerCase();

      if (!_configExtensions.contains(ext)) continue;

      try {
        String content = await entity.readAsString();
        bool modified = false;

        // Replace forward-slash paths (nginx/apache config style)
        if (content.contains(oldForwardSlash)) {
          content = content.replaceAll(oldForwardSlash, newForwardSlash);
          modified = true;
        }

        // Replace backslash paths (Windows style, php.ini, bat files)
        if (content.contains(oldBackslash)) {
          content = content.replaceAll(oldBackslash, newBackslash);
          modified = true;
        }

        if (modified) {
          await entity.writeAsString(content);
          debugPrint('Rewrote paths in: ${entity.path}');
        }
      } catch (e) {
        // Skip binary or unreadable files
        debugPrint('Skipping file (unreadable): ${entity.path}');
      }
    }
  }

  /// Update all absolute paths stored in the Isar database.
  /// Covers InstalledApp (location, execFilePath, cliFilePath) and
  /// SiteModel (rootDir) records.
  Future<void> _rewriteDbPaths(String oldDir, String newDir) async {
    final isar = await ref.read(isarProvider.future);

    // Update InstalledApp records
    final apps = await isar.installedApps.where().findAll();
    if (apps.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final app in apps) {
          bool modified = false;

          if (app.location.contains(oldDir)) {
            app.location = app.location.replaceAll(oldDir, newDir);
            modified = true;
          }
          if (app.execFilePath != null && app.execFilePath!.contains(oldDir)) {
            app.execFilePath = app.execFilePath!.replaceAll(oldDir, newDir);
            modified = true;
          }
          if (app.cliFilePath != null && app.cliFilePath!.contains(oldDir)) {
            app.cliFilePath = app.cliFilePath!.replaceAll(oldDir, newDir);
            modified = true;
          }

          if (modified) {
            await isar.installedApps.put(app);
            debugPrint('Updated DB paths for app: ${app.appId}');
          }
        }
      });
    }

    // Update SiteModel records
    final sites = await isar.siteModels.where().findAll();
    if (sites.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final site in sites) {
          if (site.rootDir.contains(oldDir)) {
            site.rootDir = site.rootDir.replaceAll(oldDir, newDir);
            await isar.siteModels.put(site);
            debugPrint('Updated DB paths for site: ${site.domain}');
          }
        }
      });
    }
  }

  /// Update Windows User PATH environment variable:
  /// Replace old bin dir with new bin dir, and update env vars like PYENV.
  Future<void> _rewriteWindowsPath(String oldDir, String newDir) async {
    try {
      // Read current User PATH
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '[Environment]::GetEnvironmentVariable("Path", "User")',
      ]);

      if (result.exitCode == 0) {
        final currentPath = (result.stdout as String).trim();
        if (currentPath.contains(oldDir)) {
          final newPath = currentPath.replaceAll(oldDir, newDir);
          await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            '[Environment]::SetEnvironmentVariable("Path", "$newPath", "User")',
          ]);
          debugPrint('Updated User PATH: replaced $oldDir → $newDir');
        }
      }

      // Update PYENV-related env vars
      for (final envVar in ['PYENV', 'PYENV_HOME', 'PYENV_ROOT']) {
        final envResult = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '[Environment]::GetEnvironmentVariable("$envVar", "User")',
        ]);

        if (envResult.exitCode == 0) {
          final envValue = (envResult.stdout as String).trim();
          if (envValue.isNotEmpty && envValue.contains(oldDir)) {
            final newEnvValue = envValue.replaceAll(oldDir, newDir);
            await Process.run('powershell', [
              '-NoProfile',
              '-Command',
              '[Environment]::SetEnvironmentVariable("$envVar", "$newEnvValue", "User")',
            ]);
            debugPrint('Updated env var $envVar: $envValue → $newEnvValue');
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to update Windows PATH: $e');
      // Non-fatal — user can fix PATH manually
    }
  }

  Future<void> updateField({
    String? baseDir,
    String? siteTemplate,
    bool? autoCreateSite,
    bool? minimizeToTray,
    bool? autoStartWithWindows,
    bool? isSslInstalled,
  }) async {
    final currentSettings = state.value;
    if (currentSettings == null) return;

    if (baseDir != null) currentSettings.baseDir = baseDir;
    if (siteTemplate != null) currentSettings.siteTemplate = siteTemplate;
    if (autoCreateSite != null) currentSettings.autoCreateSite = autoCreateSite;
    if (minimizeToTray != null) currentSettings.minimizeToTray = minimizeToTray;
    if (autoStartWithWindows != null) {
      currentSettings.autoStartWithWindows = autoStartWithWindows;
      try {
        if (autoStartWithWindows) {
          await launchAtStartup.enable();
        } else {
          if (await launchAtStartup.isEnabled()) {
            await launchAtStartup.disable();
          }
        }
      } catch (e) {
        debugPrint('Failed to toggle auto-start: $e');
      }
    }
    if (isSslInstalled != null) currentSettings.isSslInstalled = isSslInstalled;

    await updateSettings(currentSettings);
  }
}
