import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'package:dev_stack/features/databases/presentation/databases_page.dart';
import 'package:dev_stack/features/sites/data/sites_provider.dart';
import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/sites_page.dart';
import 'package:dev_stack/shared/widgets/page_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticSitesNotifier extends Sites {
  @override
  Future<List<SiteModel>> build() async => [];
}

class _StaticDatabasesNotifier extends Databases {
  @override
  Future<List<DatabaseRecord>> build() async => [];

  @override
  Future<void> fetchByEngine(String engineAppId) async {
    state = const AsyncValue.data([]);
  }
}

/// One installed database engine, so the databases page renders its toolbar
/// instead of the empty state.
class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => [
    AppModel(
      appId: 'mysql',
      name: 'MySQL',
      categories: const ['database'],
      isInstalled: true,
      status: 'installed',
      installedVersion: '8.0.0',
    ),
  ];
}

/// Every toolbar that ends in a search field must pin that field to the right
/// edge, not leave it floating in the middle of the row.
///
/// A `Row` splits free space evenly between every flex child, so pairing
/// `Flexible(searchField)` with `Expanded(toolbar)` gives the field only half
/// the leftover width: the toolbar cannot grow past its buttons, so the other
/// half is a dead gap, and the field stops short of the window edge.
void main() {
  void expectFieldHugsRightEdge(
    WidgetTester tester, {
    required String page,
    required double rightPadding,
  }) {
    final field = tester.getRect(find.byType(TextField).first);
    final pageRect = tester.getRect(find.byType(Scaffold).first);
    expect(
      field.right,
      moreOrLessEquals(pageRect.right - rightPadding, epsilon: 0.5),
      reason: 'the $page search field must sit at the right edge of the page',
    );
    // Sitting at the right edge alone is not enough: a field that was squeezed
    // and one that simply ends there both pass that check. The field must also
    // keep the design's width, which a half-share of the free space does not.
    expect(
      field.width,
      moreOrLessEquals(PageToolbar.maxSearchWidth, epsilon: 0.5),
      reason:
          'the $page search field must keep its full width at this window '
          'size, not a share of the leftover space',
    );
  }

  testWidgets('the sites search field hugs the right edge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(840, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sitesProvider.overrideWith(_StaticSitesNotifier.new)],
        child: const MaterialApp(home: Scaffold(body: SitesPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expectFieldHugsRightEdge(tester, page: 'sites', rightPadding: 24);
  });

  testWidgets('the databases search field hugs the right edge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith(_StaticAppsNotifier.new),
          databasesProvider.overrideWith(_StaticDatabasesNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DatabasesPage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    // The toolbar only renders when an engine is installed; this test installs
    // one, so an empty page here would mean the test silently stopped covering
    // the toolbar.
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: 'the databases toolbar must render for the test to measure it',
    );
    expectFieldHugsRightEdge(tester, page: 'databases', rightPadding: 24);
  });
}
