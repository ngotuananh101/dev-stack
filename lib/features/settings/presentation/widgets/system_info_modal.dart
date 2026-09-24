import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../../system/data/system_info_provider.dart';
import '../../../system/domain/system_info.dart';

class SystemInfoModal extends ConsumerWidget {
  const SystemInfoModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfoAsync = ref.watch(systemInfoStateProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        width: 800,
        height: 600,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
                    style: const TextStyle(color: AppColors.error),
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
    return AppModalHeader(
      icon: LucideIcons.terminal,
      iconColor: AppColors.accent,
      title: 'System Diagnostics',
      subtitle: 'Hardware, operating system, and runtime details',
      actions: [
        AppIconButton(
          onPressed: () => ref.read(systemInfoStateProvider.notifier).refresh(),
          icon: LucideIcons.refreshCw,
          tooltip: 'Refresh',
          color: AppColors.textSecondary,
          size: AppIconButtonSize.sm,
        ),
      ],
      onClose: () => Navigator.pop(context),
    );
  }

  Widget _buildTerminalView(BuildContext context, SystemInfo info) {
    final formattedText = info.toFormattedString();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: SelectableText(
        formattedText,
        style: GoogleFonts.jetBrainsMono(
          fontSize: AppTextSize.xs,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Copy to Clipboard',
            onPressed: () {
              final info = ref.read(systemInfoStateProvider).value;
              if (info != null) {
                Clipboard.setData(ClipboardData(text: info.toFormattedString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('System info copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    width: 300,
                  ),
                );
              }
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            style: AppButtonStyle.outline,
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
            style: AppButtonStyle.primary,
            backgroundColor: AppColors.accentStrong,
            textColor: AppColors.textOnColor,
          ),
        ],
      ),
    );
  }
}
