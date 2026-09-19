# UI Standardization & Unified Terminal Log Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize the DevStack user interface across all screens by introducing cohesive design tokens, unified interactive components (`AppButton`, `AppIconButton`, `AppTextField`), and a shared `TerminalLogView` for all log viewers and modals.

**Architecture:** Introduce `AppRadius` and centralized `inputDecorationTheme` in `AppTheme`. Build robust, reusable core UI widgets with consistent heights (32px, 36px, 40px) and sharp, developer-tool border radii (4px, 6px, 8px). Migrate all isolated log modals (`SiteLogsModal`, `ServiceLogsModal`, `TunnelLogsModal`, `LogsPage`) and form modals to use these shared primitives.

**Tech Stack:** Flutter, Dart, Flutter Riverpod, Lucide Icons Flutter, Google Fonts.

**Spec:** `docs/superpowers/specs/2026-09-19-ui-standardization-design.md`

## Global Constraints

- Primary CTA Color: `AppColors.primary` (`#58A6FF`, crisp blue with white text).
- Border Radii: `AppRadius.xs = 4.0` (action icon buttons, badges), `AppRadius.sm = 6.0` (buttons, inputs, dropdowns), `AppRadius.md = 8.0` (modals, cards).
- Terminal Background: `#1E1E1E` (Dark Charcoal), Terminal Header: `#252526`.
- Button Sizes: `sm = 32px`, `md = 36px` (default), `lg = 40px`.
- Input Sizing: Standard height 36px/40px with content padding `(12, 10)`.
- No regression in existing tests; all 588+ tests and newly written widget tests must pass.
- `flutter analyze` must report 0 issues.

---

### Task 1: Design Tokens & Base Theme Integration (`AppRadius` & `AppTheme`)

**Files:**
- Create: `lib/core/theme/app_radius.dart`
- Modify: `lib/core/theme/app_theme.dart:1-85`
- Test: `test/core/theme/app_theme_tokens_test.dart`

**Interfaces:**
- Consumes: `AppColors`
- Produces: `AppRadius.xs`, `AppRadius.sm`, `AppRadius.md`, `AppTheme.darkTheme.inputDecorationTheme`

- [ ] **Step 1: Write the failing test for AppRadius and inputDecorationTheme**

```dart
// test/core/theme/app_theme_tokens_test.dart
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_radius.dart';
import 'package:dev_stack/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppRadius provides expected token constants', () {
    expect(AppRadius.xs, 4.0);
    expect(AppRadius.sm, 6.0);
    expect(AppRadius.md, 8.0);
  });

  test('AppTheme darkTheme includes standard inputDecorationTheme and buttonTheme', () {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.inputDecorationTheme.filled, true);
    expect(theme.inputDecorationTheme.fillColor, AppColors.surface);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_tokens_test.dart`
Expected: FAIL (Target file `app_radius.dart` does not exist).

- [ ] **Step 3: Implement AppRadius and update AppTheme**

Create `lib/core/theme/app_radius.dart`:
```dart
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
}
```

Modify `lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_size.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: AppTextSize.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: AppTextSize.xxs),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_tokens_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_radius.dart lib/core/theme/app_theme.dart test/core/theme/app_theme_tokens_test.dart
git commit -m "feat(theme): add AppRadius design tokens and configure inputDecorationTheme"
```

---

### Task 2: Standardized Buttons (`AppButton` & `AppIconButton`)

**Files:**
- Modify: `lib/shared/widgets/app_button.dart:1-91`
- Create: `lib/shared/widgets/app_icon_button.dart`
- Test: `test/shared/widgets/app_button_test.dart`
- Test: `test/shared/widgets/app_icon_button_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppRadius`, `AppTextSize`
- Produces: `AppButton` (with `AppButtonSize`, `AppButtonStyle`), `AppIconButton`

- [ ] **Step 1: Write the failing tests for AppButton and AppIconButton**

```dart
// test/shared/widgets/app_button_test.dart
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton renders label, icon and fires onPressed', (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Save',
            icon: const Icon(Icons.check),
            size: AppButtonSize.md,
            style: AppButtonStyle.primary,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.height, 36.0);

    await tester.tap(find.text('Save'));
    expect(pressed, true);
  });

  testWidgets('AppButton renders loading indicator when isLoading is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });
}
```

```dart
// test/shared/widgets/app_icon_button_test.dart
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/widgets/app_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppIconButton renders icon, tooltip, and fires onPressed', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Start Service',
            color: AppColors.success,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byTooltip('Start Service'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(tapped, true);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/widgets/app_button_test.dart test/shared/widgets/app_icon_button_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement enhanced AppButton and AppIconButton**

Modify `lib/shared/widgets/app_button.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

