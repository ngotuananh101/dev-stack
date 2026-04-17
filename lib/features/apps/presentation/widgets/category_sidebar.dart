import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';

class CategorySidebar extends StatelessWidget {
  final String? selectedCategory;
  final Function(String?) onCategoryChanged;
  final Map<String, int> categoryCounts;

  const CategorySidebar({
    super.key,
    this.selectedCategory,
    required this.onCategoryChanged,
    required this.categoryCounts,
  });

  final List<Map<String, String?>> _categories = const [
    {'label': 'All', 'value': null},
    {'label': 'System Tools', 'value': 'tools'},
    {'label': 'Runtime', 'value': 'runtime'},
    {'label': 'Database', 'value': 'database'},
    {'label': 'Security', 'value': 'security'},
    {'label': 'Plugins', 'value': 'plugins'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORIES',
          style: TextStyle(
            fontSize: AppTextSize.tiny,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._categories.map((cat) => _buildCategoryItem(cat['label']!, cat['value'])).toList(),
      ],
    );
  }

  Widget _buildCategoryItem(String label, String? value) {
    final isSelected = selectedCategory == value;
    final count = categoryCounts[value ?? 'all'] ?? 0;

    return GestureDetector(
      onTap: () => onCategoryChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppTextSize.small,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: AppTextSize.tiny,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
