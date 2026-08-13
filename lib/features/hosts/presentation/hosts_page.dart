import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/widgets/code_editor/config_code_editor.dart';
import '../data/hosts_provider.dart';
import '../data/hosts_repository.dart';

class HostsPage extends ConsumerStatefulWidget {
  const HostsPage({super.key});

  @override
  ConsumerState<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends ConsumerState<HostsPage> {
  static const String _hostsPath = HostsRepository.hostsPath;

  Future<bool> _save(String content) async {
    final notifier = ref.read(hostsNotifierProvider.notifier);
    notifier.updateText(content);
    final ok = await notifier.save();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Ctrl+E reloads; Ctrl+S is handled inside the editor's Save button.
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () {
          ref.invalidate(hostsNotifierProvider);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(AppTextSize.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: ConfigCodeEditor(
                    key: const ValueKey('hosts-editor'),
                    filePath: _hostsPath,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hosts Editor',
              style: TextStyle(
                fontSize: AppTextSize.xl,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Edit C:\\Windows\\System32\\drivers\\etc\\hosts directly',
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(hostsNotifierProvider);
          },
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('Reload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
