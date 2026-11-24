import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
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
import 'core/theme/app_radius.dart';

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
import 'features/sites/data/cli_process_manager.dart';
import 'features/sites/data/cli_site_autostart.dart';
import 'features/tunnels/presentation/tunnels_page.dart';
import 'features/tunnels/data/tunnels_provider.dart';
import 'features/supervisor/presentation/supervisor_page.dart';
import 'features/supervisor/data/supervisor_manager.dart';
import 'features/cron/presentation/cron_page.dart';
import 'features/cron/data/cron_scheduler_service.dart';
import 'features/tunnels/domain/tunnel_model.dart';
import 'core/services/window_service.dart';
import 'shared/utils/app_dialogs.dart';
import 'core/services/ssl_service.dart';
import 'core/services/linux_desktop_service.dart';
import 'core/security/app_http_overrides.dart';
import 'features/apps/data/app_installer_service.dart';
import 'features/settings/domain/app_settings.dart';
import 'package:dev_stack/core/services/log_service.dart';

void main() async {
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
  AppHttpOverrides.install(
    allowInsecureSsl: settings?.allowInsecureSsl ?? false,
  );

  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version;
  final title = 'Ponta DevStack v$appVersion';

  // The runners own the window's geometry, style, and visibility: both
  // create it at its final size, centered and frameless, and show it only
  // once the first frame is rendered (Linux: `linux/runner/my_application.cc`,
  // Windows: `windows/runner/main.cpp` + `win32_window.cpp`). Dart used to
  // resize, center, and show the window here, before the first frame, and
  // that dropped the first frame often enough to open a blank window until
  // the next resize — so this callback sets only what is neither geometry
  // nor visibility: the versioned title, the transparent background, and
  // the taskbar icon. `whenCurrentWindow` waits for the window on the
  // platforms where it is not discoverable before it is shown; with no
  // window at all — a unit test — nothing here runs.
  whenCurrentWindow((window) {
    window.title = title;
    window.backgroundColor = Colors.transparent.toNative();

    // The taskbar icon is an application property, not a window one. A relative
    // path is an asset path, which is only readable from the bundle the runner
    // copied next to the executable.
    Application.instance.setIcon(_resolveIconPath());
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
      // Startup never installs anything privileged on its own: the service
      // asks through this callback, and a \"no\" is remembered so the question
      // does not come back on every launch.
      //
      // Deliberately not awaited: this can wait on a dialog, and the tunnels,
      // supervisor and scheduler below must start regardless of how long the
      // user takes to answer.
      unawaited(
        ref
            .read(sslServiceProvider.notifier)
            .initializeRootCA(
              askPermission: (prompt) => AppDialogs.showPermissionRequest(
                context,
                title: prompt.title,
                message: prompt.message,
                command: prompt.command,
              ),
              onProgress: (progress) {
                // The install outlives any dialog the user may have closed, so
                // a late result must not reach a context that is already gone.
                if (!mounted) return;
                switch (progress.status) {
                  case InstallStatus.starting:
                    AppDialogs.showInfoToast(context, progress.message);
                  case InstallStatus.succeeded:
                    AppDialogs.showToast(context, progress.message);
                  case InstallStatus.failed:
                    AppDialogs.showError(
                      context,
                      title: 'SSL setup failed',
                      message: progress.message,
                    );
                }
              },
            ),
      );

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
      final isarDb = await ref.read(isarProvider.future);

      // Start auto-start CLI sites from the boot path. Their vhost reverse
      // proxies to `127.0.0.1:<port>` as soon as the webserver starts, so
      // leaving this to the (autoDispose) Sites provider meant 502s until the
      // Sites tab was opened — a Vite dev server showed it most clearly.
      await startAutoStartCliSites(
        isar: isarDb,
        manager: ref.read(cliProcessManagerProvider),
        logger: ref.read(logServiceProvider),
      );

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
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.md),
                          bottomLeft: Radius.circular(AppRadius.md),
                        ),
                        child: _buildPage(currentTab),
                      ),
                    ),
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
