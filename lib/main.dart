import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nativeapi/nativeapi.dart' show Application;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/app_config.dart';
import 'core/database/isar_provider.dart';
import 'core/services/window_api.dart';
import 'core/theme/app_theme.dart';

import 'shared/providers/navigation_provider.dart';
import 'shared/providers/sidebar_provider.dart';
import 'shared/layouts/sidebar.dart';
import 'shared/layouts/app_header.dart';
import 'features/apps/presentation/apps_page.dart';
import 'features/apps/data/apps_provider.dart';
import 'features/logs/presentation/logs_page.dart';
import 'features/databases/presentation/databases_page.dart';
import 'features/hosts/presentation/hosts_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/sites/presentation/sites_page.dart';
import 'features/tunnels/presentation/tunnels_page.dart';
import 'features/tunnels/data/tunnels_provider.dart';
import 'features/supervisor/presentation/supervisor_page.dart';
import 'features/supervisor/data/supervisor_manager.dart';
import 'features/cron/presentation/cron_page.dart';
import 'features/cron/data/cron_scheduler_service.dart';
import 'features/tunnels/domain/tunnel_model.dart';
import 'core/services/window_service.dart';
import 'core/services/ssl_service.dart';
import 'core/services/linux_desktop_service.dart';
import 'features/apps/data/app_installer_service.dart';
import 'features/settings/domain/app_settings.dart';
import 'package:dev_stack/core/services/log_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    // Writes ~/.local/share/applications/<appId>.desktop and installs the
    // hicolor icon. On a first run that is a bundle read plus up to three
    // subprocesses (chmod, update-desktop-database, gtk-update-icon-cache),
    // and awaiting it here held the first frame back for all of it. Nothing
    // before the first build depends on the installed files: both the window
    // and the tray icon fall back to the bundled asset until
    // `_cachedIconPath` is filled in, so the work just runs alongside startup.
    unawaited(LinuxDesktopService.ensureDesktopIntegration());
  }

  // Load persisted baseDir from Isar before anything else
  final isar = await IsarInstance.getInstance();
  final settings = isar.appSettings.where().findFirst();
  if (settings != null) {
    AppConfig.initialize(baseDir: settings.baseDir);
  }

  // window_manager 0.6 has no `ensureInitialized`/`waitUntilReadyToShow`: the
  // window already exists by the time Dart runs (the runner creates it), so the
  // properties are simply set on it and `show()` decides when it becomes
  // visible. `whenCurrentWindow` waits for the window on the platforms where it
  // is not discoverable before it is shown (Windows looks the active window up);
  // with no window at all — a unit test — nothing here runs.
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version;
  final title = 'Ponta DevStack v$appVersion';

  final isMinimized = args.contains('--minimized');

  whenCurrentWindow((window) {
    // The header bar is drawn by AppHeader, so the native one goes away and the
    // window keeps no caption buttons of its own.
    //
    // On Linux that is the runner's job: it creates the window undecorated (see
    // `linux/runner/my_application.cc`). Setting the title bar style through
    // nativeapi there instead switches on its custom-shadow mode, and 0.5.10
    // gets the geometry of that mode wrong — the shadow gutter expands the
    // surface, but the input region it registers is offset by the gutter without
    // accounting for GDK's surface margin. The result is a dead band along the
    // right and bottom of the window: the caption buttons, refresh, pagination
    // and other page actions stop taking clicks. It also shrinks the window's
    // minimum size and paints an opaque band around the content.
    if (!Platform.isLinux) {
      window.titleBarStyle = TitleBarStyle.hidden;
      window.isWindowControlButtonsVisible = false;
    }
    window.title = title;
    window.setSize(const Size(1080, 720).toNative(), false);
    window.minimumSize = const Size(720, 520).toNative();
    window.backgroundColor = Colors.transparent.toNative();
    window.center();

    // The taskbar icon is an application property, not a window one. A relative
    // path is an asset path, which is only readable from the bundle the runner
    // copied next to the executable.
    Application.instance.setIcon(_resolveIconPath());

    // `--minimized` (auto-start) leaves the window hidden in the tray; the
    // runner's own first-frame show is what normally makes it visible.
    if (!isMinimized) {
      window.show();
      window.focus();
    }
  });

  runApp(ProviderScope(child: MyApp(appVersion: appVersion)));
}

