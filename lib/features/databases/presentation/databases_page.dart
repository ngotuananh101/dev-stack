import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/features/databases/data/databases_provider.dart';
import 'package:dev_stack/features/apps/data/apps_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:dev_stack/features/databases/domain/database_record.dart';
import 'widgets/database_table.dart';
import 'widgets/redis_explorer.dart';
import '../data/redis_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../apps/presentation/widgets/compact_pagination.dart';

class DatabasesPage extends ConsumerStatefulWidget {
  const DatabasesPage({super.key});

  @override
  ConsumerState<DatabasesPage> createState() => _DatabasesPageState();
}

class _DatabasesPageState extends ConsumerState<DatabasesPage> {
  AppModel? selectedEngine;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Redis specific state
  int _selectedRedisDb = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1;
      });
    });
  }

  void _refreshDatabases() {
    if (selectedEngine != null) {
      if (selectedEngine!.appId.contains('redis')) {
        ref
            .read(redisNotifierProvider.notifier)
            .fetchKeys(selectedEngine!, _selectedRedisDb, query: _searchQuery);
      } else {
        ref
            .read(databasesNotifierProvider.notifier)
            .fetchByEngine(selectedEngine!.appId);
      }
    }
  }

  List<DatabaseRecord> _paginateDatabases(List<DatabaseRecord> dbs) {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, dbs.length);
    if (start >= dbs.length) return [];
    return dbs.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final enginesAsync = ref.watch(installedDatabaseEnginesProvider);
    final databasesAsync = ref.watch(databasesNotifierProvider);
    final appsState = ref.watch(appsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: enginesAsync.when(
        data: (engines) {
          if (engines.isEmpty) return _buildEmptyState();

          if (selectedEngine == null) {
            selectedEngine = engines.first;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _refreshDatabases(),
            );
          } else if (appsState.hasValue) {
            selectedEngine = appsState.value!.firstWhere(
              (e) => e.appId == selectedEngine!.appId,
              orElse: () => engines.first,
            );
          }

          final isRedis = selectedEngine?.appId.contains('redis') ?? false;

          return Column(
            children: [
              _buildEngineTabs(engines),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActionHeader(isRedis),
                      const SizedBox(height: 16),
                      Expanded(
                        child: isRedis
                            ? RedisExplorer(
                                app: selectedEngine!,
                                searchQuery: _searchQuery,
                                selectedDb: _selectedRedisDb,
                                onDbChanged: (index) {
                                  setState(() => _selectedRedisDb = index);
                                },
                              )
                            : databasesAsync.when(
                                data: (dbs) {
                                  final filtered = dbs
                                      .where(
                                        (d) => d.name.toLowerCase().contains(
                                          _searchQuery,
                                        ),
                                      )
                                      .toList();
                                  final paginated = _paginateDatabases(
                                    filtered,
                                  );
                                  final totalPages = filtered.isEmpty
                                      ? 1
                                      : (filtered.length / _itemsPerPage)
                                            .ceil();
                                  final startItem = filtered.isEmpty
                                      ? 0
                                      : (_currentPage - 1) * _itemsPerPage + 1;
                                  final endItem = filtered.isEmpty
                                      ? 0
                                      : (_currentPage * _itemsPerPage).clamp(
                                          0,
                                          filtered.length,
                                        );

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: DatabaseTable(
                                          databases: paginated,
                                          engineId: selectedEngine?.appId ?? '',
                                          onDelete: (record) =>
                                              _handleDelete(record),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      CompactPagination(
                                        currentPage: _currentPage,
                                        totalPages: totalPages,
                                        startItem: startItem,
                                        endItem: endItem,
                                        totalItems: filtered.length,
                                        onPageChanged: (page) =>
                                            setState(() => _currentPage = page),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, s) =>
                                    Center(child: Text('Error: $e')),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _handleDelete(DatabaseRecord record) async {
    if (selectedEngine == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Database'),
        content: Text(
          'Are you sure you want to delete "${record.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(databasesNotifierProvider.notifier)
          .deleteDatabase(selectedEngine!, record);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.database, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No database engines installed',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go to Apps to install MySQL, MariaDB, or MongoDB',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineTabs(List<AppModel> engines) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: engines.length,
        itemBuilder: (context, index) {
          final engine = engines[index];
          final isSelected = selectedEngine?.appId == engine.appId;

          return InkWell(
            onTap: () {
              setState(() {
                selectedEngine = engine;
                _currentPage = 1;
              });
              _refreshDatabases();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                engine.name,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionHeader(bool isRedis) {
    return Row(
      children: [
        if (!isRedis) ...[
          _buildActionButton(
            'Add DB',
            LucideIcons.plus,
            color: AppColors.success,
            onTap: _showAddDatabaseDialog,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'phpMyAdmin',
            LucideIcons.externalLink,
            onTap: _launchPhpMyAdmin,
          ),
          const SizedBox(width: 12),
        ],
        if (isRedis) ...[
          _buildActionButton(
            'Add Key',
            LucideIcons.plus,
            color: AppColors.success,
            onTap: _showAddRedisKeyDialog,
          ),
          const SizedBox(width: 12),
        ],
        _buildActionButton(
          'Sync DB',
          LucideIcons.refreshCw,
          color: AppColors.accent,
          onTap: () {
            if (selectedEngine != null) {
              if (isRedis) {
                ref.invalidate(redisDbStatsProvider(selectedEngine!));
                ref
                    .read(redisNotifierProvider.notifier)
                    .fetchKeys(
                      selectedEngine!,
                      _selectedRedisDb,
                      query: _searchQuery,
                    );
              } else {
                ref
                    .read(databasesNotifierProvider.notifier)
                    .syncDatabases(selectedEngine!);
              }
            }
          },
        ),
        if (isRedis) ...[
          const SizedBox(width: 12),
          _buildActionButton(
            'Clear DB',
            LucideIcons.trash2,
            color: AppColors.error,
            onTap: _handleClearRedisDb,
          ),
        ],
        const SizedBox(width: 12),
        _buildServiceStatusButton(),
        const Spacer(),
        _buildSearchField(isRedis),
      ],
    );
  }

  void _handleClearRedisDb() async {
    if (selectedEngine == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Redis DB'),
        content: Text(
          'Are you sure you want to clear all keys in DB$_selectedRedisDb?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(redisNotifierProvider.notifier)
          .clearDb(selectedEngine!, _selectedRedisDb);
      ref.invalidate(redisDbStatsProvider(selectedEngine!));
    }
  }

  Widget _buildServiceStatusButton() {
    if (selectedEngine == null) return const SizedBox.shrink();

    final status = selectedEngine!.serviceStatus;
    final isRunning = status == 'running';
    final version = selectedEngine!.installedVersion ?? "N/A";

    return PopupMenuButton<String>(
      tooltip: 'Service Control',
      offset: const Offset(0, 40),
      onSelected: (value) async {
        if (value == 'start') {
          await ref
              .read(appsNotifierProvider.notifier)
              .startService(selectedEngine!);
        } else if (value == 'stop') {
          await ref
              .read(appsNotifierProvider.notifier)
              .stopService(selectedEngine!);
        } else if (value == 'restart') {
          await ref
              .read(appsNotifierProvider.notifier)
              .restartService(selectedEngine!);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            'Version: $version',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const PopupMenuDivider(),
        if (!isRunning)
          const PopupMenuItem(
            value: 'start',
            child: Row(
              children: [
                Icon(LucideIcons.play, size: 14, color: AppColors.success),
                SizedBox(width: 8),
                Text('Start Service'),
              ],
            ),
          ),
        if (isRunning) ...[
          const PopupMenuItem(
            value: 'stop',
            child: Row(
              children: [
                Icon(LucideIcons.square, size: 14, color: AppColors.error),
                SizedBox(width: 8),
                Text('Stop Service'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'restart',
            child: Row(
              children: [
                Icon(LucideIcons.refreshCw, size: 14, color: AppColors.accent),
                SizedBox(width: 8),
                Text('Restart Service'),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isRunning ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              version,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.surfaceLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSearchField(bool isRedis) {
    return SizedBox(
      width: 280,
      height: 36,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: isRedis ? 'Search key' : 'Database search',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          prefixIcon: const Icon(
            LucideIcons.search,
            size: 14,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  void _launchPhpMyAdmin() async {
    final url = Uri.parse('http://localhost/phpmyadmin/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showAddRedisKeyDialog() {
    if (selectedEngine == null) return;

    final keyController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Add Key (DB$_selectedRedisDb)',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Key Name', keyController),
            const SizedBox(height: 12),
            _buildDialogField('Value (String)', valueController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = keyController.text.trim();
              if (key.isNotEmpty) {
                await ref
                    .read(redisNotifierProvider.notifier)
                    .setKey(
                      selectedEngine!,
                      _selectedRedisDb,
                      key,
                      valueController.text,
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddDatabaseDialog() {
    if (selectedEngine == null) return;

    final nameController = TextEditingController();
    final userController = TextEditingController(text: 'root');
    final passController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Add New Database',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Database Name', nameController),
            const SizedBox(height: 12),
            _buildDialogField('Username', userController),
            const SizedBox(height: 12),
            _buildDialogField('Password', passController, isPassword: true),
            const SizedBox(height: 12),
            _buildDialogField('Note', noteController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref
                    .read(databasesNotifierProvider.notifier)
                    .addDatabase(
                      app: selectedEngine!,
                      name: name,
                      user: userController.text,
                      password: passController.text,
                      note: noteController.text,
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
