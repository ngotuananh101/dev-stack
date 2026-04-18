import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../widgets/stat_card.dart';
import '../widgets/memory_card.dart';
import '../widgets/storage_card.dart';
import '../widgets/environment_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../data/system_metrics_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(systemMetricsNotifierProvider);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
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
              height: 210,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: const StatCard(
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
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('ACTIVE ENVIRONMENTS'),
                _buildViewToggle(),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 1.5,
              children: [
                EnvironmentCard(
                  name: 'main-api-service',
                  host: 'localhost:5001',
                  runtime: 'Node.js v20.x',
                  status: StatusType.stable,
                  tags: ['JS', 'DB', 'RE'],
                ),
                EnvironmentCard(
                  name: 'react-frontend-next',
                  host: 'localhost:3000',
                  runtime: 'Next.js 14',
                  status: StatusType.restarting,
                  tags: ['TS', 'TW'],
                ),
                EnvironmentCard(
                  name: 'python-data-processor',
                  host: 'offline',
                  runtime: 'Python 3.12',
                  status: StatusType.stopped,
                  tags: ['PY', 'PD'],
                ),
              ],
            ),
            const SizedBox(height: 48),
            _buildConsoleSection(),
          ],
        ),
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

  Widget _buildViewToggle() {
    return Row(
      children: [
        Icon(LucideIcons.layoutGrid, size: 18, color: AppColors.textPrimary),
        const SizedBox(width: 12),
        Icon(LucideIcons.list, size: 18, color: AppColors.textSecondary),
      ],
    );
  }

  Widget _buildConsoleSection() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.terminal,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE CONSOLE OUTPUT',
              style: TextStyle(
                fontSize: AppTextSize.xxs,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 24),
            Text(
              'ALL SOURCES',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF07090D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView(
            children: [
              _buildConsoleLine(
                '14:32:01',
                'INFO',
                'Initializing DevStack local cluster...',
              ),
              _buildConsoleLine(
                '14:32:02',
                'INFO',
                'Mounting volumes for main-api-service...',
              ),
              _buildConsoleLine(
                '14:32:04',
                'DEBUG',
                'Connection established with PostgreSQL daemon.',
              ),
              _buildConsoleLine(
                '14:32:05',
                'SUCCESS',
                'main-api-service is listening on port 5001.',
              ),
              _buildConsoleLine(
                '14:32:10',
                'WARN',
                'react-frontend-next high memory pressure detected (88%).',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleLine(String time, String type, String message) {
    Color typeColor = Colors.blue;
    if (type == 'WARN') typeColor = Colors.yellow;
    if (type == 'SUCCESS') typeColor = Colors.green;
    if (type == 'DEBUG') typeColor = Colors.purple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          children: [
            TextSpan(
              text: '[$time] ',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextSpan(
              text: '$type: ',
              style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: message,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
