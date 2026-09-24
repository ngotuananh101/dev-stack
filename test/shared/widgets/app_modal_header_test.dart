import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/widgets/app_icon_button.dart';
import 'package:dev_stack/shared/widgets/app_modal_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('AppModalHeader', () {
    testWidgets('renders standard title, subtitle, icon, close button, and divider', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModalHeader(
              icon: LucideIcons.globe,
              title: 'Add New Site',
              subtitle: 'Configure a new virtual host for your project',
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      // Verify Icon
      final iconFinder = find.byIcon(LucideIcons.globe);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.size, 20.0);
      expect(iconWidget.color, AppColors.primary);

      // Verify Title text and style
      final titleFinder = find.text('Add New Site');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontSize, AppTextSize.sm);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
      expect(titleWidget.style?.color, AppColors.textPrimary);

      // Verify Subtitle text and style
      final subtitleFinder = find.text('Configure a new virtual host for your project');
      expect(subtitleFinder, findsOneWidget);
      final subtitleWidget = tester.widget<Text>(subtitleFinder);
      expect(subtitleWidget.style?.fontSize, AppTextSize.xxs);
      expect(subtitleWidget.style?.color, AppColors.textMuted);

      // Verify Padding
      final paddingFinder = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      );
      expect(paddingFinder, findsOneWidget);

      // Verify Close Button
      final closeButtonFinder = find.byType(AppIconButton);
      expect(closeButtonFinder, findsOneWidget);
      final closeButton = tester.widget<AppIconButton>(closeButtonFinder);
      expect(closeButton.icon, LucideIcons.x);
      expect(closeButton.size, AppIconButtonSize.sm);
      expect(closeButton.tooltip, 'Close');

      // Tap close button
      await tester.tap(closeButtonFinder);
      await tester.pump();
      expect(closed, isTrue);

      // Verify Divider
      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsOneWidget);
      final divider = tester.widget<Divider>(dividerFinder);
      expect(divider.color, AppColors.border);
      expect(divider.height, 1.0);
    });

    testWidgets('renders custom iconWidget and actions', (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModalHeader(
              iconWidget: const FlutterLogo(size: 20),
              title: 'Custom Title',
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () => actionTapped = true,
                ),
              ],
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byType(FlutterLogo), findsOneWidget);
      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
      expect(find.byType(AppIconButton), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.refreshCw));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('omits subtitle and divider when requested', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppModalHeader(
              icon: LucideIcons.database,
              title: 'No Subtitle',
              showDivider: false,
            ),
          ),
        ),
      );

      expect(find.text('No Subtitle'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(AppIconButton), findsNothing);
    });
  });
}
