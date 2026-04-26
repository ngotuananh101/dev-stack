import 'package:flutter/material.dart';
import '../../../../shared/utils/app_dialogs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import 'app_version_modal.dart';
import 'service_logs_modal.dart';
import 'app_settings_modal.dart';
import 'pyenv_manage_modal.dart';


class CompactAppsTable extends StatelessWidget {
  final List<AppModel> apps;
  final Future<void> Function(AppModel) onToggleInstall;
  final Future<void> Function(AppModel) onTogglePath;
  final Future<void> Function(AppModel) onStartService;
  final Future<void> Function(AppModel) onStopService;
  final Future<void> Function(AppModel) onRestartService;
  final Future<void> Function(String) onChangeDefault;
  final Future<void> Function(AppModel) onOpen;

  const CompactAppsTable({
    super.key,
    required this.apps,
    required this.onToggleInstall,
    required this.onTogglePath,
    required this.onStartService,
    required this.onStopService,
    required this.onRestartService,
    required this.onChangeDefault,
    required this.onOpen,
  });

  IconData _getAppIcon(String appId) {
    if (appId.contains('nginx') && appId.contains('waf')) {
      return Icons.shield;
    }
    if (appId.contains('php')) {
      return Icons.code;
    }
    if (appId.contains('apache') && appId.contains('waf')) {
      return Icons.security;
    }
    if (appId.contains('mysql')) {
      return Icons.storage;
    }
    if (appId.contains('cloud')) {
      return Icons.cloud;
    }
    return Icons.apps;
  }

  String _getIconFileName(AppModel app) {
    final id = app.appId.toLowerCase();
    final group = app.groupName?.toLowerCase() ?? '';

    if (id.contains('nodejs')) return 'nodejs';
    if (id == 'phpmyadmin') return 'phpmyadmin';
    if (id.contains('php')) return 'php';
    if (id.contains('mysql')) return 'mysql';
    if (id.contains('mariadb')) return 'mariadb';
    if (id.contains('mongodb')) return 'mongodb';
    if (id.contains('nginx')) return 'nginx';
    if (id.contains('apache')) return 'apache';
    if (id.contains('redis')) return 'redis';
    if (id.contains('python') || id.contains('pyenv')) return 'python';
    if (id.contains('heidisql')) return 'heidisql';
    if (id.contains('compass')) return 'mongodb';

    // Fallback to group name if id doesn't match
    return group;
  }

