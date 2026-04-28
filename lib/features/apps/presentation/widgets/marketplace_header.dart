import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MarketplaceHeader extends StatelessWidget {
  final VoidCallback onUpdate;
  final Widget? actions;

  const MarketplaceHeader({
    super.key,
    required this.onUpdate,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'REGISTRY EXPLORER',
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Marketplace',
              style: TextStyle(
                fontSize: AppTextSize.xxl,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Actions (e.g. Category Bar)
        actions ?? const SizedBox.shrink(),
        const SizedBox(width: 16),
        // Update Button
        IconButton(
          onPressed: onUpdate,
          icon: const Icon(
            LucideIcons.refreshCw,
            size: 18,
            color: AppColors.textSecondary,
          ),
          tooltip: 'Update App List',
          splashRadius: 20,
        ),
      ],
    );
  }
}
