import 'dart:io';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// window_manager 0.6 re-exports nativeapi's windowing API; the tray and window
// types here all come from nativeapi, so this file names its source directly
// instead of going through the re-export.
import 'package:nativeapi/nativeapi.dart';
// `ImageAsset.fromAsset` lives in `nativeapi_flutter` since nativeapi 0.4;
// the tray icon still resolves its image through it.
import 'package:nativeapi_flutter/nativeapi_flutter.dart' show ImageAsset;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/apps/domain/app_model.dart';
import '../../features/apps/data/apps_provider.dart';
import '../../features/apps/data/app_service_manager.dart';
import '../../features/settings/data/settings_provider.dart';
import 'package:dev_stack/core/services/log_service.dart';
import '../../features/sites/data/cli_process_manager.dart';
import '../../features/supervisor/data/supervisor_manager.dart';
import '../../features/cron/data/cron_scheduler_service.dart';
import 'linux_desktop_service.dart';
import 'window_api.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService {
  Timer? _updateTimer;
  TrayIcon? _trayIcon;
  Image? _trayIconImage;
  ListenerId? _trayListenerId;
  _TrayMenu? _trayMenu;
  ListenerId? _windowListenerId;

  /// True while a quit this app started is closing the window, so the close
  /// listener lets the request through instead of hiding to the tray.
  bool _isQuitting = false;

  @override
  Future<void> build() async {
    // Close requests reach only the window's own listeners. Registering there
    // is how 0.6 replaces `setPreventClose(true)` + `onWindowClose`: the request
    // is deferred until this callback finishes, so a cancelled request keeps the
    // window open and an accepted one closes it.
    //
    // `whenCurrentWindow` is what makes this reliable on Windows, where the
    // window is not discoverable until the runner shows it on the first frame.
    whenCurrentWindow((window) {
      _windowListenerId = window.addListener(_onWindowEvent);
    });

    ref.onDispose(() {
      _updateTimer?.cancel();

      final windowListenerId = _windowListenerId;
      if (windowListenerId != null) {
        currentWindow()?.removeListener(windowListenerId);
      }
      _windowListenerId = null;

      final listenerId = _trayListenerId;
      if (listenerId != null) {
        _trayIcon?.removeListener(listenerId);
      }
      _trayListenerId = null;

      _trayMenu?.dispose();
      _trayMenu = null;

      _trayIcon?.dispose();
      _trayIcon = null;
      _trayIconImage?.dispose();
      _trayIconImage = null;
    });

    _initSystemTray();
    await _initAutoStart();

    // Lắng nghe thay đổi của apps để cập nhật Menu Tray
    ref.listen(appsProvider, (previous, next) {
      if (next.hasValue) {
        _updateTrayMenu(next.value!);
      }
    });

    // Lắng nghe thay đổi của settings để cập nhật Auto-start
    ref.listen(settingsProvider, (previous, next) {
      if (next.hasValue) {
        _initAutoStart();
      }
    });

    // Khởi tạo menu và auto-start lần đầu
    final initialApps = ref.read(appsProvider).value;
    if (initialApps != null) {
      _updateTrayMenu(initialApps);
    }
    _initAutoStart();
  }

  // --- Tray ---

  void _initSystemTray() {
    String iconPath = Platform.isWindows
        ? 'assets/images/icon.ico'
        : (Platform.isLinux
            ? LinuxDesktopService.resolveIconPath()
            : 'assets/images/icon.png');

    try {
      final icon = TrayIcon.create();
      if (icon == null) {
        AppLogger.error('Tray initialization failed: TrayIcon.create() returned null');
        return;
      }
      _trayIcon = icon;

      // ImageAsset.fromAsset resolves a bundled asset against
      // Platform.resolvedExecutable; Image.fromFile covers the absolute paths
      // the Linux resolver returns. Same lookup order the legacy bridge used.
      final image = ImageAsset.fromAsset(iconPath) ?? Image.fromFile(iconPath);
      if (image != null) {
        icon.icon = image;
        // The wrapper owns the native handle and frees it when collected, so it
        // has to stay reachable for as long as the tray icon does.
        _trayIconImage = image;
      }

      if (Platform.isWindows) {
        icon.setTooltip('DevStack');
      }

      // Linux renders the tray through StatusNotifierItem over D-Bus, where
      // there is no manual popup: OpenContextMenu() is a no-op returning false,
      // and the host only shows an exported menu when a trigger is set. The
      // native backend exposes the menu (property Menu = /StatusNotifierItem/Menu,
      // ItemIsMenu = true) only for ContextMenuTrigger.clicked; any other value
      // leaves Menu = "/" and the host sees an empty menu, so clicking the icon
      // shows nothing. On GNOME's AppIndicator extension a left click toggles
      // that exported menu, so `clicked` is what makes the menu appear.
      if (Platform.isLinux) {
        icon.setContextMenuTrigger(ContextMenuTrigger.clicked);
      }
      icon.setVisible(true);

      // nativeapi reports whole clicks. The legacy bridge replayed each click as
      // mouseDown + mouseUp, and only the "down" half was ever implemented here,
      // so handling the click event directly preserves the old behaviour.
      //
      // Each handler goes through `Timer.run` for the same trampoline reason
      // documented on `_TrayMenu.addAction`.
      _trayListenerId = icon.addListener((event) {
        switch (event) {
          case TrayIconClickedEvent():
            Timer.run(_showWindow);
          case TrayIconRightClickedEvent():
            Timer.run(icon.openContextMenu);
          case TrayIconDoubleClickedEvent():
            break; // legacy was a no-op too
        }
      });
    } catch (e) {
      AppLogger.error('Tray initialization failed: $e');
    }
  }

  void _updateTrayMenu(List<AppModel> apps) {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 500), () {
      final icon = _trayIcon;
      if (icon == null) return;

      // Unlike the legacy Menu constructors, nativeapi's Menu.create() and
      // MenuItem.createWithLabelAndType() return null on failure and _TrayMenu
      // turns that into a StateError. This runs in a Timer callback, where an
      // escaping exception is an unhandled async error, so catch it the same way
      // _initSystemTray and _initAutoStart do.
      try {
        final manager = ref.read(appServiceManagerProvider);
        final runningApps = apps
            .where(
              (a) => a.isInstalled && a.isService && manager.isRunning(a.appId),
            )
            .toList();

        final menu = _TrayMenu();
        menu.addAction('Show App', _showWindow);
        menu.addSeparator();
        menu.addLabel('Running Services (${runningApps.length})');

        for (final app in runningApps) {
          menu.addSubmenu(app.name, (submenu) {
            submenu.addAction('Restart', () => _restartService(app));
            submenu.addAction('Stop', () => _stopService(app));
          });
        }

        menu.addSeparator();
        menu.addAction(
          'Stop All Services',
          () => ref.read(appsProvider.notifier).stopAllServices(),
          enabled: runningApps.isNotEmpty,
        );
        menu.addSeparator();
        menu.addAction('Quit', _quit);

        final previous = _trayMenu;
        _trayMenu = menu;
        icon.setContextMenu(menu.root);

        // A click callback runs inside the clicked item's own native callback, so
        // the outgoing menu has to outlive the call that replaces it.
        if (previous != null) {
          Timer.run(previous.dispose);
        }
      } catch (e) {
        AppLogger.error('Tray menu update failed: $e');
      }
    });
  }

  Future<void> _quit() async {
    _isQuitting = true;
    await _stopEverything();
    _closeWindow();
  }

  /// Brings the window back from the tray.
  ///
  /// `show()` alone leaves a minimized window minimized, so a window the user
  /// minimized rather than hid would stay out of sight.
  void _showWindow() {
    final window = currentWindow();
    if (window == null) return;
    if (window.isMinimized) window.restore();
    window.show();
    window.focus();
  }

  /// Closes the window for good, past the tray preference.
  ///
  /// A close request the app starts itself still travels through the window's
  /// close listeners, so [_isQuitting] is what makes [_onWindowEvent] accept it.
  void _closeWindow() {
    _isQuitting = true;
    final window = currentWindow();
    if (window == null) {
      // No native window to close (nothing to put the request through); end the
      // process instead, which is what closing the last window does anyway.
      Application.instance.quit(0);
      return;
    }
    window.close();
  }

  Future<void> _stopService(AppModel app) =>
      ref.read(appsProvider.notifier).stopService(app);

  Future<void> _restartService(AppModel app) =>
      ref.read(appsProvider.notifier).restartService(app);

  // --- Auto start ---

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

      final settings = await ref.read(settingsProvider.future);
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

  /// Handles the window events this service cares about.
  ///
  /// The return type matters: nativeapi keeps a close request pending until the
  /// listener's future completes, and accepts it when it does. Returning
  /// [_handleCloseRequest] is therefore what defers the close until the tray
  /// preference has been read.
  FutureOr<void> _onWindowEvent(WindowEvent event) {
    switch (event) {
      case WindowCloseRequestedEvent():
        return _handleCloseRequest(event.request);
      default:
        break;
    }
  }

  /// Decides what the title bar's close button does.
  ///
  /// The tray preference is read asynchronously, hence the Future: the request
  /// is held until the answer is in, then accepted by simply returning, or
  /// cancelled and answered with a hide / a full shutdown.
  Future<void> _handleCloseRequest(EventRequest request) async {
    // A close this app started itself (`_closeWindow`) is already the decision.
    if (_isQuitting) return;

    final settings = await ref.read(settingsProvider.future);
    if (_isQuitting) return;

    if (settings.minimizeToTray) {
      request.cancel();
      currentWindow()?.hide();
      return;
    }

    // Not minimizing to the tray means the close really quits — but only after
    // the services are down, so the window is kept open for now and closed
    // again once the teardown has finished.
    request.cancel();
    await _stopEverything();
    // Let this event finish dispatching first: closing the window from inside
    // its own close callback would re-enter a close that is still pending.
    Timer.run(_closeWindow);
  }

  /// Tears down everything the app started, in the order that guarantees no
  /// child outlives the process.
  Future<void> _stopEverything() async {
    // Dừng tất cả dịch vụ nhưng không lưu trạng thái (giữ nguyên auto-start)
    await ref.read(appsProvider.notifier).stopAllServicesQuietly();
    // Stop all CLI site processes so spawned dev servers are reaped on quit.
    await ref.read(cliProcessManagerProvider).stopAll();
    // Reap supervised programs and stop the in-app cron scheduler.
    await ref.read(supervisorManagerProvider).stopAll();
    ref.read(cronSchedulerProvider).stop();
    // The window is about to be destroyed: the trees are killed synchronously
    // so a child cannot outlive the app that started it.
    ref.read(cliProcessManagerProvider).stopAllSync();
    ref.read(supervisorManagerProvider).shutdown();
  }
}

