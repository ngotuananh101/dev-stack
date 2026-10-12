import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/app_dialogs.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/supervisor_provider.dart';
import '../../domain/supervisor_program.dart';

/// Create/edit form for a supervised program.
class ProgramFormModal extends ConsumerStatefulWidget {
  final SupervisorProgram? initialProgram;

  const ProgramFormModal({super.key, this.initialProgram});

  @override
  ConsumerState<ProgramFormModal> createState() => _ProgramFormModalState();
}

class _ProgramFormModalState extends ConsumerState<ProgramFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _command;
  late final TextEditingController _workingDir;
  late final TextEditingController _env;
  late final TextEditingController _maxRestarts;
  late final TextEditingController _windowSeconds;
  late final TextEditingController _delaySeconds;

  late bool _autoStart;
  late bool _autoRestart;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProgram;
    _name = TextEditingController(text: initial?.name ?? '');
    _command = TextEditingController(text: initial?.command ?? '');
    _workingDir = TextEditingController(text: initial?.workingDir ?? '');
    _env = TextEditingController(
      text: _envToText(initial?.environmentJson ?? '{}'),
    );
    _maxRestarts =
        TextEditingController(text: (initial?.maxRestarts ?? 5).toString());
    _windowSeconds = TextEditingController(
      text: (initial?.restartWindowSeconds ?? 60).toString(),
    );
    _delaySeconds = TextEditingController(
      text: (initial?.restartDelaySeconds ?? 2).toString(),
    );
    _autoStart = initial?.autoStart ?? false;
    _autoRestart = initial?.autoRestart ?? true;
    _enabled = initial?.enabled ?? true;
  }

  static String _envToText(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.entries.map((e) => '${e.key}=${e.value}').join('\n');
      }
    } catch (_) {
      // Fall through.
    }
    return '';
  }

  static String _textToEnv(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      map[trimmed.substring(0, eq).trim()] =
          trimmed.substring(eq + 1).trim();
    }
    return jsonEncode(map);
  }

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _workingDir.dispose();
    _env.dispose();
    _maxRestarts.dispose();
    _windowSeconds.dispose();
    _delaySeconds.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _workingDir.text = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEditing = widget.initialProgram != null;
    final program = SupervisorProgram(
      id: isEditing ? widget.initialProgram!.id : 0,
      name: _name.text.trim(),
      command: _command.text.trim(),
      workingDir: _workingDir.text.trim(),
      environmentJson: _textToEnv(_env.text),
      autoStart: _autoStart,
      autoRestart: _autoRestart,
      maxRestarts: int.tryParse(_maxRestarts.text.trim()) ?? 5,
      restartWindowSeconds: int.tryParse(_windowSeconds.text.trim()) ?? 60,
      restartDelaySeconds: int.tryParse(_delaySeconds.text.trim()) ?? 2,
      enabled: _enabled,
      createdAt: isEditing ? widget.initialProgram!.createdAt : DateTime.now(),
    );

    try {
      await ref.read(supervisorRepositoryProvider).save(program);
      if (mounted) Navigator.of(context).pop(program);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await AppDialogs.showError(
          context,
          title: 'Cannot Save Program',
          message: '$e',
        );
      }
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _toggle(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppTextSize.xxs,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final isEditing = widget.initialProgram != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: dims.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: dims.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppModalHeader(
              icon: LucideIcons.activity,
              title: isEditing
                  ? 'Edit Program: ${widget.initialProgram!.name}'
                  : 'New Supervised Program',
              subtitle: 'Keep a long-running process alive with a watchdog',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Name'),
                      AppTextField(
                        controller: _name,
                        hint: 'e.g. queue-worker',
                        prefixIcon: LucideIcons.tag,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Command'),
                      AppTextField(
                        controller: _command,
                        hint: 'e.g. php artisan queue:work',
                        prefixIcon: LucideIcons.terminal,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Working Directory'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _workingDir,
                              hint: 'e.g. /srv/app',
                              prefixIcon: LucideIcons.folder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Browse',
                            style: AppButtonStyle.secondary,
                            icon: const Icon(LucideIcons.folderOpen, size: 14),
                            onPressed: _pickDirectory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('Environment Variables (KEY=value, one per line)'),
                      AppTextField(
                        controller: _env,
                        hint: 'QUEUE=high\nAPP_ENV=local',
                        prefixIcon: LucideIcons.keyRound,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 18),
                      _toggle(
                        'Auto start on app launch',
                        'Start this program when DevStack opens',
                        _autoStart,
                        (v) => setState(() => _autoStart = v),
                      ),
                      const SizedBox(height: 12),
                      _toggle(
                        'Auto restart on crash',
                        'Restart automatically when the process exits',
                        _autoRestart,
                        (v) => setState(() => _autoRestart = v),
                      ),
                      const SizedBox(height: 12),
                      _toggle(
                        'Enabled',
                        'A disabled program never starts',
                        _enabled,
                        (v) => setState(() => _enabled = v),
                      ),
                      const SizedBox(height: 18),
                      _label('Restart Policy'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _maxRestarts,
                              hint: 'Max restarts',
                              prefixIcon: LucideIcons.repeat,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 0) {
                                  return 'Enter a number ≥ 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _windowSeconds,
                              hint: 'Window (seconds)',
                              prefixIcon: LucideIcons.timer,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 1) {
                                  return 'Enter a number ≥ 1';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _delaySeconds,
                              hint: 'Base delay (s)',
                              prefixIcon: LucideIcons.clock,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 0) {
                                  return 'Enter a number ≥ 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    style: AppButtonStyle.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: isEditing ? 'Save Changes' : 'Create Program',
                    style: AppButtonStyle.success,
                    isLoading: _saving,
                    icon: Icon(
                      isEditing ? LucideIcons.save : LucideIcons.plus,
                      size: 16,
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
