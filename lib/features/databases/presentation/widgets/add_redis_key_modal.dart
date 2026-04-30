import 'dart:convert';
import 'dart:io';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/redis_provider.dart';
import '../../../apps/domain/app_model.dart';
import 'package:dev_stack/shared/utils/app_dialogs.dart';

class AddRedisKeyModal extends ConsumerStatefulWidget {
  final AppModel engine;
  final int dbIndex;
  final VoidCallback onClose;
  final String? initialKey;
  final String? initialValue;
  final String? initialType;
  final int? initialTtl;

  const AddRedisKeyModal({
    super.key,
    required this.engine,
    required this.dbIndex,
    required this.onClose,
    this.initialKey,
    this.initialValue,
    this.initialType,
    this.initialTtl,
  });

  @override
  ConsumerState<AddRedisKeyModal> createState() => _AddRedisKeyModalState();
}

class _AddRedisKeyModalState extends ConsumerState<AddRedisKeyModal> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final _ttlController = TextEditingController();
  bool _isAdding = false;
  late String _type;
  bool get isEdit => widget.initialKey != null;
  bool get _isReadOnly => isEdit && _type != 'string';

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'string';
    _keyController.text = widget.initialKey ?? '';
    _valueController.text = widget.initialValue ?? '';
    if (widget.initialTtl != null && widget.initialTtl! > 0) {
      _ttlController.text = widget.initialTtl.toString();
    }

    if (isEdit) {
      _fetchFullValue();
    }
  }

  Future<void> _fetchFullValue() async {
    try {
      final cliPath = widget.engine.cliFilePath;
      if (cliPath == null) return;

      final type = widget.initialType ?? 'string';

      String fullValue = '';
      if (type == 'string') {
        final valRes = await Process.run(cliPath, [
          '-n',
          widget.dbIndex.toString(),
          'GET',
          widget.initialKey!,
        ]);
        fullValue = valRes.stdout.toString().trim();
      } else {
        // For non-string types, check length/count first
        int count = 0;
        if (type == 'list') {
          final res = await Process.run(cliPath, [
            '-n',
            widget.dbIndex.toString(),
            'LLEN',
            widget.initialKey!,
          ]);
          count = int.tryParse(res.stdout.toString().trim()) ?? 0;
        } else if (type == 'set') {
          final res = await Process.run(cliPath, [
            '-n',
            widget.dbIndex.toString(),
            'SCARD',
            widget.initialKey!,
          ]);
          count = int.tryParse(res.stdout.toString().trim()) ?? 0;
        } else if (type == 'hash') {
          final res = await Process.run(cliPath, [
            '-n',
            widget.dbIndex.toString(),
            'HLEN',
            widget.initialKey!,
          ]);
          count = int.tryParse(res.stdout.toString().trim()) ?? 0;
        } else if (type == 'zset') {
          final res = await Process.run(cliPath, [
            '-n',
            widget.dbIndex.toString(),
            'ZCARD',
            widget.initialKey!,
          ]);
          count = int.tryParse(res.stdout.toString().trim()) ?? 0;
        }

        if (count > 500) {
          fullValue =
              'The data length ($count items) exceeds the preview limit of 500 items. To ensure performance, the full data will not be displayed.';
        } else {
          // Fetch and format as JSON
          if (type == 'list') {
            final res = await Process.run(cliPath, [
              '-n',
              widget.dbIndex.toString(),
              'LRANGE',
              widget.initialKey!,
              '0',
              '-1',
            ]);
            final items = res.stdout
                .toString()
                .trim()
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            fullValue = const JsonEncoder.withIndent('  ').convert(items);
          } else if (type == 'set') {
            final res = await Process.run(cliPath, [
              '-n',
              widget.dbIndex.toString(),
              'SMEMBERS',
              widget.initialKey!,
            ]);
            final items = res.stdout
                .toString()
                .trim()
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            fullValue = const JsonEncoder.withIndent('  ').convert(items);
          } else if (type == 'hash') {
            final res = await Process.run(cliPath, [
              '-n',
              widget.dbIndex.toString(),
              'HGETALL',
              widget.initialKey!,
            ]);
            final output = res.stdout
                .toString()
                .trim()
                .split('\n')
                .map((s) => s.trim())
                .toList();
            final map = <String, String>{};
            for (int i = 0; i < output.length; i += 2) {
              if (i + 1 < output.length) map[output[i]] = output[i + 1];
            }
            fullValue = const JsonEncoder.withIndent('  ').convert(map);
          } else if (type == 'zset') {
            final res = await Process.run(cliPath, [
              '-n',
              widget.dbIndex.toString(),
              'ZRANGE',
              widget.initialKey!,
              '0',
              '-1',
              'WITHSCORES',
            ]);
            final output = res.stdout
                .toString()
                .trim()
                .split('\n')
                .map((s) => s.trim())
                .toList();
            final list = <Map<String, dynamic>>[];
            for (int i = 0; i < output.length; i += 2) {
              if (i + 1 < output.length) {
                list.add({'value': output[i], 'score': output[i + 1]});
              }
            }
            fullValue = const JsonEncoder.withIndent('  ').convert(list);
          }
        }
      }

      if (mounted) {
        setState(() {
          _type = type;
          if (fullValue.isNotEmpty) {
            _valueController.text = fullValue;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching full value: $e');
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      final key = _keyController.text.trim();

      // Check if key exists only when adding new key
      if (!isEdit) {
        final exists = await ref
            .read(redisNotifierProvider.notifier)
            .checkKeyExists(widget.engine, widget.dbIndex, key);

        if (exists) {
          if (mounted) {
            AppDialogs.showError(
              context,
              title: 'Key Already Exists',
              message:
                  'The key "$key" already exists in DB${widget.dbIndex}. Please use a different name or edit the existing key.',
            );
          }
          setState(() => _isAdding = false);
          return;
        }
      }

      await ref
          .read(redisNotifierProvider.notifier)
          .setKey(
            widget.engine,
            widget.dbIndex,
            key,
            _valueController.text,
            ttl: int.tryParse(_ttlController.text.trim()),
          );
      widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? 'Edit Redis Key (DB${widget.dbIndex})'
                              : 'Add Redis Key (DB${widget.dbIndex})',
                          style: TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Update existing key-value pair'
                              : 'Set a new key-value pair in Redis',
                          style: TextStyle(
                            fontSize: AppTextSize.xxs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Key Name'),
                    _buildTextField(
                      controller: _keyController,
                      hint: 'e.g. user:123:session',
                      enabled: !isEdit,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a key name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel(
                      _isReadOnly
                          ? 'Value (Read Only - $_type)'
                          : 'Value (String)',
                    ),
                    _buildTextField(
                      controller: _valueController,
                      hint: 'Enter string value',
                      maxLines: 8,
                      enabled: !_isReadOnly,
                      validator: (value) {
                        if (!_isReadOnly && (value == null || value.isEmpty)) {
                          return 'Please enter a value';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Term of Validity (Seconds, Optional)'),
                    _buildTextField(
                      controller: _ttlController,
                      hint: 'e.g. 3600 (empty for No limit)',
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: AppTextSize.xs,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!_isReadOnly)
                    ElevatedButton(
                      onPressed: _isAdding ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _isAdding
                            ? (isEdit ? 'Updating...' : 'Adding...')
                            : (isEdit ? 'Update Key' : 'Add Key'),
                        style: TextStyle(
                          fontSize: AppTextSize.xs,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      style: TextStyle(
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
      ),
    );
  }
}
