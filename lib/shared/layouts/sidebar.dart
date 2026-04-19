import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';
import '../../shared/providers/navigation_provider.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(navigationProvider);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildNavItem(
                  LucideIcons.layoutDashboard,
                  'Dashboard',
                  isActive: currentTab == NavigationTab.dashboard,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.dashboard),
                ),
                _buildNavItem(
                  LucideIcons.layoutGrid,
                  'Apps',
                  isActive: currentTab == NavigationTab.apps,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.apps),
                ),
                _buildNavItem(
                  LucideIcons.globe,
                  'Sites',
                  isActive: currentTab == NavigationTab.sites,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.sites),
                ),
                _buildNavItem(
                  LucideIcons.database,
                  'Databases',
                  isActive: currentTab == NavigationTab.databases,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.databases),
                ),
                _buildNavItem(
                  LucideIcons.server,
                  'Hosts',
                  isActive: currentTab == NavigationTab.hosts,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.hosts),
                ),
                _buildNavItem(
                  LucideIcons.terminal,
                  'Logs',
                  isActive: currentTab == NavigationTab.logs,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.logs),
                ),
                _buildNavItem(
                  LucideIcons.settings,
                  'Settings',
                  isActive: currentTab == NavigationTab.settings,
                  onTap: () => ref
                      .read(navigationProvider.notifier)
                      .setTab(NavigationTab.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.component,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DevStack',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextSize.lg,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'LOCAL NODE',
                style: TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppColors.surfaceLight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
