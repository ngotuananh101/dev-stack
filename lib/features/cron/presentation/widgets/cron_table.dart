import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 1000.0;
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                children: [
                  _buildHeader(),
                  if (jobs.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) => _buildRow(
                          jobs[index],
                          index == jobs.length - 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
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
          SizedBox(width: 150, child: _headerCell('LAST RUN')),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: _headerCell('ENABLED')),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
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

  Widget _buildRow(CronJob job, bool isLast) {
    final isRunning = runningIds.contains(job.id);
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
          SizedBox(
            width: 150,
            child: Text(
              _formatLastRun(job.lastRunAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: _buildStatusChip(job)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Switch(
              value: job.enabled,
              activeThumbColor: AppColors.success,
              inactiveThumbColor: AppColors.textMuted,
              onChanged: (_) => onToggleEnabled(job),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Run',
                  onPressed: isRunning ? null : () => onRunNow(job),
                  isLoading: isRunning,
                  icon: const Icon(LucideIcons.play, size: 12),
                  style: AppButtonStyle.success,
                ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: LucideIcons.history,
                  tooltip: 'Run History',
                  onPressed: () => onViewHistory(job),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.edit,
                  tooltip: 'Edit',
                  onPressed: () => onEdit(job),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: () => onDelete(job),
                  size: AppIconButtonSize.sm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
