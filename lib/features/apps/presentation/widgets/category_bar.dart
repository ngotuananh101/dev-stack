import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';

class CategoryBar extends StatelessWidget {
  final String? selectedCategory;
  final Function(String?) onCategoryChanged;
  final Map<String, int> categoryCounts;

  const CategoryBar({
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
    return Container(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _categories.asMap().entries.map((entry) {
            final index = entry.key;
            final cat = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: index == _categories.length - 1 ? 0 : 12),
              child: _buildCategoryItem(cat['label']!, cat['value']),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String label, String? value) {
    final isSelected = selectedCategory == value;
    final count = categoryCounts[value ?? 'all'] ?? 0;

    return GestureDetector(
      onTap: () => onCategoryChanged(value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(0.1) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.5) 
                  : AppColors.surfaceLight,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.small,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
