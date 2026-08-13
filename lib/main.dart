import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:window_manager/window_manager.dart';
import 'core/config/app_config.dart';
import 'core/database/isar_provider.dart';
import 'core/theme/app_theme.dart';

import 'shared/providers/navigation_provider.dart';
import 'shared/layouts/sidebar.dart';
import 'features/apps/presentation/apps_page.dart';
import 'features/apps/data/apps_provider.dart';
import 'features/logs/presentation/logs_page.dart';
import 'features/databases/presentation/databases_page.dart';
import 'features/hosts/presentation/hosts_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/sites/presentation/sites_page.dart';
import 'core/services/window_service.dart';
import 'core/services/ssl_service.dart';
import 'features/apps/data/app_installer_service.dart';
import 'features/settings/domain/app_settings.dart';
import 'package:dev_stack/core/services/log_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted baseDir from Isar before anything else
  final isar = await IsarInstance.getInstance();
  final settings = await isar.appSettings.where().findFirst();
  if (settings != null) {
    AppConfig.initialize(baseDir: settings.baseDir);
  }

  await windowManager.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version;

  WindowOptions windowOptions = WindowOptions(
    size: const Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'DevStack v$appVersion',
  );

  final isMinimized = args.contains('--minimized');

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Set icon for the window taskbar
    await windowManager.setIcon('assets/images/icon.png');

    if (!isMinimized) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  runApp(ProviderScope(child: MyApp(appVersion: appVersion)));
}

class MyApp extends StatelessWidget {
  final String appVersion;
  const MyApp({super.key, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevStack v$appVersion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sslServiceProvider.notifier).initializeRootCA();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Initialize Window Service (Tray, Auto-start, etc.)
    ref.watch(windowServiceProvider);

    // Eagerly initialize apps provider for background services auto-start
    ref.watch(appsNotifierProvider.future);

    // Listen to SSL changes to reconfigure web servers
    ref.listen(sslServiceProvider, (previous, next) async {
      final nextValue = next.asData?.value;
      final prevValue = previous?.asData?.value;

      if (nextValue != null && prevValue != null && nextValue != prevValue) {
        final apps = await ref.read(appsNotifierProvider.future);
        final installer = ref.read(appInstallerServiceProvider);
        await installer.reconfigureWebservers(
          apps,
          (msg) => AppLogger.info('SSL Sync: $msg'),
        );
      }
    });

    final currentTab = ref.watch(navigationProvider);

    return Scaffold(
      body: Row(
        children: [
          Sidebar(),
          Expanded(child: _buildPage(currentTab)),
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
      case NavigationTab.hosts:
        return const HostsPage();
      case NavigationTab.settings:
        return const SettingsPage();
    }
  }
}
