import 'package:flutter/material.dart';

/// Palette built from the Tailwind CSS scales: `slate` for every neutral and
/// the `500` step of each hue for accents.
///
/// Two token families exist because a saturated `500` fill under white text
/// fails WCAG AA — blue/cyan/green/amber all land near 2:1, which is what made
/// the action buttons hard to read:
///
///  * `*Strong` — the `700` step, for solid fills that carry white text.
///    The `600` step is not enough for every hue: cyan-600 is 3.7:1 and
///    green-600/amber-600 are 3.2:1 under white, all below AA. The `700` step
///    clears 5:1 across the board while staying distinct from the surface.
///  * the bare `500` steps above — for text and icons on a dark surface, where
///    they clear 4.7:1 against slate-900.
class AppColors {
  // Backgrounds — slate
  static const Color background = Color(0xFF020617); // slate-950
  static const Color surface = Color(0xFF0F172A); // slate-900
  static const Color surfaceLight = Color(0xFF1E293B); // slate-800

  // Accents — the 500 step of each hue
  static const Color primary = Color(0xFF3B82F6); // blue-500
  static const Color secondary = Color(0xFF64748B); // slate-500
  static const Color accent = Color(0xFF06B6D4); // cyan-500

  // Status
  static const Color success = Color(0xFF22C55E); // green-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color info = Color(0xFF0EA5E9); // sky-500

  // Text
  static const Color textPrimary = Color(0xFFE2E8F0); // slate-200
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted = Color(0xFF64748B); // slate-500
  // Text drawn on a saturated fill (primary, accent, success, error).
  static const Color textOnColor = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFF334155); // slate-700

  // Solid fills for white text — the 700 step of each hue (≥5:1 under white).
  static const Color primaryStrong = Color(0xFF1D4ED8); // blue-700
  static const Color accentStrong = Color(0xFF0E7490); // cyan-700
  static const Color successStrong = Color(0xFF15803D); // green-700
  static const Color warningStrong = Color(0xFFB45309); // amber-700
  static const Color errorStrong = Color(0xFFB91C1C); // red-700
}
