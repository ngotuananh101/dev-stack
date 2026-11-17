import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';
import '../../shared/providers/navigation_provider.dart';
import '../../shared/providers/sidebar_provider.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(navigationProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // The width changes in one step on purpose: animating it makes the nav
    // items' fixed 18px icon and 12px insets wider than the sidebar part-way
    // through, which throws a RenderFlex overflow.
    return Container(
      width: collapsed ? 64 : 200,
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
      ),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 8 : 16,
          vertical: 12,
        ),
        children: [
          _buildNavItem(
            LucideIcons.layoutGrid,
            'Apps',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.apps,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.apps),
          ),
          _buildNavItem(
            LucideIcons.globe,
            'Sites',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.sites,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.sites),
          ),
          _buildNavItem(
            LucideIcons.database,
            'Databases',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.databases,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.databases),
          ),
          _buildNavItem(
            LucideIcons.radio,
            'Tunnels',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.tunnels,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.tunnels),
          ),
          _buildNavItem(
            LucideIcons.activity,
            'Supervisor',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.supervisor,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.supervisor),
          ),
          _buildNavItem(
            LucideIcons.clock,
            'Cron',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.cron,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.cron),
          ),
          _buildNavItem(
            LucideIcons.terminal,
            'Logs',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.logs,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.logs),
          ),
          _buildNavItem(
            LucideIcons.fileText,
            'Hosts',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.hosts,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.hosts),
          ),
          _buildNavItem(
            LucideIcons.settings,
            'Settings',
            collapsed: collapsed,
            isActive: currentTab == NavigationTab.settings,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    required bool collapsed,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final item = Container(
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
                if (collapsed)
                  const SizedBox.shrink()
                else ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: AppTextSize.xs,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Collapsed, the label is gone, so the icon alone carries the entry: the
    // tooltip is what makes it usable.
    return collapsed ? Tooltip(message: label, child: item) : item;
  }
}
