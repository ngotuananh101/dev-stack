import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../tunnels/data/tunnels_provider.dart';
import '../../../tunnels/data/tunnel_manager_service.dart';
import '../../../tunnels/domain/tunnel_model.dart';
import '../../../tunnels/domain/tunnel_session.dart';
import '../../../tunnels/presentation/widgets/create_tunnel_modal.dart';
import '../../../tunnels/presentation/widgets/tunnel_qr_modal.dart';
import '../../domain/site_model.dart';

/// A popup dialog that lets the user share a site via a tunnel.
///
/// - If no tunnel is configured/running for this site: shows "Start Quick
///   Tunnel (Cloudflare)" (creates and starts a quick tunnel for the site) and
///   "Configure Tunnel" (opens [CreateTunnelModal] pre-populated with the site's
///   domain and target port).
/// - If a tunnel exists and is running: shows active status, public URL (with
///   copy & open buttons), and QR code.
/// - If a tunnel exists and is stopped: shows "Start Tunnel" button.
class SiteTunnelDialog extends ConsumerStatefulWidget {
  final SiteModel site;

  const SiteTunnelDialog({
    super.key,
    required this.site,
  });

  @override
  ConsumerState<SiteTunnelDialog> createState() => _SiteTunnelDialogState();
}

class _SiteTunnelDialogState extends ConsumerState<SiteTunnelDialog> {
  @override
  Widget build(BuildContext context) {
    final tunnelsAsync = ref.watch(tunnelsStreamProvider);
    final sessions = ref.watch(tunnelSessionsProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildContent(tunnelsAsync, sessions),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Share ${widget.site.domain}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildContent(
    AsyncValue<List<TunnelModel>> tunnelsAsync,
    Map<int, TunnelSession> sessions,
  ) {
    return tunnelsAsync.when(
      data: (tunnels) {
        final siteTunnel = _findSiteTunnel(tunnels);

        if (siteTunnel == null) {
          return _buildNoTunnelState();
        }

        final session = sessions[siteTunnel.id];
        return _buildTunnelState(siteTunnel, session);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'Error loading tunnels: $e',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  TunnelModel? _findSiteTunnel(List<TunnelModel> tunnels) {
    for (final t in tunnels) {
      if (t.targetType == 'site' &&
          t.targetSiteDomain == widget.site.domain) {
        return t;
      }
    }
    return null;
  }

  Widget _buildNoTunnelState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Start Quick Tunnel (Cloudflare)',
          onPressed: _startQuickTunnel,
          icon: const Icon(LucideIcons.cloud, size: 16, color: Colors.black),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Configure Tunnel',
          style: AppButtonStyle.secondary,
          onPressed: _openConfigure,
          icon: const Icon(LucideIcons.settings, size: 16),
        ),
      ],
    );
  }

  Widget _buildTunnelState(TunnelModel tunnel, TunnelSession? session) {
    final status = session?.status ?? TunnelStatus.stopped;
    final isRunning = status == TunnelStatus.running;
    final isStopped = status == TunnelStatus.stopped;
    final isConnecting = status == TunnelStatus.connecting ||
        status == TunnelStatus.downloadingBinary;
    final hasError = status == TunnelStatus.error;
    final publicUrl = session?.publicUrl;

    List<Widget> body;

    if (hasError) {
      body = [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Error: ${session?.errorMessage ?? 'Unknown error'}',
            style: const TextStyle(
              color: AppColors.error,
              fontSize: AppTextSize.xs,
            ),
          ),
        ),
      ];
    } else if (isConnecting) {
      body = [
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
      ];
    } else if (publicUrl != null && isRunning) {
      body = [_buildUrlRow(publicUrl)];
    } else {
      body = [
        const Text(
          'Not running',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.xs,
          ),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatusChip(status),
            const SizedBox(width: 8),
            Icon(
              tunnel.provider.toLowerCase() == 'ngrok'
                  ? LucideIcons.zap
                  : LucideIcons.cloud,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...body,
        const SizedBox(height: 12),
        _buildActions(tunnel, session, isStopped, isConnecting, hasError),
      ],
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

  Widget _buildUrlRow(String url) {
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
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Public URL copied to clipboard')),
            );
          },
        ),
        const SizedBox(width: 4),
        _urlIconButton(
          tooltip: 'Open in Browser',
          icon: LucideIcons.externalLink,
          onPressed: () {
            launchUrlString(
              url,
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        const SizedBox(width: 4),
        _urlIconButton(
          tooltip: 'QR Code',
          icon: LucideIcons.qrCode,
          onPressed: () => _showQr(url),
        ),
      ],
    );
  }

  void _showQr(String url) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: TunnelQrModal(
          tunnelName: widget.site.domain,
          publicUrl: url,
        ),
      ),
    );
  }

  Widget _buildActions(
    TunnelModel tunnel,
    TunnelSession? session,
    bool isStopped,
    bool isConnecting,
    bool hasError,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isStopped || hasError)
          FilledButton.icon(
            onPressed: () =>
                ref.read(tunnelSessionsProvider.notifier).start(tunnel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              foregroundColor: AppColors.success,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.play, size: 14),
            label: const Text('Start Tunnel'),
          )
        else if (!isConnecting)
          FilledButton.icon(
            onPressed: () =>
                ref.read(tunnelSessionsProvider.notifier).stop(tunnel.id),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.square, size: 14),
            label: const Text('Stop'),
          ),
      ],
    );
  }

  Widget _urlIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 14, color: AppColors.textSecondary),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  void _startQuickTunnel() async {
    final tunnel = TunnelModel(
      name: widget.site.domain,
      provider: 'cloudflare',
      targetType: 'site',
      targetSiteDomain: widget.site.domain,
      targetPort: widget.site.phpPort ?? 80,
      createdAt: DateTime.now(),
    );

    await ref.read(tunnelManagerServiceProvider).saveTunnel(tunnel);
    // Refresh the tunnels stream so the newly saved tunnel is picked up.
    // ignore: unused_result
    ref.refresh(tunnelsStreamProvider);

    // Allow the stream to emit the newly saved tunnel
    await Future.delayed(const Duration(milliseconds: 100));

    // Read the saved tunnel back so we have the persisted id
    final tunnelsAsync = await ref.read(tunnelsStreamProvider.future);
    TunnelModel? savedTunnel;
    for (final t in tunnelsAsync) {
      if (t.targetType == 'site' &&
          t.targetSiteDomain == widget.site.domain) {
        savedTunnel = t;
        break;
      }
    }
    final tunnelToStart = savedTunnel ?? tunnel;

    await ref.read(tunnelSessionsProvider.notifier).start(tunnelToStart);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openConfigure() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: CreateTunnelModal(
          initialTunnel: TunnelModel(
            name: widget.site.domain,
            provider: 'cloudflare',
            targetType: 'site',
            targetSiteDomain: widget.site.domain,
            targetPort: widget.site.phpPort ?? 80,
          ),
        ),
      ),
    );
  }
}
