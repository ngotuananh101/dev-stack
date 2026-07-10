import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/batch_models.dart';

/// Modal dialog showing live batch progress with a Cancel button. Cancel is
/// hidden once the batch reaches the finalizing phase.
class BatchProgressDialog extends StatefulWidget {
  final String title;
  final ValueListenable<BatchProgress> progress;
  final VoidCallback onCancel;

  const BatchProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  @override
  State<BatchProgressDialog> createState() => _BatchProgressDialogState();
}

class _BatchProgressDialogState extends State<BatchProgressDialog> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<BatchProgress>(
            valueListenable: widget.progress,
            builder: (context, p, _) {
              final isFinalizing = p.phase == BatchPhase.finalizing;
              final percent =
                  (p.fraction * 100).clamp(0, 100).toStringAsFixed(0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.md,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isFinalizing ? null : p.fraction,
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFinalizing
                        ? 'Updating hosts & restarting webservers…'
                        : '${p.current} / ${p.total}  ($percent%)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isFinalizing && p.currentLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.currentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: AppTextSize.xs,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!isFinalizing)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelling
                            ? null
                            : () {
                                setState(() => _cancelling = true);
                                widget.onCancel();
                              },
                        child: Text(
                          _cancelling ? 'Cancelling…' : 'Cancel',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
