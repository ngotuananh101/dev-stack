import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';
import '../utils/action_row_layout.dart';
import 'app_button.dart';
import 'app_icon_button.dart';

/// Renders a table row's action cluster, collapsing it into one '…' menu when
/// the row is too narrow to show every action.
///
/// A cluster that fits renders exactly as it did before: a trailing `Row` of
/// labelled and icon buttons. When it does not fit, the actions move into a
/// popup menu triggered by a single icon button, so a narrow window never
/// leaves an action unreachable — the cluster is either fully visible or fully
/// reachable.
///
/// The collapse decision belongs to [rowActionsOverflow], not to this widget:
/// it is pure and unit-tested, so every table shares one breakpoint.
class RowActionMenu extends StatelessWidget {
  /// The row's actions, in render order.
  final List<RowAction> actions;

  /// Width the cluster may occupy, taken from the row's `LayoutBuilder`.
  final double availableWidth;

  /// Inset shown before the cluster's first action.
  final double firstGap;

  /// Horizontal gap between actions inside the cluster.
  final double gap;

  const RowActionMenu({
    super.key,
    required this.actions,
    required this.availableWidth,
    this.firstGap = 0,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    if (!rowActionsOverflow(
      actions,
      availableWidth,
      firstGap: firstGap,
      gap: gap,
    )) {
      return _buildInlineRow();
    }

    return _buildOverflowMenu(context);
  }

  Widget _buildInlineRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: firstGap),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _buildActionButton(actions[i]),
        ],
      ],
    );
  }

  Widget _buildActionButton(RowAction action) {
    return switch (action.kind) {
      RowActionKind.icon => AppIconButton(
        icon: action.icon ?? LucideIcons.circle,
        onPressed: action.onPressed,
        tooltip: action.label,
      ),
      RowActionKind.button => AppButton(
        label: action.label,
        onPressed: action.onPressed,
        icon: action.icon != null ? Icon(action.icon!, size: 12) : null,
      ),
    };
  }

  Widget _buildOverflowMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      offset: const Offset(0, 40),
      color: AppColors.surface,
      onSelected: (value) {
        final index = int.parse(value);
        actions[index].onPressed?.call();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<String>(
            value: '$i',
            enabled: actions[i].onPressed != null,
            child: Row(
              children: [
                Icon(
                  actions[i].icon ?? LucideIcons.circle,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  actions[i].label,
                  style: const TextStyle(
                    fontSize: AppTextSize.sm,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      // AppIconButton renders a null-enabled button as inert, so it cannot be
      // the menu's child; the icon is inlined by hand with the same look.
      child: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: _OverflowButton(),
      ),
    );
  }
}

/// The '…' trigger, drawn by hand instead of with `AppIconButton` because a
/// `PopupMenuButton` supplies the tap target and `AppIconButton` disables
/// itself when it is given no callback.
class _OverflowButton extends StatelessWidget {
  const _OverflowButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Actions',
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(child: Icon(LucideIcons.moreHorizontal, size: 14)),
      ),
    );
  }
}
