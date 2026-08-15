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
  String? _selectedCategory;
  int _currentPage = 1;
  final int _itemsPerPage = 9;
  bool _didAutoRefreshCatalog = false;

  @override
  void initState() {
    super.initState();
    // Try refreshing the app catalog once per launch when online; failures
    // are silent (offline keeps the cached/bundled list).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didAutoRefreshCatalog) return;
      _didAutoRefreshCatalog = true;
      ref.read(appsNotifierProvider.notifier).autoUpdateCatalog();
    });
  }

  List<AppModel> _filterApps(List<AppModel> apps) {
    var filtered = apps;

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

    for (final app in apps) {
      for (final cat in app.categories) {
        final normalizedCat = cat.toLowerCase();
        counts[normalizedCat] = (counts[normalizedCat] ?? 0) + 1;
      }
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
                onUpdate: _handleUpdateList,
                actions: CategoryBar(
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _currentPage = 1;
                    });
                  },
                  categoryCounts: categoryCounts,
                ),
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
                              message: e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        },
                        onTogglePath: (app) async {
                          await ref
                              .read(appsNotifierProvider.notifier)
                              .togglePath(app);

                          if (!context.mounted) return;
                          final status = app.isAddedToPath
                              ? 'Added to'
                              : 'Removed from';
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
                          AppDialogs.showToast(
                            context,
                            'Set as Default PHP successful',
                          );
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
      await notifier.updateCatalog(AppsNotifier.catalogUrl);

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
