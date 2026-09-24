import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/tunnel_model.dart';
import '../../domain/tunnel_session.dart';

class TunnelTable extends StatelessWidget {
  final List<TunnelModel> tunnels;
  final Map<int, TunnelSession> sessions;
  final Function(TunnelModel) onStart;
  final Function(int) onStop;
  final Function(TunnelModel) onEdit;
  final Function(TunnelModel) onDelete;
  final Function(TunnelModel) onViewLogs;
  final Function(String) onOpenUrl;
  final Function(String) onCopyUrl;
  final Function(TunnelModel, String) onOpenQr;

  const TunnelTable({
    super.key,
    required this.tunnels,
    required this.sessions,
    required this.onStart,
    required this.onStop,
    required this.onEdit,
    required this.onDelete,
    required this.onViewLogs,
    required this.onOpenUrl,
    required this.onCopyUrl,
    required this.onOpenQr,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 840.0;
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                children: [
                  _buildHeader(),
                  if (tunnels.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: tunnels.length,
                        itemBuilder: (context, index) {
                          final tunnel = tunnels[index];
                          final session = sessions[tunnel.id];
                          return _buildRow(
                            context,
                            tunnel,
                            session,
                            index == tunnels.length - 1,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildHeaderCell('TUNNEL NAME')),
          const SizedBox(width: 12),
          SizedBox(width: 95, child: _buildHeaderCell('PROVIDER')),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildHeaderCell('TARGET')),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: _buildHeaderCell('STATUS')),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: _buildHeaderCell('PUBLIC URL')),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.cloud,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No tunnels configured yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Click "+ New Tunnel" to expose a local site or port to the internet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    TunnelModel tunnel,
    TunnelSession? session,
    bool isLast,
  ) {
    final status = session?.status ?? TunnelStatus.stopped;
    final isRunning = status == TunnelStatus.running;
    final isStopped = status == TunnelStatus.stopped;
    final isConnecting = status == TunnelStatus.connecting ||
        status == TunnelStatus.downloadingBinary;
    final hasError = status == TunnelStatus.error;
    final publicUrl = session?.publicUrl;
    final webInspectorUrl = session?.webInspectorUrl;
    final isNgrok = tunnel.provider == 'ngrok';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // TUNNEL NAME
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tunnel.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tunnel.autoStart) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Auto-starts on app launch',
                    child: Icon(
                      LucideIcons.playCircle,
                      size: 13,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // PROVIDER
          SizedBox(
            width: 95,
            child: Row(
              children: [
                Icon(
                  isNgrok ? LucideIcons.zap : LucideIcons.cloud,
                  size: 14,
                  color: isNgrok ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isNgrok ? 'Ngrok' : 'Cloudflare',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xs,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // TARGET
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  tunnel.targetType == 'site'
                      ? LucideIcons.globe
                      : LucideIcons.hash,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tunnel.targetType == 'site' &&
                            tunnel.targetSiteDomain != null
                        ? tunnel.targetSiteDomain!
                        : 'Port ${tunnel.targetPort}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xs,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // STATUS
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(status),
            ),
          ),
          const SizedBox(width: 12),

          // PUBLIC URL
          Expanded(
            flex: 5,
            child: _buildPublicUrlCell(
              context,
              status,
              session,
              publicUrl,
              isNgrok,
              webInspectorUrl,
              tunnel,
            ),
          ),
          const SizedBox(width: 12),

          // OPERATE
          SizedBox(
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isStopped || hasError)
                  AppButton(
                    label: 'Start',
                    onPressed: () => onStart(tunnel),
                    icon: const Icon(LucideIcons.play, size: 12),
                    style: AppButtonStyle.success,
                  )
                else if (isRunning)
                  AppButton(
                    label: 'Stop',
                    onPressed: () => onStop(tunnel.id),
                    icon: const Icon(LucideIcons.square, size: 12),
                    style: AppButtonStyle.danger,
                  )
                else if (isConnecting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: LucideIcons.list,
                  tooltip: 'View Logs',
                  onPressed: () => onViewLogs(tunnel),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.edit,
                  tooltip: 'Edit',
                  onPressed: () => onEdit(tunnel),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: () => onDelete(tunnel),
                  size: AppIconButtonSize.sm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TunnelStatus status) {
    StatusType type;
    String label;
    switch (status) {
      case TunnelStatus.stopped:
        type = StatusType.stopped;
        label = 'Stopped';
        break;
      case TunnelStatus.downloadingBinary:
        type = StatusType.restarting;
        label = 'Downloading';
        break;
      case TunnelStatus.connecting:
        type = StatusType.restarting;
        label = 'Connecting';
        break;
      case TunnelStatus.running:
        type = StatusType.stable;
        label = 'Running';
        break;
      case TunnelStatus.error:
        type = StatusType.warning;
        label = 'Error';
        break;
    }
    return StatusChip(type: type, label: label);
  }

  Widget _buildPublicUrlCell(
    BuildContext context,
    TunnelStatus status,
    TunnelSession? session,
    String? publicUrl,
    bool isNgrok,
    String? webInspectorUrl,
    TunnelModel tunnel,
  ) {
    if (status == TunnelStatus.running && publicUrl != null) {
      return Row(
        children: [
          Expanded(
            child: SelectableText(
              publicUrl,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppTextSize.xs,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          AppIconButton(
            icon: LucideIcons.copy,
            tooltip: 'Copy Link',
            onPressed: () => onCopyUrl(publicUrl),
            size: AppIconButtonSize.sm,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            icon: LucideIcons.externalLink,
            tooltip: 'Open in Browser',
            onPressed: () => onOpenUrl(publicUrl),
            size: AppIconButtonSize.sm,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            icon: LucideIcons.qrCode,
            tooltip: 'QR Code',
            onPressed: () => onOpenQr(tunnel, publicUrl),
            size: AppIconButtonSize.sm,
          ),
          if (isNgrok && webInspectorUrl != null) ...[
            const SizedBox(width: 4),
            AppIconButton(
              icon: LucideIcons.monitor,
              tooltip: 'Web Inspector',
              onPressed: () => onOpenUrl(webInspectorUrl),
              size: AppIconButtonSize.sm,
            ),
          ],
        ],
      );
    }

    if (status == TunnelStatus.connecting ||
        status == TunnelStatus.downloadingBinary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: session?.downloadProgress,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            status == TunnelStatus.downloadingBinary
                ? 'Downloading binary...'
                : 'Connecting...',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.xxs,
            ),
          ),
        ],
      );
    }

    if (status == TunnelStatus.error) {
      return Text(
        session?.errorMessage ?? 'Connection error',
        style: const TextStyle(
          color: AppColors.error,
          fontSize: AppTextSize.xs,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return const Text(
      'Not running',
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: AppTextSize.xs,
      ),
    );
  }
}
