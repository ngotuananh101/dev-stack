import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/compact_apps_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(List<AppModel> apps) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: CompactAppsTable(
                  apps: apps,
                  onToggleInstall: (_) async {},
                  onTogglePath: (_) async {},
                  onStartService: (_) async {},
                  onStopService: (_) async {},
                  onRestartService: (_) async {},
                  onChangeDefault: (_) async {},
                  onOpen: (_) async {},
                  onCancelInstall: (_) {},
                ),
              ),
            ]),
          ),
        ),
      );

  testWidgets('the OPERATE header stays visible in an empty table',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1163, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    // An empty table has no rows, so the action column's plan is zero-width.
    // The header must still show its label instead of being squeezed away.
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('OPERATE'), findsOneWidget);
    expect(
      tester.getSize(find.text('OPERATE')).width,
      greaterThan(0),
      reason: 'the OPERATE header must not be squeezed to zero width',
    );
  });
}
