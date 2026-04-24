import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../../../core/database/isar_provider.dart';
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

  Future<void> updateField({
    String? siteTemplate,
    bool? autoCreateSite,
    bool? minimizeToTray,
    bool? autoStartWithWindows,
    bool? isSslInstalled,
  }) async {
    final currentSettings = state.value;
    if (currentSettings == null) return;

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
