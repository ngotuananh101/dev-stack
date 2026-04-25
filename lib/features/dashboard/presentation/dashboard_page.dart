import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../widgets/stat_card.dart';
import '../widgets/memory_card.dart';
import '../widgets/storage_card.dart';
import '../widgets/resource_chart.dart';
import '../data/system_metrics_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(systemMetricsNotifierProvider);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'System Overview',
            ip: metrics.ipAddress,
            isMain: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: StatCard(
                    title: 'COMPUTE LOAD',
                    label: 'CPU Performance',
                    subValue: '16 CORES ACTIVE',
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: MemoryCard()),
                const SizedBox(width: 24),
                const Expanded(flex: 1, child: StorageCard()),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ResourceChart(metrics: metrics),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? ip, bool isMain = false}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMain ? AppTextSize.xl : AppTextSize.xs,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: isMain ? 0 : 1,
          ),
        ),
        if (isMain && ip != null) ...[
          const SizedBox(width: 16),
          _buildStatusDot(),
          const SizedBox(width: 8),
          Text(
            'IP ADDRESS: $ip',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}
