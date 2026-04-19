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
import 'core/theme/app_text_size.dart';

void main() async {
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
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
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

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize apps provider for background services auto-start
    ref.watch(appsNotifierProvider.future);
    
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
      default:
        return Center(
          child: Text(
            '${tab.name.toUpperCase()} feature coming soon...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTextSize.sm,
            ),
          ),
        );
    }
  }
}
