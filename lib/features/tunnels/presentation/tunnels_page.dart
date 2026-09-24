import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/widgets/app_button.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_session.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/create_tunnel_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_logs_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_qr_modal.dart';
import 'package:dev_stack/features/tunnels/presentation/widgets/tunnel_table.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: tunnelsAsync.when(
                data: (tunnels) => TunnelTable(
                  tunnels: tunnels,
                  sessions: sessions,
                  onStart: _start,
                  onStop: _stop,
                  onEdit: _edit,
                  onDelete: _delete,
                  onViewLogs: (tunnel) => _viewLogs(tunnel, sessions[tunnel.id]),
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

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Tunnels',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Expose local sites and ports to the public internet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.sm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: 'New Tunnel',
          icon: const Icon(LucideIcons.plus, size: 16),
          style: AppButtonStyle.success,
          onPressed: _showCreateModal,
        ),
      ],
    );
  }

  void _showCreateModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const Center(
        child: CreateTunnelModal(),
      ),
    );
  }

  void _start(TunnelModel tunnel) {
    ref.read(tunnelSessionsProvider.notifier).start(tunnel);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting tunnel "${tunnel.name}"...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _stop(int tunnelId) {
    ref.read(tunnelSessionsProvider.notifier).stop(tunnelId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stopping tunnel...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _delete(TunnelModel tunnel) {
    ref.read(tunnelSessionsProvider.notifier).delete(tunnel.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting tunnel "${tunnel.name}"...'),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _edit(TunnelModel tunnel) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: CreateTunnelModal(initialTunnel: tunnel),
      ),
    );
  }

  void _viewLogs(TunnelModel tunnel, TunnelSession? session) {
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

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public URL copied to clipboard')),
    );
  }

  void _openQr(TunnelModel tunnel, String url) {
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
}
