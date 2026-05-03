import 'dart:convert';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import '../../data/php_settings_provider.dart';
import '../../data/db_settings_provider.dart';
import '../../data/webserver_settings_provider.dart';
import '../../data/redis_settings_provider.dart';
import '../../data/mongodb_settings_provider.dart';
import '../../data/rustfs_settings_provider.dart';
import '../../data/meilisearch_settings_provider.dart';
import '../../data/elasticsearch_settings_provider.dart';
import '../../data/app_service_manager.dart';
import '../../data/apps_provider.dart';
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
  // ─── Constants ───────────────────────────────────────────────────────────────
  static const int _codeEditorLineThreshold = 500;

  // ─── Controllers ─────────────────────────────────────────────────────────────
  late TabController _tabController;
  CodeController? _codeController;
  final TextEditingController _fallbackController = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────────
  String? _iniContent;
  bool _isEditorReady = false;
  bool _useCodeEditor = false;
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
      widget.app.appId.toLowerCase().contains('apache');

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
    // ✅ Không preload config ở đây — Service tab hiển thị tức thì
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController?.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  // ─── Tab handling ─────────────────────────────────────────────────────────────
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;

    // ✅ Lazy load config chỉ khi user thực sự vào tab Config
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

    String content = '';
    if (_isPhp) {
      content = await ref
          .read(phpSettingsProvider.notifier)
          .readPhpIni(widget.app);
    } else if (_isDb) {
      content = await ref
          .read(dbSettingsProvider.notifier)
          .readConfig(widget.app);
    } else if (_isWebserver) {
      content = await ref
          .read(webserverSettingsProvider.notifier)
          .readConfig(widget.app);
    } else if (_isRedis) {
      content = await ref
          .read(redisSettingsProvider.notifier)
          .readConfig(widget.app);
    } else if (_isMongodb) {
      content = await ref
          .read(mongodbSettingsProvider.notifier)
          .readConfig(widget.app);
    } else if (_isRustFS) {
      final config = await ref
          .read(rustFSSettingsProvider.notifier)
          .readConfig();
      content = json.encode(config);
    } else if (_isMeilisearch) {
      final config = await ref
          .read(meilisearchSettingsProvider.notifier)
          .readConfig(widget.app);
      content = json.encode(config);
    } else if (_isElasticsearch) {
      final config = await ref
          .read(elasticsearchSettingsProvider.notifier)
          .readConfig(widget.app);
      content = json.encode(config);
    }

    if (!mounted) return;

    // ✅ Đếm dòng để quyết định dùng CodeEditor hay TextField
    final lineCount = '\n'.allMatches(content).length;
    final useCodeEditor = lineCount <= _codeEditorLineThreshold;

    setState(() {
      _iniContent = content;
      _fallbackController.text = content;
      _isConfigLoaded = true;
      _isConfigLoading = false;
      _useCodeEditor = useCodeEditor;
      // Reset editor state khi load lại
      _isEditorReady = false;
      _codeController?.dispose();
      _codeController = null;
    });

    if (_useCodeEditor) {
      _initCodeControllerLazily();
    }
  }

  Future<void> _loadExtensions() async {
    if (_isExtensionsLoading) return;
    setState(() => _isExtensionsLoading = true);

    final content =
        _iniContent ??
        await ref.read(phpSettingsProvider.notifier).readPhpIni(widget.app);

    final exts = await ref
        .read(phpSettingsProvider.notifier)
        .getExtensions(widget.app, content);

    if (mounted) {
      setState(() {
        _extensions = exts;
        _isExtensionsLoaded = true;
        _isExtensionsLoading = false;
      });
    }
  }

  // ─── Editor init ──────────────────────────────────────────────────────────────
  void _initCodeControllerLazily() {
    // Delay nhỏ để frame hiện tại (loading indicator) render xong trước
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _iniContent == null) return;

      // ✅ Gộp tạo controller + apply language trong 1 bước, 1 setState duy nhất
      // File nhỏ (≤ 500 dòng) nên highlight không gây jank đáng kể
      final controller = CodeController(
        text: _iniContent!,
        language: properties,
      );

      if (mounted) {
        setState(() {
          _codeController = controller;
          _isEditorReady = true;
        });
      }
    });
  }

  // ─── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _saveConfig() async {
    // Use _iniContent directly for UI-based configs (Meilisearch, RustFS, Elasticsearch)
    final text = (_isMeilisearch || _isRustFS || _isElasticsearch)
        ? (_iniContent ?? '')
        : (_useCodeEditor && _codeController != null
              ? _codeController!.text
              : _fallbackController.text);

    if (_isPhp) {
      await ref.read(phpSettingsProvider.notifier).savePhpIni(widget.app, text);
    } else if (_isDb) {
      await ref.read(dbSettingsProvider.notifier).saveConfig(widget.app, text);
    } else if (_isWebserver) {
      await ref
          .read(webserverSettingsProvider.notifier)
          .saveConfig(widget.app, text);
    } else if (_isRedis) {
      await ref
          .read(redisSettingsProvider.notifier)
          .saveConfig(widget.app, text);
    } else if (_isMongodb) {
      await ref
          .read(mongodbSettingsProvider.notifier)
          .saveConfig(widget.app, text);
    } else if (_isRustFS) {
      final config = json.decode(text);
      await ref.read(rustFSSettingsProvider.notifier).saveConfig(config);
    } else if (_isMeilisearch) {
      final config = json.decode(text);
      await ref
          .read(meilisearchSettingsProvider.notifier)
          .saveConfig(widget.app, config);
    } else if (_isElasticsearch) {
      final config = json.decode(text);
      await ref
          .read(elasticsearchSettingsProvider.notifier)
          .saveConfig(widget.app, config);
    }

    // Force reload sau khi save
    _isConfigLoaded = false;
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

  /// Label cho config tab — tách ra để dùng ở cả TabBar lẫn ConfigTab header
  String get _configTabLabel {
    if (_isPma) return 'config.inc.php';
    if (_isPostgresql) return 'postgresql.conf';
    if (_isDb) return 'my.ini';
    if (_isWebserver) {
      return widget.app.appId.contains('nginx') ? 'nginx.conf' : 'httpd.conf';
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
                widget.app.extraInfo['bind_address']?.toString() ?? '0.0.0.0',
                (val) async {
                  final newInfo = Map<String, dynamic>.from(widget.app.extraInfo);
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
                  final newInfo = Map<String, dynamic>.from(widget.app.extraInfo);
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigTabHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: _isRustFS
                ? _buildRustFSConfig()
                : _isMeilisearch
                ? _buildMeilisearchConfig()
                : _isElasticsearch
                ? _buildElasticsearchConfig()
                : _buildConfigEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildRustFSConfig() {
    if (!_isConfigLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final config = json.decode(_iniContent ?? '{}');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigGroup('Networking', [
            _buildSettingField(
              'API Address',
              'address',
              config['address'] ?? ':9000',
              (val) {
                config['address'] = val;
                _iniContent = json.encode(config);
              },
            ),
            _buildSettingField(
              'Console Address',
              'console_address',
              config['console_address'] ?? ':9001',
              (val) {
                config['console_address'] = val;
                _iniContent = json.encode(config);
              },
            ),
            SwitchListTile(
              title: const Text(
                'Enable Console',
                style: TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textPrimary,
                ),
              ),
              value: config['console_enable'] ?? true,
              onChanged: (val) {
                setState(() {
                  config['console_enable'] = val;
                  _iniContent = json.encode(config);
                });
              },
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ]),
          const SizedBox(height: 24),
          _buildConfigGroup('Security', [
            _buildSettingField(
              'Access Key',
              'access_key',
              config['access_key'] ?? 'rustfsadmin',
              (val) {
                config['access_key'] = val;
                _iniContent = json.encode(config);
              },
            ),
            _buildSettingField(
              'Secret Key',
              'secret_key',
              config['secret_key'] ?? 'rustfsadmin',
              (val) {
                config['secret_key'] = val;
                _iniContent = json.encode(config);
              },
              obscureText: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMeilisearchConfig() {
    if (!_isConfigLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final config = json.decode(_iniContent ?? '{}');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigGroup('Server Settings', [
            _buildSettingField(
              'HTTP Address',
              'http_addr',
              config['http_addr'] ?? '127.0.0.1:7700',
              (val) {
                config['http_addr'] = val;
                _iniContent = json.encode(config);
              },
            ),
            _buildSettingField(
              'Master Key',
              'master_key',
              config['master_key'] ?? '',
              (val) {
                config['master_key'] = val;
                _iniContent = json.encode(config);
              },
              obscureText: true,
            ),
            _buildSettingField(
              'Database Path',
              'db_path',
              config['db_path'] ?? '',
              (val) {
                config['db_path'] = val;
                _iniContent = json.encode(config);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildConfigGroup('Advanced', [
            _buildDropdownField(
              'Environment',
              'env',
              config['env'] ?? 'development',
              ['development', 'production'],
              (val) {
                if (val != null) {
                  config['env'] = val;
                  _iniContent = json.encode(config);
                }
              },
            ),
            SwitchListTile(
              title: const Text(
                'Disable Analytics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.sm,
                ),
              ),
              subtitle: const Text(
                'Prevent Meilisearch from sending usage data',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xxs,
                ),
              ),
              value: config['no_analytics'] ?? true,
              onChanged: (val) {
                setState(() {
                  config['no_analytics'] = val;
                  _iniContent = json.encode(config);
                });
              },
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildElasticsearchConfig() {
    if (!_isConfigLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final config = json.decode(_iniContent ?? '{}');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigGroup('Cluster Settings', [
            _buildSettingField(
              'Cluster Name',
              'cluster.name',
              config['cluster.name'] ?? 'ponta-cluster',
              (val) {
                config['cluster.name'] = val;
                _iniContent = json.encode(config);
              },
            ),
            _buildSettingField(
              'Node Name',
              'node.name',
              config['node.name'] ?? 'ponta-node-1',
              (val) {
                config['node.name'] = val;
                _iniContent = json.encode(config);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildConfigGroup('Network Settings', [
            _buildSettingField(
              'HTTP Address',
              'network.host',
              config['network.host'] ?? '127.0.0.1',
              (val) {
                config['network.host'] = val;
                _iniContent = json.encode(config);
              },
            ),
            _buildSettingField(
              'HTTP Port',
              'http.port',
              (config['http.port'] ?? 9200).toString(),
              (val) {
                config['http.port'] = int.tryParse(val) ?? 9200;
                _iniContent = json.encode(config);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildConfigGroup('Security & Features', [
            SwitchListTile(
              title: const Text(
                'Enable X-Pack Security',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.sm,
                ),
              ),
              subtitle: const Text(
                'Requires authentication for all requests',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xxs,
                ),
              ),
              value: config['xpack.security.enabled'] ?? false,
              onChanged: (val) {
                setState(() {
                  config['xpack.security.enabled'] = val;
                  _iniContent = json.encode(config);
                });
              },
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            ),
            SwitchListTile(
              title: const Text(
                'Enable GeoIP Downloader',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.sm,
                ),
              ),
              subtitle: const Text(
                'Automatically update GeoIP databases',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xxs,
                ),
              ),
              value: config['ingest.geoip.downloader.enabled'] ?? false,
              onChanged: (val) {
                setState(() {
                  config['ingest.geoip.downloader.enabled'] = val;
                  _iniContent = json.encode(config);
                });
              },
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildConfigGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
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
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (val) {
              onChanged(val);
            },
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value.length),
            obscureText: obscureText,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
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

  Widget _buildDropdownField(
    String label,
    String key,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surfaceLight,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
                items: options.map((String val) {
                  return DropdownMenuItem<String>(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    onChanged(val);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTabHeader() {
    return Row(
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
        // ✅ Badge thông báo nếu file quá lớn để dùng syntax highlight
        if (_isConfigLoaded && !_useCodeEditor) ...[
          const SizedBox(width: 8),
          Tooltip(
            message:
                'File has more than $_codeEditorLineThreshold lines.\n'
                'Using plain text editor for better performance.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    size: 10,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Performance mode',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Spacer(),
        if (_isConfigLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_isConfigLoaded)
          ElevatedButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfigEditor() {
    // ✅ State 1: Đang load
    if (_isConfigLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ State 2: Chưa load (user chưa vào tab này lần nào — không xảy ra vì
    //    _handleTabSelection đã trigger _loadConfig, nhưng guard phòng hờ)
    if (!_isConfigLoaded) {
      return const Center(
        child: Text(
          'Loading configuration...',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildEditorContent(),
    );
  }

  Widget _buildEditorContent() {
    // ✅ File lớn: dùng TextField — render tức thì, không jank
    if (!_useCodeEditor) {
      return TextField(
        controller: _fallbackController,
        maxLines: null,
        expands: true,
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
      );
    }

    // ✅ File nhỏ: chờ CodeController khởi tạo xong (150ms delay)
    if (!_isEditorReady || _codeController == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // ✅ CodeEditor với syntax highlight
    return CodeTheme(
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
            Clipboard.setData(ClipboardData(text: value));
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
