import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';

enum StatusType { stable, restarting, stopped, warning }

class StatusChip extends StatelessWidget {
  final StatusType type;
  final String? label;

  const StatusChip({
    super.key,
    required this.type,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getColor().withOpacity(0.2)),
      ),
      child: Text(
        (label ?? _getDefaultLabel()).toUpperCase(),
        style: TextStyle(
          color: _getColor(),
          fontSize: AppTextSize.small,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (type) {
      case StatusType.stable:
        return AppColors.success;
      case StatusType.restarting:
        return AppColors.warning;
      case StatusType.stopped:
        return AppColors.error;
      case StatusType.warning:
        return AppColors.warning;
    }
  }

  String _getDefaultLabel() {
    switch (type) {
      case StatusType.stable:
        return 'Stable';
      case StatusType.restarting:
        return 'Restarting';
      case StatusType.stopped:
        return 'Stopped';
      case StatusType.warning:
        return 'Warning';
    }
  }
}
