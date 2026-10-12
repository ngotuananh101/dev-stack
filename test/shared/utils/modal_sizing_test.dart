import 'package:dev_stack/shared/utils/modal_sizing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Resolves [size] at a given window and returns the geometry.
  Future<ModalDimensions> dimsFor(
    WidgetTester tester,
    ModalSize size, {
    required Size window,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late ModalDimensions result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = modalDimensions(context, size);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  group('modalDimensions widths', () {
    testWidgets('each tier uses its base width on a wide window', (
      tester,
    ) async {
      const wide = Size(1920, 1080);
      expect(
        (await dimsFor(tester, ModalSize.sm, window: wide)).width,
        kModalWidthSm,
      );
      expect(
        (await dimsFor(tester, ModalSize.md, window: wide)).width,
        kModalWidthMd,
      );
      expect(
        (await dimsFor(tester, ModalSize.lg, window: wide)).width,
        kModalWidthLg,
      );
      expect(
        (await dimsFor(tester, ModalSize.xl, window: wide)).width,
        kModalWidthXl,
      );
    });

    testWidgets('widths never overflow the window minus the dialog insets', (
      tester,
    ) async {
      for (final window in [900.0, 700.0, 600.0, 480.0]) {
        for (final size in [
          ModalSize.sm,
          ModalSize.md,
          ModalSize.lg,
          ModalSize.xl,
        ]) {
          final d = await dimsFor(
            tester,
            size,
            window: Size(window, 800),
          );
          expect(
            d.width,
            lessThanOrEqualTo(window - kModalInsetPadding.horizontal),
            reason: 'size=$size window=$window width=${d.width}',
          );
        }
      }
    });

    testWidgets('a narrow window shrinks the modal below its base width', (
      tester,
    ) async {
      final d = await dimsFor(
        tester,
        ModalSize.xl,
        window: const Size(700, 800),
      );
      expect(d.width, lessThan(kModalWidthXl));
      expect(d.width, greaterThan(0));
    });
  });

  group('modalDimensions heights', () {
    testWidgets('tiers use their base height on a tall window', (tester) async {
      const tall = Size(1920, 1200);
      expect(
        (await dimsFor(tester, ModalSize.md, window: tall)).height,
        kModalHeightMd,
      );
      expect(
        (await dimsFor(tester, ModalSize.lg, window: tall)).height,
        kModalHeightLg,
      );
      expect(
        (await dimsFor(tester, ModalSize.xl, window: tall)).height,
        kModalHeightXl,
      );
    });

    testWidgets('sm has no fixed height so the modal sizes to its content', (
      tester,
    ) async {
      final d = await dimsFor(
        tester,
        ModalSize.sm,
        window: const Size(1920, 1080),
      );
      expect(d.height, isNull);
    });

    testWidgets('height is capped at 85% of a short window', (tester) async {
      const short = Size(1920, 500);
      for (final size in [ModalSize.md, ModalSize.lg, ModalSize.xl]) {
        final d = await dimsFor(tester, size, window: short);
        expect(
          d.height,
          lessThanOrEqualTo(500 * 0.85),
          reason: 'size=$size height=${d.height}',
        );
      }
    });
  });

  group('modalDimensions full', () {
    testWidgets('fills the whole window with no inset', (tester) async {
      const window = Size(1440, 900);
      final d = await dimsFor(tester, ModalSize.full, window: window);
      expect(d.width, window.width);
      expect(d.height, window.height);
      expect(d.insetPadding, EdgeInsets.zero);
      expect(d.isFullscreen, isTrue);
    });

    testWidgets('non-full tiers are not fullscreen', (tester) async {
      final d = await dimsFor(
        tester,
        ModalSize.xl,
        window: const Size(1440, 900),
      );
      expect(d.isFullscreen, isFalse);
      expect(d.insetPadding, kModalInsetPadding);
    });
  });
}
