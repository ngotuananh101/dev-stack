import 'package:dev_stack/shared/utils/action_row_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('measureRowActions', () {
    test('returns null for an empty cluster', () {
      expect(measureRowActions(const []), isNull);
    });

    test('four icons are four 28px boxes plus the icon gaps', () {
      // Icon boxes are 28px (AppIconButtonSize.sm) and the cluster separates
      // icons with 4px gaps: 28*4 + 4*3 = 124.
      final size = measureRowActions(const [
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
        RowAction.icon('Copy Link', null),
      ]);

      expect(size, 124);
    });

    test('a button plus icons adds the button label and icon gap', () {
      // 'Run' at size 12 is estimated as 3 chars * 6.5 = 19.5, plus 20 of
      // horizontal padding, the 12px icon, the 8px icon gap, then three 28px
      // icon boxes and their 4px gaps: 20 + 19.5 + 12 + 8 + 84 + 12 = 155.5.
      final size = measureRowActions(const [
        RowAction.button('Run', null),
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ]);

      expect(size, 155.5);
    });

    test('the first icon of a cluster gets an extra 6px inset', () {
      // Tables show a 6px inset before the first icon button (cron, tunnels).
      final withInset = measureRowActions(
        const [RowAction.icon('Edit', null), RowAction.icon('Delete', null)],
        firstGap: 6,
      );
      // No inset: 28*2 + 4 = 60.
      expect(withInset, 66);
    });
  });

  group('rowActionsOverflow', () {
    test('is false when the cluster fits the available width', () {
      const actions = [
        RowAction.button('Run', null),
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ];

      // 155.5 of cluster, and the cluster may grow to overflow-menu width.
      expect(rowActionsOverflow(actions, 200), isFalse);
      expect(rowActionsOverflow(actions, 183.5), isFalse);
    });

    test('is true when one px is missing', () {
      const actions = [
        RowAction.button('Run', null),
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ];

      expect(rowActionsOverflow(actions, 183), isTrue);
    });

    test('an empty cluster never overflows', () {
      expect(rowActionsOverflow(const [], 10), isFalse);
    });

    test('a long label is treated as overflow at a narrow width', () {
      const actions = [RowAction.button('Restart Program', null)];
      expect(rowActionsOverflow(actions, 60), isTrue);
    });

    test('the supervisor cluster overflows at the 180px a 700px window leaves',
        () {
      // Supervisor: Start (button) + 4 icon buttons, no inset.
      const actions = [
        RowAction.button('Start', null),
        RowAction.icon('Restart', null),
        RowAction.icon('Logs', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ];

      expect(rowActionsOverflow(actions, 180), isTrue);
      expect(rowActionsOverflow(actions, 1000), isFalse);
    });

    test('a disabled action still occupies layout space', () {
      // A disabled button renders at its label width, so it must be measured.
      const disabled = [RowAction.button('Run', null)];
      final actions = [RowAction.button('Run', () {})];

      expect(measureRowActions(disabled), measureRowActions(actions));
    });
  });

  group('RowAction', () {
    test('icon actions use their label as the tooltip', () {
      const action = RowAction.icon('Edit', null);
      expect(action.kind, RowActionKind.icon);
      expect(action.label, 'Edit');
      expect(action.onPressed, isNull);
    });

    test('button actions keep a separate kind', () {
      void noop() {}
      final action = RowAction.button('Run', noop);
      expect(action.kind, RowActionKind.button);
      expect(action.onPressed, noop);
    });
  });
}
