import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import 'app_version_modal.dart';

class CompactAppsTable extends StatelessWidget {
  final List<AppModel> apps;
  final Future<void> Function(AppModel) onToggleInstall;
  final Future<void> Function(AppModel) onToggleDashboard;

  const CompactAppsTable({
    super.key,
    required this.apps,
    required this.onToggleInstall,
    required this.onToggleDashboard,
  });

  IconData _getAppIcon(String appId) {
    if (appId.contains('nginx') && appId.contains('waf')) return Icons.shield;
    if (appId.contains('php')) return Icons.code;
    if (appId.contains('apache') && appId.contains('waf'))
      return Icons.security;
    if (appId.contains('mysql')) return Icons.storage;
    if (appId.contains('cloud')) return Icons.cloud;
    return Icons.apps;
  }

  Color _getIconColor(String appId) {
    if (appId.contains('nginx') && appId.contains('waf'))
      return const Color(0xFF4169E1);
    if (appId.contains('php')) return const Color(0xFF7B68EE);
    if (appId.contains('apache') && appId.contains('waf'))
      return const Color(0xFFDC143C);
    if (appId.contains('mysql')) return const Color(0xFF20B2AA);
    if (appId.contains('cloud')) return const Color(0xFF58A6FF);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildHeaderCell('SOFTWARE NAME')),
                Expanded(flex: 2, child: _buildHeaderCell('DEVELOPER')),
                Expanded(flex: 3, child: _buildHeaderCell('DESCRIPTION')),
                Expanded(flex: 1, child: _buildHeaderCell('STATUS')),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell(
                    'OPERATE',
                    alignment: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table Body
          ...apps.asMap().entries.map((entry) {
            final index = entry.key;
            final app = entry.value;
            return _buildAppRow(context, app, index == apps.length - 1);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    TextAlign alignment = TextAlign.left,
  }) {
    return Text(
      label,
      textAlign: alignment,
      style: const TextStyle(
        fontSize: AppTextSize.xxxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAppRow(BuildContext context, AppModel app, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? Border()
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Software name with icon
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getIconColor(app.appId).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getAppIcon(app.appId),
                    size: 16,
                    color: _getIconColor(app.appId),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontSize: AppTextSize.sm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'v0.1.0',
                        style: TextStyle(
                          fontSize: AppTextSize.xxxs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Developer
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: app.developer.toLowerCase() == 'official'
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: app.developer.toLowerCase() == 'official'
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  app.developer.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: app.developer.toLowerCase() == 'official'
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // Description
          Expanded(
            flex: 3,
            child: Text(
              app.description ?? 'No description',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSize.xxs,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Status
          Expanded(flex: 1, child: _buildStatusIndicator(app)),
          // Operate buttons
          Expanded(flex: 2, child: _buildOperateButtons(context, app)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AppModel app) {
    if (app.isInstalled && app.status == 'running') {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Running',
            style: TextStyle(
              fontSize: AppTextSize.xxs,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (app.isInstalled) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Installed',
            style: TextStyle(
              fontSize: AppTextSize.xxs,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return const Text(
        'Not Installed',
        style: TextStyle(fontSize: AppTextSize.xxs, color: AppColors.textMuted),
      );
    }
  }

  Widget _buildOperateButtons(BuildContext context, AppModel app) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (app.isInstalled) ...[
          if (app.status == 'running') ...[
            OutlinedButton(
              onPressed: () => onToggleInstall(app),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surfaceLight,
              ),
              child: const Text(
                'STOP',
                style: TextStyle(
                  fontSize: AppTextSize.xxxs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => onToggleInstall(app),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surfaceLight,
              ),
              child: const Text(
                'LOGS',
                style: TextStyle(
                  fontSize: AppTextSize.xxxs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => onToggleInstall(app),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surfaceLight,
              ),
              child: const Text(
                'SETUP',
                style: TextStyle(
                  fontSize: AppTextSize.xxxs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onToggleInstall(app),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                backgroundColor: AppColors.primary.withOpacity(0.2),
              ),
              child: const Text(
                'UPDATE',
                style: TextStyle(
                  fontSize: AppTextSize.xxxs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ] else
          OutlinedButton(
            onPressed: () => _showVersionModal(context, app),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              side: BorderSide(color: AppColors.primary),
              backgroundColor: Colors.transparent,
            ),
            child: const Text(
              'INSTALL',
              style: TextStyle(
                fontSize: AppTextSize.xxxs,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  void _showVersionModal(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: AppVersionModal(
            app: app,
            onInstall: () {
              Navigator.of(dialogContext).pop();
              onToggleInstall(app);
            },
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }
}
