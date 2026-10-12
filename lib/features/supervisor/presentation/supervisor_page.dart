import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/supervisor_manager.dart';
import '../data/supervisor_provider.dart';
import '../domain/supervisor_program.dart';
import 'widgets/program_form_modal.dart';
import 'widgets/program_logs_modal.dart';
import 'widgets/supervisor_table.dart';

class SupervisorPage extends ConsumerWidget {
  const SupervisorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(supervisorProgramsProvider);
    final statuses = ref.watch(supervisorStatusProvider);
    final manager = ref.watch(supervisorManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 24),
            Expanded(
              child: programsAsync.when(
                data: (programs) => SupervisorTable(
                  programs: programs,
                  statuses: statuses,
                  pids: {
                    for (final p in programs) p.id: manager.getPid(p.id),
                  },
                  onStart: (p) => _start(context, manager, p),
                  onStop: (id) => manager.stop(id),
                  onRestart: (p) => _restart(context, manager, p),
                  onViewLogs: (p) => _viewLogs(context, manager, p),
                  onEdit: (p) => _edit(context, p),
                  onDelete: (p) => _delete(context, ref, manager, p),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading programs: $e',
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

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep long-running processes alive with automatic restarts',
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
          label: 'New Program',
          icon: const Icon(LucideIcons.plus, size: 16),
          style: AppButtonStyle.success,
          onPressed: () => _create(context),
        ),
      ],
    );
  }

  void _create(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const Center(child: ProgramFormModal()),
    );
  }

  void _edit(BuildContext context, SupervisorProgram program) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Center(child: ProgramFormModal(initialProgram: program)),
    );
  }

  void _viewLogs(
    BuildContext context,
    SupervisorManager manager,
    SupervisorProgram program,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => ProgramLogsModal(manager: manager, program: program),
    );
  }

  Future<void> _start(
    BuildContext context,
    SupervisorManager manager,
    SupervisorProgram program,
  ) async {
    try {
      await manager.start(program);
    } catch (e) {
      if (context.mounted) {
        await AppDialogs.showError(
          context,
          title: 'Cannot Start Program',
          message: '$e',
        );
      }
    }
  }

  Future<void> _restart(
    BuildContext context,
    SupervisorManager manager,
    SupervisorProgram program,
  ) async {
    try {
      await manager.restart(program);
    } catch (e) {
      if (context.mounted) {
        await AppDialogs.showError(
          context,
          title: 'Cannot Restart Program',
          message: '$e',
        );
      }
    }
  }

  void _delete(
    BuildContext context,
    WidgetRef ref,
    SupervisorManager manager,
    SupervisorProgram program,
  ) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Delete Program',
      text: 'Delete "${program.name}"? The process will be stopped and its '
          'configuration removed. This cannot be undone.',
      confirmBtnText: 'DELETE',
      onConfirm: () async {
        await manager.stop(program.id);
        await ref.read(supervisorRepositoryProvider).delete(program.id);
      },
    );
  }
}