enum AppButtonStyle { primary, secondary, ghost, outline, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppButtonSize size;
  final Widget? icon;
  final double? width;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.width,
    this.isLoading = false,
  });

  double get _height {
    switch (size) {
      case AppButtonSize.sm:
        return 32.0;
      case AppButtonSize.md:
        return 36.0;
      case AppButtonSize.lg:
        return 40.0;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.sm:
        return AppTextSize.xs; // 12
      case AppButtonSize.md:
        return 13.0;
      case AppButtonSize.lg:
        return AppTextSize.sm; // 14
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10);
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 14);
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: width,
      height: _height,
      child: Material(
        color: _getBackgroundColor(isEnabled),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: _padding,
            decoration: BoxDecoration(
              border: _getBorder(isEnabled),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_getTextColor(isEnabled)),
                    ),
                  ),
                ] else ...[
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: TextStyle(
                      color: _getTextColor(isEnabled),
                      fontWeight: FontWeight.w600,
                      fontSize: _fontSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (!isEnabled) {
      return AppColors.surfaceLight.withValues(alpha: 0.5);
    }
    switch (style) {
      case AppButtonStyle.primary:
        return AppColors.primary;
      case AppButtonStyle.secondary:
        return AppColors.surfaceLight;
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return Colors.transparent;
      case AppButtonStyle.danger:
        return AppColors.error.withValues(alpha: 0.15);
    }
  }

  Color _getTextColor(bool isEnabled) {
    if (!isEnabled) {
      return AppColors.textMuted;
    }
    switch (style) {
      case AppButtonStyle.primary:
        return Colors.white;
      case AppButtonStyle.secondary:
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return AppColors.textPrimary;
      case AppButtonStyle.danger:
        return AppColors.error;
    }
  }

  Border? _getBorder(bool isEnabled) {
    if (style == AppButtonStyle.outline || style == AppButtonStyle.secondary) {
      return Border.all(
        color: isEnabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        width: 0.5,
      );
    }
    if (style == AppButtonStyle.danger) {
      return Border.all(
        color: isEnabled ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
        width: 0.5,
      );
    }
    return null;
  }
}
```

Create `lib/shared/widgets/app_icon_button.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

