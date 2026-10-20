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
  Widget host(Widget page) => ProviderScope(
        overrides: [appsProvider.overrideWith(_StaticAppsNotifier.new)],
        child: MaterialApp(home: Scaffold(body: page)),
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
    for (final size in const [
      kMinimumWindowSize,
      // The sidebar is 240px wide until the window drops below the collapse
      // breakpoint, so the page only gets 480px of content in a 720px window
      // — but it gets even less when the sidebar is open and the window is
      // just above the breakpoint.
      Size(1000, 700),
      Size(1400, 900),
    ]) {
      testWidgets(
          'the ${entry.key} page lays out at ${size.width}x${size.height}',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        await tester.pumpWidget(host(entry.value));
        // A fixed number of frames rather than pumpAndSettle: some pages run a
        // perpetual animation, which would never let the tree settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // A RenderFlex overflow is thrown as an exception, so a null
        // exception is the proof that the page fits the window.
        expect(tester.takeException(), isNull,
            reason: 'the ${entry.key} page must not overflow at '
                '${size.width}x${size.height}');
      });
    }
  }
}
