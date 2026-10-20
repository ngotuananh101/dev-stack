import 'package:flutter/material.dart';
import 'package:dev_stack/shared/utils/action_row_layout.dart';
import 'package:dev_stack/shared/widgets/row_action_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  const actions = <RowAction>[
    RowAction.button('Run', null),
    RowAction.icon('Run History', null),
    RowAction.icon('Edit', null),
    RowAction.icon('Delete', null),
  ];

  Widget host(double availableWidth, List<RowAction> actions) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: availableWidth,
            // The menu gets its own budget from the box it is laid out in,
            // exactly as a table row passes its LayoutBuilder constraints.
            child: Builder(
              builder: (context) => RowActionMenu(
                actions: actions,
                availableWidth: availableWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders plain buttons when the cluster fits', (tester) async {
    await tester.pumpWidget(host(600, actions));

    expect(find.text('Run'), findsOneWidget);
    // Icons only appear as their icon buttons; no overflow menu yet.
    expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
  });

  testWidgets('collapses into one overflow button when it does not fit',
      (tester) async {
    await tester.pumpWidget(host(150, actions));

    expect(find.byIcon(LucideIcons.moreHorizontal), findsOneWidget);
    expect(find.text('Run'), findsNothing);
  });

  testWidgets('the overflow menu lists every action', (tester) async {
    await tester.pumpWidget(host(150, actions));
    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Run History'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a disabled action appears as a disabled menu item', (tester) async {
    await tester.pumpWidget(host(150, actions));

    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Run'), findsOneWidget);
    expect(tester.widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>).first).enabled, isFalse);
  });

  testWidgets('choosing a menu item fires its callback', (tester) async {
    var tapped = 0;
    final trackable = <RowAction>[
      RowAction.button('Run', () => tapped++),
      RowAction.icon('Edit', () => tapped++),
    ];

    await tester.pumpWidget(host(60, trackable));
    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('icon actions still fire their callbacks when shown inline',
      (tester) async {
    var tapped = 0;
    final trackable = <RowAction>[
      RowAction.icon('Edit', () => tapped++),
    ];

    await tester.pumpWidget(host(600, trackable));
    await tester.tap(find.byType(InkWell).last);
    await tester.pump();

    expect(tapped, 1);
  });
}
