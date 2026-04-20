import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import '../../data/php_settings_provider.dart';
import '../../data/db_settings_provider.dart';
import '../../data/app_service_manager.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/properties.dart';

class AppSettingsModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onClose;

  const AppSettingsModal({super.key, required this.app, required this.onClose});

  @override
  ConsumerState<AppSettingsModal> createState() => _AppSettingsModalState();
}

class _AppSettingsModalState extends ConsumerState<AppSettingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CodeController? _codeController;
  final TextEditingController _fallbackController = TextEditingController();
  String? _iniContent;
  bool _isLoading = true;
  bool _isEditorReady = false;
  bool _useCodeEditor = false;
  List<PhpExtension> _extensions = [];
  String _searchQuery = '';
  
  // Lazy loading flags
  bool _isConfigLoaded = false;
  bool _isExtensionsLoaded = false;
  bool _isConfigLoading = false;
  bool _isExtensionsLoading = false;

  bool get _isPhp =>
      widget.app.groupName == 'php' || widget.app.appId.startsWith('php');
  bool get _isDb =>
      widget.app.groupName == 'mysql' ||
      widget.app.groupName == 'mariadb' ||
      widget.app.appId.toLowerCase().contains('mysql') ||
      widget.app.appId.toLowerCase().contains('mariadb');

  @override
  void initState() {
    super.initState();
    int tabLength = 1;
    if (_isPhp) {
      tabLength = 3;
    } else if (_isDb) {
      tabLength = 2;
    } else {
      tabLength = 1; // Default for others (Show only service tab)
    }

    _tabController = TabController(length: tabLength, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Set loading to false immediately to show Service tab info instantly
    _isLoading = false;
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    
    final index = _tabController.index;
    if (index == 1 && (_isPhp || _isDb) && !_isConfigLoaded) {
      _loadConfig();
    } else if (index == 2 && _isPhp && !_isExtensionsLoaded) {
      _loadExtensions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController?.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    if (_isConfigLoading) return;
    setState(() => _isConfigLoading = true);
    
    String content = '';
    if (_isPhp) {
      content = await ref.read(phpSettingsProvider.notifier).readPhpIni(widget.app);
    } else if (_isDb) {
      content = await ref.read(dbSettingsProvider.notifier).readConfig(widget.app);
    }

    if (mounted) {
      setState(() {
        _iniContent = content;
        _fallbackController.text = content;
        _isConfigLoaded = true;
        _isConfigLoading = false;
        
        // Use CodeEditor for all configs to maintain consistent UI
        _useCodeEditor = true;
      });

      if (_useCodeEditor) {
        _initCodeControllerLazily();
      }
    }
  }

  Future<void> _loadExtensions() async {
    if (_isExtensionsLoading) return;
    setState(() => _isExtensionsLoading = true);
    
    final content = _iniContent ?? await ref.read(phpSettingsProvider.notifier).readPhpIni(widget.app);
    final exts = await ref.read(phpSettingsProvider.notifier).getExtensions(widget.app, content);

    if (mounted) {
      setState(() {
        _extensions = exts;
        _isExtensionsLoaded = true;
        _isExtensionsLoading = false;
      });
    }
  }



  void _initCodeControllerLazily() {
    // Wait for modal transition to finish completely
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _iniContent == null) return;

      // Step 1: Create controller WITHOUT language (much faster)
      final controller = CodeController(text: _iniContent!);
      if (mounted) {
        setState(() {
          _codeController = controller;
          _isEditorReady = true;
        });
      }

      // Step 2: Apply highlighting after another delay to avoid micro-stutter
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _codeController != null) {
          _codeController!.language = properties;
        }
      });
    });
  }

  Future<void> _saveConfig() async {
    final text = _useCodeEditor && _codeController != null
        ? _codeController!.text
        : _fallbackController.text;

    if (_isPhp) {
      await ref.read(phpSettingsProvider.notifier).savePhpIni(widget.app, text);
    } else if (_isDb) {
      await ref.read(dbSettingsProvider.notifier).saveConfig(widget.app, text);
    }

    _isConfigLoaded = false; // Force reload after save
    await _loadConfig();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _toggleExtension(PhpExtension ext, bool value) async {
    await ref
        .read(phpSettingsProvider.notifier)
        .toggleExtension(widget.app, ext, value);
    _isExtensionsLoaded = false;
    await _loadExtensions();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 700,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      KeepAliveWrapper(child: _buildServiceTab()),
                      if (_isPhp || _isDb) KeepAliveWrapper(child: _buildConfigTab()),
                      if (_isPhp) KeepAliveWrapper(child: _buildExtensionsTab()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.app.name} Settings',
                style: const TextStyle(
                  fontSize: AppTextSize.base,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Manage configuration and extensions',
                style: TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (widget.app.serviceStatus == 'running')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(appServiceManagerProvider).restart(widget.app);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Service restarted successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Restart'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            color: AppColors.textMuted,
            hoverColor: AppColors.error.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16),
                const SizedBox(width: 8),
                const Text('Service'),
              ],
            ),
          ),
          if (_isPhp || _isDb)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(_isDb ? 'my.ini' : 'Config'),
                ],
              ),
            ),
          if (_isPhp)
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.extension_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Extensions'),
                ],
              ),
            ),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: AppTextSize.xs,
        ),
      ),
    );
  }

  Widget _buildServiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection('Installation Details', [
            _buildInfoRow(
              Icons.folder_open,
              'Location',
              widget.app.location ?? 'Unknown',
            ),
            _buildInfoRow(
              Icons.new_releases_outlined,
              'Installed Version',
              widget.app.installedVersion ?? 'N/A',
            ),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Installed At',
              widget.app.installedAt != null
                  ? widget.app.installedAt.toString().split('.')[0]
                  : 'N/A',
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Executable Paths', [
            _buildInfoRow(
              Icons.terminal,
              'PHP CLI',
              widget.app.cliFilePath ?? 'Not found',
            ),
            _buildInfoRow(
              Icons.javascript_outlined,
              'PHP CGI',
              widget.app.execFilePath ?? 'Not found',
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('System Integration', [
            _buildInfoRow(
              widget.app.isAddedToPath
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              'PATH Environment',
              widget.app.isAddedToPath
                  ? 'Added to Windows PATH'
                  : 'Not added to PATH',
              valueColor: widget.app.isAddedToPath
                  ? AppColors.success
                  : AppColors.warning,
            ),
            _buildInfoRow(
              Icons.auto_mode,
              'Auto Start',
              widget.app.autoStartService ? 'Enabled' : 'Disabled',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children
                .expand(
                  (w) => [
                    w,
                    if (w != children.last)
                      const Divider(height: 24, color: AppColors.border),
                  ],
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTextSize.xxs,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTextSize.xxs,
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _isDb ? 'my.ini' : 'php.ini',
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_isConfigLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isConfigLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: !_useCodeEditor ||
                            !_isEditorReady ||
                            _codeController == null
                        ? TextField(
                            controller: _fallbackController,
                            maxLines: null,
                            expands: true,
                            readOnly: false,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: AppTextSize.xs,
                              color: Color(0xFFD4D4D4),
                              height: 1.5,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(20),
                              border: InputBorder.none,
                              hintText: 'Configuration content...',
                              hintStyle: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : CodeTheme(
                            data: CodeThemeData(styles: monokaiSublimeTheme),
                            child: CodeField(
                              controller: _codeController!,
                              textStyle: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: AppTextSize.xs,
                                height: 1.5,
                              ),
                              expands: true,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsTab() {
    final filteredExtensions = _extensions.where((ext) {
      return ext.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search extensions (e.g. mbstring, curl, gd)...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isExtensionsLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredExtensions.isEmpty
                    ? _buildEmptyExtensions()
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredExtensions.length,
                        itemBuilder: (context, index) {
                          final ext = filteredExtensions[index];
                          return _buildExtensionCard(ext);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionCard(PhpExtension ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ext.isEnabled
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
          width: ext.isEnabled ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ext.isZend ? Icons.bolt : Icons.extension_outlined,
            size: 20,
            color: ext.isEnabled ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ext.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTextSize.xs,
                    color: ext.isEnabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  ext.isZend ? 'Zend Extension' : 'Standard extension',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: ext.isEnabled,
              onChanged: (v) => _toggleExtension(ext, v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyExtensions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No extensions found matching "$_searchQuery"',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}
