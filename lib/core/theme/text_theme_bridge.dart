import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

/// Bridges the two `TextTheme` classes: `package:flutter/material.dart`'s and
/// the one `package:material_ui` defines.
///
/// google_fonts 9 is built on `material_ui`, the standalone home of Material
/// Design, so `GoogleFonts.interTextTheme` takes and returns a
/// `material_ui.TextTheme`. The app's widget tree still comes from
/// `package:flutter/material.dart`, whose `TextTheme` is a different class —
/// which is why the types do not line up even though the two libraries agree on
/// everything below them.
///
/// The conversion is a member-by-member copy and nothing more: every role holds
/// the same `dart:ui` `TextStyle` in both classes, so no style is rebuilt and no
/// value is reinterpreted. A role the source leaves null stays null, letting the
/// theme's own typography fill it in, exactly as passing a partial `TextTheme`
/// by hand would.

/// Converts a Flutter [TextTheme] into the `material_ui` type.
material_ui.TextTheme toMaterialUiTextTheme(TextTheme textTheme) {
  return material_ui.TextTheme(
    displayLarge: textTheme.displayLarge,
    displayMedium: textTheme.displayMedium,
    displaySmall: textTheme.displaySmall,
    headlineLarge: textTheme.headlineLarge,
    headlineMedium: textTheme.headlineMedium,
    headlineSmall: textTheme.headlineSmall,
    titleLarge: textTheme.titleLarge,
    titleMedium: textTheme.titleMedium,
    titleSmall: textTheme.titleSmall,
    bodyLarge: textTheme.bodyLarge,
    bodyMedium: textTheme.bodyMedium,
    bodySmall: textTheme.bodySmall,
    labelLarge: textTheme.labelLarge,
    labelMedium: textTheme.labelMedium,
    labelSmall: textTheme.labelSmall,
  );
}

/// Converts a `material_ui` [material_ui.TextTheme] into the Flutter type.
TextTheme toFlutterTextTheme(material_ui.TextTheme textTheme) {
  return TextTheme(
    displayLarge: textTheme.displayLarge,
    displayMedium: textTheme.displayMedium,
    displaySmall: textTheme.displaySmall,
    headlineLarge: textTheme.headlineLarge,
    headlineMedium: textTheme.headlineMedium,
    headlineSmall: textTheme.headlineSmall,
    titleLarge: textTheme.titleLarge,
    titleMedium: textTheme.titleMedium,
    titleSmall: textTheme.titleSmall,
    bodyLarge: textTheme.bodyLarge,
    bodyMedium: textTheme.bodyMedium,
    bodySmall: textTheme.bodySmall,
    labelLarge: textTheme.labelLarge,
    labelMedium: textTheme.labelMedium,
    labelSmall: textTheme.labelSmall,
  );
}
