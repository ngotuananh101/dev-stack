import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_logs_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';

/// Content width below which the Tunnels header stacks instead of putting
/// the title and the three buttons on one row. The buttons plus their gaps
/// need 657px side by side (265.5 + 192 + 167.5 + 16 + 8 + 8 in the test
/// font), and the title word needs 98px, so a single row only works once
/// the content is about 768px wide; below that the title takes its own row
/// and the buttons wrap underneath it.
const double _kHeaderStackWidth = 768;

class TunnelsPage extends ConsumerStatefulWidget {
  const TunnelsPage({super.key});

  @override
  ConsumerState<TunnelsPage> createState() => _TunnelsPageState();
}

class _TunnelsPageState extends ConsumerState<TunnelsPage> {
  final Set<String> _updating = {};
  @override
  Widget build(BuildContext context) {
    final tunnelsAsync = ref.watch(tunnelsStreamProvider);
    final sessions = ref.watch(tunnelSessionsProvider);

    bool isProviderBusy(String provider) =>
        (tunnelsAsync.value ?? const <TunnelModel>[]).any(
          (tunnel) =>
              tunnel.provider.toLowerCase() == provider &&
              const {
                TunnelStatus.downloadingBinary,
                TunnelStatus.connecting,
                TunnelStatus.running,
              }.contains(sessions[tunnel.id]?.status),
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              isCloudflaredBusy: isProviderBusy('cloudflare'),
              isNgrokBusy: isProviderBusy('ngrok'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: tunnelsAsync.when(
                data: (tunnels) => TunnelTable(
                  tunnels: tunnels,
                  sessions: sessions,
                  onStart: _start,
                  onStop: _stop,
                  onCancel: _cancel,
                  onEdit: _edit,
                  onDelete: _delete,
                  onViewLogs: (tunnel) =>
                      _viewLogs(tunnel, sessions[tunnel.id]),
                  onOpenUrl: _openUrl,
                  onCopyUrl: _copyUrl,
                  onOpenQr: _openQr,
                ),
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
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isCloudflaredBusy,
    required bool isNgrokBusy,
  }) {
    // The title and the three actions, shared by both layouts below.
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tunnels',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.sm,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Expose local sites and ports to the public internet',
          style: TextStyle(
            color: AppColors.textDimmed,
            fontSize: AppTextSize.xxs,
          ),
        ),
      ],
    );
    final actions = <Widget>[
      AppButton(
        label: 'Update cloudflared',
        icon: const Icon(LucideIcons.download, size: 16),
        style: AppButtonStyle.success,
        isLoading: _updating.contains('cloudflare'),
        onPressed: () => _updateBinary('cloudflare', isCloudflaredBusy),
      ),
      AppButton(
        label: 'Update ngrok',
        icon: const Icon(LucideIcons.download, size: 16),
        style: AppButtonStyle.success,
        isLoading: _updating.contains('ngrok'),
        onPressed: () => _updateBinary('ngrok', isNgrokBusy),
      ),
      AppButton(
        label: 'New Tunnel',
        icon: const Icon(LucideIcons.plus, size: 16),
        style: AppButtonStyle.success,
        onPressed: _showCreateModal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow windows cannot fit the title and all three buttons on one
        // row, so the title takes its own row and the buttons wrap
        // underneath it instead of overflowing.
        if (constraints.maxWidth < _kHeaderStackWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: title),
            const SizedBox(width: 16),
            actions[0],
            const SizedBox(width: 8),
            actions[1],
            const SizedBox(width: 8),
            actions[2],
          ],
        );
      },
    );
  }

  void _showCreateModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const Center(child: CreateTunnelModal()),
    );
  }

  Future<void> _updateBinary(String provider, bool isBusy) async {
    final displayName = provider == 'cloudflare' ? 'Cloudflare' : 'ngrok';
    final binaryName = provider == 'cloudflare' ? 'cloudflared' : 'ngrok';
    if (isBusy) {
      AppDialogs.showInfoToast(
        context,
        'Stop the running $displayName tunnel first, then update.',
      );
      return;
    }
    if (_updating.contains(provider)) return;
    setState(() => _updating.add(provider));
    try {
      await ref
          .read(tunnelDownloaderServiceProvider)
          .downloadBinary(provider);
      if (!mounted) return;
      AppDialogs.showToast(
        context,
        '$binaryName updated to the latest version',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showErrorFrom(
        context,
        e,
        title: 'Could not update $binaryName',
      );
    } finally {
      if (mounted) setState(() => _updating.remove(provider));
    }
  }

  void _start(TunnelModel tunnel) {
    ref.read(tunnelSessionsProvider.notifier).start(tunnel);
    AppDialogs.showInfoToast(context, 'Starting tunnel "${tunnel.name}"...');
  }

  void _stop(int tunnelId) {
    ref.read(tunnelSessionsProvider.notifier).stop(tunnelId);
    AppDialogs.showInfoToast(context, 'Stopping tunnel...');
  }

  void _cancel(int tunnelId) {
    ref.read(tunnelSessionsProvider.notifier).cancelStart(tunnelId);
    AppDialogs.showInfoToast(context, 'Cancelling tunnel start...');
  }

  void _delete(TunnelModel tunnel) {
    ref.read(tunnelSessionsProvider.notifier).delete(tunnel.id);
    AppDialogs.showInfoToast(context, 'Deleting tunnel "${tunnel.name}"...');
  }

  void _edit(TunnelModel tunnel) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) =>
          Center(child: CreateTunnelModal(initialTunnel: tunnel)),
    );
  }

  void _viewLogs(TunnelModel tunnel, TunnelSession? session) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: TunnelLogsModal(tunnelName: tunnel.name, session: session),
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    AppDialogs.showToast(context, 'Public URL copied to clipboard');
  }

  void _openQr(TunnelModel tunnel, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: TunnelQrModal(tunnelName: tunnel.name, publicUrl: url),
      ),
    );
  }
}
