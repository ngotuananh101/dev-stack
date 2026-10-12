import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../domain/app_model.dart';

class ServiceLogsModal extends ConsumerWidget {
  final AppModel app;
  final VoidCallback onClose;

  const ServiceLogsModal({
    super.key,
    required this.app,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = modalDimensions(context, ModalSize.xl);
    return SizedBox(
      width: dims.width,
      height: dims.height,
      child: TerminalLogView(
        title: 'Service Logs: ${app.name}',
        lines: app.serviceLogs,
        isModal: true,
        onClose: onClose,
        statusWidget: _buildStatusWidget(),
      ),
    );
  }

  Widget _buildStatusWidget() {
    final isRunning = app.serviceStatus == 'running';
    return Text(
      isRunning ? 'Running (PID: ${app.servicePid})' : 'Service Stopped',
      style: TextStyle(
        fontSize: AppTextSize.xxs,
        color: isRunning ? AppColors.success : AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
