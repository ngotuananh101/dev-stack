import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/code_editor/config_code_editor.dart';
import '../data/hosts_provider.dart';
import '../data/hosts_repository.dart';

/// A full-screen-ish dialog wrapping [ConfigCodeEditor] bound to the Windows
/// hosts file. Replaces the old "Open in Notepad++" flow.
///
/// Reads via [HostsRepository.readHostsRaw] (system encoding, non-ASCII safe)
/// and persists via [HostsNotifier.save], which already does direct-write →
/// elevated `runElevatedPowerShell(Copy-Item ...)` fallback (UAC). The
/// editor receives the hosts path so [languageForConfigPath] maps it to
/// plaintext.
class HostsEditorDialog extends ConsumerStatefulWidget {
  const HostsEditorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const HostsEditorDialog(),
    );
  }

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

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(32),
      child: SizedBox(
        width: double.maxFinite,
        height: double.maxFinite,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns_outlined, size: 18,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Hosts File',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Editing C:\\Windows\\System32\\drivers\\etc\\hosts — saving '
                'prompts for admin (UAC) if DevStack is not elevated.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: hostsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Failed to load hosts: $e',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                  data: (content) {
                    // Seed initial content once loaded; ConfigCodeEditor reads
                    // the file itself, so we just need the path here.
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
            ],
          ),
        ),
      ),
    );
  }
}
