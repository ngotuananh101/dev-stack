import 'package:material_ui/material_ui.dart';

/// Theme tokens after the UI reset (2026-11-17).
///
/// One flat palette for now: a single app background, a single
/// dialog/surface background, white text everywhere, and one primary
/// colour (#DB2A83). Hierarchy will be reintroduced per-section later.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF181819);
  // App shell (scaffold, header, sidebar): a step darker than the pages.
  static const Color shellBackground = Color(0xFF101011);
  static const Color surface = Color(0xFF1F1F20); // dialogs, cards, inputs
  static const Color surfaceLight = Color(0xFF1F1F20);

  // Accents — the primary colour, used for buttons, selections and icons
  static const Color primary = Color(0xFFDB2A83);
  static const Color secondary = Color(0xFF64748B); // slate-500
  static const Color accent = Color(0xFFDB2A83);

  // Status — unchanged by the reset; adjusted per-section later.
  static const Color success = Color(0xFF22C55E); // green-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color info = Color(0xFF0EA5E9); // sky-500

  // Text — all white for the reset.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFFFFFFF);
  // Text drawn on a saturated fill (primary, accent, success, error).
  static const Color textOnColor = Color(0xFFFFFFFF);

  // Borders — back for dialogs, tables, inputs, switches and buttons
  // (2026-11-17): white at 12%, a hairline on the dark surfaces. The
  // window frame itself stays borderless: ColorScheme outline is kept
  // transparent in AppTheme, because VirtualWindowFrame paints the
  // window's edge with dividerColor, which derives from outline.
  static const Color border = Color(0x1FFFFFFF); // white, 12%

  // Solid fills for white text.
  static const Color primaryStrong = Color(0xFFDB2A83);
  static const Color accentStrong = Color(0xFFDB2A83);
  static const Color successStrong = Color(0xFF15803D); // green-700
  static const Color warningStrong = Color(0xFFB45309); // amber-700
  static const Color errorStrong = Color(0xFFB91C1C); // red-700
}
