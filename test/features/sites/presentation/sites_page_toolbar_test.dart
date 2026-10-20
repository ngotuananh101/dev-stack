import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/sites_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticSitesNotifier extends Sites {
  @override
  Future<List<SiteModel>> build() async => [];
}

void main() {
  testWidgets('sites toolbar wraps its buttons and shrinks the search field',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sitesProvider.overrideWith(_StaticSitesNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: SitesPage())),
      ),
    );
    await tester.pumpAndSettle();

    // No RenderFlex overflow reaching this point is the proof the toolbar fits
    // a narrow window instead of pushing its search field out of reach.
    expect(tester.takeException(), isNull);

    final searchWidth = tester.getSize(find.byType(TextField).first).width;
    expect(searchWidth, lessThan(280));
    expect(find.text('Add Site'), findsOneWidget);
  });
}
