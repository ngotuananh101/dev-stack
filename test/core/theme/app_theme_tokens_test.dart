import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_radius.dart';
import 'package:dev_stack/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'test_font_harness.dart';

void main() {
  late ThemeData theme;

  setUpAll(() async {
    theme = await loadThemeWithTestFonts();
  });

  test('real theme fonts finish loading without runtime fetching', () async {
    final wasAllowed = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    try {
      final theme = AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter_regular');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Inter_700');
      expect(await GoogleFonts.pendingFonts(), isEmpty);
    } finally {
      GoogleFonts.config.allowRuntimeFetching = wasAllowed;
    }
  });

  test('AppRadius provides expected token constants', () {
    expect(AppRadius.xs, 4.0);
    expect(AppRadius.sm, 6.0);
    expect(AppRadius.md, 8.0);
  });

  test(
    'AppTheme darkTheme includes standard inputDecorationTheme and buttonTheme',
    () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.inputDecorationTheme.filled, true);
      expect(theme.inputDecorationTheme.fillColor, AppColors.surface);
      expect(theme.inputDecorationTheme.isDense, true);
      expect(
        theme.inputDecorationTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
      final border = theme.inputDecorationTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(AppRadius.md));
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    },
  );

  testWidgets('default input renders a dim placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: TextField(decoration: InputDecoration(hintText: 'Enter value')),
        ),
      ),
    );

    final hint = find.text('Enter value');
    final text = tester.widget<Text>(hint);
    final style = DefaultTextStyle.of(
      tester.element(hint),
    ).style.merge(text.style);
    expect(style.color, const Color(0x59FFFFFF));
    expect(style.fontSize, 12);
  });

  test('AppTheme darkTheme keeps the window frame borderless', () {
    // The frame is borderless by design: `outline` and `outlineVariant`
    // are transparent rather than the palette border, and Material derives
    // `ThemeData.dividerColor` from `outline`, so it is transparent too.
    // Dividers and inputs read `AppColors.border` directly instead
    // (see `dividerTheme` and `inputDecorationTheme` in the theme).
    expect(theme.dividerColor, Colors.transparent);
    expect(theme.colorScheme.outline, Colors.transparent);
    expect(theme.colorScheme.outlineVariant, Colors.transparent);
  });
}
