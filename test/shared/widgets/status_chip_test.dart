import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(double width) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: const StatusChip(
                type: StatusType.restarting,
                label: 'Restarting',
              ),
            ),
          ),
        ),
      );

  testWidgets('renders its label without wrapping at a narrow width',
      (tester) async {
    await tester.pumpWidget(host(200));
    await tester.pumpAndSettle();
    final roomyHeight = tester.getSize(find.byType(StatusChip)).height;

    await tester.pumpWidget(host(60));
    await tester.pumpAndSettle();

    // A 60px box cannot hold "RESTARTING" on one line, so the chip either
    // ellipsizes to one line or wraps to two. Wrapping would double the height
    // and blow out every fixed-height status column it sits in.
    expect(tester.getSize(find.byType(StatusChip)).height, roomyHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uppercases its label', (tester) async {
    await tester.pumpWidget(host(200));
    await tester.pumpAndSettle();

    expect(find.text('RESTARTING'), findsOneWidget);
  });
}