/// Owns every native wrapper created for one context menu.
///
/// `nativeapi` wrappers free their native handle when collected, and a listener
/// only outlives the wrapper it was registered on — so the menu, its items, and
/// their listener ids all have to stay reachable until the menu is replaced.
///
/// This mirrors the ownership pattern in `tray_manager`'s own `NativeMenuBinding`,
/// which is the reference implementation for wrapping this API. Two details from
/// it that matter here:
///
///  * `Menu.dispose()` does **not** free the items added to it, so items and
///    menus each need their own dispose pass. Skipping either leaks.
///  * Listeners are removed before anything is disposed, because a callback can
///    still fire while its item is alive.
///
/// The one deliberate difference: `NativeMenuBinding` keeps a single flat list
/// of menus and items across the whole tree, while this holder nests a child
/// `_TrayMenu` per submenu and disposes depth-first. Both free every wrapper
/// exactly once — the native handles are independent, so the order among them
/// does not matter — but nesting keeps each submenu's wrappers together, which
/// makes the structure easier to read than three parallel flat lists.
class _TrayMenu {
  _TrayMenu() {
    final menu = Menu.create();
    if (menu == null) {
      throw StateError('Unable to create the tray context menu');
    }
    root = menu;
    _menus.add(menu);
  }

  late final Menu root;

