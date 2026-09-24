import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';
import 'app_icon_button.dart';

/// Standard modal header unified across all popups/modals in the application,
/// matching the AddSiteModal header layout and styling.
class AppModalHeader extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final double iconSize;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final Widget? subtitleWidget;
  final TextStyle? subtitleStyle;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const AppModalHeader({
    super.key,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.iconSize = 20.0,
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleWidget,
    this.subtitleStyle,
    this.actions,
    this.onClose,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 24.0,
      vertical: 12.0,
    ),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leading;
    if (iconWidget != null) {
      leading = iconWidget;
    } else if (icon != null) {
      leading = Icon(
        icon,
        size: iconSize,
        color: iconColor ?? AppColors.primary,
      );
    }

    final effectiveTitleStyle = const TextStyle(
      fontSize: AppTextSize.sm,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ).merge(titleStyle);

    final effectiveSubtitleStyle = const TextStyle(
      fontSize: AppTextSize.xxs,
      color: AppColors.textMuted,
    ).merge(subtitleStyle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: effectiveTitleStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (subtitleWidget != null)
                      subtitleWidget!
                    else if (subtitle != null)
                      Text(
                        subtitle!,
                        style: effectiveSubtitleStyle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                ...actions!,
                if (onClose != null) const SizedBox(width: 8),
              ],
              if (onClose != null)
                AppIconButton(
                  onPressed: onClose,
                  icon: LucideIcons.x,
                  tooltip: 'Close',
                  color: AppColors.textMuted,
                  size: AppIconButtonSize.sm,
                ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            color: AppColors.border,
            height: 1,
          ),
      ],
    );
  }
}
