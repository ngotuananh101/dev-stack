import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/action_row_layout.dart';
import '../../../../shared/widgets/row_action_menu.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/cron_expression.dart';
import '../../domain/cron_job.dart';

/// Table of cron jobs. Presentational: run state and every action arrive as
/// parameters/callbacks, so it is testable without Isar or a timer.
class CronTable extends StatelessWidget {
  final List<CronJob> jobs;
  final Set<int> runningIds;
  final Function(CronJob) onRunNow;
  final Function(CronJob) onToggleEnabled;
  final Function(CronJob) onViewHistory;
  final Function(CronJob) onEdit;
  final Function(CronJob) onDelete;

  const CronTable({
    super.key,
    required this.jobs,
    required this.runningIds,
    required this.onRunNow,
    required this.onToggleEnabled,
    required this.onViewHistory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // No horizontal scroll and no minimum width: a scroll the user cannot see
    // hides the actions off-screen, so the table shrinks instead and the row's
    // action cluster collapses into a menu when it no longer fits.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final operateWidth = availableWidth - _operateReservedWidth;
        // One action-column width for every row, so the data columns line up
        // even when rows carry different numbers of actions.
        final plan = planActionColumn(
          [for (final job in jobs) _rowActions(job)],
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
              if (jobs.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) => _buildRow(
                      jobs[index],
                      availableWidth,
                      plan,
                      index == jobs.length - 1,
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
          Expanded(flex: 3, child: _headerCell('JOB NAME')),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _headerCell('SCHEDULE')),
          const SizedBox(width: 12),
          // Every header cell but the two flexible ones can give up width,
          // otherwise the header's fixed budget overflows the window while the
          // rows below it shrink correctly.
          Flexible(child: _headerCell('LAST RUN')),
          const SizedBox(width: 12),
          Flexible(child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          Flexible(child: _headerCell('ENABLED')),
          const SizedBox(width: 12),
          SizedBox(
            // The action column takes the shared width so the header lines up
            // with the button cluster of every row below it.
            width: actionColumnWidth(plan),
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
            Icon(LucideIcons.clock, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No cron jobs yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Click "+ New Job" to run a command on a schedule.',
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

  Widget _buildRow(
    CronJob job,
    double availableWidth,
    ActionColumnPlan plan,
    bool isLast,
  ) {
    final valid = CronExpression.isValid(job.schedule);
    final description =
        valid ? CronExpression.parse(job.schedule).describe() : 'Invalid schedule';

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
                    job.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!job.enabled) ...[
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
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  job.schedule,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.xs,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: valid ? AppColors.textMuted : AppColors.error,
                    fontSize: AppTextSize.xxs,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // The three middle cells are Flexible rather than fixed-width so the
          // row shrinks with the window; their labels ellipsize instead of
          // forcing the table wider than it is.
          Flexible(
            child: Text(
              _formatLastRun(job.lastRunAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: _buildStatusChip(job)),
          const SizedBox(width: 12),
          Flexible(
            child: Switch(
              value: job.enabled,
              activeThumbColor: AppColors.success,
              inactiveThumbColor: AppColors.textMuted,
              onChanged: (_) => onToggleEnabled(job),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            // The action column takes the shared width so the header and every
            // row align, and collapse into the '…' menu together.
            width: actionColumnWidth(plan),
            child: RowActionMenu(
              actions: _rowActions(job),
              availableWidth: availableWidth - _operateReservedWidth,
              firstGap: 6,
              columnWidth: plan.width,
              collapsed: plan.collapsed,
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
  List<RowAction> _rowActions(CronJob job) {
    final isRunning = runningIds.contains(job.id);
    return [
      RowAction.button(
        'Run',
        isRunning ? null : () => onRunNow(job),
        icon: LucideIcons.play,
        isLoading: isRunning,
      ),
      RowAction.icon(
        'Run History',
        () => onViewHistory(job),
        icon: LucideIcons.history,
      ),
      RowAction.icon(
        'Edit',
        () => onEdit(job),
        icon: LucideIcons.edit,
      ),
      RowAction.icon(
        'Delete',
        () => onDelete(job),
        icon: LucideIcons.trash2,
      ),
    ];
  }

  /// Width the action cluster cannot grow into: the row padding, the gaps
  /// before it, the three fixed-width middle cells, and the floor the two
  /// flexible name/schedule columns need before their text becomes unreadable.
  static const double _operateReservedWidth =
      16 * 2 + 12 * 5 + 150 + 90 + 80 + 2 * _flexColumnMinWidth;

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 120;

  static String _formatLastRun(DateTime? dt) {
    if (dt == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildStatusChip(CronJob job) {
    switch (job.lastStatus) {
      case 'running':
        return const StatusChip(type: StatusType.restarting, label: 'Running');
      case 'success':
        return const StatusChip(type: StatusType.stable, label: 'Success');
      case 'failed':
        return const StatusChip(type: StatusType.stopped, label: 'Failed');
      default:
        return const StatusChip(type: StatusType.warning, label: 'Never');
    }
  }
}
