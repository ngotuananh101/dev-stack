import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:dev_stack/features/supervisor/presentation/widgets/supervisor_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupervisorProgram program(String id, String name) => SupervisorProgram(
        id: int.parse(id),
        name: name,
        command: 'queue:work',
        workingDir: '/srv',
      );

  Widget host(List<SupervisorProgram> programs,
          {Map<int, SupervisorStatus> statuses = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: SupervisorTable(
                  programs: programs,
                  statuses: statuses,
                  pids: const {1: 4242},
                  onStart: (_) {},
                  onStop: (_) {},
                  onRestart: (_) {},
                  onViewLogs: (_) {},
                  onEdit: (_) {},
                  onDelete: (_) {},
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

    await tester.pumpWidget(host([
      program('1', 'Queue Worker'),
      program('2', 'Cron Watcher'),
    ]));
    await tester.pumpAndSettle();

    final pidHeaderX = tester.getTopLeft(find.text('PID')).dx;
    final pidRow1X = tester.getTopLeft(find.text('4242')).dx;
    expect(pidRow1X, pidHeaderX,
        reason: 'the PID cell starts where the PID header starts');
  });

  testWidgets('survives a ~412px row without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([program('1', 'Queue Worker')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
