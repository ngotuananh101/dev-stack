import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import '../../data/php_settings_provider.dart';
import '../../data/app_service_manager.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/properties.dart';

class AppSettingsModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onClose;

  const AppSettingsModal({
    super.key,
    required this.app,
    required this.onClose,
  });

  @override
  ConsumerState<AppSettingsModal> createState() => _AppSettingsModalState();
}

class _AppSettingsModalState extends ConsumerState<AppSettingsModal> {
  CodeController? _codeController;
  bool _isLoading = true;
  List<PhpExtension> _extensions = [];
  String _searchQuery = '';

  @override
  void dispose() {
    _codeController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = ref.read(phpSettingsProvider.notifier);
    
    final content = await provider.readPhpIni(widget.app);
    if (_codeController == null) {
      _codeController = CodeController(text: content, language: properties);
    } else {
      _codeController!.text = content;
    }
    
    _extensions = await provider.getExtensions(widget.app);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (_codeController == null) return;
    setState(() => _isLoading = true);
    await ref.read(phpSettingsProvider.notifier).savePhpIni(widget.app, _codeController!.text);
    await _loadData();
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
    await ref.read(phpSettingsProvider.notifier).toggleExtension(widget.app, ext, value);
    await _loadData();
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
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildConfigTab(),
                        _buildExtensionsTab(),
                      ],
                    ),
            ),
            _buildFooter(),
          ],
        ),
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
            child: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 20),
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
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16),
                SizedBox(width: 8),
                Text('Configuration'),
              ],
            ),
          ),
          Tab(
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
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTextSize.xs),
      ),
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
              const Icon(Icons.description_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'php.ini',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
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
                    controller: _codeController!,
                    textStyle: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: AppTextSize.xs,
                      height: 1.5,
                    ),
                  ),
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
            style: const TextStyle(fontSize: AppTextSize.xs, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search extensions (e.g. mbstring, curl, gd)...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                borderSide: const BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filteredExtensions.isEmpty
                ? _buildEmptyExtensions()
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    color: ext.isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Text(
                  ext.isZend ? 'Zend Extension' : 'Standard extension',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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

  Widget _buildFooter() {
    final isRunning = widget.app.serviceStatus == 'running';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (isRunning) ...[
            const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text(
              'A restart is required to apply changes to the running service.',
              style: TextStyle(fontSize: AppTextSize.xxs, color: AppColors.textSecondary),
            ),
            const Spacer(),
            OutlinedButton.icon(
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
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Restart Service'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            const Spacer(),
            TextButton(
              onPressed: widget.onClose,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Close Settings'),
            ),
          ],
        ],
      ),
    );
  }
}
