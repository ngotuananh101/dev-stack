import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/apps/domain/app_model.dart';
import '../../features/apps/data/apps_provider.dart';
import '../../features/apps/data/app_service_manager.dart';
import '../../features/settings/data/settings_provider.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService with WindowListener, TrayListener {
  Timer? _updateTimer;

  @override
  Future<void> build() async {
    windowManager.addListener(this);
    trayManager.addListener(this);

    // Prevent app from closing when X is pressed, we will handle it in onWindowClose
    await windowManager.setPreventClose(true);

    await _initSystemTray();
    await _initAutoStart();

    // Lắng nghe thay đổi của apps để cập nhật Menu Tray
    ref.listen(appsNotifierProvider, (previous, next) {
      if (next.hasValue) {
        _updateTrayMenu(next.value!);
      }
    });

    // Khởi tạo menu lần đầu
    final initialApps = ref.read(appsNotifierProvider).valueOrNull;
    if (initialApps != null) {
      _updateTrayMenu(initialApps);
    }
  }

  // --- Tray Events ---

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == null) return;

    if (key == 'show_app') {
      windowManager.show();
    } else if (key == 'quit_app') {
      exit(0);
    } else if (key == 'stop_all') {
      ref.read(appsNotifierProvider.notifier).stopAllServices();
    } else if (key.startsWith('stop:')) {
      final appId = key.substring(5);
      final apps = ref.read(appsNotifierProvider).valueOrNull ?? [];
      final app = apps.firstWhere((a) => a.appId == appId);
      ref.read(appsNotifierProvider.notifier).stopService(app);
    } else if (key.startsWith('restart:')) {
      final appId = key.substring(8);
      final apps = ref.read(appsNotifierProvider).valueOrNull ?? [];
      final app = apps.firstWhere((a) => a.appId == appId);
      ref.read(appsNotifierProvider.notifier).restartService(app);
    }
  }

  // --- Initialization ---

  Future<void> _initSystemTray() async {
    String iconPath = Platform.isWindows
        ? 'assets/images/icon.ico'
        : 'assets/images/icon.png';

    try {
      await trayManager.setIcon(iconPath);
      if (Platform.isWindows) {
        await trayManager.setToolTip('DevStack');
      }
    } catch (e) {
      debugPrint('Tray initialization failed: $e');
    }
  }

  Future<void> _updateTrayMenu(List<AppModel> apps) async {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 500), () async {
      final manager = ref.read(appServiceManagerProvider);
      final runningApps = apps
          .where(
            (a) => a.isInstalled && a.isService && manager.isRunning(a.appId),
          )
          .toList();

      List<MenuItem> items = [
        MenuItem(key: 'show_app', label: 'Show App'),
        MenuItem(key: 'quit_app', label: 'Quit'),
        MenuItem.separator(),
      ];

      items.add(
        MenuItem(
          label: 'Running Services (${runningApps.length})',
          disabled: true,
        ),
      );

      for (final app in runningApps) {
        final appId = app.appId;
        final appName = app.name;

        items.add(
          MenuItem.submenu(
            key: 'app_$appId',
            label: appName,
            submenu: Menu(
              items: [
                MenuItem(key: 'restart:$appId', label: 'Restart'),
                MenuItem(key: 'stop:$appId', label: 'Stop'),
              ],
            ),
          ),
        );
      }

      items.add(MenuItem.separator());
      items.add(
        MenuItem(
          key: 'stop_all',
          label: 'Stop All Services',
          disabled: runningApps.isEmpty,
        ),
      );

      await trayManager.setContextMenu(Menu(items: items));
    });
  }

  Future<void> _initAutoStart() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // Nếu appName trống (thường gặp khi debug), dùng tên mặc định
      String appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : "DevStack";

      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );

      final settings = await ref.read(settingsNotifierProvider.future);
      if (settings.autoStartWithWindows) {
        await launchAtStartup.enable();
      } else {
        // Chỉ gọi disable nếu cần thiết để tránh lỗi Noop
        if (await launchAtStartup.isEnabled()) {
          await launchAtStartup.disable();
        }
      }
    } catch (e) {
      debugPrint('Auto-start initialization failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    if (settings.minimizeToTray) {
      await windowManager.hide();
    } else {
      exit(0);
    }
  }

  @override
  void onWindowFocus() {
    // Force a redraw if needed
  }
}
