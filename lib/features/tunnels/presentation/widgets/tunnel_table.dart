import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/action_row_layout.dart';
import '../../../../shared/widgets/row_action_menu.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/tunnel_model.dart';
import '../../domain/tunnel_session.dart';

class TunnelTable extends StatelessWidget {
  final List<TunnelModel> tunnels;
  final Map<int, TunnelSession> sessions;
  final Function(TunnelModel) onStart;
  final Function(int) onStop;
  final Function(int) onCancel;
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
    required this.onCancel,
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
        // Shrink instead of scrolling sideways out of reach.
        final availableWidth = constraints.maxWidth;
        final operateWidth = availableWidth - _operateReservedWidth;
        // One action-column width for every row, so the data columns line up
        // even when rows carry different numbers of actions.
        final plan = planActionColumn(
          [
            for (final tunnel in tunnels)
              _rowActions(
                tunnel,
                sessions[tunnel.id] ?? TunnelSession(tunnelId: tunnel.id),
              ),
          ],
          availableWidth: operateWidth.isFinite && operateWidth > 0 ? operateWidth : 1,
          firstGap: 6,
        );

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildHeader(plan),
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
                        availableWidth,
                        tunnel,
                        session,
                        plan,
                        index == tunnels.length - 1,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ActionColumnPlan plan) {
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
            // Action column takes the shared width so it lines up with every
            // row's cluster below.
            width: actionColumnWidth(plan),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
            const Icon(LucideIcons.cloud, size: 48, color: AppColors.textMuted),
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
    double availableWidth,
    TunnelModel tunnel,
    TunnelSession? session,
    ActionColumnPlan plan,
    bool isLast,
  ) {
    final status = session?.status ?? TunnelStatus.stopped;
    final publicUrl = session?.publicUrl;
    final isNgrok = tunnel.provider == 'ngrok';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
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
            child: _buildPublicUrlCell(context, status, session, publicUrl),
          ),
          const SizedBox(width: 12),

          // OPERATE — every action of this row, the URL cell's ones first,
          // collapses into one '…' menu when the row gets too narrow. The
          // column width comes from the shared plan so the header lines up.
          SizedBox(
            width: actionColumnWidth(plan),
            child: RowActionMenu(
              availableWidth: availableWidth - _operateReservedWidth,
              firstGap: 6,
              columnWidth: plan.width,
              collapsed: plan.collapsed,
              actions: _rowActions(tunnel, session),
            ),
          ),
        ],
      ),
    );
  }

  /// The actions of one row, in render order.
  ///
  /// Extracted so [planActionColumn] can measure every row before layout: the
  /// column width is the widest cluster, not each row's own. The URL-cell
  /// actions (Copy Link, Open in Browser, …) fold into the same cluster and '…'
  /// menu, so the OPERATE column is one width for the whole table.
  List<RowAction> _rowActions(TunnelModel tunnel, TunnelSession? session) {
    final status = session?.status ?? TunnelStatus.stopped;
    final isRunning = status == TunnelStatus.running;
    final isStopped = status == TunnelStatus.stopped;
    final isConnecting =
        status == TunnelStatus.connecting ||
        status == TunnelStatus.downloadingBinary;
    final hasError = status == TunnelStatus.error;
    final publicUrl = session?.publicUrl;
    final webInspectorUrl = session?.webInspectorUrl;
    final isNgrok = tunnel.provider == 'ngrok';

    return [
      if (isRunning && publicUrl != null) ...[
        RowAction.icon(
          'Copy Link',
          () => onCopyUrl(publicUrl),
          icon: LucideIcons.copy,
        ),
        RowAction.icon(
          'Open in Browser',
          () => onOpenUrl(publicUrl),
          icon: LucideIcons.externalLink,
        ),
        RowAction.icon(
          'QR Code',
          () => onOpenQr(tunnel, publicUrl),
          icon: LucideIcons.qrCode,
        ),
        if (isNgrok && webInspectorUrl != null)
          RowAction.icon(
            'Web Inspector',
            () => onOpenUrl(webInspectorUrl),
            icon: LucideIcons.monitor,
          ),
      ],
      if (isStopped || hasError)
        RowAction.button(
          'Start',
          () => onStart(tunnel),
          icon: LucideIcons.play,
        ),
      if (isRunning)
        RowAction.button(
          'Stop',
          () => onStop(tunnel.id),
          icon: LucideIcons.square,
        ),
      if (isConnecting)
        RowAction.button(
          'Cancel',
          () => onCancel(tunnel.id),
          icon: LucideIcons.x,
        ),
      RowAction.icon(
        'View Logs',
        () => onViewLogs(tunnel),
        icon: LucideIcons.list,
      ),
      RowAction.icon(
        'Edit',
        () => onEdit(tunnel),
        icon: LucideIcons.edit,
      ),
      RowAction.icon(
        'Delete',
        () => onDelete(tunnel),
        icon: LucideIcons.trash2,
      ),
    ];
  }

  /// Width the OPERATE menu cannot grow into: the row padding, the gaps before
  /// it, the two fixed data columns, and the floor for the flexible name /
  /// target / public-url columns.
  static const double _operateReservedWidth =
      16 * 2 + 12 * 5 + 95 + 90 + _flexColumnMinWidth * 3;

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 110;

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
  ) {
    // The URL is data: it stays here. Its actions live with the row's actions,
    // so the cell never decides on its own how wide it must be to stay usable.
    if (status == TunnelStatus.running && publicUrl != null) {
      // The URL is selectable (SelectableText scrolls horizontally when it is
      // clipped), and a long subdomain gets a tooltip so the full address can be
      // read without selecting the text.
      return Tooltip(
        message: publicUrl,
        child: SelectableText(
          publicUrl,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
        ),
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
      style: TextStyle(color: AppColors.textMuted, fontSize: AppTextSize.xs),
    );
  }
}
