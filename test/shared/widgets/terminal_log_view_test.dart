import 'package:dev_stack/shared/widgets/terminal_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
