import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'package:dev_stack/features/databases/presentation/widgets/database_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DatabaseRecord db({
    required String name,
    String username = 'root',
    String password = 'secret',
    String note = 'note',
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

  Widget host(List<DatabaseRecord> dbs) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: DatabaseTable(
                  engineId: 'mysql',
                  databases: dbs,
                  onDelete: (_) {},
                  onEdit: (_) {},
                ),
              ),
            ]),
          ),
        ),
      );

  testWidgets('header and rows line up on the same columns at a wide window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([db(name: 'shop'), db(name: 'shop2')]));
    await tester.pumpAndSettle();

    // The NAME column header must start at the same x as the first row's name.
    final nameHeaderX = tester.getTopLeft(find.text('DATABASE NAME')).dx;
    final nameRowX = tester.getTopLeft(find.text('shop')).dx;
    expect(nameRowX, closeTo(nameHeaderX, 1),
        reason: 'the row name starts where the header starts');

    // PASSWORD header must align with the row's masked-password cell ('---').
    final pwHeaderX = tester.getTopLeft(find.text('PASSWORD')).dx;
    final pwRowX = tester.getTopLeft(find.text('********').first).dx;
    expect(pwRowX, closeTo(pwHeaderX, 1),
        reason: 'the password cell starts where the header starts');
  });

  testWidgets('survives a ~412px row without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(host([db(name: 'shop')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
