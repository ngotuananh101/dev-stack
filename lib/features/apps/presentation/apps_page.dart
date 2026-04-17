import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../data/apps_provider.dart';
import '../domain/app_model.dart';
import 'widgets/marketplace_header.dart';
import 'widgets/featured_banner.dart';
import 'widgets/category_sidebar.dart';
import 'widgets/compact_apps_table.dart';
import 'widgets/compact_pagination.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  String? _selectedTab;
  String? _selectedCategory;
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  List<AppModel> _filterApps(List<AppModel> apps) {
    var filtered = apps;

    // Filter by tab
    if (_selectedTab == 'installed') {
      filtered = filtered.where((app) => app.isInstalled).toList();
    } else if (_selectedTab == 'professional') {
      filtered = filtered
          .where((app) => app.price != null && app.price! > 0)
          .toList();
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

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: appsAsync.when(
        data: (apps) {
          final filteredApps = _filterApps(apps);
          final paginatedApps = _paginateApps(filteredApps);
          final totalPages = filteredApps.isEmpty ? 1 : (filteredApps.length / _itemsPerPage).ceil();
          final startItem = filteredApps.isEmpty ? 0 : (_currentPage - 1) * _itemsPerPage + 1;
          final endItem = filteredApps.isEmpty ? 0 : (_currentPage * _itemsPerPage).clamp(0, filteredApps.length);
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
              ),
              const SizedBox(height: 24),
              // Main content: Sidebar + Table
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sidebar
                    SizedBox(
                      width: 160,
                      child: CategorySidebar(
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
                    const SizedBox(width: 24),
                    // Table area
                    Expanded(
                      child: Column(
                        children: [
                          // Table
                          Expanded(
                            child: CompactAppsTable(
                              apps: paginatedApps,
                              onToggleInstall: (app) async {
                                await ref
                                    .read(appsNotifierProvider.notifier)
                                    .toggleInstallation(app);
                              },
                              onToggleDashboard: (app) async {
                                final repository = await ref.read(
                                  appsRepositoryProvider.future,
                                );
                                app.displayOnDashboard =
                                    !app.displayOnDashboard;
                                await repository.save(app);
                                await ref
                                    .read(appsNotifierProvider.notifier)
                                    .refresh();
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
}
