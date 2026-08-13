import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../../core/services/log_service.dart';
import '../../../core/theme/app_colors.dart';
import 'language_for_config.dart';

/// Threshold above which the editor shows a "large file" banner. The editor
/// still loads and renders lazily (re_editor only paints the visible lines
/// and parses highlighting in an isolate); this is UX feedback only, NOT a
/// cutoff.
const int kLargeFileBytes = 2 * 1024 * 1024; // 2 MB

/// A reusable in-app code editor for config files, built on [re_editor].
///
/// Replaces the old "Open in Notepad++" flow. Reads the file on init, lets the
/// user edit inline with syntax highlighting + line numbers, and persists via
/// [onSave]. Large files are handled natively by re_editor (lazy viewport
/// rendering + isolate-based highlight parsing); [CodeHighlightThemeMode]
/// caps highlight parsing at 4 MB / 1 MB-per-line to avoid stack overflow.
class ConfigCodeEditor extends StatefulWidget {
  const ConfigCodeEditor({
    super.key,
    required this.filePath,
    required this.onSave,
    this.readOnly = false,
    this.saveLabel = 'Save Changes',
    this.encoding = utf8,
    this.decodeFallback,
  });

  /// Absolute path of the file to edit.
  final String filePath;

  /// Persists [content] to the file. Returns true on success. The caller owns
  /// the write semantics (e.g. hosts-file elevation, domain re-validation).
  final Future<bool> Function(String content) onSave;

  /// When true, the editor is read-only (no Save button).
  final bool readOnly;

  final String saveLabel;

  /// Encoding used to decode/encode the file content. Defaults to UTF-8.
  /// Pass [systemEncoding] for the Windows hosts file (non-ASCII hostnames).
  final Encoding encoding;

  /// Optional fallback decoder if [encoding].decode throws (e.g. mixed
  /// encodings). Defaults to lossy char-code decode.
  final String Function(List<int> bytes)? decodeFallback;

  @override
  State<ConfigCodeEditor> createState() => _ConfigCodeEditorState();
}

class _ConfigCodeEditorState extends State<ConfigCodeEditor> {
  late final CodeLineEditingController _controller;
  final _scrollController = CodeScrollController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;
  int _fileBytes = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText('');
    _controller.addListener(_onChanged);
    _loadFile();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _loadError = 'File does not exist: ${widget.filePath}';
        });
        return;
      }
      final bytes = await file.readAsBytes();
      _fileBytes = bytes.length;
      String text;
      try {
        text = widget.encoding.decode(bytes);
      } catch (_) {
        text = (widget.decodeFallback ??
                (b) => String.fromCharCodes(b))
            .call(bytes);
      }
      _controller.text = text;
      _dirty = false;
      setState(() => _isLoading = false);
    } catch (e) {
      AppLogger.error('ConfigCodeEditor load failed: $e');
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load file: $e';
      });
    }
  }

  Future<void> _save() async {
    if (widget.readOnly || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final ok = await widget.onSave(_controller.text);
      if (ok) {
        _dirty = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save (permission denied or UAC declined)'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('ConfigCodeEditor save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @visibleForTesting
  static CodeHighlightTheme buildHighlightTheme(String filePath) {
    return CodeHighlightTheme(
      languages: {
        'config': CodeHighlightThemeMode(
          mode: languageForConfigPath(filePath),
        ),
      },
      theme: atomOneDarkTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _loadError!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final large = _fileBytes > kLargeFileBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.filePath,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (large)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message:
                        'Large file (${(_fileBytes / 1024 / 1024).toStringAsFixed(1)} MB) — '
                        'editor may be slower; highlighting is capped above 4 MB.',
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reload'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_isSaving || !_dirty) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 14),
                  label: Text(widget.saveLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Editor
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2127),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: CodeEditor(
              controller: _controller,
              scrollController: _scrollController,
              readOnly: widget.readOnly,
              style: CodeEditorStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                backgroundColor: const Color(0xFF1E2127),
                codeTheme: buildHighlightTheme(widget.filePath),
              ),
              indicatorBuilder: (
                context,
                editingController,
                chunkController,
                notifier,
              ) {
                return Row(
                  children: [
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                    ),
                    const SizedBox(width: 8),
                    DefaultCodeChunkIndicator(
                      width: 16,
                      controller: chunkController,
                      notifier: notifier,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
