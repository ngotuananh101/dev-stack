import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_table.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  group('responsive actions', () {
    // A 700px window leaves ~412px for the table (700 - 240 sidebar - 48
    // padding), which is narrower than the old 1000px minWidth floor, so the
    // row used to push its actions out of reach with an invisible scroll.
    testWidgets('collapses actions into one menu at a ~412px row',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      CronJob? ran;
      await tester.pumpWidget(wrap(CronTable(
        jobs: [job],
        runningIds: const {},
        onRunNow: (j) => ran = j,
        onToggleEnabled: (_) {},
        onViewHistory: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));
      await tester.pumpAndSettle();

      // A RenderFlex overflow is a Flutter error, so the header and
      // every data row fitting the narrow window is proved by there
      // being no exception here.
      expect(tester.takeException(), isNull);

      // The RunFlex overflowed exception is thrown, not logged: getting here
      // is proof the row fits. No action label is laid out inline.
      expect(find.text('Run'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
      await tester.pumpAndSettle();
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Run History'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Run').last);
      expect(ran?.id, 1);
    });

    testWidgets('shows every action inline at a wide row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(wrap(CronTable(
        jobs: [job],
        runningIds: const {},
        onRunNow: (_) {},
        onToggleEnabled: (_) {},
        onViewHistory: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Run'), findsOneWidget);
      expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
    });
  });
}
