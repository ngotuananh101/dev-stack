import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/apps/domain/app_model.dart';
import '../../features/apps/data/apps_provider.dart';
import '../../features/apps/data/app_service_manager.dart';
import '../../features/settings/data/settings_provider.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  Timer? _updateTimer;

  @override
  Future<void> build() async {
    windowManager.addListener(this);
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

  Future<void> _initSystemTray() async {
    // Lưu ý: system_tray sẽ tự động tìm kiếm trong assets bundle
    String iconPath = Platform.isWindows 
        ? 'assets/images/icon.ico' 
        : 'assets/images/icon.png';

    try {
      await _systemTray.initSystemTray(
        title: "DevStack",
        iconPath: iconPath,
      );

      await _menu.buildFrom([
        MenuItemLabel(label: 'Show Dashboard', onClicked: (menuItem) => windowManager.show()),
        MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
      ]);

      await _systemTray.setContextMenu(_menu);
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          Platform.isWindows ? windowManager.show() : _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          Platform.isWindows ? _systemTray.popUpContextMenu() : windowManager.show();
        }
      });
    } catch (e) {
      debugPrint('System tray initialization failed: $e');
    }
  }

  Future<void> _updateTrayMenu(List<AppModel> apps) async {
    // Debounce: Chỉ cập nhật menu sau 500ms kể từ thay đổi cuối cùng
    // để tránh việc rebuild menu quá nhanh gây mất callback
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 500), () async {
      final manager = ref.read(appServiceManagerProvider);
      final runningApps = apps.where((a) => a.isInstalled && a.isService && manager.isRunning(a.appId)).toList();

      List<MenuItemBase> menuItems = [
        MenuItemLabel(
          label: 'Show App', 
          onClicked: (menuItem) => windowManager.show(),
        ),
        MenuItemLabel(
          label: 'Quit', 
          onClicked: (menuItem) => exit(0),
        ),
        MenuSeparator(),
      ];

      // Running Services Section
      menuItems.add(MenuItemLabel(
        label: 'Running Services (${runningApps.length})',
        enabled: false,
      ));

      for (final app in runningApps) {
        final appId = app.appId;
        final appName = app.name;
        final version = app.installedVersion ?? "v?";
        
        // Header cho từng app
        menuItems.add(MenuItemLabel(
          label: ' ● $appName ($version)',
          enabled: false,
        ));

        // Nút Stop và Restart thụt lề
        menuItems.add(MenuItemLabel(
          label: '      Restart',
          onClicked: (m) {
            debugPrint('Tray: Restarting $appName');
            final currentApps = ref.read(appsNotifierProvider).valueOrNull ?? [];
            final targetApp = currentApps.firstWhere((a) => a.appId == appId);
            ref.read(appsNotifierProvider.notifier).restartService(targetApp);
          }
        ));
        menuItems.add(MenuItemLabel(
          label: '      Stop',
          onClicked: (m) {
            debugPrint('Tray: Stopping $appName');
            final currentApps = ref.read(appsNotifierProvider).valueOrNull ?? [];
            final targetApp = currentApps.firstWhere((a) => a.appId == appId);
            ref.read(appsNotifierProvider.notifier).stopService(targetApp);
          }
        ));
      }

      if (runningApps.isNotEmpty) {
        menuItems.add(MenuSeparator());
        menuItems.add(MenuItemLabel(
          label: 'Stop All Services',
          onClicked: (menuItem) {
            debugPrint('Tray: Stop All Services clicked');
            ref.read(appsNotifierProvider.notifier).stopAllServices();
          },
        ));
      }

      await _menu.buildFrom(menuItems);
      await _systemTray.setContextMenu(_menu);
    });
  }

  Future<void> _initAutoStart() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // Nếu appName trống (thường gặp khi debug), dùng tên mặc định
      String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : "DevStack";
      
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
