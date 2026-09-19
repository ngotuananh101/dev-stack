import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/site_model.dart';
import '../../../apps/data/apps_provider.dart';
import '../../../apps/domain/app_model.dart';
import '../../data/sites_provider.dart';

class AddSiteModal extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final SiteModel? initialData;

  static void _defaultOnClose() {}

  const AddSiteModal({super.key, this.onClose = _defaultOnClose, this.initialData});

  @override
  ConsumerState<AddSiteModal> createState() => _AddSiteModalState();
}

class _AddSiteModalState extends ConsumerState<AddSiteModal> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  final _rootDirController = TextEditingController();
  final _proxyTargetController = TextEditingController();
  final _commandController = TextEditingController();
  final _portController = TextEditingController();

  String _siteType = 'php'; // 'php', 'static', 'proxy', 'cli'
  String? _selectedPhpAppId;
  String _selectedPreset = 'node_npm';
  bool _useSsl = false;
  bool _autoStart = false;
  bool _isSaving = false;

  /// Preset CLI definitions. When a non-custom preset is selected, its command
  /// and port are written into [_commandController] / [_portController].
  final Map<String, ({String name, String command, int port})> _cliPresets = {
    'node_npm': (name: 'Node.js (npm)', command: 'npm run dev', port: 3000),
    'node_pnpm': (name: 'Node.js (pnpm)', command: 'pnpm dev', port: 3000),
    'node_yarn': (name: 'Node.js (yarn)', command: 'yarn dev', port: 3000),
    'bun': (name: 'Bun', command: 'bun dev', port: 3000),
    'deno': (name: 'Deno', command: 'deno task dev', port: 8000),
    'custom': (name: 'Custom', command: '', port: 3000),
  };

  bool get isEdit => widget.initialData != null;

  /// Returns the preset key whose command matches [command], or `'custom'` when
  /// the command does not correspond to any preset.
  String _presetForCommand(String? command) {
    final trimmed = command?.trim() ?? '';
    for (final entry in _cliPresets.entries) {
      if (entry.value.command == trimmed) return entry.key;
    }
    return 'custom';
  }

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _domainController.text = widget.initialData!.domain;
      _rootDirController.text = widget.initialData!.rootDir;
      _siteType = widget.initialData!.siteType;
      _proxyTargetController.text = widget.initialData!.proxyTarget ?? '';
      _useSsl = widget.initialData!.useSsl;
      _commandController.text = widget.initialData!.command ?? 'npm run dev';
      _portController.text =
          widget.initialData!.port?.toString() ?? '3000';
      _autoStart = widget.initialData!.autoStart;
      _selectedPreset = _presetForCommand(widget.initialData!.command);
    } else {
      _commandController.text = 'npm run dev';
      _portController.text = '3000';
    }
  }

  @override
  void dispose() {
    _domainController.dispose();
    _rootDirController.dispose();
    _proxyTargetController.dispose();
    _commandController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.getDirectoryPath();
    if (result != null) {
      setState(() {
        _rootDirController.text = result;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_siteType == 'php' && _selectedPhpAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PHP version'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (isEdit) {
        await ref
            .read(sitesNotifierProvider.notifier)
            .updateSite(
              id: widget.initialData!.id,
              domain: _domainController.text.trim(),
              rootDir: _siteType == 'proxy'
                  ? ''
                  : _rootDirController.text.trim(),
              siteType: _siteType,
              phpAppId: _siteType == 'php' ? _selectedPhpAppId : null,
              proxyTarget: _siteType == 'proxy'
                  ? _proxyTargetController.text.trim()
                  : null,
              command: _siteType == 'cli'
                  ? _commandController.text.trim()
                  : null,
              port: _siteType == 'cli'
                  ? int.tryParse(_portController.text.trim())
                  : null,
              autoStart: _siteType == 'cli' ? _autoStart : false,
              useSsl: _useSsl,
            );
      } else {
        await ref
            .read(sitesNotifierProvider.notifier)
            .addSite(
              domain: _domainController.text.trim(),
              rootDir: _siteType == 'proxy'
                  ? ''
                  : _rootDirController.text.trim(),
              siteType: _siteType,
              phpAppId: _siteType == 'php' ? _selectedPhpAppId : null,
              proxyTarget: _siteType == 'proxy'
                  ? _proxyTargetController.text.trim()
                  : null,
              command: _siteType == 'cli'
                  ? _commandController.text.trim()
                  : null,
              port: _siteType == 'cli'
                  ? int.tryParse(_portController.text.trim())
                  : null,
              autoStart: _siteType == 'cli' ? _autoStart : false,
              useSsl: _useSsl,
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsNotifierProvider);

    return appsAsync.when(
      data: (apps) {
        final phpApps = apps
            .where((a) => a.isInstalled && a.groupName == 'php')
            .toList();

        // Auto select static or match existing
        if (_selectedPhpAppId == null && phpApps.isNotEmpty) {
          if (isEdit && widget.initialData!.phpVersion != null) {
            final match = phpApps.indexWhere(
              (a) => a.appId.contains(widget.initialData!.phpVersion!),
            );
            if (match != -1) {
              _selectedPhpAppId = phpApps[match].appId;
            } else {
              _selectedPhpAppId = phpApps.first.appId;
            }
          } else {
            _selectedPhpAppId = phpApps.first.appId;
          }
        }

        return _buildUI(phpApps);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading apps: $e')),
    );
  }

  Widget _buildUI(List<AppModel> phpApps) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                    LucideIcons.globe,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Site' : 'Add New Site',
                          style: const TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Configure a new virtual host for your project',
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
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Content (scrolls when the form is taller than the viewport,
            // e.g. on small screens or when the CLI options are shown).
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    _buildLabel('Domain Name'),
                    _buildTextField(
                      controller: _domainController,
                      hint: 'e.g. my-project.test',
                      icon: LucideIcons.atSign,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a domain';
                        }
                        if (!RegExp(
                          r'^[a-zA-Z0-9][-a-zA-Z0-9.]+$',
                        ).hasMatch(value)) {
                          return 'Invalid domain format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Site Type'),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildTypeOption('PHP', 'php', LucideIcons.code),
                        _buildTypeOption(
                          'Static',
                          'static',
                          LucideIcons.fileCode,
                        ),
                        _buildTypeOption('Proxy', 'proxy', LucideIcons.shuffle),
                        _buildTypeOption('CLI App', 'cli', LucideIcons.terminal),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_siteType != 'proxy') ...[
                      _buildLabel('Root Directory'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _rootDirController,
                              hint: 'C:\\Projects\\my-project',
                              icon: LucideIcons.folder,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a directory';
                                }
                                if (!Directory(value).existsSync()) {
                                  return 'Directory does not exist';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _pickDirectory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.folderOpen,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // --- CLI App options ---
                    // A directory selector (working directory) is already shown
                    // above via the `if (_siteType != 'proxy')` block. When the
                    // site type is CLI, additionally surface the preset, start
                    // command, internal port and auto-start toggle that the
                    // CliProcessManager uses to spawn and proxy the process.
                    if (_siteType == 'cli') ...[
                      _buildLabel('Preset'),
                      _buildPresetDropdown(),
                      const SizedBox(height: 20),
                      _buildLabel('Start Command'),
                      _buildTextField(
                        controller: _commandController,
                        hint: 'e.g. npm run dev',
                        icon: LucideIcons.terminal,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a start command';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Internal Port'),
                      _buildTextField(
                        controller: _portController,
                        hint: 'e.g. 3000',
                        icon: LucideIcons.server,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a port';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null ||
                              parsed < 1 ||
                              parsed > 65535) {
                            return 'Enter a valid port (1-65535)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Auto-start on launch',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch.adaptive(
                            value: _autoStart,
                            onChanged: (v) => setState(() => _autoStart = v),
                            activeThumbColor: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_siteType == 'proxy') ...[
                      _buildLabel('Proxy Target URL'),
                      _buildTextField(
                        controller: _proxyTargetController,
                        hint: 'e.g. http://localhost:3000',
                        icon: LucideIcons.link,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a target URL';
                          }
                          try {
                            SitesNotifier.validateProxyTarget(value);
                          } on ArgumentError catch (e) {
                            return e.message.toString();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_siteType == 'php')
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('PHP Version'),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedPhpAppId,
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 16,
                                      ),
                                      items: phpApps.map((app) {
                                        return DropdownMenuItem(
                                          value: app.appId,
                                          child: Text(
                                            app.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(
                                        () => _selectedPhpAppId = val,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('SSL'),
                            InkWell(
                              onTap: () => setState(() => _useSsl = !_useSsl),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _useSsl
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _useSsl
                                        ? AppColors.success
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _useSsl
                                          ? LucideIcons.shieldCheck
                                          : LucideIcons.shieldAlert,
                                      size: 16,
                                      color: _useSsl
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Apply SSL',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _useSsl
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                        fontWeight: _useSsl
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _useSsl,
                                        onChanged: (val) => setState(
                                          () => _useSsl = val ?? false,
                                        ),
                                        activeColor: AppColors.success,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _isSaving
                          ? 'Saving...'
                          : (isEdit ? 'Update Site' : 'Add Site'),
                      style: const TextStyle(
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

  Widget _buildTypeOption(String label, String value, IconData icon) {
    final isSelected = _siteType == value;
    return InkWell(
      onTap: () => setState(() => _siteType = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
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

  Widget _buildPresetDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPreset,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
          items: _cliPresets.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedPreset = val;
              // Auto-fill command and port from the preset, unless the user
              // explicitly chose "Custom" (which leaves their input untouched).
              if (val != 'custom') {
                final preset = _cliPresets[val]!;
                _commandController.text = preset.command;
                _portController.text = preset.port.toString();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      style: TextStyle(
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textMuted),
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
