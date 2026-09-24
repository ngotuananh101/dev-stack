import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/widgets/terminal_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TerminalLogView uses AppColors.surface when isModal is true', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TerminalLogView(
            title: 'Test Modal Terminal',
            lines: ['Line 1', 'Line 2'],
            isModal: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final modalContainerFinder = find.byWidgetPredicate(
      (w) => w is Container && (w.decoration is BoxDecoration) && (w.decoration as BoxDecoration).color == AppColors.surface,
    );
    expect(modalContainerFinder, findsWidgets);

    final container = tester.widget<Container>(modalContainerFinder.first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surface);
  });
}
