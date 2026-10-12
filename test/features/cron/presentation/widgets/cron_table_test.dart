import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  final job = CronJob(
    id: 1,
    name: 'Backup',
    schedule: '@daily',
    command: 'php artisan backup:run',
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders headers and the empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(wrap(CronTable(
      jobs: const [],
      runningIds: const {},
      onRunNow: (_) {},
      onToggleEnabled: (_) {},
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('JOB NAME'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('LAST RUN'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ENABLED'), findsOneWidget);
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('No cron jobs yet'), findsOneWidget);
  });

  testWidgets('renders a row with its schedule description and status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    CronJob? ran;
    CronJob? toggled;

    await tester.pumpWidget(wrap(CronTable(
      jobs: [job],
      runningIds: const {},
      onRunNow: (j) => ran = j,
      onToggleEnabled: (j) => toggled = j,
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('@daily'), findsOneWidget);
    expect(find.text('At 00:00'), findsOneWidget); // describe()
    expect(find.text('—'), findsOneWidget); // never run
    expect(find.text('NEVER'), findsOneWidget); // status chip

    await tester.tap(find.text('Run'));
    expect(ran?.id, 1);

    await tester.tap(find.byType(Switch));
    expect(toggled?.id, 1);
  });

  testWidgets('swaps the Run button for a spinner while the job is running',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(wrap(CronTable(
      jobs: [job],
      runningIds: const {1},
      onRunNow: (_) {},
      onToggleEnabled: (_) {},
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    // AppButton renders an indeterminate CircularProgressIndicator while
    // loading, so pumpAndSettle() would never settle — advance one frame
    // instead.
    await tester.pump(const Duration(milliseconds: 100));

    // AppButton renders a spinner in place of its label while loading, so the
    // in-flight row shows no "Run" text.
    expect(find.text('Run'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