/// Resolves [iconPath] to a path the native side can open.
///
/// The Linux resolver already returns an absolute path when it finds an
/// installed icon, but falls back to the bundled asset path, which is relative
/// to `data/flutter_assets` rather than to the working directory.
String _resolveIconPath() {
  final iconPath = Platform.isWindows
      ? 'assets/images/icon.ico'
      : (Platform.isLinux
            ? LinuxDesktopService.resolveIconPath()
            : 'assets/images/icon.png');
  if (File(iconPath).isAbsolute) return iconPath;

  final assetsDir = Directory(
    '${File(Platform.resolvedExecutable).parent.path}'
    '${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets',
  );
  return '${assetsDir.path}${Platform.pathSeparator}$iconPath';
}

class MyApp extends StatelessWidget {
  final String appVersion;
  const MyApp({super.key, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    // ToastificationWrapper must sit above MaterialApp: it installs the overlay
    // `toastification.show` draws into and lets that call work without being
    // handed a context (see AppDialogs).
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Ponta DevStack v$appVersion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: VirtualWindowFrameInit(),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize SSL Root CA if not already installed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(sslServiceProvider.notifier).initializeRootCA();

      // Auto-start tunnels with autoStart == true
      final isar = await IsarInstance.getInstance();
      final autoTunnels = isar.tunnelModels
          .where()
          .autoStartEqualTo(true)
          .findAll();
      for (final tunnel in autoTunnels) {
        ref.read(tunnelSessionsProvider.notifier).start(tunnel);
      }

      // Resolve the Isar provider first: the manager/scheduler resolve Isar
      // lazily, and a read before this future completes would see null and
      // silently start nothing.
      await ref.read(isarProvider.future);
      await ref.read(supervisorManagerProvider).startAutoStart();
      ref.read(cronSchedulerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initialize Window Service (Tray, Auto-start, etc.)
    ref.watch(windowServiceProvider);

    // Keep the supervisor and scheduler alive while the app is open.
    ref.watch(supervisorManagerProvider);
    ref.watch(cronSchedulerProvider);

    // Eagerly initialize apps provider for background services auto-start
    ref.watch(appsProvider.future);

    // Listen to SSL changes to reconfigure web servers
    ref.listen(sslServiceProvider, (previous, next) async {
      final nextValue = next.asData?.value;
      final prevValue = previous?.asData?.value;

      if (nextValue != null && prevValue != null && nextValue != prevValue) {
        final apps = await ref.read(appsProvider.future);
        final installer = ref.read(appInstallerServiceProvider);
        await installer.reconfigureWebservers(
          apps,
          (msg) => AppLogger.info('SSL Sync: $msg'),
        );
      }
    });

    final currentTab = ref.watch(navigationProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Narrow the window below this and the sidebar auto-collapses,
                // giving the page content room without horizontal scroll.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final collapsed = ref.read(sidebarCollapsedProvider);
                  final next = computeSidebarCollapse(
                    constraints.maxWidth,
                    collapsed,
                  );
                  if (next != collapsed) {
                    ref
                        .read(sidebarCollapsedProvider.notifier)
                        .setCollapsed(next);
                  }
                });
                return Row(
                  children: [
                    const Sidebar(),
                    Expanded(child: _buildPage(currentTab)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(NavigationTab tab) {
    switch (tab) {
      case NavigationTab.apps:
        return const AppsPage();
      case NavigationTab.sites:
        return const SitesPage();
      case NavigationTab.logs:
        return const LogsPage();
      case NavigationTab.databases:
        return const DatabasesPage();
      case NavigationTab.tunnels:
        return const TunnelsPage();
      case NavigationTab.supervisor:
        return const SupervisorPage();
      case NavigationTab.cron:
        return const CronPage();
      case NavigationTab.hosts:
        return const HostsPage();
      case NavigationTab.settings:
        return const SettingsPage();
    }
  }
}
