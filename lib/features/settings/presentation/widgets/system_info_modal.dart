import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../dashboard/data/system_info_provider.dart';
import '../../../dashboard/domain/system_info.dart';

class SystemInfoModal extends ConsumerWidget {
  const SystemInfoModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfoAsync = ref.watch(systemInfoNotifierProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        width: 800,
        height: 600,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117), // Deeper dark for terminal feel
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: systemInfoAsync.when(
                data: (info) => _buildTerminalView(context, info),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
            _buildFooter(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.terminal, color: AppColors.accent, size: 18),
          const SizedBox(width: 12),
          const Text(
            'System Diagnostics',
            style: TextStyle(
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => ref.read(systemInfoNotifierProvider.notifier).refresh(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: AppColors.textSecondary,
            hoverColor: AppColors.surfaceLight,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x, size: 18),
            color: AppColors.textSecondary,
            hoverColor: Colors.red.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView(BuildContext context, SystemInfo info) {
    // Generate the formatted string based on user's requested format
    final formattedText = _formatSystemInfo(info);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF010409),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: SelectableText(
        formattedText,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: const Color(0xFFE6EDF3),
          height: 1.5,
        ),
      ),
    );
  }

  String _formatSystemInfo(SystemInfo info) {
    return info.toFormattedString();
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              final info = ref.read(systemInfoNotifierProvider).value;
              if (info != null) {
                Clipboard.setData(ClipboardData(text: _formatSystemInfo(info)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('System info copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    width: 300,
                  ),
                );
              }
            },
            icon: const Icon(LucideIcons.copy, size: 14),
            label: const Text('Copy to Clipboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

