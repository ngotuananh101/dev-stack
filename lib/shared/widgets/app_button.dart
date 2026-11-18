import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';

enum AppButtonStyle { primary, secondary, success, ghost, outline, danger, warning }

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
    this.size = AppButtonSize.sm,
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

  /// Every size reads at the body size; the size only changes the box around
  /// it. A taller button with a larger label is how one form ended up with two
  /// type sizes in the same row of controls.
  double get _fontSize => AppTextSize.xs;

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasExplicitWidth =
                    width != null ||
                    constraints.minWidth == constraints.maxWidth;
                final labelWidget = Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: _getTextColor(isEnabled),
                    fontWeight: FontWeight.w600,
                    fontSize: _fontSize,
                  ),
                );
                return Row(
                  mainAxisSize: hasExplicitWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getTextColor(isEnabled),
                          ),
                        ),
                      )
                    else ...[
                      if (icon != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: _getTextColor(isEnabled),
                          ),
                          child: icon!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      // A flex child is only legal when this button has a
                      // tight/explicit width constraint. In loose contexts
                      // (Row, Wrap) it must size to its text instead.
                      hasExplicitWidth
                          ? Flexible(child: labelWidget)
                          : labelWidget,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // All buttons are outline (2026-11-17): transparent fill, a border in
  // the style's colour, and text to match. An explicit [backgroundColor]
  // still wins for callers that pass one.
  Color _getBackgroundColor(bool isEnabled) {
    if (backgroundColor != null) {
      return isEnabled
          ? backgroundColor!
          : backgroundColor!.withValues(alpha: 0.5);
    }
    return Colors.transparent;
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
        return AppColors.primary;
      case AppButtonStyle.success:
        return AppColors.success;
      case AppButtonStyle.warning:
        return AppColors.warning;
      case AppButtonStyle.secondary:
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        return AppColors.textPrimary;
      case AppButtonStyle.danger:
        return AppColors.error;
    }
  }

  Border _getBorder(bool isEnabled) {
    final Color color;
    switch (style) {
      case AppButtonStyle.primary:
        color = AppColors.primary;
        break;
      case AppButtonStyle.success:
        color = AppColors.success;
        break;
      case AppButtonStyle.warning:
        color = AppColors.warning;
        break;
      case AppButtonStyle.danger:
        color = AppColors.error;
        break;
      case AppButtonStyle.secondary:
      case AppButtonStyle.outline:
      case AppButtonStyle.ghost:
        color = AppColors.border;
        break;
    }
    return Border.all(
      color: isEnabled ? color : color.withValues(alpha: 0.5),
      width: 0.5,
    );
  }
}
