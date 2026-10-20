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
      // 'Run' (3 chars) at 12.25px = 36.75, plus 20 of horizontal padding,
      // the 12px icon, the 8px icon gap, then three 28px icon boxes and their
      // 4px gaps: 20 + 36.75 + 12 + 8 + 84 + 12 = 172.75.
      final size = measureRowActions(const [
        RowAction.button('Run', null),
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ]);

      expect(size, 172.75);
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

      // 172.75 of cluster; it must also leave room for the 28px overflow-menu
      // width, so it overflows once the available width drops to 200.75.
      expect(rowActionsOverflow(actions, 201), isFalse);
      expect(rowActionsOverflow(actions, 200), isTrue);
    });

    test('is true when one px is missing', () {
      const actions = [
        RowAction.button('Run', null),
        RowAction.icon('Run History', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ];

      expect(rowActionsOverflow(actions, 200.74), isTrue);
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
      // Supervisor: Start (button) + 4 icon buttons, with the 6px first inset.
      const actions = [
        RowAction.button('Start', null),
        RowAction.icon('Restart', null),
        RowAction.icon('Logs', null),
        RowAction.icon('Edit', null),
        RowAction.icon('Delete', null),
      ];

      expect(rowActionsOverflow(actions, 180, firstGap: 6), isTrue);
      expect(rowActionsOverflow(actions, 1000, firstGap: 6), isFalse);
    });

    test('a disabled action still occupies layout space', () {
      // A disabled button renders at its label width, so it must be measured.
      const disabled = [RowAction.button('Run', null)];
      final actions = [RowAction.button('Run', () {})];

      expect(measureRowActions(disabled), measureRowActions(actions));
    });
  });

  group('planActionColumn', () {
    test('sizes the column to the widest row when every row fits', () {
      // One row has a single 28px icon, the other two (28*2 + 4 gap = 60). The
      // column takes the widest so every row's cluster is right-aligned inside
      // the same box, which is what keeps the data columns aligned.
      final plan = planActionColumn(
        [
          const [RowAction.icon('Edit', null)],
          const [RowAction.icon('Edit', null), RowAction.icon('Delete', null)],
        ],
        availableWidth: 300,
      );

      expect(plan.collapsed, isFalse);
      expect(plan.width, 60);
    });

    test('collapses the whole table to the menu width when the widest row does '
        'not fit', () {
      // The widest row needs 28*3 + 4*2 = 92, which does not fit in 50. One
      // breakpoint per table, not per row: a table that mixes inline clusters
      // and menus would draw its action column at two different widths.
      final plan = planActionColumn(
        [
          const [RowAction.icon('Edit', null)],
          const [
            RowAction.icon('A', null),
            RowAction.icon('B', null),
            RowAction.icon('C', null),
          ],
        ],
        availableWidth: 50,
        firstGap: 6,
      );

      expect(plan.collapsed, isTrue);
      // The '…' button plus the 6px inset before it.
      expect(plan.width, 34);
    });

    test('is zero-wide for a table with no rows', () {
      expect(planActionColumn(const [], availableWidth: 100).width, 0);
    });
  });

  group('actionColumnWidth', () {
    test('keeps the planned width when the table has rows', () {
      const plan = ActionColumnPlan(width: 60, collapsed: false);
      expect(actionColumnWidth(plan), 60);
    });

    test('gives an empty table the width of its header label', () {
      // An empty table has no cluster to align to, but its header still shows
      // the OPERATE label: a zero-wide column squeezes the label away.
      const plan = ActionColumnPlan(width: 0, collapsed: false);
      expect(actionColumnWidth(plan), greaterThan(0));
      expect(actionColumnWidth(plan), kActionHeaderMinWidth);
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
