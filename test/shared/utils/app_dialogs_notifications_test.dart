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

    // Top right: above the vertical middle, and against the right edge.
    final toast = tester.getRect(find.text('Saved'));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(
      toast.top,
      lessThan(screen.center.dy),
      reason: 'the toast must sit in the top half of the window',
    );
    expect(
      toast.right,
      greaterThan(screen.center.dx),
      reason: 'the toast must sit in the right half of the window',
    );

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

  group('showPermissionRequest', () {
    Future<bool?> askAndTap(
      WidgetTester tester,
      String buttonText, {
      bool tapBarrier = false,
    }) async {
      bool? answer;
      await tester.pumpWidget(
        host(tester, (c) async {
          answer = await AppDialogs.showPermissionRequest(
            c,
            title: 'Allow package installation?',
            message: 'Ponta needs certutil to trust its certificate.',
            command: 'sudo dnf install -y nss-tools',
          );
        }),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();

      if (tapBarrier) {
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.text(buttonText));
        await tester.pumpAndSettle();
      }
      return answer;
    }

    testWidgets('shows the exact command before asking', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        host(tester, (c) async {
          answer = await AppDialogs.showPermissionRequest(
            c,
            title: 'Allow package installation?',
            message: 'Ponta needs certutil to trust its certificate.',
            command: 'sudo dnf install -y nss-tools',
          );
        }),
      );
      await tester.tap(find.text('act'));
      await tester.pumpAndSettle();

      // The user has to be able to read what will run, not just be told that
      // something will.
      expect(find.text('sudo dnf install -y nss-tools'), findsOneWidget);
      expect(find.text('ALLOW'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(answer, isNull);
    });

    testWidgets('ALLOW answers true', (tester) async {
      expect(await askAndTap(tester, 'ALLOW'), isTrue);
    });

    testWidgets('CANCEL answers false', (tester) async {
      expect(await askAndTap(tester, 'CANCEL'), isFalse);
    });

    testWidgets('dismissing by tapping outside answers false', (tester) async {
      // Anything but an explicit ALLOW must count as "no": a stray click
      // must not be able to install a system package.
      expect(await askAndTap(tester, 'ALLOW', tapBarrier: true), isFalse);
    });
  });
}
