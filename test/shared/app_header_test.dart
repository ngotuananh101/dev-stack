import 'dart:async';

import 'package:dev_stack/core/services/window_api.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/shared/layouts/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

/// A [Window] that records what the header asks of it.
///
/// `Window.borrowed` keeps the handle from being freed on collection, so the
/// fake never reaches the native library — there is none in a widget test.
class _FakeWindow extends Window {
  _FakeWindow() : super.borrowed(0);

  bool maximized = false;
  int minimizes = 0;
  int maximizes = 0;
  int unmaximizes = 0;
  int closes = 0;
  final List<ListenerId> removedListeners = <ListenerId>[];
  void Function(WindowEvent)? _listener;
  final ListenerId _nextListenerId = 1;

  @override
  bool get isMaximized => maximized;

  @override
  void minimize() => minimizes++;

  @override
  void maximize() {
    maximizes++;
    maximized = true;
  }

  @override
  void unmaximize() {
    unmaximizes++;
    maximized = false;
  }

  @override
  bool close() {
    closes++;
    return true;
  }

  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) {
    _listener = (event) => callback(event);
    return _nextListenerId;
  }

  @override
  bool removeListener(ListenerId listenerId) {
    removedListeners.add(listenerId);
    return true;
  }

  /// Emits an event the way nativeapi would.
  void emit(WindowEvent event) => _listener?.call(event);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWindow window;
  late Window? Function() previousResolver;

  setUp(() {
    window = _FakeWindow();
    previousResolver = debugSetCurrentWindowResolver(() => window);
  });

  tearDown(() {
    debugSetCurrentWindowResolver(previousResolver);
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

  testWidgets('tapping minimize button minimizes the window', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pump();

    expect(window.minimizes, 1);
  });

  testWidgets('tapping maximize button maximizes when not maximized',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.square));
    await tester.pump();

    expect(window.maximizes, 1);
    expect(window.unmaximizes, 0);
  });

  testWidgets('tapping close button closes the window, never destroys it',
      (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    // `close()` goes through the window's close listeners, which is where the
    // tray preference is applied; `Window` has no destroy() of its own.
    expect(window.closes, 1);
  });

  testWidgets('maximize and restore events swap the maximize icon',
      (tester) async {
    await pumpHeader(tester);

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);

    // nativeapi reports the new state by event, and the header reads the state
    // back from the window rather than trusting the event alone.
    window.maximized = true;
    window.emit(const WindowMaximizedEvent(windowId: 0));
    await tester.pump();

    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.byIcon(LucideIcons.square), findsNothing);

    // Tapping while maximized restores
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(window.unmaximizes, 1);

    window.maximized = false;
    window.emit(const WindowRestoredEvent(windowId: 0));
    await tester.pump();

    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsNothing);
  });

  testWidgets('removes its window listener when disposed', (tester) async {
    await pumpHeader(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(window.removedListeners, isNotEmpty);
  });
}
