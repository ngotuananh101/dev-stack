import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/services/log_service.dart';
import '../../../apps/data/apps_provider.dart';
import '../../../apps/domain/app_model.dart';
import '../../domain/site_model.dart';
import '../../data/sites_provider.dart';
import '../../../../shared/utils/app_dialogs.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../data/cli_process_manager.dart';
import 'site_logs_modal.dart';
import 'site_tunnel_dialog.dart';
import '../../../../shared/utils/action_row_layout.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/row_action_menu.dart';

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
    // The row used to read the run/stop state inside a StreamBuilder that also
    // rebuilt it on status changes. Watching the derived running set keeps the
    // whole table current when a CLI process starts or stops.
    ref.watch(cliRunningSitesProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The row's action cluster needs the width it really has, so the
          // table measures itself instead of assuming a window width.
          final availableWidth = constraints.maxWidth;

          return Column(
            children: [
              _buildHeader(),
              if (sites.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: sites.length,
                    itemBuilder: (context, index) => _buildRow(
                      context,
                      ref,
                      availableWidth,
                      sites[index],
                      index == sites.length - 1,
                    ),
                  ),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final allSelected =
        sites.isNotEmpty && sites.every((s) => selectedIds.contains(s.id));

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
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
            width: 160,
            child: _buildHeaderCell('OPERATE', alignment: TextAlign.right),
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

  /// Width the action cluster cannot grow into: the row padding, the checkbox
  /// column, the gaps before it, the two fixed data columns, and the floor for
  /// the two flexible name/path columns.
  static const double _operateReservedWidth =
      16 * 2 + 32 + 8 + 12 * 4 + 100 + 50 + _flexColumnMinWidth * 2;

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 120;

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    double availableWidth,
    SiteModel site,
    bool isLast,
  ) {
    final isSelected = selectedIds.contains(site.id);
    // The row used to read these inside a StreamBuilder that also rebuilt it on
    // status changes. The provider is read here so the actions keep working;
    // the rebuild itself comes from watching the stream in [build].
    final cliManager = ref.read(cliProcessManagerProvider);
    final isRunning = cliManager.isSiteRunning(site.id);

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    site.domain,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.externalLink,
                  onPressed: () {
                    final protocol = site.useSsl ? 'https' : 'http';
                    launchUrlString('$protocol://${site.domain}');
                  },
                  color: AppColors.textSecondary,
                  tooltip: 'Open in browser',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Tooltip(
              message: site.siteType == 'cli' && site.command != null
                  ? 'Command: ${site.command}'
                  : (site.siteType == 'proxy'
                      ? (site.proxyTarget ?? '-')
                      : site.rootDir),
              child: Text(
                site.siteType == 'proxy'
                    ? (site.proxyTarget ?? '-')
                    : site.rootDir,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xs,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: site.siteType == 'cli'
                ? Row(
                    children: [
                      const Icon(
                        LucideIcons.terminal,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'CLI :${site.port ?? 3000}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Text(
                    site.siteType == 'php'
                        ? 'PHP ${site.phpVersion}'
                        : site.siteType.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xs,
                    ),
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
          RowActionMenu(
            availableWidth: availableWidth - _operateReservedWidth,
            firstGap: 8,
            gap: 8,
            actions: [
              if (site.siteType == 'cli') ...[
                RowAction.icon(
                  isRunning ? 'Stop' : 'Start',
                  () async {
                    if (isRunning) {
                      await cliManager.stopSite(site.id);
                    } else {
                      await cliManager.startSite(site);
                    }
                  },
                  icon: isRunning ? LucideIcons.square : LucideIcons.play,
                ),
                RowAction.icon(
                  isRunning ? 'Restart' : 'Not running',
                  isRunning ? () => cliManager.restartSite(site) : null,
                  icon: LucideIcons.rotateCw,
                ),
                RowAction.icon(
                  'Logs',
                  () {
                    showDialog(
                      context: context,
                      builder: (context) => SiteLogsModal(site: site),
                    );
                  },
                  icon: LucideIcons.scrollText,
                ),
              ],
              if (site.siteType == 'php')
                RowAction.icon(
                  'Open Terminal',
                  () => _openTerminal(site, ref),
                  icon: LucideIcons.terminal,
                ),
              RowAction.icon(
                'Share / Tunnel',
                () {
                  showDialog(
                    context: context,
                    builder: (context) => SiteTunnelDialog(site: site),
                  );
                },
                icon: LucideIcons.radio,
              ),
              RowAction.icon(
                'Config',
                () => onEdit(site),
                icon: LucideIcons.settings,
              ),
              RowAction.icon(
                'Delete',
                () {
                  AppDialogs.showConfirm(
                    context: context,
                    title: 'Delete Site',
                    text:
                        'Are you sure you want to delete ${site.domain}? This will also remove vhost configurations and logs.',
                    confirmBtnText: 'DELETE',
                    onConfirm: () {
                      ref.read(sitesProvider.notifier).deleteSite(site.id);
                    },
                  );
                },
                icon: Icons.delete_outline_rounded,
              ),
            ],
          ),
        ],
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

  @visibleForTesting
  static ({String executable, List<String> arguments, bool runInShell})
      buildTerminalLaunchSpec({
    required bool isLinux,
    required String sitePath,
    String? phpDir,
    String? domain,
  }) {
    final title =
        domain != null ? 'DevStack Terminal for $domain' : 'DevStack Terminal';
    if (!isLinux) {
      String psCommand = '';
      if (phpDir != null) {
        psCommand += '\$env:PATH = "$phpDir;" + \$env:PATH; ';
      }
      psCommand += 'Clear-Host; ';
      psCommand +=
          'Write-Host "==========================================" -ForegroundColor Cyan; ';
      psCommand +=
          'Write-Host " $title" -ForegroundColor White; ';
      psCommand +=
          'Write-Host "==========================================" -ForegroundColor Cyan; ';
      if (phpDir != null) {
        psCommand += 'Write-Host "PHP Path : $phpDir" -ForegroundColor DarkGray; ';
      }
      psCommand += 'Write-Host "Site Path: $sitePath" -ForegroundColor DarkGray; ';
      psCommand += 'Write-Host ""; ';
      if (phpDir != null) {
        psCommand += 'php -v; Write-Host ""; ';
      }
      return (
        executable: 'start',
        arguments: ['powershell', '-NoExit', '-Command', psCommand],
        runInShell: true,
      );
    }

    // Linux terminal launch
    String bashInit = '';
    if (phpDir != null) {
      bashInit += 'export PATH="$phpDir:\$PATH"; ';
    }
    bashInit +=
        'echo "=========================================="; '
        'echo " $title"; '
        'echo "=========================================="; '
        'echo "Site Path: $sitePath"; ';
    if (phpDir != null) {
      bashInit += 'echo "PHP Path : $phpDir"; php -v; ';
    }
    bashInit += 'echo ""; exec bash';

    return (
      executable: 'x-terminal-emulator',
      arguments: ['-e', 'bash', '-c', bashInit],
      runInShell: false,
    );
  }

  Future<void> _openTerminal(SiteModel site, WidgetRef ref) async {
    final phpApps =
        ref
            .read(appsProvider)
            .value
            ?.where((a) => a.isInstalled && a.groupName == 'php') ??
        [];
    String? phpDir;

    if (site.siteType == 'php' && site.phpVersion != null) {
      final app = phpApps.cast<AppModel?>().firstWhere(
        (a) => a!.appId.contains(site.phpVersion!),
        orElse: () => phpApps.isNotEmpty ? phpApps.first : null,
      );
      if (app != null && app.cliFilePath != null) {
        phpDir = p.dirname(app.cliFilePath!);
      }
    }

    final workingDir = site.rootDir;
    final launchSpec = buildTerminalLaunchSpec(
      isLinux: Platform.isLinux,
      sitePath: workingDir,
      phpDir: phpDir,
      domain: site.domain,
    );

    try {
      if (Platform.isLinux) {
        // Attempt x-terminal-emulator, fallback to gnome-terminal / xterm
        try {
          await Process.start(
            launchSpec.executable,
            launchSpec.arguments,
            workingDirectory: workingDir,
          );
        } catch (_) {
          await Process.start(
            'xterm',
            ['-e', 'bash', '-c', launchSpec.arguments.last],
            workingDirectory: workingDir,
          );
        }
      } else {
        await Process.start(
          launchSpec.executable,
          launchSpec.arguments,
          workingDirectory: workingDir,
          runInShell: launchSpec.runInShell,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to open terminal for ${site.domain}: $e');
    }
  }
}
