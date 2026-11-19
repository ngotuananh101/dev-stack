import 'package:dev_stack/core/theme/app_text_size.dart';
import 'test_font_harness.dart';
import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text that names no size falls back to the theme's typography, which is what
/// kept parts of the app at 14/16 while the rest used the 12px tokens. The
/// theme's text roles are pinned to the base size here, so an undeclared size
/// lands on the same number as an explicit one.
void main() {
  late ThemeData theme;

  setUpAll(() async {
    theme = await loadThemeWithTestFonts();
  });

  test('the theme text roles resolve to the base size', () {
    for (final entry in <String, TextStyle?>{
      'bodyLarge': theme.textTheme.bodyLarge,
      'bodyMedium': theme.textTheme.bodyMedium,
      'bodySmall': theme.textTheme.bodySmall,
      'titleLarge': theme.textTheme.titleLarge,
      'titleMedium': theme.textTheme.titleMedium,
      'titleSmall': theme.textTheme.titleSmall,
      'labelLarge': theme.textTheme.labelLarge,
      'labelMedium': theme.textTheme.labelMedium,
      'labelSmall': theme.textTheme.labelSmall,
    }.entries) {
      expect(
        entry.value?.fontSize,
        AppTextSize.xs,
        reason: '${entry.key} carries text that names no size of its own',
      );
    }
  });

  testWidgets('a bare Text renders at the base size', (tester) async {
    late TextStyle inherited;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              inherited = DefaultTextStyle.of(context).style;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(inherited.fontSize, AppTextSize.xs);
  });

  testWidgets('a status chip label sits on the base size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: StatusChip(type: StatusType.stable)),
      ),
    );

    final label = tester.widget<Text>(find.text('STABLE'));
    expect(label.style?.fontSize, AppTextSize.xs);
  });
}
