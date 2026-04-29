import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/site_model.dart';
import '../../data/sites_provider.dart';
import '../../../../shared/utils/app_dialogs.dart';

class SiteTable extends ConsumerWidget {
  final List<SiteModel> sites;
  final Set<int> selectedIds;
  final Function(SiteModel) onEdit;
  final Function(int) onToggleSelection;
  final Function(bool) onToggleAll;

  const SiteTable({
    super.key,
    required this.sites,
    required this.selectedIds,
    required this.onEdit,
    required this.onToggleSelection,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (sites.isEmpty)
            _buildEmptyState()
          else
            Expanded(
              child: ListView.builder(
                itemCount: sites.length,
                itemBuilder: (context, index) =>
                    _buildRow(context, ref, sites[index], index == sites.length - 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final allSelected = sites.isNotEmpty && sites.every((s) => selectedIds.contains(s.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allSelected,
              onChanged: (val) => onToggleAll(val ?? false),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _buildHeaderCell('SITE NAME')),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _buildHeaderCell('PATH / TARGET')),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: _buildHeaderCell('TYPE')),
          const SizedBox(width: 12),
          SizedBox(width: 50, child: _buildHeaderCell('SSL')),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: _buildHeaderCell('OPERATE', alignment: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {TextAlign alignment = TextAlign.left}) {
    return Text(
      label,
      textAlign: alignment,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, SiteModel site, bool isLast) {
    final isSelected = selectedIds.contains(site.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent.withValues(alpha: 0.05) : null,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelection(site.id),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              site.domain,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              site.siteType == 'proxy' ? (site.proxyTarget ?? '-') : site.rootDir,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              site.siteType == 'php' ? 'PHP ${site.phpVersion}' : site.siteType.toUpperCase(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 50,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                site.useSsl ? LucideIcons.lock : LucideIcons.unlock,
                size: 14,
                color: site.useSsl ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: LucideIcons.settings,
                  onPressed: () => onEdit(site),
                  color: AppColors.textSecondary,
                  tooltip: 'Config',
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: LucideIcons.trash2,
                  onPressed: () {
                    AppDialogs.showConfirm(
                      context: context,
                      title: 'Delete Site',
                      text: 'Are you sure you want to delete ${site.domain}? This will also remove vhost configurations and logs.',
                      confirmBtnText: 'DELETE',
                      onConfirm: () {
                        ref.read(sitesNotifierProvider.notifier).deleteSite(site.id);
                      },
                    );
                  },
                  color: AppColors.error,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Text(
          'No sites found',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
