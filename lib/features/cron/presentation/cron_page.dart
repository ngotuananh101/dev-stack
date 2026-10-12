import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/cron_provider.dart';
import '../data/cron_scheduler_service.dart';
import '../domain/cron_job.dart';
import 'widgets/cron_form_modal.dart';
import 'widgets/cron_table.dart';
import 'widgets/run_history_modal.dart';

class CronPage extends ConsumerWidget {
  const CronPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(cronJobsProvider);
    final runningIds = ref.watch(cronRunStateProvider);
    final scheduler = ref.watch(cronSchedulerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Expanded(
              child: jobsAsync.when(
                data: (jobs) => CronTable(
                  jobs: jobs,
                  runningIds: runningIds,
                  onRunNow: (job) async {
                    try {
                      await scheduler.runNow(job);
                    } catch (e) {
                      if (context.mounted) {
                        AppDialogs.showError(
                          context,
                          title: 'Run Failed',
                          message: '$e',
                        );
                      }
                    }
                  },
                  onToggleEnabled: (job) async {
                    try {
                      await _toggleEnabled(ref, job);
                    } catch (e) {
                      if (context.mounted) {
                        AppDialogs.showError(
                          context,
                          title: 'Cannot Update Job',
                          message: '$e',
                        );
                      }
                    }
                  },
                  onViewHistory: (job) =>
                      _viewHistory(context, scheduler, job),
                  onEdit: (job) => _edit(context, job),
                  onDelete: (job) => _delete(context, ref, job),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading cron jobs: $e',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cron',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Run commands on a schedule while DevStack is open',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.sm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: 'New Job',
          icon: const Icon(LucideIcons.plus, size: 16),
          style: AppButtonStyle.success,
          onPressed: () => _create(context),
        ),
      ],
    );
  }

  Future<void> _toggleEnabled(WidgetRef ref, CronJob job) async {
    job.enabled = !job.enabled;
    await ref.read(cronRepositoryProvider).save(job);
  }

  void _create(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const Center(child: CronFormModal()),
    );
  }

  void _edit(BuildContext context, CronJob job) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Center(child: CronFormModal(initialJob: job)),
    );
  }

  void _viewHistory(
    BuildContext context,
    CronSchedulerService scheduler,
    CronJob job,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => RunHistoryModal(scheduler: scheduler, job: job),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, CronJob job) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Delete Job',
      text: 'Delete "${job.name}"? Its configuration will be removed. '
          'This cannot be undone.',
      confirmBtnText: 'DELETE',
      onConfirm: () => ref.read(cronRepositoryProvider).delete(job.id),
    );
  }
}
