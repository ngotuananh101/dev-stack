import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/app_dialogs.dart';
import 'widgets/site_table.dart';
import '../domain/site_model.dart';
import '../data/sites_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../../apps/data/apps_provider.dart';
import 'widgets/add_site_modal.dart';
import 'widgets/edit_site_modal.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  String selectedTab = 'PHP Project';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedSiteIds = {};

  final List<String> tabs = [
    'PHP Project',
    'NodeJs Project',
    'Proxy Project',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSiteDialog([SiteModel? site]) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: site != null
            ? EditSiteModal(
                site: site,
                onClose: () => Navigator.of(context).pop(),
              )
            : AddSiteModal(
                onClose: () => Navigator.of(context).pop(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = selectedTab == tab;

          return InkWell(
            onTap: () {
              setState(() {
                selectedTab = tab;
              });
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
                tab,
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

  Widget _buildHeader() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showSiteDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text(
            'Add Site',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _handleBatchCreateSites(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
            elevation: 0,
          ),
          icon: const Icon(LucideIcons.folderPlus, size: 16),
          label: const Text(
            'Batch Create',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (_selectedSiteIds.isNotEmpty) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _handleBulkDelete(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.error),
              ),
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: Text(
              'Delete (${_selectedSiteIds.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const Spacer(),
        _buildSearchField(),
      ],
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      width: 280,
      height: 36,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search sites...',
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

  Widget _buildContent() {
    if (selectedTab != 'PHP Project') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedTab == 'NodeJs Project'
                  ? LucideIcons.box
                  : LucideIcons.shuffle,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              '$selectedTab is Under Development',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final sitesAsync = ref.watch(sitesNotifierProvider);

    return sitesAsync.when(
      data: (sites) {
        final filteredSites = sites.where((site) {
          return site.domain.toLowerCase().contains(_searchQuery) ||
              site.rootDir.toLowerCase().contains(_searchQuery);
        }).toList();

        return SiteTable(
          sites: filteredSites,
          selectedIds: _selectedSiteIds,
          onEdit: (site) => _showSiteDialog(site),
          onToggleSelection: (id) {
            setState(() {
              if (_selectedSiteIds.contains(id)) {
                _selectedSiteIds.remove(id);
              } else {
                _selectedSiteIds.add(id);
              }
            });
          },
          onToggleAll: (isSelected) {
            setState(() {
              if (isSelected) {
                _selectedSiteIds.addAll(filteredSites.map((s) => s.id));
              } else {
                _selectedSiteIds.clear();
              }
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading sites: $e')),
    );
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedSiteIds.isEmpty) return;

    final count = _selectedSiteIds.length;
    AppDialogs.showConfirm(
      context: context,
      title: 'Bulk Delete Sites',
      text: 'Are you sure you want to delete $count selected sites? This action cannot be undone.',
      confirmBtnText: 'DELETE ALL',
      onConfirm: () async {
        final sitesNotifier = ref.read(sitesNotifierProvider.notifier);
        
        // Use a copy to avoid concurrent modification issues
        final idsToDelete = _selectedSiteIds.toList();
        
        for (final id in idsToDelete) {
          await sitesNotifier.deleteSite(id);
        }

        setState(() {
          _selectedSiteIds.clear();
        });

        if (mounted) {
          AppDialogs.showSuccess(
            context: context,
            title: 'Success',
            text: 'Successfully deleted $count sites.',
          );
        }
      },
    );
  }

  Future<void> _handleBatchCreateSites() async {
    final settingsAsync = ref.read(settingsNotifierProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) return;

    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    final dir = Directory(path);
    final List<Directory> subdirs =
        dir.listSync().whereType<Directory>().toList();

    if (subdirs.isEmpty) {
      if (mounted) {
        AppDialogs.showToast(
          context,
          'No subfolders found in the selected directory.',
          isError: true,
        );
      }
      return;
    }

    if (mounted) {
      AppDialogs.showConfirm(
        context: context,
        title: 'Batch Create Sites',
        text:
            'Found ${subdirs.length} folders. Do you want to create sites for all of them using template "${settings.siteTemplate}"?',
        confirmBtnText: 'CREATE ALL',
        onConfirm: () async {
          final sitesNotifier = ref.read(sitesNotifierProvider.notifier);
          final existingSites = ref.read(sitesNotifierProvider).value ?? [];
          final apps = ref.read(appsNotifierProvider).value ?? [];

          // Get default PHP version (first installed or first overall)
          final defaultPhpApp = apps.where((a) => a.groupName == 'php').firstWhere(
            (a) => a.isInstalled,
            orElse: () => apps.firstWhere(
              (a) => a.groupName == 'php',
              orElse: () => apps.first, // Dummy fallback
            ),
          );
          
          final String defaultPhp = (defaultPhpApp.isInstalled && defaultPhpApp.groupName == 'php') 
              ? defaultPhpApp.appId 
              : 'static';

          int count = 0;
          int skipped = 0;
          for (final subdir in subdirs) {
            final folderName = p.basename(subdir.path);
            
            // Flexible replacement for common placeholders
            String domain = settings.siteTemplate;
            if (domain.contains('[site-name]')) {
              domain = domain.replaceAll('[site-name]', folderName);
            } else if (domain.contains('{name}')) {
              domain = domain.replaceAll('{name}', folderName);
            } else if (domain.contains('{site-name}')) {
              domain = domain.replaceAll('{site-name}', folderName);
            } else {
              // Fallback: if no placeholder found, maybe it's just a suffix like ".test"
              // but if it's literally "[site-name].test" it will be handled above
            }

            // Skip if domain already exists
            if (existingSites.any((s) => s.domain == domain)) {
              skipped++;
              continue;
            }

            try {
              await sitesNotifier.addSite(
                domain: domain,
                rootDir: subdir.path,
                phpAppId: defaultPhp,
                useSsl: true,
              );
              count++;
            } catch (e) {
              // Log error but continue with others
              debugPrint('Error adding site $domain: $e');
            }
          }

          if (mounted) {
            String message = 'Successfully created $count sites.';
            if (skipped > 0) {
              message += ' Skipped $skipped existing domains.';
            }
            AppDialogs.showSuccess(
              context: context,
              title: 'Batch Creation Finished',
              text: message,
            );
          }
        },
      );
    }
  }
}
