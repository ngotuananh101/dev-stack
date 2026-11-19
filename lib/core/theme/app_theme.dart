import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_size.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.shellBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        // Material derives `ThemeData.dividerColor` from `outline` when it is
        // not given one, and window_manager's VirtualWindowFrame paints the
        // window's own border with `dividerColor`. The border token is
        // visible again (dialogs, tables, inputs), so `outline` stays
        // transparent here to keep the window frame borderless; dividers
        // and inputs read the token directly instead.
        outline: Colors.transparent,
        outlineVariant: Colors.transparent,
        onPrimary: AppColors.textOnColor,
        onSecondary: AppColors.textOnColor,
        onSurface: AppColors.textPrimary,
      ),
      // UI reset (2026-11-17): every text role reads at [AppTextSize.xs] (12).
      // Page headers are the one exception at [AppTextSize.sm] (14) and are
      // set where the page is built, not here. Roles left null would be
      // filled in by GoogleFonts/Material at their own large sizes, so the
      // display and headline roles are pinned to 12 here too.
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
          ),
          displayMedium: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
          ),
          displaySmall: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
          ),
          headlineLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.shellBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.sm,
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
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.xs,
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
          color: AppColors.textPlaceholder,
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
          fontSize: AppTextSize.xs,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
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
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
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
          if (states.contains(WidgetState.selected)) return AppColors.success;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.success.withValues(alpha: 0.2);
          }
          return AppColors.surfaceLight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.success.withValues(alpha: 0.6);
          }
          return AppColors.border;
        }),
      ),
    );
  }
}
