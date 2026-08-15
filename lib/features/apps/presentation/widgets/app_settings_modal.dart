import 'dart:async';
import 'dart:io';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'package:dev_stack/shared/widgets/code_editor/config_code_editor.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/log_service.dart';
import '../../domain/app_model.dart';
import '../../data/php_settings_provider.dart';
import '../../data/apps_provider.dart';
import '../../data/webserver_settings_provider.dart';

class AppSettingsModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onClose;

  const AppSettingsModal({super.key, required this.app, required this.onClose});

  @override
  ConsumerState<AppSettingsModal> createState() => _AppSettingsModalState();
}

class _AppSettingsModalState extends ConsumerState<AppSettingsModal>
    with SingleTickerProviderStateMixin {
  // ─── Controllers ─────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ─── State ────────────────────────────────────────────────────────────────────
  List<PhpExtension> _extensions = [];
  String _searchQuery = '';

  // Lazy loading flags
  bool _isConfigLoaded = false;
  bool _isExtensionsLoaded = false;
  bool _isConfigLoading = false;
  bool _isExtensionsLoading = false;

  // ─── App type getters ─────────────────────────────────────────────────────────
  bool get _isPma => widget.app.appId.toLowerCase() == 'phpmyadmin';

  bool get _isPhp =>
      (widget.app.groupName == 'php' || widget.app.appId.startsWith('php')) &&
      !_isPma;

  bool get _isDb =>
      widget.app.groupName == 'mysql' ||
      widget.app.groupName == 'mariadb' ||
      widget.app.groupName == 'postgresql' ||
      widget.app.appId.toLowerCase().contains('mysql') ||
      widget.app.appId.toLowerCase().contains('mariadb') ||
      widget.app.appId.toLowerCase().contains('postgresql') ||
      _isPma;

  bool get _isWebserver =>
      widget.app.groupName == 'webserver' ||
      widget.app.appId.toLowerCase().contains('nginx') ||
      widget.app.appId.toLowerCase().contains('apache') ||
      widget.app.appId.toLowerCase().contains('caddy');

  bool get _isRedis =>
      widget.app.groupName == 'redis' ||
      widget.app.appId.toLowerCase().contains('redis');

  bool get _isMongodb => widget.app.appId == 'mongodb';

  bool get _isPostgresql =>
      widget.app.groupName == 'postgresql' ||
      widget.app.appId.toLowerCase().contains('postgresql');

  bool get _isRustFS => widget.app.appId == 'rustfs';

  bool get _isMeilisearch => widget.app.appId == 'meilisearch';
  bool get _isElasticsearch => widget.app.appId == 'elasticsearch';

  bool get _hasConfigTab =>
      _isPhp ||
      _isDb ||
      _isWebserver ||
      _isRedis ||
      _isMongodb ||
      _isPostgresql ||
      _isRustFS ||
      _isMeilisearch ||
      _isElasticsearch;

  int get _tabCount {
    if (_isPma) {
      return 2;
    }
    if (_isPhp) {
      return 3;
    }
    if (_isDb ||
        _isWebserver ||
        _isRedis ||
        _isMongodb ||
        _isRustFS ||
        _isMeilisearch ||
        _isElasticsearch) {
      return 2;
    }
    return 1;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Tab handling ─────────────────────────────────────────────────────────────
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;

    if (index == 1 && _hasConfigTab && !_isConfigLoaded && !_isConfigLoading) {
      _loadConfig();
    }

    if (index == 2 && _isPhp && !_isExtensionsLoaded && !_isExtensionsLoading) {
      _loadExtensions();
    }
  }

  // ─── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadConfig() async {
    if (_isConfigLoading) return;
    setState(() => _isConfigLoading = true);

    // Just mark config as loaded (file existence checked when opening NPP)
    if (mounted) {
      setState(() {
        _isConfigLoaded = true;
        _isConfigLoading = false;
      });
    }
  }

  Future<void> _loadExtensions() async {
    if (_isExtensionsLoading) return;
    setState(() => _isExtensionsLoading = true);

    final exts = await ref
        .read(phpSettingsProvider.notifier)
        .getExtensions(widget.app);

    if (mounted) {
      setState(() {
        _extensions = exts;
        _isExtensionsLoaded = true;
        _isExtensionsLoading = false;
      });
    }
  }

  // ─── Config file path resolution ──────────────────────────────────────────────
  String? _getConfigFilePath() {
    final app = widget.app;
    if (app.location == null) return null;
    final location = app.location!;

    if (_isPhp) return p.join(location, 'php.ini');

    if (_isDb) {
      if (_isPma) return p.join(location, 'config.inc.php');

      final isMariaDb =
          app.groupName == 'mariadb' ||
          app.appId.toLowerCase().contains('mariadb');
      if (isMariaDb || app.appId.toLowerCase().contains('mysql')) {
        final version = app.installedVersion ?? 'unknown';
        final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
        return p.join(dataDir, 'my.ini');
      }

      if (_isPostgresql) {
        final version = app.installedVersion ?? 'unknown';
        final dataDir = p.join(AppConfig.dataDir, '${app.appId}-$version');
        return p.join(dataDir, 'postgresql.conf');
      }

      return p.join(location, 'my.ini');
    }

    if (_isWebserver) return webserverConfigFileFor(app)?.path;

    if (_isRedis) {
      final winPath = p.join(location, 'redis.windows.conf');
      if (File(winPath).existsSync()) return winPath;
      return p.join(location, 'redis.conf');
    }

    if (_isMongodb) {
      final binPath = p.join(location, 'bin', 'mongod.cfg');
      if (File(binPath).existsSync()) return binPath;
      final rootPath = p.join(location, 'mongod.cfg');
      if (File(rootPath).existsSync()) return rootPath;
      return p.join(location, 'mongod.conf');
    }

    if (_isRustFS) return p.join(AppConfig.dataDir, 'rustfs', 'config.json');
    if (_isMeilisearch) return p.join(location, 'config.toml');
    if (_isElasticsearch) {
      return p.join(location, 'config', 'elasticsearch.yml');
    }

    return null;
  }

  // ─── Save config file ────────────────────────────────────────────────────────
  /// Persists the edited config content directly to the resolved config file.
  /// These are arbitrary user-authored config files (php.ini, nginx.conf,
  /// mongod.cfg, ...); there is no domain to validate, so the content is
  /// written verbatim — mirroring the per-app *_settings_provider.saveConfig
  /// pattern.
  Future<bool> _saveConfigFile(String content) async {
    final path = _getConfigFilePath();
    if (path == null) {
      AppLogger.warning(
        'Cannot save config: path not resolved for ${widget.app.appId}',
      );
      return false;
    }
    try {
      await File(path).writeAsString(content);
      AppLogger.info('Saved config: $path');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save config $path: $e');
      return false;
    }
  }

  // ─── Toggle extension ─────────────────────────────────────────────────────────
  Future<void> _toggleExtension(PhpExtension ext, bool value) async {
    await ref
        .read(phpSettingsProvider.notifier)
        .toggleExtension(widget.app, ext, value);
    _isExtensionsLoaded = false;
    await _loadExtensions();
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
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
            child: TabBarView(
              controller: _tabController,
              children: [
                KeepAliveWrapper(child: _buildServiceTab()),
                if (_hasConfigTab) KeepAliveWrapper(child: _buildConfigTab()),
                if (_isPhp) KeepAliveWrapper(child: _buildExtensionsTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────
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
          if (_hasConfigTab)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.edit_note, size: 14),
                label: const Text('Edit Config'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
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
          if (widget.app.serviceStatus == 'running')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Route through AppsNotifier so service status changes
                  // notify the apps table/provider, not only AppServiceManager.
                  await ref
                      .read(appsNotifierProvider.notifier)
                      .restartService(widget.app);
                  if (mounted) {
                    setState(() {});
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

  // ─── Tab bar ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Service'),
                ],
              ),
            ),
            if (_hasConfigTab)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(_configTabLabel),
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
        ),
      ),
    );
  }

  String get _configTabLabel {
    if (_isPma) return 'config.inc.php';
    if (_isPostgresql) return 'postgresql.conf';
    if (_isDb) return 'my.ini';
    if (_isWebserver) {
      final id = widget.app.appId.toLowerCase();
      if (id.contains('caddy')) return 'Caddyfile';
      if (id.contains('nginx')) return 'nginx.conf';
      return 'httpd.conf';
    }
    if (_isRedis) return 'redis.conf';
    if (_isMongodb) return 'mongod.cfg';
    if (_isRustFS) return 'Configuration';
    if (_isMeilisearch) return 'config.toml';
    if (_isElasticsearch) return 'elasticsearch.yml';
    return 'php.ini';
  }

  // ─── Service tab ──────────────────────────────────────────────────────────────
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
              'CLI File Path',
              widget.app.cliFilePath ?? 'Not found',
            ),
            _buildInfoRow(
              Icons.javascript_outlined,
              'Executable File Path',
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
          if (widget.app.defaultUsername != null) ...[
            const SizedBox(height: 24),
            _buildInfoSection('Default Credentials', [
              _buildCredentialRow(
                LucideIcons.user,
                'Username',
                widget.app.defaultUsername!,
              ),
              if (widget.app.defaultPassword != null)
                _buildCredentialRow(
                  LucideIcons.key,
                  'Password',
                  widget.app.defaultPassword!,
                  isPassword: true,
                ),
            ]),
          ],
          if (_isPhp) ...[
            const SizedBox(height: 24),
            _buildInfoSection('Startup Configuration', [
              _buildSettingField(
                'Bind Address',
                'bind_address',
                widget.app.extraInfo['bind_address']?.toString() ?? '127.0.0.1',
                (val) async {
                  final newInfo = Map<String, dynamic>.from(
                    widget.app.extraInfo,
                  );
                  newInfo['bind_address'] = val;
                  widget.app.extraInfo = newInfo;
                  final repo = await ref.read(appsRepositoryProvider.future);
                  await repo.save(widget.app);
                  ref.invalidate(appsNotifierProvider);
                },
              ),
              _buildSettingField(
                'Port',
                'port',
                widget.app.extraInfo['port']?.toString() ?? '',
                (val) async {
                  final newInfo = Map<String, dynamic>.from(
                    widget.app.extraInfo,
                  );
                  newInfo['port'] = val;
                  widget.app.extraInfo = newInfo;
                  final repo = await ref.read(appsRepositoryProvider.future);
                  await repo.save(widget.app);
                  ref.invalidate(appsNotifierProvider);
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Note: Changing the port may require reconfiguration of Nginx/Apache.',
                  style: TextStyle(
                    fontSize: AppTextSize.xxs,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ]),
          ],
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

  // ─── Config tab ───────────────────────────────────────────────────────────────
  Widget _buildConfigTab() {
    final configPath = _getConfigFilePath();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _configTabLabel,
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (configPath != null)
            Expanded(
              child: ConfigCodeEditor(
                filePath: configPath,
                onSave: _saveConfigFile,
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text(
                  'Config file path not found for this app.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Extensions tab ───────────────────────────────────────────────────────────
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
                      return _buildExtensionCard(filteredExtensions[index]);
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

  Widget _buildCredentialRow(
    IconData icon,
    String label,
    String value, {
    bool isPassword = false,
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
        _buildCredentialChip(context, icon, value, isPassword: isPassword),
      ],
    );
  }

  Widget _buildCredentialChip(
    BuildContext context,
    IconData icon,
    String value, {
    bool isPassword = false,
  }) {
    final displayValue = isPassword && value.isEmpty ? '(empty)' : value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (value.isNotEmpty) {
            AppDialogs.showToast(context, 'Copied: $value');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.copy,
                size: 12,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingField(
    String label,
    String key,
    String value,
    Function(String) onChanged, {
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.xxs,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('$key-$value'),
            initialValue: value,
            onChanged: onChanged,
            obscureText: obscureText,
            style: const TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KeepAliveWrapper ─────────────────────────────────────────────────────────
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
