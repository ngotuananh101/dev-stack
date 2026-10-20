import 'package:flutter/material.dart';
import '../../../../shared/utils/action_row_layout.dart';
import '../../../../shared/utils/app_dialogs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/row_action_menu.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_brand_resolver.dart';
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
  final void Function(AppModel) onCancelInstall;

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
    required this.onCancelInstall,
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
    if (appId.contains('elasticsearch')) {
      return Icons.search_rounded;
    }
    if (appId.contains('caddy')) return Icons.dns;
    return Icons.apps;
  }

  String _getIconFileName(AppModel app) {
    return AppBrandResolver.iconFileName(app.appId, groupName: app.groupName);
  }

  Color _getIconColor(String appId) {
    return AppBrandResolver.iconColor(appId, fallback: AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    // The row's action cluster needs to know the width it really has, so the
    // table measures itself instead of assuming a window width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final operateWidth = availableWidth - _operateReservedWidth;
        // One column width for every row, so the data columns line up even
        // when different rows carry different numbers of actions.
        final plan = planActionColumn(
          [for (final app in apps) _buildAppActions(context, app)],
          availableWidth: operateWidth.isFinite ? operateWidth : 0,
          gap: 8,
        );

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 7, child: _buildHeaderCell('SOFTWARE NAME')),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: _buildHeaderCell('DESCRIPTION')),
                    const SizedBox(width: 12),
                    SizedBox(width: 120, child: _buildHeaderCell('STATUS')),
                    const SizedBox(width: 12),
                    SizedBox(width: 50, child: _buildHeaderCell('PATH')),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: plan.width.isFinite ? plan.width : 140,
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
                  itemBuilder: (context, index) => _buildAppRow(
                    context,
                    availableWidth,
                    apps[index],
                    plan,
                    index == apps.length - 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildAppRow(
    BuildContext context,
    double availableWidth,
    AppModel app,
    ActionColumnPlan plan,
    bool isLast,
  ) {
    return Container(
      height: 55,
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
            flex: 7,
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
          // Description
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  app.description ?? 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.xxs,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status
          SizedBox(width: 120, child: _buildStatusIndicator(app)),
          const SizedBox(width: 12),
          // PATH toggle
          SizedBox(width: 50, child: _buildPathToggle(app)),
          const SizedBox(width: 12),
          // Operate buttons. The column takes a fixed width (the plan's shared
          // width) so the header and every row align; without a width each row
          // would let its cluster grow to its own size and the flexible data
          // columns would land at a different x per row.
          SizedBox(
            width: plan.width.isFinite ? plan.width : null,
            child: RowActionMenu(
              availableWidth: availableWidth - _operateReservedWidth,
              gap: 8,
              columnWidth: plan.width,
              collapsed: plan.collapsed,
              actions: _buildAppActions(context, app),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AppModel app) {
    if (app.isInstalled) {
      if (app.isService) {
        return Row(
          children: [
            if (app.serviceStatus == 'stopped')
              AppIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Start',
                color: AppColors.success,
                onPressed: () => onStartService(app),
              )
            else if (app.serviceStatus == 'running') ...[
              AppIconButton(
                icon: Icons.stop_rounded,
                tooltip: 'Stop',
                color: AppColors.error,
                onPressed: () => onStopService(app),
              ),
              const SizedBox(width: 4),
              AppIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Restart',
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
              Expanded(
                child: Text(
                  app.serviceStatus.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSize.xxs,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
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
    // phpMyAdmin has no CLI binary to expose on PATH — it's a web app served
    // through the webserver, not an executable. Hide the toggle for it.
    if (!app.isInstalled ||
        app.cliFilePath == null ||
        app.appId == 'pyenv' ||
        app.appId == 'phpMyAdmin') {
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

  /// Width the OPERATE menu cannot grow into: the row padding, the gaps before
  /// it, the two fixed data columns, and the floor for the two flexible
  /// name/description columns.
  static const double _operateReservedWidth =
      16 * 2 + 12 * 4 + 120 + 50 + _flexColumnMinWidth * 2;

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 140;

  /// Every action of a row, in the order the row showed them inline.
  ///
  /// [RowActionMenu] renders these as buttons while they fit and collapses
  /// them into a single '…' menu when the row gets narrow.
  List<RowAction> _buildAppActions(BuildContext context, AppModel app) {
    return [
      if (app.appId == 'pyenv' && app.isInstalled)
        RowAction.icon(
          'Manage Python Versions',
          () => _showPyenvModal(context, app),
          icon: Icons.list_alt_rounded,
        ),
      if (app.isInstalled) ...[
        if (app.hasUpdateAvailable)
          RowAction.icon('Update to new patch', () {
            // Find the latest compatible version
            final parts = app.installedVersion!.split('.');
            final baseVersion = '${parts[0]}.${parts[1]}';
            final latestPatch = app.versions
                .where((v) => v.startsWith('$baseVersion.'))
                .reduce((a, b) => app.isVersionNewer(b, a) ? b : a);

            app.selectedVersion = latestPatch;
            _showVersionModal(context, app, isUpdate: true);
          }, icon: Icons.refresh_rounded),
        if (app.isService)
          RowAction.icon(
            'View Logs',
            () => _showLogsModal(context, app),
            icon: Icons.terminal_rounded,
          ),
        if (app.groupName == 'php' && !app.isDefault)
          RowAction.icon(
            'Set as Default PHP',
            () => onChangeDefault(app.appId),
            icon: Icons.star_border_rounded,
          ),
        RowAction.icon(
          'Settings',
          () => _showSettingsModal(context, app),
          icon: Icons.settings_outlined,
        ),
        RowAction.icon('Uninstall', () {
          AppDialogs.showConfirm(
            context: context,
            title: 'Uninstall App',
            text:
                'Are you sure you want to uninstall ${app.name}?\nThis will delete all files.',
            onConfirm: () => onToggleInstall(app),
          );
        }, icon: Icons.delete_outline_rounded),
      ] else if (app.status == 'installing')
        RowAction.button('INSTALLING...', null)
      else
        RowAction.icon(
          'Install',
          () => _showVersionModal(context, app),
          icon: Icons.file_download_outlined,
        ),
      if (app.isInstalled &&
          (app.appId == 'mongodb-compass' ||
              app.appId == 'heidisql' ||
              app.appId == 'rustfs'))
        RowAction.icon(
          'Open Application',
          () => onOpen(app),
          icon: Icons.open_in_new_rounded,
        ),
    ];
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
            onCancel: () {
              onCancelInstall(app);
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
