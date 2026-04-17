import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';

class CompactPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int startItem;
  final int endItem;
  final int totalItems;
  final Function(int) onPageChanged;

  const CompactPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.startItem,
    required this.endItem,
    required this.totalItems,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Showing X-Y of Z items
        Text(
          'Showing $startItem-$endItem of $totalItems items',
          style: const TextStyle(
            fontSize: AppTextSize.small,
            color: AppColors.textMuted,
          ),
        ),
        // Page numbers
        Row(
          children: [
            // Previous button
            _buildPageButton(
              icon: Icons.chevron_left,
              onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            ),
            const SizedBox(width: 4),
            // Page numbers
            ..._buildPageNumbers(),
            const SizedBox(width: 4),
            // Next button
            _buildPageButton(
              icon: Icons.chevron_right,
              onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: onPressed == null ? AppColors.textMuted : AppColors.textSecondary,
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    if (totalPages <= 0) return [];
    
    final List<Widget> widgets = [];
    
    int start = (currentPage - 2).clamp(1, totalPages);
    int end = (start + 4).clamp(start, totalPages);
    
    if (end == totalPages) {
      start = (end - 4).clamp(1, totalPages);
    }
    
    for (int i = start; i <= end; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _buildPageNumberButton(i),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildPageNumberButton(int page) {
    final isSelected = page == currentPage;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextButton(
        onPressed: () => onPageChanged(page),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: AppTextSize.small,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
