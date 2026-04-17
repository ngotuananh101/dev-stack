import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/properties.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../data/hosts_provider.dart';

class HostsPage extends ConsumerStatefulWidget {
  const HostsPage({super.key});

  @override
  ConsumerState<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends ConsumerState<HostsPage> {
  CodeController? _controller;
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void dispose() {
    _controller?.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final success = await ref.read(hostsNotifierProvider.notifier).save();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hosts file saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save hosts file.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initController(String text) {
    if (_controller == null) {
      _controller = CodeController(text: text, language: properties);
      _controller!.addListener(() {
        ref.read(hostsNotifierProvider.notifier).updateText(_controller!.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostsAsync = ref.watch(hostsNotifierProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _handleSave(),
      },
      child: Focus(
        autofocus: true,
        focusNode: _editorFocusNode,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(AppTextSize.h1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Expanded(
                  child: hostsAsync.when(
                    data: (content) {
                      _initController(content);
                      return _buildEditor();
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
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
                fontSize: AppTextSize.h3,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Edit C:\\Windows\\System32\\drivers\\etc\\hosts directly',
              style: TextStyle(
                fontSize: AppTextSize.label,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _handleSave,
          icon: const Icon(LucideIcons.save, size: 18),
          label: const Text('Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CodeTheme(
        data: CodeThemeData(styles: monokaiSublimeTheme),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _controller!,
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),
      ),
    );
  }
}
