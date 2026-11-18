import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/apps_page.dart';
import 'package:dev_stack/features/cron/presentation/cron_page.dart';
import 'package:dev_stack/features/supervisor/presentation/supervisor_page.dart';
import 'package:dev_stack/features/tunnels/presentation/tunnels_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page's title is the one place the app goes a step above its body size,
/// and it goes exactly one step: [AppTextSize.sm]. A larger title is how the
/// header of every page ended up taller than the rows beneath it.
///
/// The settings page is not here: it cannot render without an initialized
/// database, and its title is set from the same token as the rest.
class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => const [];
}

void main() {
  final pages = <String, (Widget, String)>{
    'apps': (const AppsPage(), 'Marketplace'),
    'tunnels': (const TunnelsPage(), 'Tunnels'),
    'supervisor': (const SupervisorPage(), 'Supervisor'),
    'cron': (const CronPage(), 'Cron'),
  };

  for (final entry in pages.entries) {
    final (page, title) = entry.value;

    testWidgets('the ${entry.key} page title reads at AppTextSize.sm', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      // The scope sits directly under pumpWidget on purpose: a scope
      // returned from a helper counts as nested, and the lint then demands
      // the overridden providers declare dependencies.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appsProvider.overrideWith(_StaticAppsNotifier.new)],
          child: MaterialApp(home: Scaffold(body: page)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final heading = tester.widget<Text>(find.text(title));
      expect(heading.style?.fontSize, AppTextSize.sm);
      expect(heading.style?.fontWeight, FontWeight.bold);
    });
  }
}
