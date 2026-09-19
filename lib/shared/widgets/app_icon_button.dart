import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

enum AppIconButtonSize { sm, md }

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;
  final AppIconButtonSize size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = AppIconButtonSize.sm,
  });

  double get _dimension => size == AppIconButtonSize.sm ? 28.0 : 32.0;
  double get _iconSize => size == AppIconButtonSize.sm ? 14.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            width: _dimension,
            height: _dimension,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surfaceLight,
              border: Border.all(
                color: (color != null ? color!.withValues(alpha: 0.25) : AppColors.border),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Center(
              child: Icon(
                icon,
                size: _iconSize,
                color: isEnabled ? effectiveColor : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
