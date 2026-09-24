import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_radius.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTextField renders prefix icon, hint, and handles input', (tester) async {
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
              validator: (v) => v == null || v.isEmpty ? 'Port is required' : null,
            ),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pumpAndSettle();

    expect(find.text('Port is required'), findsOneWidget);
  });

  testWidgets('AppTextField has standardized benchmark decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(
            hint: 'Search...',
            prefixIcon: Icons.search,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;

    expect(decoration.isDense, true);
    expect(decoration.fillColor, AppColors.surface);
    expect(decoration.contentPadding, const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
    expect(decoration.hintStyle?.fontSize, AppTextSize.xs);

    final border = decoration.border as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AppRadius.md));
  });
}
