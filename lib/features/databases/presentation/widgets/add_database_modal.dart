import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/databases_provider.dart';
import '../../domain/database_record.dart';
import '../../../apps/domain/app_model.dart';

class AddDatabaseModal extends ConsumerStatefulWidget {
  final AppModel engine;
  final VoidCallback onClose;
  final DatabaseRecord? initialData;

  const AddDatabaseModal({
    super.key,
    required this.engine,
    required this.onClose,
    this.initialData,
  });

  @override
  ConsumerState<AddDatabaseModal> createState() => _AddDatabaseModalState();
}

class _AddDatabaseModalState extends ConsumerState<AddDatabaseModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isCreating = false;
  bool get isEdit => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.initialData!.name;
      _userController.text = widget.initialData!.username;
      _passController.text = widget.initialData!.password;
      _noteController.text = widget.initialData!.note ?? '';
    } else {
      _nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() {
    if (_userController.text.isEmpty ||
        _userController.text ==
            _nameController.text.substring(
              0,
              _nameController.text.isNotEmpty
                  ? _nameController.text.length - 1
                  : 0,
            )) {
      _userController.text = _nameController.text;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _userController.dispose();
    _passController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);
    try {
      final dbName = _nameController.text.trim();
      final userName = _userController.text.trim().isEmpty
          ? dbName
          : _userController.text.trim();

      if (isEdit) {
        await ref
            .read(databasesProvider.notifier)
            .updateDatabase(
              app: widget.engine,
              record: widget.initialData!,
              newUser: userName,
              newPassword: _passController.text,
              newNote: _noteController.text.trim(),
            );
      } else {
        await ref
            .read(databasesProvider.notifier)
            .addDatabase(
              app: widget.engine,
              name: dbName,
              user: userName,
              password: _passController.text,
              note: _noteController.text.trim(),
            );
      }
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
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 450,
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
                  const Icon(
                    LucideIcons.database,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Database' : 'Create New Database',
                          style: const TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Update database configuration'
                              : 'Configure your new database instance',
                          style: const TextStyle(
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
                    _buildLabel('Database Name'),
                    AppTextField(
                      controller: _nameController,
                      hint: 'e.g. my_project_db',
                      prefixIcon: LucideIcons.tag,
                      enabled: !isEdit,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a database name';
                        }
                        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(value)) {
                          return 'Letters, digits, _ only; must start with a letter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Username'),
                              AppTextField(
                                controller: _userController,
                                hint: 'Same as DB name',
                                prefixIcon: LucideIcons.user,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (!RegExp(
                                    r'^[A-Za-z][A-Za-z0-9_]*$',
                                  ).hasMatch(value)) {
                                    return 'Letters, digits, _ only; start with a letter';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Password'),
                              AppTextField(
                                controller: _passController,
                                hint: 'Leave empty if none',
                                prefixIcon: LucideIcons.key,
                                obscureText: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Note (Optional)'),
                    AppTextField(
                      controller: _noteController,
                      hint: 'Description or project name',
                      prefixIcon: LucideIcons.fileText,
                      maxLines: 2,
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
                  AppButton(
                    label: 'Cancel',
                    onPressed: widget.onClose,
                    style: AppButtonStyle.ghost,
                    size: AppButtonSize.md,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: isEdit ? 'Update Database' : 'Create Database',
                    onPressed: _handleCreate,
                    style: AppButtonStyle.primary,
                    size: AppButtonSize.md,
                    isLoading: _isCreating,
                    icon: const Icon(LucideIcons.save, size: 16),
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
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}
