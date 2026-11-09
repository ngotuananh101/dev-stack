import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/apps_page.dart';
import 'package:dev_stack/features/apps/presentation/widgets/category_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// An apps list big enough that the category bar's natural width matters.
class _StaticAppsNotifier extends Apps {
  @override
  Future<List<AppModel>> build() async => [
    for (final category in ['runtime', 'database', 'storage'])
      AppModel(
        appId: category,
        name: category,
        categories: [category],
        isInstalled: false,
        status: 'installed',
      ),
  ];
}

void main() {
  testWidgets(
    'the marketplace header gives the category bar all the free width',
    (tester) async {
      // 840px is a window the app really allows. The header sits in AppsPage's
      // 32px padding, so the row is 776px wide.
      await tester.binding.setSurfaceSize(const Size(840, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appsProvider.overrideWith(_StaticAppsNotifier.new)],
          child: const MaterialApp(home: Scaffold(body: AppsPage())),
        ),
      );
      await tester.pumpAndSettle();

      final categoryBar = find.byType(CategoryBar);
      final barRect = tester.getRect(categoryBar);
      // The IconButton's own 48px tap target wraps the 40px glyph, so measure
      // the tap target: it is what sits against the header's right edge.
      final refreshRect = tester.getRect(find.byType(IconButton));

      // The bar must reach the refresh button, minus the 16px gap the header
      // reserves before it. A `Spacer` next to a `Flexible` splits the free
      // space in half instead, which leaves the bar floating mid-header and cuts
      // the categories at its right edge.
      expect(
        barRect.right,
        moreOrLessEquals(refreshRect.left - 16, epsilon: 0.5),
        reason:
            'the category bar must use all the width left of the refresh '
            'button, not half of it',
      );

      // Whether every pill fits is a question for the real font: the bar is a
      // horizontal scroller, and the test font's square glyphs are wider than
      // the app's, so measuring text here would not prove anything about the
      // real window.
    },
  );
}
