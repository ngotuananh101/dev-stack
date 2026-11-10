import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_radius.dart';
import 'package:dev_stack/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppRadius provides expected token constants', () {
    expect(AppRadius.xs, 4.0);
    expect(AppRadius.sm, 6.0);
    expect(AppRadius.md, 8.0);
  });

  test(
    'AppTheme darkTheme includes standard inputDecorationTheme and buttonTheme',
    () {
      final theme = AppTheme.darkTheme;
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

  test('AppTheme darkTheme keeps window-frame colours on the palette', () {
    final theme = AppTheme.darkTheme;
    // window_manager's VirtualWindowFrame borders the whole window with
    // `ThemeData.dividerColor`, which Material derives from
    // `ColorScheme.outline`. Leaving `outline` unset makes both fall back to
    // `onBackground`, and `ColorScheme.dark` defaults that to pure white.
    expect(theme.dividerColor, AppColors.border);
    expect(theme.colorScheme.outline, AppColors.border);
    expect(theme.colorScheme.outlineVariant, AppColors.border);
  });
}
