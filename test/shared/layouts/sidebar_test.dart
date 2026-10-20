import 'package:dev_stack/shared/layouts/sidebar.dart';
import 'package:dev_stack/shared/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Widget host() => ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: const Row(
              children: [
                Sidebar(),
                Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      );

  testWidgets('starts expanded at 240px with every nav label visible',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Sidebar)).width, 240);
    expect(find.text('Apps'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byIcon(LucideIcons.panelLeftClose), findsOneWidget);
  });

  testWidgets('collapses to 64px, keeps icons and tooltips', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Sidebar)).width, 64);
    expect(find.text('Apps'), findsNothing);
    expect(
      tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((tooltip) => tooltip.message),
      contains('Apps'),
    );
    expect(find.byIcon(LucideIcons.panelLeftOpen), findsOneWidget);
  });

  testWidgets('expands again from collapsed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.panelLeftOpen));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Sidebar)).width, 240);
    expect(find.text('Apps'), findsOneWidget);
  });

  testWidgets('nav still switches tabs while collapsed', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      find.byType(Sidebar).evaluate().first,
      listen: false,
    );
    expect(container.read(navigationProvider), NavigationTab.apps);

    await tester.tap(find.byIcon(LucideIcons.panelLeftClose));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cron'));
    await tester.pumpAndSettle();

    expect(container.read(navigationProvider), NavigationTab.cron);
  });
}
