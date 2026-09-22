import 'dart:io';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
// tray_manager 0.7.x moved the classic `trayManager` / `TrayListener` /
// `Menu` / `MenuItem` API to `legacy.dart`. This is the documented one-line
// migration path. The native replacement is a low-level FFI API
// (`package:nativeapi`) requiring a full rewrite of the tray wiring below,
// so we stay on the supported bridge for now. See TRAY_MIGRATION_TODO.
// ignore_for_file: deprecated_member_use
import 'package:tray_manager/legacy.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/apps/domain/app_model.dart';
import '../../features/apps/data/apps_provider.dart';
import '../../features/apps/data/app_service_manager.dart';
import '../../features/settings/data/settings_provider.dart';
import 'package:dev_stack/core/services/log_service.dart';
import '../../features/sites/data/cli_process_manager.dart';
import 'linux_desktop_service.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService with WindowListener, TrayListener {
  Timer? _updateTimer;

  @override
  Future<void> build() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    ref.onDispose(() {
      _updateTimer?.cancel();
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    });

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

    // Lắng nghe thay đổi của settings để cập nhật Auto-start
    ref.listen(settingsNotifierProvider, (previous, next) {
      if (next.hasValue) {
        _initAutoStart();
      }
    });

    // Khởi tạo menu và auto-start lần đầu
    final initialApps = ref.read(appsNotifierProvider).valueOrNull;
    if (initialApps != null) {
      _updateTrayMenu(initialApps);
    }
    _initAutoStart();
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
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final key = menuItem.key;
    if (key == null) return;

    if (key == 'show_app') {
      windowManager.show();
    } else if (key == 'quit_app') {
      // Dừng tất cả dịch vụ nhưng không lưu trạng thái (giữ nguyên auto-start)
      await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
      // Stop all CLI site processes so spawned dev servers are reaped on quit.
      await ref.read(cliProcessManagerProvider).stopAll();
      await windowManager.destroy();
    } else if (key == 'stop_all') {
      ref.read(appsNotifierProvider.notifier).stopAllServices();
    } else if (key.startsWith('stop:')) {
      final appId = key.substring(5);
      final apps = ref.read(appsNotifierProvider).valueOrNull ?? [];
      final app = apps.where((a) => a.appId == appId).firstOrNull;
      if (app == null) return;
      ref.read(appsNotifierProvider.notifier).stopService(app);
    } else if (key.startsWith('restart:')) {
      final appId = key.substring(8);
      final apps = ref.read(appsNotifierProvider).valueOrNull ?? [];
      final app = apps.where((a) => a.appId == appId).firstOrNull;
      if (app == null) return;
      ref.read(appsNotifierProvider.notifier).restartService(app);
    }
  }

  // --- Initialization ---

  Future<void> _initSystemTray() async {
    String iconPath = Platform.isWindows
        ? 'assets/images/icon.ico'
        : (Platform.isLinux
            ? LinuxDesktopService.resolveIconPath()
            : 'assets/images/icon.png');

    try {
      await trayManager.setIcon(iconPath);
      if (Platform.isWindows) {
        await trayManager.setToolTip('DevStack');
      }
    } catch (e) {
      AppLogger.error('Tray initialization failed: $e');
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
      items.add(MenuItem.separator());
      items.add(MenuItem(key: 'quit_app', label: 'Quit'));

      await trayManager.setContextMenu(Menu(items: items));
    });
  }

  Future<void> _initAutoStart() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : "Ponta DevStack";

      final appPath = Platform.isLinux
          ? (Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable)
          : Platform.resolvedExecutable;

      launchAtStartup.setup(
        appName: appName,
        appPath: appPath,
        args: ['--minimized'],
      );

      final settings = await ref.read(settingsNotifierProvider.future);
      if (settings.autoStartWithWindows) {
        await launchAtStartup.enable();
        AppLogger.info('Auto-start enabled with --minimized');
      } else {
        if (await launchAtStartup.isEnabled()) {
          await launchAtStartup.disable();
          AppLogger.info('Auto-start disabled');
        }
      }
    } catch (e) {
      AppLogger.error('Auto-start initialization failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    if (settings.minimizeToTray) {
      await windowManager.hide();
    } else {
      // Dừng tất cả dịch vụ nhưng không lưu trạng thái (giữ nguyên auto-start)
      await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
      // Stop all CLI site processes so spawned dev servers are reaped on exit.
      await ref.read(cliProcessManagerProvider).stopAll();
      await windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    // Force a redraw if needed
  }
}
