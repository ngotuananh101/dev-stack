import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme/app_text_size.dart';
import '../data/system_metrics_provider.dart';

class StorageCard extends ConsumerWidget {
  const StorageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(systemMetricsNotifierProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STORAGE USAGE',
            style: TextStyle(
              fontSize: AppTextSize.xxs,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${metrics.storageUsed.toStringAsFixed(0)} GB / ${metrics.storageTotal.toStringAsFixed(0)} GB',
            style: const TextStyle(
              fontSize: AppTextSize.lg,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: metrics.storageUsed / metrics.storageTotal,
            backgroundColor: AppColors.surfaceLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'USED: ${metrics.storagePercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'AVAILABLE: ${(metrics.storageTotal - metrics.storageUsed).toStringAsFixed(0)} GB',
                style: const TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _buildMiniStat('DISK 0', 'NVMe SSD'),
              const SizedBox(width: 24),
              _buildMiniStat('HEALTH', '98%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTextSize.xxxs,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
