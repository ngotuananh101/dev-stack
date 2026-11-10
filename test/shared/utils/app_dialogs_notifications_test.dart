import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';

/// A page with something to call [AppDialogs] from, wrapped the way `main.dart`
/// wraps the app.
Widget host(WidgetTester tester, void Function(BuildContext) onTap) {
  return ToastificationWrapper(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('act'),
          ),
        ),
      ),
    ),
  );
}

/// Taps the button and lets the toast's enqueue/entry animation finish.
///
/// The toast is inserted from a post-frame callback, so it needs a frame after
/// the tap before it exists, then a few hundred milliseconds for its entry
/// animation to reach full size.
Future<void> tapAndSettleToast(WidgetTester tester) async {
  await tester.tap(find.text('act'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

/// Runs past the toast's own auto-close timer so no pending timer outlives the
/// test.
Future<void> drainToastTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('a success message is a toast, not a SnackBar', (tester) async {
    await tester.pumpWidget(
      host(tester, (c) => AppDialogs.showToast(c, 'Saved')),
    );
    await tapAndSettleToast(tester);

    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await drainToastTimers(tester);
  });

  testWidgets('a neutral message is an info toast', (tester) async {
    await tester.pumpWidget(
      host(tester, (c) => AppDialogs.showInfoToast(c, 'Starting tunnel...')),
    );
    await tapAndSettleToast(tester);

    expect(find.text('Starting tunnel...'), findsOneWidget);
    // The info icon is what distinguishes it from a success toast.
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    await drainToastTimers(tester);
  });

  testWidgets('a success toast is not confused with an info one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(tester, (c) => AppDialogs.showToast(c, 'Saved')),
    );
    await tapAndSettleToast(tester);

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);

    await drainToastTimers(tester);
  });

  testWidgets('an error is a blocking alert, not a toast', (tester) async {
    await tester.pumpWidget(
      host(
        tester,
        (c) => AppDialogs.showError(
          c,
          title: 'Delete failed',
          message: 'Permission denied',
        ),
      ),
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();

    expect(find.text('Delete failed'), findsOneWidget);
    expect(find.text('Permission denied'), findsOneWidget);
    // The alert's own button is the acknowledgement a toast does not have.
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('showErrorFrom reports the exception text', (tester) async {
    await tester.pumpWidget(
      host(tester, (c) => AppDialogs.showErrorFrom(c, Exception('boom'))),
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
