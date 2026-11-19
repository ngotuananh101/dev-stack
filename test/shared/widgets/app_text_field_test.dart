import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_radius.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/widgets/app_text_field.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTextField renders prefix icon, hint, and handles input', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            hint: 'Enter domain name',
            prefixIcon: Icons.language,
          ),
        ),
      ),
    );

    expect(find.text('Enter domain name'), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'myapp.test');
    expect(controller.text, 'myapp.test');
  });

  testWidgets('AppTextField displays validation error message', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              controller: controller,
              hint: 'Port',
              validator: (v) =>
                  v == null || v.isEmpty ? 'Port is required' : null,
            ),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pumpAndSettle();

    expect(find.text('Port is required'), findsOneWidget);
  });

  for (final enabled in [true, false]) {
    testWidgets('AppTextField dims only hints (enabled: $enabled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              hint: 'Enter value',
              prefixIcon: Icons.search,
              enabled: enabled,
            ),
          ),
        ),
      );

      void expectHintColor() {
        final hint = find.text('Enter value');
        final text = tester.widget<Text>(hint);
        final style = DefaultTextStyle.of(
          tester.element(hint),
        ).style.merge(text.style);
        expect(style.color, const Color(0x59FFFFFF));
        expect(style.fontSize, AppTextSize.xs);
      }

      expectHintColor();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.style?.color,
        enabled ? AppColors.textPrimary : AppColors.textMuted,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.search)).color,
        AppColors.textMuted,
      );

      if (enabled) {
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expectHintColor();
        await tester.enterText(find.byType(TextField), 'actual value');
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.controller.text, 'actual value');
        expect(editable.style.color, AppColors.textPrimary);
      }
    });
  }

  testWidgets('disabled input preserves its prefilled text color', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'saved value');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            enabled: false,
            hint: 'Enter value',
          ),
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.color, AppColors.textMuted);
    expect(editable.controller.text, 'saved value');
    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);
    expect(controller.text, 'saved value');
  });

  testWidgets('AppTextField has standardized benchmark decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(hint: 'Search...', prefixIcon: Icons.search),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;

    expect(decoration.isDense, true);
    expect(decoration.fillColor, AppColors.surface);
    expect(
      decoration.contentPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    expect(decoration.hintStyle?.fontSize, AppTextSize.xs);

    final border = decoration.border as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AppRadius.md));
  });
}
