import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton renders label, icon and fires onPressed', (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Save',
            icon: const Icon(Icons.check),
            size: AppButtonSize.md,
            style: AppButtonStyle.primary,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.height, 36.0);

    await tester.tap(find.text('Save'));
    expect(pressed, true);
  });

  testWidgets('AppButton renders loading indicator when isLoading is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('AppButton applies custom backgroundColor and textColor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Install',
            onPressed: () {},
            backgroundColor: Colors.green,
            textColor: Colors.white,
          ),
        ),
      ),
    );

    expect(find.text('Install'), findsOneWidget);

    final material = tester.widget<Material>(find
        .descendant(
          of: find.byType(AppButton),
          matching: find.byType(Material),
        )
        .first);
    expect(material.color, Colors.green);
  });

  testWidgets('AppButton disabled state uses muted text color with custom colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Disabled',
            onPressed: null,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          ),
        ),
      ),
    );

    expect(find.text('Disabled'), findsOneWidget);

    final material = tester.widget<Material>(find
        .descendant(
          of: find.byType(AppButton),
          matching: find.byType(Material),
        )
        .first);
    expect(material.color, Colors.green.withValues(alpha: 0.5));

    final text = tester.widget<Text>(find.text('Disabled'));
    expect(text.style!.color, AppColors.textMuted);
  });
}
