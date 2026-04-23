import 'dart:io';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/settings/data/settings_provider.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  @override
  Future<void> build() async {
    windowManager.addListener(this);
    // Prevent app from closing when X is pressed, we will handle it in onWindowClose
    await windowManager.setPreventClose(true);
    
    await _initSystemTray();
    await _initAutoStart();
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
