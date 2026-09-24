import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/site_model.dart';
import '../../../apps/data/apps_provider.dart';
import '../../data/sites_provider.dart';
import '../site_editor_options.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/code_editor/config_code_editor.dart';

class EditSiteModal extends ConsumerStatefulWidget {
  final SiteModel site;
  final VoidCallback onClose;

  const EditSiteModal({super.key, required this.site, required this.onClose});

  @override
  ConsumerState<EditSiteModal> createState() => _EditSiteModalState();
}

class _EditSiteModalState extends ConsumerState<EditSiteModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 620,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    _GeneralTab(site: widget.site),
                    _ConfigTab(site: widget.site),
                    _SslTab(site: widget.site),
                    _LogTab(site: widget.site),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.globe, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Site Settings: ${widget.site.domain}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.base,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppIconButton(
            onPressed: widget.onClose,
            icon: LucideIcons.x,
            tooltip: 'Close',
            color: AppColors.textMuted,
            size: AppIconButtonSize.sm,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'General'),
            Tab(text: 'Config'),
            Tab(text: 'SSL'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
    );
  }
}

class _GeneralTab extends ConsumerStatefulWidget {
  final SiteModel site;
  const _GeneralTab({required this.site});

  @override
  ConsumerState<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends ConsumerState<_GeneralTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _domainController;
  late TextEditingController _rootDirController;
  late TextEditingController _proxyTargetController;
  late TextEditingController _commandController;
  late TextEditingController _portController;
  late String _siteType;
  String? _selectedPhpAppId;
  late bool _useSsl;
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
  late String _selectedPreset;
  bool _autoStart = false;

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
    _domainController = TextEditingController(text: widget.site.domain);
    _rootDirController = TextEditingController(text: widget.site.rootDir);
    _proxyTargetController = TextEditingController(
      text: widget.site.proxyTarget ?? '',
    );
    _siteType = widget.site.siteType;
    _useSsl = widget.site.useSsl;
    _commandController = TextEditingController(
      text: widget.site.command ?? 'npm run dev',
    );
    _portController = TextEditingController(
      text: widget.site.port?.toString() ?? '3000',
    );
    _autoStart = widget.site.autoStart;
    _selectedPreset = _presetForCommand(widget.site.command);
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
      setState(() => _rootDirController.text = result);
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
      await ref
          .read(sitesProvider.notifier)
          .updateSite(
            id: widget.site.id,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('General settings updated')),
        );
      }
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
    final appsAsync = ref.watch(appsProvider);

    return appsAsync.when(
      data: (apps) {
        final phpApps = apps
            .where((a) => a.isInstalled && a.groupName == 'php')
            .toList();
        if (_selectedPhpAppId == null && phpApps.isNotEmpty) {
          final match = phpApps.indexWhere(
            (a) =>
                widget.site.phpVersion != null &&
                a.appId.contains(widget.site.phpVersion!),
          );
          _selectedPhpAppId = match != -1
              ? phpApps[match].appId
              : phpApps.first.appId;
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _buildLabel('Domain Name'),
                AppTextField(
                  controller: _domainController,
                  enabled: false,
                  hint: 'e.g. my-project.test',
                  prefixIcon: LucideIcons.atSign,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Site Type'),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildTypeOption('PHP', 'php', LucideIcons.code),
                    _buildTypeOption('Static', 'static', LucideIcons.fileCode),
                    _buildTypeOption('Proxy', 'proxy', LucideIcons.shuffle),
                    _buildTypeOption('CLI App', 'cli', LucideIcons.terminal),
                  ],
                ),
                const SizedBox(height: 20),

                // --- CLI App options ---
                // When the site type is CLI, surface the preset (which
                // auto-fills command + port), the start command, the internal
                // port and the auto-start toggle that CliProcessManager uses to
                // spawn and proxy the process.
                if (_siteType == 'cli') ...[
                  _buildLabel('Preset'),
                  _buildPresetDropdown(),
                  const SizedBox(height: 20),
                  _buildLabel('Start Command'),
                  AppTextField(
                    controller: _commandController,
                    hint: 'e.g. npm run dev',
                    prefixIcon: LucideIcons.terminal,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a start command';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Internal Port'),
                  AppTextField(
                    controller: _portController,
                    hint: 'e.g. 3000',
                    prefixIcon: LucideIcons.server,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a port';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 1 || parsed > 65535) {
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.xs,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _autoStart,
                        onChanged: (v) => setState(() => _autoStart = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                if (_siteType != 'proxy') ...[
                  _buildLabel('Root Directory'),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _rootDirController,
                          hint: 'Path to project',
                          prefixIcon: LucideIcons.folder,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        style: AppButtonStyle.secondary,
                        icon: const Icon(
                          LucideIcons.folderOpen,
                          size: 18,
                        ),
                        onPressed: _pickDirectory,
                        label: '',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                if (_siteType == 'proxy') ...[
                  _buildLabel('Proxy Target URL'),
                  AppTextField(
                    controller: _proxyTargetController,
                    hint: 'e.g. http://localhost:3000',
                    prefixIcon: LucideIcons.link,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a target URL';
                      }
                      try {
                        Sites.validateProxyTarget(value);
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
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.border,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPhpAppId,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: const Icon(
                                    LucideIcons.chevronDown,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                  items: phpApps
                                      .map(
                                        (a) => DropdownMenuItem(
                                          value: a.appId,
                                          child: Text(
                                            a.name,
                                            style: const TextStyle(
                                              fontSize: AppTextSize.sm,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedPhpAppId = v),
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
                        Switch(
                          value: _useSsl,
                          onChanged: (v) => setState(() => _useSsl = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.bottomRight,
                  child: AppButton(
                    label: 'Save General Settings',
                    icon: const Icon(LucideIcons.save, size: 14),
                    style: AppButtonStyle.success,
                    isLoading: _isSaving,
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildTypeOption(String label, String value, IconData icon) {
    final isSelected = _siteType == value;
    return InkWell(
      onTap: () => setState(() => _siteType = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
                fontSize: AppTextSize.sm,
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

  Widget _buildPresetDropdown() {
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
          value: _selectedPreset,
          isExpanded: true,
          style: const TextStyle(fontSize: AppTextSize.sm, color: AppColors.textPrimary),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.textMuted,
          ),
          items: _cliPresets.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value.name,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
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

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // _buildTextField removed: replaced with AppTextField from shared widgets.
}

class _ConfigTab extends ConsumerStatefulWidget {
  final SiteModel site;
  const _ConfigTab({required this.site});

  @override
  ConsumerState<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends ConsumerState<_ConfigTab> {
  String _selectedType = 'nginx';

  @override
  Widget build(BuildContext context) {
    final configPath = Sites.vhostConfigPath(_selectedType, widget.site.domain);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < siteConfigEditorOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildTypeButton(
                  siteConfigEditorOptions[i].id,
                  siteConfigEditorOptions[i].label,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ConfigCodeEditor(
              key: ValueKey('$_selectedType-${widget.site.domain}'),
              filePath: configPath,
              createIfMissing: true,
              onSave: (newContent) async {
                await ref
                    .read(sitesProvider.notifier)
                    .saveConfig(widget.site, _selectedType, newContent);
                return true;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedType = type);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SslTab extends ConsumerStatefulWidget {
  final SiteModel site;
  const _SslTab({required this.site});

  @override
  ConsumerState<_SslTab> createState() => _SslTabState();
}

class _SslTabState extends ConsumerState<_SslTab> {
  String _selectedFile = 'cert';
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSslFiles();
  }

  Future<void> _loadSslFiles() async {
    setState(() => _isLoading = true);
    final files = await ref
        .read(sitesProvider.notifier)
        .getSslFiles(widget.site);
    _controller.text = files[_selectedFile] ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveSslFile() async {
    await ref
        .read(sitesProvider.notifier)
        .saveSslFile(widget.site, _selectedFile, _controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SSL file saved successfully')),
      );
    }
  }

  Future<void> _regenerate() async {
    await ref.read(sitesProvider.notifier).regenerateSsl(widget.site);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SSL certificate regenerated')),
      );
      _loadSslFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeButton('cert', 'Certificate', tooltip: 'Certificate (cert.pem)'),
                      const SizedBox(width: 8),
                      _buildTypeButton('key', 'Private Key', tooltip: 'Private Key (key.pem)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                style: AppButtonStyle.outline,
                icon: const Icon(LucideIcons.refreshCcw, size: 14),
                label: 'Regenerate SSL',
                onPressed: _regenerate,
                textColor: AppColors.accent,
              ),
              const SizedBox(width: 8),
              AppButton(
                style: AppButtonStyle.success,
                icon: const Icon(LucideIcons.save, size: 14),
                label: 'Save Changes',
                onPressed: _saveSslFile,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: AppTextSize.xs,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, {String? tooltip}) {
    final isSelected = _selectedFile == type;
    final button = InkWell(
      onTap: () {
        setState(() => _selectedFile = type);
        _loadSslFiles();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}

class _LogTab extends ConsumerStatefulWidget {
  final SiteModel site;
  const _LogTab({required this.site});

  @override
  ConsumerState<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<_LogTab> {
  String _selectedLog = 'nginx_access';
  Map<String, String> _logs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  Future<void> _refreshLogs() async {
    setState(() => _isLoading = true);
    final logs = await ref
        .read(sitesProvider.notifier)
        .getLogs(widget.site);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(appsProvider).value ?? [];
    final hasNginx = apps.any((a) => a.isInstalled && a.appId.toLowerCase().contains('nginx'));
    final hasApache = apps.any((a) => a.isInstalled && a.appId.toLowerCase().contains('apache'));
    final hasCaddy = apps.any((a) => a.isInstalled && a.appId.toLowerCase().contains('caddy'));

    final availableOptions = (hasNginx || hasApache || hasCaddy)
        ? siteLogOptions.where((opt) {
            if (opt.id.startsWith('nginx_') && hasNginx) return true;
            if (opt.id.startsWith('apache_') && hasApache) return true;
            if (opt.id.startsWith('caddy_') && hasCaddy) return true;
            return false;
          }).toList()
        : siteLogOptions;

    final effectiveLog = availableOptions.any((opt) => opt.id == _selectedLog)
        ? _selectedLog
        : (availableOptions.isNotEmpty ? availableOptions.first.id : _selectedLog);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildLogSelect(availableOptions, effectiveLog)),
              const SizedBox(width: 8),
              AppIconButton(
                icon: LucideIcons.refreshCw,
                onPressed: _refreshLogs,
                tooltip: 'Refresh Logs',
                color: AppColors.textSecondary,
                size: AppIconButtonSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ConfigCodeEditor(
              key: ValueKey('$effectiveLog-${widget.site.domain}'),
              filePath: '$effectiveLog.log',
              content: _isLoading && !_logs.containsKey(effectiveLog)
                  ? 'Loading logs...'
                  : (_logs[effectiveLog] ?? 'No log data'),
              readOnly: true,
              showToolbar: true,
              onReload: _refreshLogs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogButton(String id, String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() => _selectedLog = id);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Center(
          widthFactor: 1.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogSelect(List<({String id, String label})> options, String currentSelected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildLogButton(
              options[i].id,
              options[i].label,
              currentSelected == options[i].id,
            ),
          ],
        ],
      ),
    );
  }
}
