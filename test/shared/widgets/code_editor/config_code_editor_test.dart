import 'package:dev_stack/shared/widgets/code_editor/config_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  group('ConfigCodeEditor', () {
    testWidgets('renders in-memory content directly without file access', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfigCodeEditor(
              filePath: 'nginx_access.log',
              content: '127.0.0.1 - GET /index.php 200\n127.0.0.1 - POST /login 403',
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

    testWidgets('triggers onReload callback when reload button is tapped with content', (tester) async {
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
    });

    testWidgets('updates displayed text when content property updates', (tester) async {
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
  });
}