enum AppIconButtonSize { sm, md }

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;
  final AppIconButtonSize size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = AppIconButtonSize.sm,
  });

  double get _dimension => size == AppIconButtonSize.sm ? 28.0 : 32.0;
  double get _iconSize => size == AppIconButtonSize.sm ? 14.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            width: _dimension,
            height: _dimension,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceLight,
              border: Border.all(
                color: (color != null ? color!.withValues(alpha: 0.25) : AppColors.border),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Center(
              child: Icon(
                icon,
                size: _iconSize,
                color: isEnabled ? effectiveColor : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/app_button_test.dart test/shared/widgets/app_icon_button_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_button.dart lib/shared/widgets/app_icon_button.dart test/shared/widgets/app_button_test.dart test/shared/widgets/app_icon_button_test.dart
git commit -m "feat(ui): enhance AppButton and introduce standardized AppIconButton"
```

---

### Task 3: Standardized Input Field (`AppTextField`)

**Files:**
- Create: `lib/shared/widgets/app_text_field.dart`
- Test: `test/shared/widgets/app_text_field_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppRadius`, `AppTextSize`
- Produces: `AppTextField`

- [ ] **Step 1: Write the failing test for AppTextField**

```dart
// test/shared/widgets/app_text_field_test.dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/app_text_field_test.dart`
Expected: FAIL (Target file `app_text_field.dart` does not exist).

- [ ] **Step 3: Implement AppTextField**

Create `lib/shared/widgets/app_text_field.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final int maxLines;
  final bool readOnly;

  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      focusNode: focusNode,
      maxLines: maxLines,
      style: TextStyle(
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        fontSize: AppTextSize.sm, // 14
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 16, color: AppColors.textMuted)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/app_text_field_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_text_field.dart test/shared/widgets/app_text_field_test.dart
git commit -m "feat(ui): create standardized AppTextField component"
```

---

### Task 4: Unified Terminal Log Viewer Component (`TerminalLogView`)

**Files:**
- Create: `lib/shared/widgets/terminal_log_view.dart`
- Test: `test/shared/widgets/terminal_log_view_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppRadius`, `AppTextSize`, `AppIconButton`
- Produces: `TerminalLogView`

- [ ] **Step 1: Write the failing test for TerminalLogView**

```dart
// test/shared/widgets/terminal_log_view_test.dart
import 'package:dev_stack/shared/widgets/terminal_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('TerminalLogView renders title, logs, error color and auto-scroll button', (tester) async {
    bool cleared = false;
    final logs = [
      'Server started on port 3000',
      '[ERROR] Failed to connect to upstream',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLogView(
            title: 'Logs: myapp.test',
            lines: logs,
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    expect(find.text('Logs: myapp.test'), findsOneWidget);
    expect(find.text('Server started on port 3000'), findsOneWidget);
    expect(find.text('[ERROR] Failed to connect to upstream'), findsOneWidget);

    // Test clear
    await tester.tap(find.byTooltip('Clear'));
    expect(cleared, true);

    // Test Auto-scroll toggle
    expect(find.byTooltip('Auto-scroll ON'), findsOneWidget);
    await tester.tap(find.byTooltip('Auto-scroll ON'));
    await tester.pump();
    expect(find.byTooltip('Auto-scroll OFF'), findsOneWidget);
  });

  testWidgets('TerminalLogView displays empty state message when lines is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TerminalLogView(
            title: 'Logs: empty',
            lines: [],
          ),
        ),
      ),
    );

    expect(find.text('No logs available yet.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/terminal_log_view_test.dart`
Expected: FAIL (Target file `terminal_log_view.dart` does not exist).

- [ ] **Step 3: Implement TerminalLogView**

Create `lib/shared/widgets/terminal_log_view.dart`:
```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

class TerminalLogView extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> lines;
  final VoidCallback? onClear;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenFile;
  final VoidCallback? onClose;
  final Widget? statusWidget;
  final bool isModal;
  final String emptyMessage;

  const TerminalLogView({
    super.key,
    required this.title,
    this.icon = LucideIcons.terminal,
    required this.lines,
    this.onClear,
    this.onCopy,
    this.onOpenFile,
    this.onClose,
    this.statusWidget,
    this.isModal = true,
    this.emptyMessage = 'No logs available yet.',
  });

  @override
  State<TerminalLogView> createState() => _TerminalLogViewState();
}

class _TerminalLogViewState extends State<TerminalLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(TerminalLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _defaultCopy() {
    Clipboard.setData(ClipboardData(text: widget.lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildLogContent()),
      ],
    );

    if (!widget.isModal) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.statusWidget != null) ...[
            const SizedBox(width: 12),
            widget.statusWidget!,
          ],
          const Spacer(),
          IconButton(
            icon: Icon(
              _autoScroll ? LucideIcons.arrowDownCircle : LucideIcons.pauseCircle,
              size: 16,
              color: _autoScroll ? AppColors.success : AppColors.textMuted,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          if (widget.onClear != null)
            IconButton(
              icon: const Icon(Icons.clear_all, size: 16, color: AppColors.textSecondary),
              tooltip: 'Clear',
              onPressed: widget.onClear,
            ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            tooltip: 'Copy all',
            onPressed: widget.onCopy ?? _defaultCopy,
          ),
          if (widget.onOpenFile != null)
            IconButton(
              icon: const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
              tooltip: 'Open log file',
              onPressed: widget.onOpenFile,
            ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
              tooltip: 'Close',
              onPressed: widget.onClose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogContent() {
    if (widget.lines.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isError = line.contains('[ERROR]') || line.contains('Error:');
        final isWarning = line.contains('[WARN]') || line.contains('Warning:');
        final isInfo = line.contains('[INFO]') || line.contains('Service started');

        Color textColor = const Color(0xFFCCCCCC);
        if (isError) {
          textColor = const Color(0xFFF48771);
        } else if (isWarning) {
          textColor = AppColors.warning;
        } else if (isInfo) {
          textColor = AppColors.primary;
        }

        return SelectableText(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: textColor,
            height: 1.4,
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/terminal_log_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/terminal_log_view.dart test/shared/widgets/terminal_log_view_test.dart
git commit -m "feat(ui): create unified TerminalLogView component"
```

---

### Task 5: Migrate All Log Viewers to Unified `TerminalLogView`

**Files:**
- Modify: `lib/features/sites/presentation/widgets/site_logs_modal.dart:1-207`
- Modify: `lib/features/apps/presentation/widgets/service_logs_modal.dart:1-143`
- Modify: `lib/features/tunnels/presentation/widgets/tunnel_logs_modal.dart:1-88`
- Modify: `lib/features/logs/presentation/logs_page.dart:1-490`
- Test: `test/features/sites/presentation/widgets/site_logs_modal_test.dart`

**Interfaces:**
- Consumes: `TerminalLogView`, `SiteModel`, `AppModel`, `TunnelSession`
- Produces: Standardized log viewing across sites, apps, tunnels, and main logs page.

- [ ] **Step 1: Update SiteLogsModal to use TerminalLogView**

Modify `lib/features/sites/presentation/widgets/site_logs_modal.dart`:
Refactor `SiteLogsModal` to delegate rendering to `TerminalLogView`, keeping stream subscription and log file opening intact.
Verify with: `flutter test test/features/sites/presentation/widgets/site_logs_modal_test.dart`.

- [ ] **Step 2: Update ServiceLogsModal to use TerminalLogView**

Modify `lib/features/apps/presentation/widgets/service_logs_modal.dart`:
Replace custom container with `TerminalLogView(title: 'Service Logs: ${app.name}', lines: app.serviceLogs, isModal: true, onClose: onClose)`.

- [ ] **Step 3: Update TunnelLogsModal to use TerminalLogView**

Modify `lib/features/tunnels/presentation/widgets/tunnel_logs_modal.dart`:
Use `Dialog(backgroundColor: Colors.transparent, child: SizedBox(width: 800, height: 500, child: TerminalLogView(title: 'Logs - $tunnelName', lines: logs, onClose: () => Navigator.of(context).pop())))`.

- [ ] **Step 4: Update LogsPage to use TerminalLogView and standardized action buttons**

Modify `lib/features/logs/presentation/logs_page.dart`:
1. Use `TerminalLogView` in page mode (`isModal: false`) for displaying logs.
2. Standardize top action buttons with `AppButton(size: AppButtonSize.sm)`.

- [ ] **Step 5: Run tests to verify all log viewers pass**

Run: `flutter test test/features/sites/presentation/widgets/site_logs_modal_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_logs_modal.dart lib/features/apps/presentation/widgets/service_logs_modal.dart lib/features/tunnels/presentation/widgets/tunnel_logs_modal.dart lib/features/logs/presentation/logs_page.dart
git commit -m "refactor(logs): migrate all log viewers to unified TerminalLogView"
```

---

### Task 6: Standardize Site Table & Modals (`SiteTable`, `AddSiteModal`, `EditSiteModal`, `SitesPage`)

**Files:**
- Modify: `lib/features/sites/presentation/sites_page.dart:80-140`
- Modify: `lib/features/sites/presentation/widgets/site_table.dart:250-380`
- Modify: `lib/features/sites/presentation/widgets/add_site_modal.dart:280-799`
- Modify: `lib/features/sites/presentation/widgets/edit_site_modal.dart:280-799`
- Test: `test/features/sites/presentation/widgets/site_table_cli_test.dart`
- Test: `test/features/sites/presentation/widgets/cli_site_modal_test.dart`

**Interfaces:**
- Consumes: `AppButton`, `AppIconButton`, `AppTextField`
- Produces: Uniform table actions and form inputs for Sites feature.

- [ ] **Step 1: Replace custom action buttons in SiteTable with AppIconButton**

Modify `lib/features/sites/presentation/widgets/site_table.dart`:
Replace internal `_buildActionButton` with `AppIconButton`:
- Start button: `AppIconButton(icon: LucideIcons.play, color: AppColors.success, tooltip: 'Start', onPressed: ...)`
- Stop button: `AppIconButton(icon: LucideIcons.square, color: AppColors.error, tooltip: 'Stop', onPressed: ...)`
- Restart button: `AppIconButton(icon: LucideIcons.rotateCw, color: isRunning ? AppColors.info : AppColors.textMuted, tooltip: isRunning ? 'Restart' : 'Not running', onPressed: ...)`
- Logs button: `AppIconButton(icon: LucideIcons.scrollText, color: AppColors.textSecondary, tooltip: 'Logs', onPressed: ...)`
- Delete button: `AppIconButton(icon: Icons.delete_outline_rounded, color: AppColors.error, tooltip: 'Delete', onPressed: ...)`

- [ ] **Step 2: Run site_table_cli_test to verify compatibility**

Run: `flutter test test/features/sites/presentation/widgets/site_table_cli_test.dart`
Expected: PASS

- [ ] **Step 3: Standardize SitesPage CTA button**

Modify `lib/features/sites/presentation/sites_page.dart`:
Replace `ElevatedButton.icon` with `AppButton(label: 'Add Site', icon: const Icon(LucideIcons.plus, size: 16), size: AppButtonSize.md, style: AppButtonStyle.primary, onPressed: ...)`.

- [ ] **Step 4: Standardize AddSiteModal and EditSiteModal with AppTextField and AppButton**

Modify `lib/features/sites/presentation/widgets/add_site_modal.dart` and `edit_site_modal.dart`:
1. Use `AppTextField` for domain, rootDir, port, command.
2. Standardize modal footer buttons with `AppButton(label: 'Cancel', style: AppButtonStyle.ghost)` and `AppButton(label: 'Save', style: AppButtonStyle.primary)`.

- [ ] **Step 5: Run tests to verify site modals pass**

Run: `flutter test test/features/sites/presentation/widgets/cli_site_modal_test.dart test/features/sites/presentation/widgets/site_table_cli_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/sites/presentation/sites_page.dart lib/features/sites/presentation/widgets/site_table.dart lib/features/sites/presentation/widgets/add_site_modal.dart lib/features/sites/presentation/widgets/edit_site_modal.dart
git commit -m "refactor(sites): standardize SiteTable actions and site modals with AppButton and AppTextField"
```

---

### Task 7: Standardize Apps, Databases, Tunnels Views

**Files:**
- Modify: `lib/features/apps/presentation/widgets/compact_apps_table.dart:250-460`
- Modify: `lib/features/databases/presentation/databases_page.dart:280-320`
- Modify: `lib/features/databases/presentation/widgets/database_table.dart:240-280`
- Modify: `lib/features/databases/presentation/widgets/add_database_modal.dart:200-360`
- Modify: `lib/features/tunnels/presentation/tunnels_page.dart:50-80`
- Modify: `lib/features/tunnels/presentation/widgets/create_tunnel_modal.dart:150-370`
- Test: `test/features/databases/database_modal_validation_test.dart`

**Interfaces:**
- Consumes: `AppButton`, `AppIconButton`, `AppTextField`
- Produces: Uniform UI across Apps, Databases, and Tunnels.

- [ ] **Step 1: Standardize CompactAppsTable actions with AppIconButton**

Modify `lib/features/apps/presentation/widgets/compact_apps_table.dart`:
Replace internal `_buildIconButton` and `_buildServiceButton` with `AppIconButton`.

- [ ] **Step 2: Standardize DatabasesPage and DatabaseTable**

Modify `lib/features/databases/presentation/databases_page.dart` and `database_table.dart`:
1. Use `AppButton` for "Add Database" CTA.
2. Use `AppIconButton` for database table action buttons.
3. In `AddDatabaseModal`, replace custom text field logic with `AppTextField`.

- [ ] **Step 3: Standardize TunnelsPage and CreateTunnelModal**

Modify `lib/features/tunnels/presentation/tunnels_page.dart` and `create_tunnel_modal.dart`:
1. Use `AppButton` for "Create Tunnel" CTA.
2. In `CreateTunnelModal`, replace text inputs with `AppTextField` and action buttons with `AppButton`.

- [ ] **Step 4: Run tests to verify databases and apps**

Run: `flutter test test/features/databases/database_modal_validation_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/presentation/widgets/compact_apps_table.dart lib/features/databases/presentation/databases_page.dart lib/features/databases/presentation/widgets/database_table.dart lib/features/databases/presentation/widgets/add_database_modal.dart lib/features/tunnels/presentation/tunnels_page.dart lib/features/tunnels/presentation/widgets/create_tunnel_modal.dart
git commit -m "refactor(ui): standardize Apps, Databases, and Tunnels with shared components"
```

---

### Task 8: Full End-to-End Regression, Static Analysis & Build Verification

**Files:**
- Test: Full repository test suite (`test/`)
- Verification: `flutter analyze` & `flutter build linux --debug`

- [ ] **Step 1: Run complete test suite**

Run: `flutter test`
Expected: All 590+ tests PASS (0 failures).

- [ ] **Step 2: Run static code analysis**

Run: `flutter analyze`
Expected: No issues found (0 warnings, 0 errors).

- [ ] **Step 3: Verify Linux Desktop build**

Run: `PKG_CONFIG_PATH="/tmp/ayatana/root/usr/lib64/pkgconfig:${PKG_CONFIG_PATH}" flutter build linux --debug`
Expected: Build succeeds without errors.

- [ ] **Step 4: Commit and finalize**

```bash
git add -A
git commit -m "chore: verify UI standardization end-to-end regression and build"
```
