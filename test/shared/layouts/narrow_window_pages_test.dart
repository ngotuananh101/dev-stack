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

/// The window's minimum size, as set in `main.dart`.
const Size kMinimumWindowSize = Size(720, 520);

class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => const [];
}

void main() {
  // The real layout is a sidebar next to the page, so the page only gets the
  // window width minus the sidebar's. Reproducing both here makes the test
  // measure the width the page really has.
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
    for (final scenario in const [
      // The narrowest window the app allows, with the sidebar folded away.
      (size: kMinimumWindowSize, collapsed: true),
      // A window just above the collapse breakpoint, with the sidebar still
      // open: the page gets the least room of any realistic layout.
      (size: Size(1000, 700), collapsed: false),
      (size: Size(1400, 900), collapsed: false),
    ]) {
      final label = '${scenario.size.width}x${scenario.size.height}'
          '${scenario.collapsed ? ' collapsed' : ''}';
      testWidgets('the ${entry.key} page lays out at $label', (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        await tester.pumpWidget(
          host(entry.value, sidebarCollapsed: scenario.collapsed),
        );
        // A fixed number of frames rather than pumpAndSettle: some pages run a
        // perpetual animation, which would never let the tree settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // A RenderFlex overflow is thrown as an exception, so a null exception
        // is the proof that the page fits the window.
        expect(tester.takeException(), isNull,
            reason: 'the ${entry.key} page must not overflow at $label');
      });
    }
  }
}

/// A sidebar state that is fixed instead of user-toggleable.
class _StaticSidebar extends SidebarCollapsed {
  _StaticSidebar({required this.collapsed});

  final bool collapsed;

  @override
  bool build() => collapsed;
}
