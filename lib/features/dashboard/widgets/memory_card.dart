import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme/app_text_size.dart';
import '../data/system_metrics_provider.dart';

class MemoryCard extends ConsumerWidget {
  const MemoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(systemMetricsNotifierProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEMORY ALLOCATION',
            style: TextStyle(
              fontSize: AppTextSize.cardTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${metrics.memoryUsed.toStringAsFixed(1)} GB / ${metrics.memoryTotal.toStringAsFixed(0)} GB',
            style: const TextStyle(
              fontSize: AppTextSize.h4,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: metrics.memoryUsed / metrics.memoryTotal,
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
                'USED: ${metrics.memoryPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: AppTextSize.small, color: AppColors.textSecondary),
              ),
              Text(
                'FREE: ${(metrics.memoryTotal - metrics.memoryUsed).toStringAsFixed(1)} GB',
                style: const TextStyle(fontSize: AppTextSize.small, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _buildMiniStat('CACHED', '2.1 GB'),
              const SizedBox(width: 24),
              _buildMiniStat('SWAP', '512 MB'),
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
            fontSize: AppTextSize.tiny,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
