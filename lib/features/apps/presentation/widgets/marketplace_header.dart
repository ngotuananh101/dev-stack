import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';

class MarketplaceHeader extends StatelessWidget {
  final String? selectedTab;
  final Function(String?) onTabChanged;

  const MarketplaceHeader({
    super.key,
    this.selectedTab,
    required this.onTabChanged,
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
                fontSize: AppTextSize.caption,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Marketplace',
              style: TextStyle(
                fontSize: AppTextSize.h2,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Right: Filter tabs
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              _buildTab('All Software', null),
              _buildTab('Installed', 'installed'),
              _buildTab('Professional', 'professional'),
              _buildTab('Third-party', 'third-party'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, String? value) {
    final isSelected = selectedTab == value;
    return GestureDetector(
      onTap: () => onTabChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTextSize.small,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
