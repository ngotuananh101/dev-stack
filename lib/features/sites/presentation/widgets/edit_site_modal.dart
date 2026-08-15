import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/site_model.dart';
import '../../../apps/data/apps_provider.dart';
import '../../data/sites_provider.dart';
import '../site_editor_options.dart';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1000,
        height: 800,
        decoration: BoxDecoration(
          color: AppColors.background,
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
          const Icon(LucideIcons.settings, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            'Site Settings: ${widget.site.domain}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              LucideIcons.x,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          isScrollable: true,
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
  late String _siteType;
  String? _selectedPhpAppId;
  late bool _useSsl;
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _domainController.dispose();
    _rootDirController.dispose();
    _proxyTargetController.dispose();
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
          .read(sitesNotifierProvider.notifier)
          .updateSite(
            id: widget.site.id,
            domain: _domainController.text.trim(),
            rootDir: _rootDirController.text.trim(),
            siteType: _siteType,
            phpAppId: _siteType == 'php' ? _selectedPhpAppId : null,
            proxyTarget: _siteType == 'proxy'
                ? _proxyTargetController.text.trim()
                : null,
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
    final appsAsync = ref.watch(appsNotifierProvider);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Domain Name'),
                _buildTextField(
                  controller: _domainController,
                  enabled: false,
                  hint: 'e.g. my-project.test',
                  icon: LucideIcons.atSign,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Site Type'),
                Row(
                  children: [
                    _buildTypeOption('PHP', 'php', LucideIcons.code),
                    const SizedBox(width: 12),
                    _buildTypeOption('Static', 'static', LucideIcons.fileCode),
                    const SizedBox(width: 12),
                    _buildTypeOption('Proxy', 'proxy', LucideIcons.shuffle),
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
                          hint: 'Path to project',
                          icon: LucideIcons.folder,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.5),
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Icon(LucideIcons.folderOpen, size: 18),
                        ),
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
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.5,
                                  ),
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
                                              fontSize: 14,
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
                          activeThumbColor: AppColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: const Icon(LucideIcons.save, size: 16),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save General Settings',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
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
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _siteType = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    enabled: enabled,
    style: TextStyle(
      color: enabled ? AppColors.textPrimary : AppColors.textMuted,
      fontSize: 14,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 16, color: AppColors.textMuted),
      filled: true,
      fillColor: enabled
          ? AppColors.surface
          : AppColors.background.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );
}

class _ConfigTab extends ConsumerStatefulWidget {
  final SiteModel site;
  const _ConfigTab({required this.site});

  @override
  ConsumerState<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends ConsumerState<_ConfigTab> {
  String _selectedType = 'nginx';
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final configs = await ref
        .read(sitesNotifierProvider.notifier)
        .getConfigs(widget.site);
    _controller.text = configs[_selectedType] ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    await ref
        .read(sitesNotifierProvider.notifier)
        .saveConfig(widget.site, _selectedType, _controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config saved successfully')),
      );
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
              for (var i = 0; i < siteConfigEditorOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildTypeButton(
                  siteConfigEditorOptions[i].id,
                  siteConfigEditorOptions[i].label,
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(LucideIcons.save, size: 14),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
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
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontFamily: 'monospace',
                        fontSize: 12,
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

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedType = type);
        _loadConfig();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        .read(sitesNotifierProvider.notifier)
        .getSslFiles(widget.site);
    _controller.text = files[_selectedFile] ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveSslFile() async {
    await ref
        .read(sitesNotifierProvider.notifier)
        .saveSslFile(widget.site, _selectedFile, _controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SSL file saved successfully')),
      );
    }
  }

  Future<void> _regenerate() async {
    await ref.read(sitesNotifierProvider.notifier).regenerateSsl(widget.site);
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
              _buildTypeButton('cert', 'Certificate (cert.pem)'),
              const SizedBox(width: 8),
              _buildTypeButton('key', 'Private Key (key.pem)'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _regenerate,
                icon: const Icon(LucideIcons.refreshCcw, size: 14),
                label: const Text('Regenerate SSL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saveSslFile,
                icon: const Icon(LucideIcons.save, size: 14),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
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
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontFamily: 'monospace',
                        fontSize: 12,
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

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _selectedFile == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedFile = type);
        _loadSslFiles();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
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
        .read(sitesNotifierProvider.notifier)
        .getLogs(widget.site);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLogSelect(),
              const Spacer(),
              IconButton(
                onPressed: _refreshLogs,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _logs[_selectedLog] ?? 'No log data',
                  style: const TextStyle(
                    color: Color(0xFF00FF00),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSelect() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: siteLogOptions.map((item) {
          final isSelected = _selectedLog == item.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.label),
              selected: isSelected,
              onSelected: (value) {
                if (value) setState(() => _selectedLog = item.id);
              },
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
