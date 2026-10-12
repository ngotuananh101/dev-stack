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
import '../../data/cron_provider.dart';
import '../../domain/cron_expression.dart';
import '../../domain/cron_job.dart';

/// Create/edit form for a cron job: schedule text with quick presets, live
/// validation, and a "next run" preview.
class CronFormModal extends ConsumerStatefulWidget {
  final CronJob? initialJob;

  const CronFormModal({super.key, this.initialJob});

  @override
  ConsumerState<CronFormModal> createState() => _CronFormModalState();
}

class _CronFormModalState extends ConsumerState<CronFormModal> {
  /// Quick presets offered in the dropdown; the value is the cron expression.
  static const Map<String, String> _presets = {
    '*/5 * * * *': 'Every 5 minutes',
    '*/15 * * * *': 'Every 15 minutes',
    '@hourly': 'Hourly',
    '@daily': 'Daily',
    '@weekly': 'Weekly',
    '@monthly': 'Monthly',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _schedule;
  late final TextEditingController _command;
  late final TextEditingController _workingDir;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialJob;
    _name = TextEditingController(text: initial?.name ?? '');
    _schedule = TextEditingController(text: initial?.schedule ?? '@daily');
    _command = TextEditingController(text: initial?.command ?? '');
    _workingDir = TextEditingController(text: initial?.workingDir ?? '');
    _enabled = initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _schedule.dispose();
    _command.dispose();
    _workingDir.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _workingDir.text = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEditing = widget.initialJob != null;
    final job = CronJob(
      id: isEditing ? widget.initialJob!.id : 0,
      name: _name.text.trim(),
      schedule: _schedule.text.trim(),
      command: _command.text.trim(),
      workingDir: _workingDir.text.trim(),
      enabled: _enabled,
      lastRunAt: isEditing ? widget.initialJob!.lastRunAt : null,
      lastStatus: isEditing ? widget.initialJob!.lastStatus : null,
      lastExitCode: isEditing ? widget.initialJob!.lastExitCode : null,
      createdAt: isEditing ? widget.initialJob!.createdAt : DateTime.now(),
    );

    try {
      await ref.read(cronRepositoryProvider).save(job);
      if (mounted) {
        Navigator.of(context).pop(job);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await AppDialogs.showError(
          context,
          title: 'Cannot Save Job',
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

  String _formatNext(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final isEditing = widget.initialJob != null;

    final scheduleText = _schedule.text.trim();
    final error = CronExpression.validate(scheduleText);
    final preview = error == null
        ? CronExpression.parse(scheduleText).nextOccurrence(DateTime.now())
        : null;
    final presetValue = _presets.containsKey(scheduleText) ? scheduleText : null;

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
              icon: LucideIcons.clock,
              title: isEditing ? 'Edit Job: ${widget.initialJob!.name}' : 'New Cron Job',
              subtitle: 'Runs only while DevStack is open — missed runs are not back-filled',
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
                        hint: 'e.g. nightly-backup',
                        prefixIcon: LucideIcons.tag,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Schedule'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _schedule,
                              hint: '*/5 * * * * or @daily',
                              prefixIcon: LucideIcons.clock,
                              onChanged: (_) => setState(() {}),
                              validator: (v) =>
                                  CronExpression.validate((v ?? '').trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPresetDropdown(presetValue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (error != null)
                        Text(
                          error,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: AppTextSize.xxs,
                          ),
                        )
                      else
                        Text(
                          preview == null
                              ? 'No matching time within 4 years.'
                              : 'Next run: ${_formatNext(preview)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: AppTextSize.xxs,
                          ),
                        ),
                      const SizedBox(height: 18),
                      _label('Command'),
                      AppTextField(
                        controller: _command,
                        hint: 'e.g. php artisan schedule:run',
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
                              hint: 'e.g. /srv/app (optional)',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enabled',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: AppTextSize.sm,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'A disabled job is never scheduled',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: AppTextSize.xxs,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              activeThumbColor: AppColors.success,
                              onChanged: (v) => setState(() => _enabled = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    label: isEditing ? 'Save Changes' : 'Create Job',
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

  Widget _buildPresetDropdown(String? value) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text(
            'Preset',
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textMuted,
            ),
          ),
          isExpanded: false,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            color: AppColors.textPrimary,
          ),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.textMuted,
          ),
          items: _presets.entries
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _schedule.text = v);
          },
        ),
      ),
    );
  }
}
