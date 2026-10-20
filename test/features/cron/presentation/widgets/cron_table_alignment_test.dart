import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CronJob job(int id, String name) => CronJob(
        id: id,
        name: name,
        schedule: '@daily',
        command: 'php artisan backup:run',
      );

  Widget host(List<CronJob> jobs) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: CronTable(
                  jobs: jobs,
                  runningIds: const {},
                  onRunNow: (_) {},
                  onToggleEnabled: (_) {},
                  onViewHistory: (_) {},
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

    await tester.pumpWidget(host([job(1, 'Backup'), job(2, 'Cleanup')]));
    await tester.pumpAndSettle();

    // The SCHEDULE header must start at the same x as the row's schedule text.
    final scheduleHeaderX = tester.getTopLeft(find.text('SCHEDULE')).dx;
    final scheduleRowX = tester.getTopLeft(find.text('@daily').first).dx;
    expect(scheduleRowX, closeTo(scheduleHeaderX, 1),
        reason: 'the schedule cell starts where the SCHEDULE header starts');
  });

  testWidgets('survives a ~412px row without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([job(1, 'Backup')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
