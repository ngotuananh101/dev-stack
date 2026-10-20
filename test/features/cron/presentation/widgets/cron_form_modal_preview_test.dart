import 'package:dev_stack/features/cron/presentation/widgets/cron_form_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the cron form computes its next-run preview without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CronFormModal())),
    );
    await tester.pump();

    // The preview is debounced by 250 ms, so the timer has to fire before the
    // computation runs. The computation happens in a background isolate, and
    // the closure that reaches it must not capture the widget's state — the
    // state holds a Timer, which cannot be sent to another isolate.
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason: 'the next-run preview must be computed without an isolate error',
    );
  });
}
