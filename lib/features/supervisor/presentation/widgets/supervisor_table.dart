import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
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
        const minWidth = 880.0;
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
                  if (programs.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: programs.length,
                        itemBuilder: (context, index) => _buildRow(
                          programs[index],
                          index == programs.length - 1,
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
          Expanded(flex: 3, child: _headerCell('PROGRAM')),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: _headerCell('PID')),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _headerCell('COMMAND')),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
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

  Widget _buildRow(SupervisorProgram program, bool isLast) {
    final status = statuses[program.id] ?? SupervisorStatus.stopped;
    final isRunning = status == SupervisorStatus.running;
    final isTransitioning = status == SupervisorStatus.starting ||
        status == SupervisorStatus.stopping ||
        status == SupervisorStatus.restarting;
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
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isRunning)
                  AppButton(
                    label: 'Stop',
                    onPressed: () => onStop(program.id),
                    icon: const Icon(LucideIcons.square, size: 12),
                    style: AppButtonStyle.danger,
                  )
                else
                  AppButton(
                    label: 'Start',
                    onPressed: isTransitioning ? null : () => onStart(program),
                    icon: const Icon(LucideIcons.play, size: 12),
                    style: AppButtonStyle.success,
                  ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: LucideIcons.rotateCw,
                  tooltip: 'Restart',
                  onPressed: isRunning ? () => onRestart(program) : null,
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.list,
                  tooltip: 'View Logs',
                  onPressed: () => onViewLogs(program),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.edit,
                  tooltip: 'Edit',
                  onPressed: () => onEdit(program),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: () => onDelete(program),
                  size: AppIconButtonSize.sm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
