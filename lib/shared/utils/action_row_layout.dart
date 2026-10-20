import 'package:flutter/widgets.dart';

/// Whether a row action shows a text label or only an icon.
@immutable
enum RowActionKind { button, icon }

/// One action inside a table row's action cluster.
///
/// [label] is the button's text, the icon button's tooltip, and the label shown
/// in the '…' overflow menu. [icon] is the icon the table already uses for this
/// action; it is reused in the overflow menu so the collapsed state looks like
/// the expanded one. Actions with no [icon] fall back to a dot.
@immutable
class RowAction {
  final RowActionKind kind;
  final String label;

  /// The icon the table renders for this action.
  final IconData? icon;

  /// `null` when the action is disabled. A disabled action still occupies
  /// layout space, so it is measured like an enabled one.
  final VoidCallback? onPressed;

  const RowAction.button(this.label, this.onPressed, {this.icon})
    : kind = RowActionKind.button;

  const RowAction.icon(this.label, this.onPressed, {this.icon})
    : kind = RowActionKind.icon;
}

/// Width of one icon action: an `AppIconButton` at its default `sm` size.
const double kRowActionIconWidth = 28;

/// Horizontal padding an `AppButton` of size `sm` adds around its label.
const double kRowActionButtonPadding = 20;

/// Gap between an `AppButton`'s icon and its label.
const double kRowActionButtonIconGap = 8;

/// Width of the icon an `AppButton` renders before its label.
const double kRowActionButtonIconWidth = 12;

/// Estimated advance width per character at the table's `AppTextSize.sm` (12).
///
/// Labels cannot be measured exactly without rendering (`TextPainter` needs a
/// `TextDirection` and the theme's resolved text style). The consequence of an
/// imprecise estimate is only that the cluster collapses a few dozen pixels
/// earlier or later than a pixel-perfect survey would pick, so an average
/// character advance is deliberate rather than lazy.
const double kRowActionCharWidth = 6.5;

/// The width of the single '…' button that replaces a cluster that does not fit.
double get kOverflowMenuWidth => kRowActionIconWidth;

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
/// A cluster is only kept when it fits comfortably; one that would sit within a
/// menu-button's width of the limit collapses too, so a row never shows a
/// cluster that is barely reachable.
bool rowActionsOverflow(
  List<RowAction> actions,
  double availableWidth, {
  double firstGap = 0,
  double gap = 4,
}) {
  final needed = measureRowActions(actions, firstGap: firstGap, gap: gap);
  if (needed == null) return false;
  return needed + kOverflowMenuWidth > availableWidth;
}
