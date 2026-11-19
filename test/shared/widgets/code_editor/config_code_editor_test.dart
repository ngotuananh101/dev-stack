import 'package:dev_stack/shared/widgets/code_editor/config_code_editor.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('ConfigCodeEditor', () {
    testWidgets('renders in-memory content directly without file access', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfigCodeEditor(
              filePath: 'nginx_access.log',
              content:
                  '127.0.0.1 - GET /index.php 200\n127.0.0.1 - POST /login 403',
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
      expect(find.text('nginx_access.log'), findsOneWidget);
      expect(find.text('Find'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
      // In readOnly mode, Save button should not be present
      expect(find.text('Save Changes'), findsNothing);
    });

    testWidgets(
      'triggers onReload callback when reload button is tapped with content',
      (tester) async {
        var reloadTapped = false;
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConfigCodeEditor(
                filePath: 'test.log',
                content: 'Initial log text',
                readOnly: true,
                onReload: () {
                  reloadTapped = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reload'));
        await tester.pump();

        expect(reloadTapped, isTrue);
      },
    );

    testWidgets('updates displayed text when content property updates', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfigCodeEditor(
              filePath: 'test.log',
              content: 'Version 1',
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfigCodeEditor(
              filePath: 'test.log',
              content: 'Version 2 updated',
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
    });

    for (final replaceMode in [false, true]) {
      testWidgets('editor search hints are dim (replace: $replaceMode)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConfigCodeEditor(filePath: 'hosts', content: 'localhost'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find'));
        await tester.pumpAndSettle();
        if (replaceMode) {
          tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .findController!
              .replaceMode();
          await tester.pumpAndSettle();
        }

        final hints = replaceMode ? ['Replace', 'Find'] : ['Find'];
        for (final hint in hints) {
          final field = tester.widget<TextField>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.decoration?.hintText == hint,
            ),
          );
          expect(field.decoration?.hintStyle?.color, const Color(0x59FFFFFF));
          expect(field.style?.color, AppColors.textPrimary);
          expect(field.decoration?.hintStyle?.fontSize, 12);
        }
      });
    }

    testWidgets(
      'renders plaintext code in the app text color, not the ambient theme',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ConfigCodeEditor(
                filePath: 'hosts',
                content: '127.0.0.1 localhost\n# a comment',
                readOnly: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The editor must not depend on the ambient Flutter theme for its
        // colors: the app runs on material_ui's MaterialApp, so Flutter's
        // Theme.of falls back to the light defaults and plaintext code
        // (the hosts file) renders near-black on the dark background.
        final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
        expect(codeEditor.style?.textColor, AppColors.textPrimary);
        expect(
          codeEditor.style?.selectionColor,
          AppColors.primary.withValues(alpha: 0.4),
        );
        expect(
          codeEditor.style?.highlightColor,
          AppColors.primary.withValues(alpha: 0.4),
        );
        expect(codeEditor.style?.cursorColor, AppColors.primary);
      },
    );
  });
}
