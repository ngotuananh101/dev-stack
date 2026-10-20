import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/action_row_layout.dart';
import '../../../../shared/widgets/row_action_menu.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/supervisor_program.dart';
import '../../domain/supervisor_status.dart';

/// Table of supervised programs. Purely presentational: status/pids come in as
/// maps and every action is a callback, so the widget is testable without a
/// manager or Isar.
class SupervisorTable extends StatelessWidget {
  final List<SupervisorProgram> programs;
  final Map<int, SupervisorStatus> statuses;
  final Map<int, int?> pids;
  final void Function(SupervisorProgram) onStart;
  final void Function(int) onStop;
  final void Function(SupervisorProgram) onRestart;
  final void Function(SupervisorProgram) onViewLogs;
  final void Function(SupervisorProgram) onEdit;
  final void Function(SupervisorProgram) onDelete;

  const SupervisorTable({
    super.key,
    required this.programs,
    required this.statuses,
    required this.pids,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onViewLogs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Shrink instead of scrolling sideways out of reach.
        final availableWidth = constraints.maxWidth;
        final operateWidth = availableWidth - _operateReservedWidth;
        // One action-column width for every row, so the data columns line up
        // even when rows carry different numbers of actions.
        final plan = planActionColumn(
          [for (final program in programs) _rowActions(program)],
          availableWidth: operateWidth.isFinite && operateWidth > 0 ? operateWidth : 1,
          firstGap: 6,
        );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildHeader(plan),
              if (programs.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: programs.length,
                    itemBuilder: (context, index) => _buildRow(
                      programs[index],
                      availableWidth,
                      plan,
                      index == programs.length - 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ActionColumnPlan plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerCell('PROGRAM')),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: _headerCell('PID')),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _headerCell('COMMAND')),
          const SizedBox(width: 12),
          SizedBox(
            // Header action column takes the shared width so it lines up with
            // the action buttons of every row below it.
            width: plan.width.isFinite && plan.width > 0 ? plan.width : null,
            child: _headerCell('OPERATE', align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: AppTextSize.xxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.activity, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No supervised programs yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Click "+ New Program" to keep a long-running process alive.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Width the OPERATE cell cannot grow into: the row padding, the gaps before
  /// it, the two fixed data columns, and the floor for the two flexible
  /// program/command columns.
  static const double _operateReservedWidth =
      16 * 2 + 12 * 4 + 100 + 80 + _flexColumnMinWidth * 2;

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 120;

  static VoidCallback? _maybeOnPressed(bool blocked, VoidCallback action) =>
      blocked ? null : action;

  Widget _buildRow(
    SupervisorProgram program,
    double availableWidth,
    ActionColumnPlan plan,
    bool isLast,
  ) {
    final status = statuses[program.id] ?? SupervisorStatus.stopped;
    final pid = pids[program.id];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (program.autoStart) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Starts on app launch',
                    child: Icon(
                      LucideIcons.playCircle,
                      size: 13,
                      color: AppColors.success,
                    ),
                  ),
                ],
                if (!program.enabled) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Disabled',
                    child: Icon(
                      LucideIcons.pauseCircle,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(status),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              pid?.toString() ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              program.command,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: AppTextSize.xs,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Actions render in the shared-width column so the header and every
          // row align, and collapse into the '…' menu together.
          SizedBox(
            width: plan.width.isFinite && plan.width > 0 ? plan.width : null,
            child: RowActionMenu(
              availableWidth: availableWidth - _operateReservedWidth,
              firstGap: 6,
              columnWidth: plan.width,
              collapsed: plan.collapsed,
              actions: _rowActions(program),
            ),
          ),
        ],
      ),
    );
  }

  /// The actions of one row, in render order.
  ///
  /// Extracted so [planActionColumn] can measure every row before layout: the
  /// column width is the widest cluster, not each row's own.
  List<RowAction> _rowActions(SupervisorProgram program) {
    final status = statuses[program.id] ?? SupervisorStatus.stopped;
    final isRunning = status == SupervisorStatus.running;
    final isTransitioning =
        status == SupervisorStatus.starting ||
        status == SupervisorStatus.stopping ||
        status == SupervisorStatus.restarting;

    return [
      RowAction.button(
        isRunning ? 'Stop' : 'Start',
        isRunning
            ? () => onStop(program.id)
            : _maybeOnPressed(isTransitioning, () => onStart(program)),
        icon: isRunning ? LucideIcons.square : LucideIcons.play,
      ),
      RowAction.icon(
        'Restart',
        isRunning ? () => onRestart(program) : null,
        icon: LucideIcons.rotateCw,
      ),
      RowAction.icon(
        'View Logs',
        () => onViewLogs(program),
        icon: LucideIcons.list,
      ),
      RowAction.icon(
        'Edit',
        () => onEdit(program),
        icon: LucideIcons.edit,
      ),
      RowAction.icon(
        'Delete',
        () => onDelete(program),
        icon: LucideIcons.trash2,
      ),
    ];
  }

  Widget _buildStatusChip(SupervisorStatus status) {
    StatusType type;
    String label;
    switch (status) {
      case SupervisorStatus.stopped:
        type = StatusType.stopped;
        label = 'Stopped';
        break;
      case SupervisorStatus.starting:
        type = StatusType.restarting;
        label = 'Starting';
        break;
      case SupervisorStatus.running:
        type = StatusType.stable;
        label = 'Running';
        break;
      case SupervisorStatus.stopping:
        type = StatusType.restarting;
        label = 'Stopping';
        break;
      case SupervisorStatus.restarting:
        type = StatusType.restarting;
        label = 'Restarting';
        break;
      case SupervisorStatus.fatal:
        type = StatusType.warning;
        label = 'Fatal';
        break;
    }
    return StatusChip(type: type, label: label);
  }
}
