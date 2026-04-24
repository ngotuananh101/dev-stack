import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/apps_provider.dart';
import '../domain/app_model.dart';
import '../../../shared/providers/error_provider.dart';
import 'widgets/marketplace_header.dart';
import 'widgets/category_bar.dart';
import 'widgets/compact_apps_table.dart';
import 'widgets/compact_pagination.dart';
import '../../../shared/utils/app_dialogs.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  String? _selectedTab;
  String? _selectedCategory;
  int _currentPage = 1;
  final int _itemsPerPage = 8;

  List<AppModel> _filterApps(List<AppModel> apps) {
    var filtered = apps;

    // Filter by tab
    if (_selectedTab == 'installed') {
      filtered = filtered.where((app) => app.isInstalled).toList();
    } else if (_selectedTab == 'third-party') {
      filtered = filtered
          .where((app) => app.developer.toLowerCase() != 'official')
          .toList();
    }

    // Filter by category
    if (_selectedCategory != null) {
      filtered = filtered.where((app) {
        return app.categories.any(
          (cat) => cat.toLowerCase() == _selectedCategory!.toLowerCase(),
        );
      }).toList();
    }

    return filtered;
  }

  List<AppModel> _paginateApps(List<AppModel> apps) {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, apps.length);
    if (start >= apps.length) return [];
    return apps.sublist(start, end);
  }

  Map<String, int> _getCategoryCounts(List<AppModel> apps) {
    final counts = <String, int>{'all': apps.length};

    final categories = ['tools', 'runtime', 'database', 'security', 'plugins'];
    for (final cat in categories) {
      counts[cat] = apps.where((app) {
        return app.categories.any((c) => c.toLowerCase() == cat);
      }).length;
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsNotifierProvider);

    // Listen for global errors
    ref.listen(errorNotifierProvider, (previous, next) {
      if (next != null) {
        AppDialogs.showError(context, title: 'Error', message: next);
        ref.read(errorNotifierProvider.notifier).clearError();
      }
    });

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: appsAsync.when(
        data: (apps) {
          final filteredApps = _filterApps(apps);
          final paginatedApps = _paginateApps(filteredApps);
          final totalPages = filteredApps.isEmpty
              ? 1
              : (filteredApps.length / _itemsPerPage).ceil();
          final startItem = filteredApps.isEmpty
              ? 0
              : (_currentPage - 1) * _itemsPerPage + 1;
          final endItem = filteredApps.isEmpty
              ? 0
              : (_currentPage * _itemsPerPage).clamp(0, filteredApps.length);
          final categoryCounts = _getCategoryCounts(apps);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              MarketplaceHeader(
                selectedTab: _selectedTab,
                onTabChanged: (value) {
                  setState(() {
                    _selectedTab = value;
                    _currentPage = 1;
                  });
                },
                onUpdate: _handleUpdateList,
              ),
              const SizedBox(height: 24),
              // Category Bar
              CategoryBar(
                selectedCategory: _selectedCategory,
                onCategoryChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _currentPage = 1;
                  });
                },
                categoryCounts: categoryCounts,
              ),
              const SizedBox(height: 24),
              // Main content: Table
              Expanded(
                child: Column(
                  children: [
                    // Table
                    Expanded(
                      child: CompactAppsTable(
                        apps: paginatedApps,
                        onToggleInstall: (app) async {
                          try {
                            await ref
                                .read(appsNotifierProvider.notifier)
                                .toggleInstallation(app);
                          } catch (e) {
                            if (!context.mounted) return;
                            AppDialogs.showError(
                              context,
                              title: 'Action Failed',
                              message: e.toString().replaceFirst('Exception: ', ''),
                            );
                          }
                        },
                        onToggleDashboard: (app) async {
                          final repository = await ref.read(
                            appsRepositoryProvider.future,
                          );
                          app.displayOnDashboard = !app.displayOnDashboard;
                          await repository.save(app);
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .refresh();
                        },
                        onTogglePath: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .togglePath(app);
                          
                          if (!context.mounted) return;
                          final status = app.isAddedToPath ? 'Added to' : 'Removed from';
                          AppDialogs.showToast(
                            context, 
                            '${app.name} $status system PATH',
                          );
                        },
                        onStartService: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .startService(app);
                        },
                        onStopService: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .stopService(app);
                        },
                        onRestartService: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .restartService(app);
                        },
                        onChangeDefault: (appId) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .changeDefaultPhp(appId);
                          
                          if (!context.mounted) return;
                          AppDialogs.showToast(context, 'Set as Default PHP successful');
                        },
                        onOpen: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .openApp(app);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pagination
                    CompactPagination(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      startItem: startItem,
                      endItem: endItem,
                      totalItems: filteredApps.length,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _handleUpdateList() async {
    try {
      final notifier = ref.read(appsNotifierProvider.notifier);
      await notifier.updateCatalog(
        'https://gist.githubusercontent.com/ngotuananh101/d2e69956bc2030b0bcf27707aef9e9cd/raw/apps.json',
      );
      
      if (!mounted) return;
      
      AppDialogs.showSuccess(
        context: context,
        title: 'Success',
        text: 'App list updated successfully',
      );
    } catch (e) {
      if (!mounted) return;
      
      AppDialogs.showError(
        context,
        title: 'Update Failed',
        message: 'Could not update app list: $e',
      );
    }
  }
}
