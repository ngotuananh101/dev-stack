import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'package:dev_stack/features/databases/presentation/widgets/database_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  DatabaseRecord db({
    String name = 'shop',
    String username = 'root',
    String password = 'secret',
    String? note,
  }) {
    final record = DatabaseRecord();
    record.id = 1;
    record.name = name;
    record.username = username;
    record.password = password;
    record.note = note;
    record.createdAt = DateTime(2026);
    return record;
  }

  Widget host(String engineId, List<DatabaseRecord> databases) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: DatabaseTable(
              engineId: engineId,
              databases: databases,
              onDelete: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      );

  testWidgets('renders both row actions inline when the row is wide',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host('mysql', [db()]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
  });

  testWidgets('collapses row actions into one menu at a ~412px row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host('mysql', [db()]));
    await tester.pumpAndSettle();

    // Reaching this pump without a RenderFlex overflow means the row fits.
    expect(find.byIcon(LucideIcons.moreHorizontal), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Edit Database'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a redis row keeps its actions inline at a 700px window',
      (tester) async {
    // The redis row carries one data column fewer than the SQL row, so a 700px
    // window still leaves room for the pair.
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host('redis', [db(name: 'DB 0')]));
    await tester.pumpAndSettle();

    expect(find.text('DB 0'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);
  });

  testWidgets('a redis row collapses its flush/clear pair when narrow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host('redis', [db(name: 'DB 0')]));
    await tester.pumpAndSettle();

    expect(find.text('DB 0'), findsOneWidget);
    expect(find.byIcon(LucideIcons.moreHorizontal), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Flush DB'), findsOneWidget);
    expect(find.text('Clear Record'), findsOneWidget);
  });
}