  Color _getIconColor(String appId) {
    if (appId.contains('nginx') && appId.contains('waf')) {
      return const Color(0xFF4169E1);
    }
    if (appId.contains('php')) {
      return const Color(0xFF7B68EE);
    }
    if (appId.contains('apache') && appId.contains('waf')) {
      return const Color(0xFFDC143C);
    }
    if (appId.contains('mysql')) {
      return const Color(0xFF20B2AA);
    }
    if (appId.contains('cloud')) {
      return const Color(0xFF58A6FF);
    }
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
                Expanded(flex: 4, child: _buildHeaderCell('SOFTWARE NAME')),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildHeaderCell('DEVELOPER')),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: _buildHeaderCell('DESCRIPTION')),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildHeaderCell('STATUS')),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: _buildHeaderCell('PATH')),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildHeaderCell(
                    'OPERATE',
                    alignment: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table Body — scrollable to prevent overflow
          Expanded(
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                return _buildAppRow(
                    context, apps[index], index == apps.length - 1);
              },
            ),
          ),
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
        fontSize: AppTextSize.xxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAppRow(BuildContext context, AppModel app, bool isLast) {
    return SizedBox(
      height: 56,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: isLast
              ? const Border()
              : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Software name with icon
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Image.asset(
                      'assets/images/${_getIconFileName(app)}.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getAppIcon(app.appId),
                        size: 16,
                        color: _getIconColor(app.appId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                app.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTextSize.xs,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (app.isInstalled &&
                                app.installedVersion != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.installedVersion?.toLowerCase() == 'latest'
                                      ? 'latest'
                                      : 'v${app.installedVersion}',
                                  style: const TextStyle(
                                    fontSize: AppTextSize.xxs,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            if (app.isDefault) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Default Version',
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Developer
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: app.developer.toLowerCase() == 'official'
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: app.developer.toLowerCase() == 'official'
                          ? AppColors.primary.withValues(alpha: 0.3)
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
            const SizedBox(width: 12),
            // Description
            Expanded(
              flex: 4,
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
            const SizedBox(width: 12),
            // Status
            Expanded(flex: 2, child: _buildStatusIndicator(app)),
            const SizedBox(width: 12),
            // PATH toggle
            Expanded(flex: 1, child: _buildPathToggle(app)),
            const SizedBox(width: 12),
            // Operate buttons
            Expanded(flex: 4, child: _buildOperateButtons(context, app)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(AppModel app) {
    if (app.isInstalled) {
      if (app.isService) {
        return Row(
          children: [
            if (app.serviceStatus == 'stopped')
              _buildServiceButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                color: AppColors.success,
                onPressed: () => onStartService(app),
              )
            else if (app.serviceStatus == 'running') ...[
              _buildServiceButton(
                icon: Icons.stop_rounded,
                label: 'Stop',
                color: AppColors.error,
                onPressed: () => onStopService(app),
              ),
              const SizedBox(width: 4),
              _buildServiceButton(
                icon: Icons.refresh_rounded,
                label: 'Restart',
                color: AppColors.primary,
                onPressed: () => onRestartService(app),
              ),
            ] else ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                app.serviceStatus.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        );
      }

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
    } else if (app.status == 'installing') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  app.installStatus ?? 'Installing...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: AppTextSize.xxs,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: app.installProgress,
              minHeight: 3,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              color: AppColors.primary,
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

  Widget _buildPathToggle(AppModel app) {
    if (!app.isInstalled || app.cliFilePath == null || app.appId == 'pyenv') {
      return const SizedBox.shrink();
    }

    return Transform.scale(
      scale: 0.7,
      alignment: Alignment.centerLeft,
      child: Switch(
        value: app.isAddedToPath,
        onChanged: (_) => onTogglePath(app),
        activeThumbColor: AppColors.success,
        activeTrackColor: AppColors.success.withValues(alpha: 0.2),
        inactiveThumbColor: AppColors.textMuted,
        inactiveTrackColor: AppColors.border,
      ),
    );
  }

  Widget _buildServiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
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

  Widget _buildOperateButtons(BuildContext context, AppModel app) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (app.appId == 'pyenv' && app.isInstalled) ...[
          _buildIconButton(
            icon: Icons.list_alt_rounded,
            onPressed: () => _showPyenvModal(context, app),
            color: AppColors.primary,
            tooltip: 'Manage Python Versions',
          ),
          const SizedBox(width: 8),
        ],
        if (app.isInstalled) ...[
          if (app.hasUpdateAvailable) ...[
            _buildIconButton(
              icon: Icons.refresh_rounded,
              onPressed: () {
                // Find the latest compatible version
                final parts = app.installedVersion!.split('.');
                final baseVersion = '${parts[0]}.${parts[1]}';
                final latestPatch = app.versions
                    .where((v) => v.startsWith('$baseVersion.'))
                    .reduce((a, b) => app.isVersionNewer(b, a) ? b : a);

                app.selectedVersion = latestPatch;
                _showVersionModal(context, app, isUpdate: true);
              },
              color: AppColors.primary,
              tooltip: 'Update to new patch',
            ),
            const SizedBox(width: 8),
          ],
          if (app.isService) ...[
            _buildIconButton(
              icon: Icons.terminal_rounded,
              onPressed: () => _showLogsModal(context, app),
              color: AppColors.primary,
              tooltip: 'View Logs',
            ),
            const SizedBox(width: 8),
          ],
          if (app.groupName == 'php' && !app.isDefault) ...[
            _buildIconButton(
              icon: Icons.star_border_rounded,
              onPressed: () => onChangeDefault(app.appId),
              color: Colors.amber,
              tooltip: 'Set as Default PHP',
            ),
            const SizedBox(width: 8),
          ],
          _buildIconButton(
            icon: Icons.settings_outlined,
            onPressed: () => _showSettingsModal(context, app),
            color: AppColors.textSecondary,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.delete_outline_rounded,
            onPressed: () {
              AppDialogs.showConfirm(
                context: context,
                title: 'Uninstall App',
                text:
                    'Are you sure you want to uninstall ${app.name}?\nThis will delete all files.',
                onConfirm: () => onToggleInstall(app),
              );
            },
            color: AppColors.error,
            tooltip: 'Uninstall',
          ),
        ] else if (app.status == 'installing')
          const OutlinedButton(
            onPressed: null,
            child: Text(
              'INSTALLING...',
              style: TextStyle(
                fontSize: AppTextSize.xxxs,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          _buildIconButton(
            icon: Icons.file_download_outlined,
            onPressed: () => _showVersionModal(context, app),
            color: AppColors.primary,
            tooltip: 'Install',
          ),
        if (app.isInstalled &&
            (app.appId == 'mongodb-compass' || app.appId == 'heidisql')) ...[
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.open_in_new_rounded,
            onPressed: () => onOpen(app),
            color: AppColors.success,
            tooltip: 'Open Application',
          ),
        ],
      ],
    );
  }

  void _showVersionModal(
    BuildContext context,
    AppModel app, {
    bool isUpdate = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: AppVersionModal(
            app: app,
            isUpdate: isUpdate,
            onInstall: () {
              onToggleInstall(app);
            },
            onClose: () {
              app.installLogs = [];
              Navigator.of(dialogContext).pop();
            },
          ),
        );
      },
    );
  }

  void _showLogsModal(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ServiceLogsModal(
            app: app,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  void _showSettingsModal(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: AppSettingsModal(
            app: app,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  void _showPyenvModal(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: PyenvManageModal(
            app: app,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }
}
