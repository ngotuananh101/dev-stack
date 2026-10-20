import 'package:dev_stack/features/sites/domain/site_model.dart';
import 'package:dev_stack/features/sites/presentation/widgets/site_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  SiteModel site(String domain) => SiteModel(
        id: 1,
        domain: domain,
        rootDir: '/srv',
        siteType: 'php',
        phpVersion: '8.3',
      );

  Widget host(List<SiteModel> sites) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Expanded(
                  child: SiteTable(
                    sites: sites,
                    selectedIds: const {},
                    onEdit: (_) {},
                    onToggleSelection: (_) {},
                    onToggleAll: (_) {},
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  testWidgets('header and rows line up on the same columns at a wide window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1163, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([site('alpha.test'), site('beta.test')]));
    await tester.pumpAndSettle();

    final typeHeaderX = tester.getTopLeft(find.text('TYPE')).dx;
    final typeRowX = tester.getTopLeft(find.text('PHP 8.3').last).dx;
    expect(typeRowX, closeTo(typeHeaderX, 1),
        reason: 'the type cell starts where the TYPE header starts');
  });

  testWidgets('survives a ~412px row without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([site('alpha.test')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
