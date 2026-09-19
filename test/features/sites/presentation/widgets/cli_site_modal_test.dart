import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/add_site_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A no-op replacement for [AppsNotifier] that resolves instantly to an empty
/// app list, so [AddSiteModal] can build without touching the real database.
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
}
