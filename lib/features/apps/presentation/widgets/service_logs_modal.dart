import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
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
    return Container(
      width: 800,
      height: 600,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Logs: ${app.name}',
                        style: const TextStyle(
                          fontSize: AppTextSize.sm,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        app.serviceStatus == 'running' 
                          ? 'Running (PID: ${app.servicePid})' 
                          : 'Service Stopped',
                        style: TextStyle(
                          fontSize: AppTextSize.xxs,
                          color: app.serviceStatus == 'running' 
                            ? AppColors.success 
                            : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.border, height: 1),
          // Logs Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117), // GitHub Dark Terminal Color
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                itemCount: app.serviceLogs.length,
                reverse: true, // Show latest logs first
                itemBuilder: (context, index) {
                  final log = app.serviceLogs[app.serviceLogs.length - 1 - index];
                  final isError = log.contains('[ERROR]');
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono', // Or any monospace
                        fontSize: 12,
                        color: isError ? AppColors.error : const Color(0xFFE6EDF3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
