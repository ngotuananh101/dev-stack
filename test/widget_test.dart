import 'package:dev_stack/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test renders without the default counter UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp(appVersion: '1.0.0')),
    );

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
  });
}
