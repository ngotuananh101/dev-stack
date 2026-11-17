import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_size.dart';
import 'text_theme_bridge.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        // The 500 steps read as accents; solid fills that carry white text use
        // the `*Strong` (600) tokens below instead.
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        // Material derives `ThemeData.dividerColor` from `outline` when it is
        // not given one, and falls back from there to `onBackground` — which
        // `ColorScheme.dark` defaults to pure white. window_manager's
        // VirtualWindowFrame paints the window's own border with
        // `dividerColor`, so leaving it unset drew a 1px white outline around
        // the window.
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        onPrimary: AppColors.textOnColor,
        onSecondary: AppColors.textOnColor,
        onSurface: AppColors.textPrimary,
      ),
      // google_fonts 9 speaks `material_ui`'s `TextTheme`; the bridge hands the
      // styles back in the type `package:flutter/material.dart` builds with.
      //
      // Every body and label role is pinned to [AppTextSize.xs]. A `Text` that
      // names no size of its own inherits one of these, so leaving them at
      // Material's 14/16 made half the app a step larger than the 12px cells
      // and buttons beside it. The display and headline roles keep their
      // Material sizes: no page or modal title is built from them.
      textTheme: toFlutterTextTheme(
        GoogleFonts.interTextTheme(
          toMaterialUiTextTheme(
            TextTheme(
              headlineLarge: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              headlineMedium: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              bodyLarge: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.xs,
              ),
              bodyMedium: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
              bodySmall: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
              titleLarge: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.xs,
              ),
              titleMedium: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.xs,
              ),
              titleSmall: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.xs,
              ),
              labelLarge: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.xs,
              ),
              labelMedium: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
              labelSmall: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.lg,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: AppTextSize.xs,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: AppTextSize.xxs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: AppColors.textOnColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.accent,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        dividerColor: AppColors.border,
        indicatorSize: TabBarIndicatorSize.tab,
        tabAlignment: TabAlignment.start,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: AppColors.textOnColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      // Material 3's default switch track is 52x32 inside a 52x48 box, which
      // towers over the ~40px inputs and 36px buttons. Shrink it app-wide.
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent.withValues(alpha: 0.35);
          }
          return AppColors.surfaceLight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent.withValues(alpha: 0.6);
          }
          return AppColors.border;
        }),
      ),
    );
  }
}
