import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/code_editor/config_code_editor.dart';
import '../data/hosts_provider.dart';
import '../data/hosts_repository.dart';

class HostsPage extends ConsumerStatefulWidget {
  const HostsPage({super.key});

  @override
  ConsumerState<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends ConsumerState<HostsPage> {
  final String _hostsPath = HostsRepository.hostsPath;

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
            padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }
}
