import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/theme/app_text_size.dart';

class EnvironmentCard extends StatelessWidget {
  final String name;
  final String host;
  final String runtime;
  final StatusType status;
  final List<String> tags;

  const EnvironmentCard({
    super.key,
    required this.name,
    required this.host,
    required this.runtime,
    required this.status,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusChip(type: status),
              Row(
                children: [
                  _buildIconButton(LucideIcons.play),
                  const SizedBox(width: 4),
                  _buildIconButton(LucideIcons.maximize2),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: AppTextSize.base,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$host • $runtime',
            style: const TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ...tags.map((tag) => _buildTag(tag)),
              const Spacer(),
              _buildIconButton(LucideIcons.refreshCw, size: 14),
              const SizedBox(width: 12),
              _buildIconButton(LucideIcons.image, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: AppTextSize.xxxs,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {double size = 16}) {
    return Icon(icon, size: size, color: AppColors.primary.withOpacity(0.7));
  }
}
