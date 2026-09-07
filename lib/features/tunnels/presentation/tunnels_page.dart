import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/widgets/status_chip.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_logs_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';

class TunnelsPage extends ConsumerStatefulWidget {
  const TunnelsPage({super.key});

  @override
  ConsumerState<TunnelsPage> createState() => _TunnelsPageState();
}

class _TunnelsPageState extends ConsumerState<TunnelsPage> {
  @override
  Widget build(BuildContext context) {
    final tunnelsAsync = ref.watch(tunnelsStreamProvider);
    final sessions = ref.watch(tunnelSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContent(tunnelsAsync, sessions)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _showCreateModal,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text(
            'New Tunnel',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildContent(
    AsyncValue<List<TunnelModel>> tunnelsAsync,
    Map<int, TunnelSession> sessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tunnels',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xxl,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Expose local sites and ports to the public internet',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.sm,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: tunnelsAsync.when(
            data: (tunnels) => tunnels.isEmpty
                ? _buildEmptyState()
                : _buildTunnelList(tunnels, sessions),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                'Error loading tunnels: $e',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
            LucideIcons.cloud,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tunnels configured yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "+ New Tunnel" to expose a local site or port to the internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.sm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTunnelList(
    List<TunnelModel> tunnels,
    Map<int, TunnelSession> sessions,
  ) {
    return ListView.builder(
      itemCount: tunnels.length,
      itemBuilder: (context, index) {
        final tunnel = tunnels[index];
        final session = sessions[tunnel.id];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: _TunnelCard(tunnel: tunnel, session: session),
        );
      },
    );
  }

  void _showCreateModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: CreateTunnelModal(),
      ),
    );
  }
}

class _TunnelCard extends ConsumerWidget {
  final TunnelModel tunnel;
  final TunnelSession? session;

  const _TunnelCard({required this.tunnel, required this.session});

  TunnelStatus get status => session?.status ?? TunnelStatus.stopped;

  bool get isRunning => status == TunnelStatus.running;
  bool get isStopped => status == TunnelStatus.stopped;
  bool get isConnecting =>
      status == TunnelStatus.connecting ||
      status == TunnelStatus.downloadingBinary;
  bool get hasError => status == TunnelStatus.error;

  String get targetLabel {
    if (tunnel.targetType == 'site' && tunnel.targetSiteDomain != null) {
      return tunnel.targetSiteDomain!;
    }
    return 'Port ${tunnel.targetPort}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providerLabel = tunnel.provider == 'ngrok' ? 'ngrok' : 'Cloudflare';
    final providerIcon = tunnel.provider == 'ngrok'
        ? LucideIcons.zap
        : LucideIcons.cloud;
    final publicUrl = session?.publicUrl;
    final webInspectorUrl = session?.webInspectorUrl;
    final isNgrok = tunnel.provider == 'ngrok';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row: name, provider, target, status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tunnel.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            providerIcon,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            providerLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppTextSize.xxs,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            targetLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppTextSize.xxs,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 12),
            // Body: error / connecting / url / not running
            if (hasError && session?.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Error: ${session!.errorMessage}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: AppTextSize.xs,
                  ),
                ),
              ),
            if (isConnecting)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: session?.downloadProgress,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status == TunnelStatus.downloadingBinary
                        ? 'Downloading tunnel binary...'
                        : 'Connecting...',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xxs,
                    ),
                  ),
                ],
              )
            else if (publicUrl != null && isRunning)
              _buildUrlRow(context, publicUrl, isNgrok, webInspectorUrl)
            else
              const Text(
                'Not running',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xs,
                ),
              ),
            const SizedBox(height: 12),
            _buildActions(context, ref, isNgrok, webInspectorUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
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

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public URL copied to clipboard')),
    );
  }

  void _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openQr(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: TunnelQrModal(
          tunnelName: tunnel.name,
          publicUrl: url,
        ),
      ),
    );
  }

  void _viewLogs(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: TunnelLogsModal(
          tunnelName: tunnel.name,
          session: session,
        ),
      ),
    );
  }

  void _start(WidgetRef ref, BuildContext context) {
    ref.read(tunnelSessionsProvider.notifier).start(tunnel);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting tunnel "${tunnel.name}"...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _stop(WidgetRef ref, BuildContext context) {
    ref.read(tunnelSessionsProvider.notifier).stop(tunnel.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stopping tunnel "${tunnel.name}"...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _delete(WidgetRef ref, BuildContext context) {
    ref.read(tunnelSessionsProvider.notifier).delete(tunnel.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting tunnel "${tunnel.name}"...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _edit(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: CreateTunnelModal(initialTunnel: tunnel),
      ),
    );
  }

  Widget _buildUrlRow(
    BuildContext context,
    String url,
    bool isNgrok,
    String? webInspectorUrl,
  ) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            url,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppTextSize.xs,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _urlIconButton(
          tooltip: 'Copy',
          icon: LucideIcons.copy,
          onPressed: () => _copyUrl(context, url),
          iconColor: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        _urlIconButton(
          tooltip: 'Open in Browser',
          icon: LucideIcons.externalLink,
          onPressed: () => _openUrl(context, url),
          iconColor: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        _urlIconButton(
          tooltip: 'QR Code',
          icon: LucideIcons.qrCode,
          onPressed: () => _openQr(context, url),
          iconColor: AppColors.textSecondary,
        ),
        if (isNgrok && webInspectorUrl != null) ...[
          const SizedBox(width: 4),
          _urlIconButton(
            tooltip: 'Web Inspector',
            icon: LucideIcons.monitor,
            onPressed: () => _openUrl(context, webInspectorUrl),
            iconColor: AppColors.textSecondary,
          ),
        ],
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isNgrok,
    String? webInspectorUrl,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isStopped || hasError)
          FilledButton.icon(
            onPressed: () => _start(ref, context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              foregroundColor: AppColors.success,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.play, size: 14),
            label: const Text('Start'),
          )
        else if (!isConnecting)
          FilledButton.icon(
            onPressed: () => _stop(ref, context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.square, size: 14),
            label: const Text('Stop'),
          ),
        const SizedBox(width: 8),
        _actionIcon(
          icon: LucideIcons.list,
          tooltip: 'View Logs',
          onPressed: () => _viewLogs(context),
        ),
        const SizedBox(width: 4),
        _actionIcon(
          icon: LucideIcons.edit,
          tooltip: 'Edit',
          onPressed: () => _edit(context),
        ),
        const SizedBox(width: 4),
        _actionIcon(
          icon: LucideIcons.trash2,
          tooltip: 'Delete',
          onPressed: () => _delete(ref, context),
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    Color color = AppColors.textSecondary,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 16, color: color),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _urlIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 14, color: iconColor),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
