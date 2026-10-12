import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../data/cron_scheduler_service.dart';
import '../../domain/cron_job.dart';

/// Recent runs for one job, newest first. Reads the scheduler's RAM history and
/// re-renders whenever the scheduler reports a state change for the job.
class RunHistoryModal extends StatefulWidget {
  final CronSchedulerService scheduler;
  final CronJob job;

  const RunHistoryModal({
    super.key,
    required this.scheduler,
    required this.job,
  });

  @override
  State<RunHistoryModal> createState() => _RunHistoryModalState();
}

class _RunHistoryModalState extends State<RunHistoryModal> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.scheduler.statusStream.listen((id) {
      if (mounted && id == widget.job.id) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final records = widget.scheduler.historyFor(widget.job.id);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: dims.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: Column(
          children: [
            AppModalHeader(
              icon: LucideIcons.history,
              title: 'Run History - ${widget.job.name}',
              subtitle: 'Latest ${records.length} of 20 retained runs (in-memory)',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'No runs recorded yet.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.sm,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) =>
                          _buildTile(records[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(RunRecord record) {
    final running = record.exitCode == null;
    final success = record.exitCode == 0;
    final color = running
        ? AppColors.warning
        : (success ? AppColors.success : AppColors.error);
    final label = running ? 'Running' : (success ? 'Success' : 'Failed');

    String duration = '—';
    if (record.finishedAt != null) {
      final ms = record.finishedAt!.difference(record.startedAt).inMilliseconds;
      duration = '$ms ms';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                running
                    ? LucideIcons.hourglass
                    : (success ? LucideIcons.checkCircle : LucideIcons.xCircle),
                size: 14,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _format(record.startedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xs,
                ),
              ),
              const Spacer(),
              Text(
                duration,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.xs,
                ),
              ),
            ],
          ),
          if (record.output.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.output,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xxs,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
