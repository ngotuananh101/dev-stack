import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/layouts/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final methodCalls = <String>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'isMaximized') return false;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpHeader(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              AppHeader(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppHeader renders brand icon, title, and three window controls',
      (tester) async {
    await pumpHeader(tester);

    expect(find.text('Ponta DevStack'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(DragToMoveArea), findsOneWidget);
    expect(find.byIcon(LucideIcons.minus), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);

    final headerBox = tester.renderObject<RenderBox>(find.byType(AppHeader));
    expect(headerBox.size.height, equals(kAppHeaderHeight));
  });

  testWidgets('tapping minimize button invokes windowManager.minimize()',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pump();

    expect(methodCalls, contains('minimize'));
  });

  testWidgets(
      'tapping maximize button invokes windowManager.maximize() when not maximized',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.square));
    await tester.pump();

    expect(methodCalls, contains('maximize'));
  });

  testWidgets(
      'tapping close button invokes windowManager.close() and NEVER destroy()',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    expect(methodCalls, contains('close'));
    expect(methodCalls, isNot(contains('destroy')));
  });

  testWidgets('onWindowMaximize and onWindowUnmaximize swap maximize icon',
      (tester) async {
    await pumpHeader(tester);

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);

    // Simulate platform event maximize
    final codec = const StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'window_manager',
      codec.encodeMethodCall(
        MethodCall('onEvent', {'eventName': 'maximize'}),
      ),
      (_) {},
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);

    // Tapping while maximized calls unmaximize
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(methodCalls, contains('unmaximize'));

    // Simulate platform event unmaximize
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'window_manager',
      codec.encodeMethodCall(
        MethodCall('onEvent', {'eventName': 'unmaximize'}),
      ),
      (_) {},
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);
  });
}