  final List<Menu> _menus = <Menu>[];
  final List<MenuItem> _items = <MenuItem>[];
  final List<_TrayMenu> _submenus = <_TrayMenu>[];
  final List<(MenuItem, ListenerId)> _listeners = <(MenuItem, ListenerId)>[];

  /// Adds a clickable row. The action is captured in the closure, which is why
  /// the old string-key dispatch protocol (`'stop:<appId>'`) is gone: a
  /// `nativeapi.MenuItem` has no key.
  MenuItem addAction(
    String label,
    void Function() action, {
    bool enabled = true,
  }) {
    final item = _newItem(label, MenuItemType.normal);
    item.isEnabled = enabled;
    _listeners.add((
      item,
      item.addListener((event) {
        if (event is MenuItemClickedEvent) {
          // `isolateLocal` runs this listener synchronously inside the native
          // trampoline, on the platform thread. The trampoline returns to
          // native the instant `action` suspends at its first `await`, and the
          // continuation is queued as a *microtask*. Flutter only drains that
          // queue after a task runs on the UI task runner (or after a frame),
          // so with nothing else scheduled the action simply stops — and while
          // the window is hidden there are no frames to flush it either. That
          // is why Quit did nothing until the window was shown again.
          //
          // Starting the work from the event loop instead makes the first
          // suspension happen inside a real task, so the microtask queue is
          // drained the moment that task returns.
          Timer.run(action);
        }
      }),
    ));
    root.addItem(item);
    return item;
  }

  /// A disabled row used as a heading, e.g. "Running Services (2)".
  void addLabel(String label) {
    final item = _newItem(label, MenuItemType.normal);
    item.isEnabled = false;
    root.addItem(item);
  }

  void addSubmenu(String label, void Function(_TrayMenu submenu) build) {
    final item = _newItem(label, MenuItemType.submenu);
    final submenu = _TrayMenu();
    build(submenu);
    item.submenu = submenu.root;
    _submenus.add(submenu);
    root.addItem(item);
  }

  void addSeparator() => root.addSeparator();

  MenuItem _newItem(String label, MenuItemType type) {
    final item = MenuItem.createWithLabelAndType(label, type);
    if (item == null) {
      throw StateError('Unable to create the tray menu item "$label"');
    }
    _items.add(item);
    return item;
  }

  void dispose() {
    for (final (item, listenerId) in _listeners) {
      item.removeListener(listenerId);
    }
    _listeners.clear();
    // Children first: a submenu's items and menu are freed before the item that
    // owns them, and every wrapper is disposed exactly once.
    for (final submenu in _submenus) {
      submenu.dispose();
    }
    _submenus.clear();
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    for (final menu in _menus) {
      menu.dispose();
    }
    _menus.clear();
  }
}
