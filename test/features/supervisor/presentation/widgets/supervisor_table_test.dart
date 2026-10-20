import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:dev_stack/features/supervisor/presentation/widgets/supervisor_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  final program = SupervisorProgram(
    id: 1,
    name: 'Queue Worker',
    command: 'php artisan queue:work',
    workingDir: '/srv/app',
  );

  testWidgets('renders headers and empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: const [],
          statuses: const {},
          pids: const {},
          onStart: (_) {},
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PROGRAM'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('PID'), findsOneWidget);
    expect(find.text('No supervised programs yet'), findsOneWidget);
  });

  testWidgets('shows Stop for a running program and Start otherwise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    int? stoppedId;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: [program],
          statuses: const {1: SupervisorStatus.running},
          pids: const {1: 4242},
          onStart: (_) {},
          onStop: (id) => stoppedId = id,
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Queue Worker'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('4242'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    expect(stoppedId, 1);
  });

  testWidgets('shows Start and a FATAL chip for a fatal program',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    SupervisorProgram? started;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: [program],
          statuses: const {1: SupervisorStatus.fatal},
          pids: const {},
          onStart: (p) => started = p,
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FATAL'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(started?.id, 1);
  });

  group('responsive actions', () {
    // A 700px window leaves ~412px for the table: narrower than the old 880px
    // floor, so the actions used to sit outside an invisible scroll.
    testWidgets('collapses actions into one menu at a ~412px row',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      SupervisorProgram? started;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: SupervisorTable(
                  programs: [program],
                  statuses: const {},
                  pids: const {},
                  onStart: (p) => started = p,
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
      ));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('View Logs'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Start').last);
      expect(started?.id, 1);
    });

    testWidgets('shows every action inline at a wide row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 720));
      addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: SupervisorTable(
                  programs: [program],
                  statuses: const {},
                  pids: const {},
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
      ));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
      expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
    });
  });
}
