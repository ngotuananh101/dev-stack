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

  testWidgets('opens at the tail of a huge log without laying out every row',
      (tester) async {
    // The regression this guards: a non-reversed ListView had to build and lay
    // out all rows to find maxScrollExtent for the initial jumpTo, which froze
    // the first open of a large log. A reversed list starts at the tail, so
    // only the visible rows exist after the first pump.
    const total = 50000;
    final lines = [for (var i = 0; i < total; i++) 'line number $i'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLogView(title: 'big.log', lines: lines),
        ),
      ),
    );
    await tester.pump();

    // The newest line is visible immediately...
    expect(find.text('line number ${total - 1}'), findsOneWidget);
    // ...while the oldest one was never built.
    expect(find.text('line number 0'), findsNothing);
  });

  testWidgets('shrinks an over-long line and keeps the full text for copy',
      (tester) async {
    final longLine = 'x' * (TerminalLogView.maxRenderedLineLength + 500);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLogView(title: 'long.log', lines: [longLine]),
        ),
      ),
    );

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((text) => text.startsWith('xxx'));
    expect(rendered.length, TerminalLogView.maxRenderedLineLength + 1,
        reason: 'trailing ellipsis replaces the clipped remainder');
  });

  testWidgets('re-follows the tail when a capped list appends a line',
      (tester) async {
    // With a stable, length-capped list the viewer cannot detect an append
    // through identity or length; `revision` is what carries it.
    final lines = List.generate(1000, (i) => 'l$i');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLogView(title: 'cap.log', lines: lines, revision: 1),
        ),
      ),
    );

    lines
      ..removeAt(0)
      ..add('newest');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLogView(title: 'cap.log', lines: lines, revision: 2),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('newest'), findsOneWidget);
  });
}
