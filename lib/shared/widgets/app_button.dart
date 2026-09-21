import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

enum AppButtonStyle { primary, secondary, ghost, outline, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppButtonSize size;
  final Widget? icon;
  final double? width;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.width,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
  });

  double get _height {
    switch (size) {
      case AppButtonSize.sm:
        return 32.0;
      case AppButtonSize.md:
        return 36.0;
      case AppButtonSize.lg:
        return 40.0;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.sm:
        return AppTextSize.xs; // 12
      case AppButtonSize.md:
        return 13.0;
      case AppButtonSize.lg:
        return AppTextSize.sm; // 14
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10);
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 14);
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: width,
      height: _height,
      child: Material(
        color: _getBackgroundColor(isEnabled),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: _padding,
            decoration: BoxDecoration(
              border: _getBorder(isEnabled),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_getTextColor(isEnabled)),
                    ),
                  ),
                ] else ...[
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: TextStyle(
                      color: _getTextColor(isEnabled),
                      fontWeight: FontWeight.w600,
                      fontSize: _fontSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (backgroundColor != null) {
      return isEnabled
          ? backgroundColor!
          : backgroundColor!.withValues(alpha: 0.5);
    }
    if (!isEnabled) {
      return AppColors.surfaceLight.withValues(alpha: 0.5);
    }
    switch (style) {
      case AppButtonStyle.primary:
        return AppColors.primary;
      case AppButtonStyle.secondary:
        return AppColors.surfaceLight;
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return Colors.transparent;
      case AppButtonStyle.danger:
        return AppColors.error.withValues(alpha: 0.15);
    }
  }

  Color _getTextColor(bool isEnabled) {
    if (textColor != null) {
      return isEnabled ? textColor! : AppColors.textMuted;
    }
    if (!isEnabled) {
      return AppColors.textMuted;
    }
    switch (style) {
      case AppButtonStyle.primary:
        return Colors.white;
      case AppButtonStyle.secondary:
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return AppColors.textPrimary;
      case AppButtonStyle.danger:
        return AppColors.error;
    }
  }

  Border? _getBorder(bool isEnabled) {
    if (style == AppButtonStyle.outline || style == AppButtonStyle.secondary) {
      return Border.all(
        color: isEnabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        width: 0.5,
      );
    }
    if (style == AppButtonStyle.danger) {
      return Border.all(
        color: isEnabled ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
        width: 0.5,
      );
    }
    return null;
  }
}
