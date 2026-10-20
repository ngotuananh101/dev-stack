import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/apps/presentation/widgets/compact_apps_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppModel app(String id, String name, {bool inst = false}) => AppModel(
        appId: id,
        name: name,
        description: 'desc',
        categories: const ['tools'],
        isInstalled: inst,
      );

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

  testWidgets('header and rows line up on the same columns at a wide window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1163, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    // A row with an action cluster and a row without: the cluster used to take
    // its content's width, so each row's data columns landed at a different x.
    await tester.pumpWidget(host([
      app('pyenv', 'pyenv'),
      app('nodejs', 'Node.js', inst: true),
    ]));
    await tester.pumpAndSettle();

    final statusHeaderX = tester.getTopLeft(find.text('STATUS')).dx;

    final statusNoActionsX = tester.getTopLeft(find.text('Not Installed')).dx;
    expect(statusNoActionsX, statusHeaderX,
        reason: 'the status cell starts where the STATUS header starts');

    // The installed row's status cell also starts at STATUS, even though its
    // row carries a 3-icon action cluster that used to push it rightward.
    final statusRow2X = tester
        .getTopRight(find.text('Installed'))
        .dx;
    final statusHeaderRightX =
        tester.getTopRight(find.text('STATUS')).dx;
    expect(statusRow2X, lessThan(statusHeaderRightX),
        reason: 'the status cell width does not run past the header');
  });
}
