import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';

enum AppButtonStyle { primary, secondary, ghost, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final AppButtonStyle style;
  final Widget? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: Material(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: _getBorder(),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(
                  label,
                  style: TextStyle(
                    color: _getTextColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: AppTextSize.xs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (style) {
      case AppButtonStyle.primary:
        return AppColors.accent;
      case AppButtonStyle.secondary:
        return AppColors.surfaceLight;
      case AppButtonStyle.ghost:
      case AppButtonStyle.outline:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    switch (style) {
      case AppButtonStyle.primary:
        return Colors.black;
      case AppButtonStyle.secondary:
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return AppColors.textPrimary;
    }
  }

  Border? _getBorder() {
    if (style == AppButtonStyle.outline) {
      return Border.all(color: AppColors.border);
    }
    return null;
  }
}
