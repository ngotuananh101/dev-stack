import 'package:flutter/foundation.dart';

/// One action inside a table row's action cluster.
///
/// Either a labelled button ([RowActionKind.button], the `AppButton` used for the
/// row's primary action) or an icon-only button ([RowActionKind.icon], an
/// `AppIconButton`). [label] doubles as the icon button's tooltip and as the
/// label shown in the '…' overflow menu.
@immutable
enum RowActionKind { button, icon }

@immutable
class RowAction {
  final RowActionKind kind;

  /// Button label, icon tooltip and overflow-menu label.
  final String label;

  /// `null` when the action is currently disabled. A disabled action still
  /// occupies layout space, so it is measured like an enabled one.
  final VoidCallback? onPressed;

  const RowAction.button(this.label, this.onPressed)
    : kind = RowActionKind.button;

  const RowAction.icon(this.label, this.onPressed)
    : kind = RowActionKind.icon;
}

/// Width of one icon action: an `AppIconButton` at `AppIconButtonSize.sm`.
const double kRowActionIconWidth = 28;

/// Horizontal padding an `AppButton` of size `sm` adds around its label.
const double kRowActionButtonPadding = 20;

/// Gap between an `AppButton`'s icon and its label.
const double kRowActionButtonIconGap = 8;

/// Width of the icon an `AppButton` renders before a non-empty label.
const double kRowActionButtonIconWidth = 12;

/// Estimated advance width per character at the table's `AppTextSize.sm` (12).
///
/// Labels cannot be measured exactly without rendering (`TextPainter` needs a
/// `TextDirection` and the theme's resolved text style). The consequence of an
/// imprecise estimate is only that the cluster collapses a few dozen pixels
/// earlier or later than a pixel-perfect survey would pick, so an average
/// character advance is deliberate rather than lazy.
const double kRowActionCharWidth = 6.5;

/// The width of a single '…' overflow button ([kRowActionIconWidth]).
double get kOverflowMenuWidth => kRowActionIconWidth;

/// Estimated rendered width of one action at its own size.
double _measure(RowAction action) {
  final labelWidth = action.label.length * kRowActionCharWidth;
  return switch (action.kind) {
    RowActionKind.icon => kRowActionIconWidth,
    RowActionKind.button =>
      kRowActionButtonPadding +
          labelWidth +
          kRowActionButtonIconWidth +
          kRowActionButtonIconGap,
  };
}

/// Minimum width the [actions] cluster needs, or `null` when it is empty.
///
/// [firstGap] is the inset shown before the cluster's first action (tables use
/// 6px before the first icon button); [gap] separates actions inside it.
double? measureRowActions(
  List<RowAction> actions, {
  double firstGap = 0,
  double gap = 4,
}) {
  if (actions.isEmpty) return null;
  var total = firstGap;
  for (var i = 0; i < actions.length; i++) {
    if (i > 0) total += gap;
    total += _measure(actions[i]);
  }
  return total;
}

/// Whether the [actions] cluster has to collapse into the '…' menu to fit in
/// [availableWidth].
///
/// The cluster is allowed to grow to the width the overflow menu would take, so
/// no row renders a wider cluster than the menu that replaces it.
bool rowActionsOverflow(
  List<RowAction> actions,
  double availableWidth, {
  double firstGap = 0,
  double gap = 4,
}) {
  final needed = measureRowActions(actions, firstGap: firstGap, gap: gap);
  if (needed == null) return false;
  // A cluster that only just fits collapses to the menu, keeping one consistent
  // breakpoint instead of a near-miss that overflows by a pixel.
  return needed + kOverflowMenuWidth > availableWidth;
}
