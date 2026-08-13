import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/theme/app_colors.dart';
import '../../hosts/presentation/hosts_editor_dialog.dart';
import '../../../../shared/utils/app_dialogs.dart';
import 'widgets/site_table.dart';
import '../domain/site_model.dart';
import '../domain/batch_models.dart';
import '../domain/site_domain_utils.dart';
import '../data/sites_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../../apps/data/apps_provider.dart';
import 'widgets/add_site_modal.dart';
import 'widgets/edit_site_modal.dart';
import 'widgets/batch_progress_dialog.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedSiteIds = {};

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
            : AddSiteModal(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => HostsEditorDialog.show(context),
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
          icon: const Icon(LucideIcons.fileText, size: 16),
          label: const Text(
            'Edit Hosts',
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
    final sitesAsync = ref.watch(sitesNotifierProvider);

    return sitesAsync.when(
      data: (sites) {
        final filteredSites = sites.where((site) {
          return site.domain.toLowerCase().contains(_searchQuery) ||
              site.rootDir.toLowerCase().contains(_searchQuery) ||
              (site.proxyTarget?.toLowerCase().contains(_searchQuery) ?? false);
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
      text:
          'Are you sure you want to delete $count selected sites? This action cannot be undone.',
      confirmBtnText: 'DELETE ALL',
      onConfirm: () async {
        final sitesNotifier = ref.read(sitesNotifierProvider.notifier);
        final idsToDelete = _selectedSiteIds.toList();
        final progress = ValueNotifier<BatchProgress>(
          BatchProgress(
            current: 0,
            total: idsToDelete.length,
            currentLabel: '',
            phase: BatchPhase.processing,
          ),
        );
        final token = CancelToken();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BatchProgressDialog(
            title: 'Deleting Sites',
            progress: progress,
            onCancel: token.cancel,
          ),
        );

        final result = await sitesNotifier.deleteSitesBatch(
          idsToDelete,
          onProgress: (p) => progress.value = p,
          cancel: token,
        );

        progress.dispose();
        setState(() => _selectedSiteIds.clear());

        if (mounted) {
          Navigator.of(context).pop(); // close progress dialog
          var text = 'Deleted ${result.succeeded} sites.';
          if (result.failed.isNotEmpty) {
            text += ' Failed: ${result.failed.length}.';
          }
          if (result.cancelled) text += ' (Cancelled)';
          AppDialogs.showSuccess(
            context: context,
            title: 'Bulk Delete Finished',
            text: text,
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
    final List<Directory> subdirs = dir
        .listSync()
        .whereType<Directory>()
        .toList();

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
          final apps = ref.read(appsNotifierProvider).value ?? [];

          // Get default PHP version (prioritize isDefault, then installed).
          final defaultPhpApp = apps.firstWhere(
            (a) => a.groupName == 'php' && a.isInstalled && a.isDefault,
            orElse: () => apps.firstWhere(
              (a) => a.groupName == 'php' && a.isInstalled,
              orElse: () => apps.firstWhere(
                (a) => a.groupName == 'php',
                orElse: () => apps.first,
              ),
            ),
          );
          final String defaultPhp =
              (defaultPhpApp.isInstalled && defaultPhpApp.groupName == 'php')
              ? defaultPhpApp.appId
              : 'static';

          final specs = subdirs.map((subdir) {
            final folderName = p.basename(subdir.path);
            return BatchSiteSpec(
              domain: resolveDomainFromTemplate(
                settings.siteTemplate,
                folderName,
              ),
              rootDir: subdir.path,
              siteType: 'php',
              phpAppId: defaultPhp,
              useSsl: true,
            );
          }).toList();

          final progress = ValueNotifier<BatchProgress>(
            BatchProgress(
              current: 0,
              total: specs.length,
              currentLabel: '',
              phase: BatchPhase.processing,
            ),
          );
          final token = CancelToken();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => BatchProgressDialog(
              title: 'Creating Sites',
              progress: progress,
              onCancel: token.cancel,
            ),
          );

          final result = await sitesNotifier.addSitesBatch(
            specs,
            onProgress: (pr) => progress.value = pr,
            cancel: token,
          );

          progress.dispose();

          if (mounted) {
            Navigator.of(context).pop(); // close progress dialog
            var message = 'Created ${result.succeeded} sites.';
            if (result.skipped > 0) {
              message += ' Skipped ${result.skipped} existing/invalid.';
            }
            if (result.failed.isNotEmpty) {
              message += ' Failed: ${result.failed.length}.';
            }
            if (result.cancelled) message += ' (Cancelled)';
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
