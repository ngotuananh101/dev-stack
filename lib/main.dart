import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_page.dart';

import 'shared/providers/navigation_provider.dart';
import 'shared/layouts/sidebar.dart';
import 'features/hosts/presentation/hosts_page.dart';
import 'features/apps/presentation/apps_page.dart';
import 'features/apps/data/apps_provider.dart';
import 'features/logs/presentation/logs_page.dart';
import 'features/databases/presentation/databases_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/sites/presentation/sites_page.dart';
import 'core/services/window_service.dart';
import 'core/services/ssl_service.dart';
import 'features/apps/data/app_installer_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'DevStack Dashboard',
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

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevStack Dashboard',
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
        await installer.reconfigureWebservers(apps, (msg) => debugPrint('SSL Sync: $msg'));
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
      case NavigationTab.dashboard:
        return const DashboardPage();
      case NavigationTab.apps:
        return const AppsPage();
      case NavigationTab.hosts:
        return const HostsPage();
      case NavigationTab.logs:
        return const LogsPage();
      case NavigationTab.databases:
        return const DatabasesPage();
      case NavigationTab.sites:
        return const SitesPage();
      case NavigationTab.settings:
        return const SettingsPage();
    }
  }
}
