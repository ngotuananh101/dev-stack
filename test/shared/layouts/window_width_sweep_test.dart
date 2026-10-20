import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/apps_page.dart';
import 'package:dev_stack/features/cron/presentation/cron_page.dart';
import 'package:dev_stack/features/databases/presentation/databases_page.dart';
import 'package:dev_stack/features/hosts/presentation/hosts_page.dart';
import 'package:dev_stack/features/logs/presentation/logs_page.dart';
import 'package:dev_stack/features/settings/presentation/settings_page.dart';
import 'package:dev_stack/features/sites/presentation/sites_page.dart';
import 'package:dev_stack/features/supervisor/presentation/supervisor_page.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:dev_stack/shared/layouts/sidebar.dart';
import 'package:dev_stack/shared/providers/sidebar_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => const [];
}

/// A sidebar state that is fixed instead of user-toggleable.
class _StaticSidebar extends SidebarCollapsed {
  _StaticSidebar({required this.collapsed});

  final bool collapsed;

  @override
  bool build() => collapsed;
}

void main() {
  Widget host(Widget page, {required bool sidebarCollapsed}) =>
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(_StaticAppsNotifier.new),
          sidebarCollapsedProvider.overrideWith(
            () => _StaticSidebar(collapsed: sidebarCollapsed),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const Sidebar(),
                Expanded(child: page),
              ],
            ),
          ),
        ),
      );

  final pages = <String, Widget>{
    'apps': const AppsPage(),
    'sites': const SitesPage(),
    'databases': const DatabasesPage(),
    'tunnels': const TunnelsPage(),
    'supervisor': const SupervisorPage(),
    'cron': const CronPage(),
    'logs': const LogsPage(),
    'hosts': const HostsPage(),
    'settings': const SettingsPage(),
  };

  for (final entry in pages.entries) {
    testWidgets('the ${entry.key} page fits every window width', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      // The window can be resized to any width, so every width must work. The
      // sidebar folds below the collapse breakpoint and is open above it, so
      // both states are checked at every width.
      final failures = <String>[];
      for (var width = 720; width <= 1600; width += 20) {
        for (final collapsed in [true, false]) {
          await tester.binding.setSurfaceSize(Size(width.toDouble(), 700));
          await tester.pumpWidget(
            host(entry.value, sidebarCollapsed: collapsed),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final error = tester.takeException();
          if (error != null) {
            failures.add(
              '${width}px ${collapsed ? 'collapsed' : 'expanded'}: $error',
            );
          }
        }
      }

      expect(failures, isEmpty,
          reason: 'the ${entry.key} page must fit every window width');
    });
  }
}
