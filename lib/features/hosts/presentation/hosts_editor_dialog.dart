import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/widgets/code_editor/config_code_editor.dart';
import '../data/hosts_provider.dart';
import '../data/hosts_repository.dart';

/// A modal dialog wrapping [ConfigCodeEditor] bound to the Windows hosts file.
/// Replaces the old "Open in Notepad++" flow.
///
/// Reads via [HostsRepository.readHostsRaw] (system encoding, non-ASCII safe)
/// and persists via [HostsNotifier.save], which already does direct-write →
/// elevated `runElevatedPowerShell(Copy-Item ...)` fallback (UAC). The
/// editor receives the hosts path so [languageForConfigPath] maps it to
/// plaintext.
///
/// Mirrors the app's shared modal template: transparent [Dialog] wrapper,
/// a rounded [Container] with border + shadow, and a surface header row
/// (tinted icon box → title/subtitle → close). See [AppSettingsModal].
class HostsEditorDialog extends ConsumerStatefulWidget {
  const HostsEditorDialog({super.key, required this.onClose});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: HostsEditorDialog(
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  final VoidCallback onClose;

  @override
  ConsumerState<HostsEditorDialog> createState() => _HostsEditorDialogState();
}

class _HostsEditorDialogState extends ConsumerState<HostsEditorDialog> {
  Future<bool> _save(String content) async {
    // HostsNotifier.save() reads its current state.value, so set it first.
    ref.read(hostsNotifierProvider.notifier).updateText(content);
    return ref.read(hostsNotifierProvider.notifier).save();
  }

  @override
  Widget build(BuildContext context) {
    final hostsAsync = ref.watch(hostsNotifierProvider);

    return Container(
      width: 900,
      height: 700,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: hostsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load hosts: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                data: (_) {
                  // ConfigCodeEditor reads the file itself, so we just need
                  // the path here.
                  return ConfigCodeEditor(
                    key: ValueKey(HostsRepository.hostsPath),
                    filePath: HostsRepository.hostsPath,
                    onSave: _save,
                    saveLabel: 'Save Hosts',
                    encoding: systemEncoding,
                    decodeFallback: (bytes) {
                      try {
                        return systemEncoding.decode(bytes);
                      } catch (_) {
                        return String.fromCharCodes(bytes);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.dns_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Hosts File',
                  style: TextStyle(
                    fontSize: AppTextSize.base,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Editing ${HostsRepository.hostsPath} — saving prompts for '
                  'admin (UAC) if DevStack is not elevated.',
                  style: const TextStyle(
                    fontSize: AppTextSize.xxs,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            color: AppColors.textMuted,
            hoverColor: AppColors.error.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}
