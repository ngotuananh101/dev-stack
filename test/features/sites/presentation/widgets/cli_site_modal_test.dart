import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:dev_stack/features/sites/presentation/widgets/edit_site_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A no-op replacement for [AppsNotifier] that resolves instantly to an empty
/// app list, so [AddSiteModal] / [EditSiteModal] can build without touching the
/// real database.
class _EmptyAppsNotifier extends AppsNotifier {
  @override
  Future<List<AppModel>> build() => Future.value(<AppModel>[]);
}

void main() {
  testWidgets('AddSiteModal shows CLI App type option and presets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsNotifierProvider.overrideWith(() => _EmptyAppsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddSiteModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLI App'), findsOneWidget);

    // Tap CLI App button
    await tester.tap(find.text('CLI App'));
    await tester.pumpAndSettle();

    expect(find.text('Start Command'), findsOneWidget);
    expect(find.text('Internal Port'), findsOneWidget);
    expect(find.text('Preset'), findsOneWidget);
  });

  testWidgets('EditSiteModal shows CLI App inputs and preset auto-fill',
      (tester) async {
    // The modal is a 1000x800 Dialog; make the surface tall/wide enough to
    // avoid layout overflow on the small default 800x600 test surface.
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    final site = SiteModel(
      id: 1,
      domain: 'cli-app.test',
      rootDir: '/projects/cli-app',
      siteType: 'cli',
      command: 'npm run dev',
      port: 3000,
      autoStart: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsNotifierProvider.overrideWith(() => _EmptyAppsNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditSiteModal(site: site, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The CLI type option is rendered (selected by default for a cli site) ...
    expect(find.text('CLI App'), findsOneWidget);
    // ... and the whole CLI form block is shown.
    expect(find.text('Preset'), findsOneWidget);
    expect(find.text('Node.js (npm)'), findsOneWidget);
    expect(find.text('Start Command'), findsOneWidget);
    expect(find.text('Internal Port'), findsOneWidget);
    expect(find.text('Auto-start on launch'), findsOneWidget);
    // Fields are pre-filled from the SiteModel.
    expect(find.text('npm run dev'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);

    // Switching the preset auto-fills the command + port from the preset.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bun').last);
    await tester.pumpAndSettle();
    expect(find.text('npm run dev'), findsNothing);
    expect(find.text('bun dev'), findsOneWidget);
  });
}
