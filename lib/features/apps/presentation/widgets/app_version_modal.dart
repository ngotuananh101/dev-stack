import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_conflict_policy.dart';
import '../../domain/app_brand_resolver.dart';
import '../../domain/app_model.dart';
import '../../data/app_version_provider.dart';
import '../../data/apps_provider.dart';

class AppVersionModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onInstall;
  final VoidCallback onClose;
  final bool isUpdate;

  const AppVersionModal({
    super.key,
    required this.app,
    required this.onInstall,
    required this.onClose,
    this.isUpdate = false,
  });

  @override
  ConsumerState<AppVersionModal> createState() => _AppVersionModalState();
}

class _AppVersionModalState extends ConsumerState<AppVersionModal> {
  String _selectedVersion = 'latest';

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(appVersionsProvider(widget.app.appId));
    final appsAsync = ref.watch(appsNotifierProvider);

    // Find current app state in notifier list
    final appState = appsAsync.when(
      data: (list) => list.firstWhere(
        (a) => a.appId == widget.app.appId,
        orElse: () => widget.app,
      ),
      loading: () => widget.app,
      error: (_, _) => widget.app,
    );

    // Port-sharing web servers and database alternatives are mutually exclusive.
    final conflictingApp = widget.isUpdate
        ? null
        : AppConflictPolicy.firstInstalledConflict(
            widget.app,
            appsAsync.valueOrNull ?? const <AppModel>[],
          );

    // Show progress if installing OR if just finished installing
    final isInProgress =
        appState.status == 'installing' ||
        (appState.status == 'installed' && appState.installLogs.isNotEmpty);

    return Container(
      width: 550, // Slightly wider for logs
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(isInProgress),
          const Divider(color: AppColors.border, height: 1),
          // Content
          if (isInProgress)
            _buildProgressSection(appState)
          else
            versionsAsync.when(
              data: (versionInfo) =>
                  _buildVersionSelection(versionInfo, conflictingApp),
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          const Divider(color: AppColors.border, height: 1),
          // Footer
          _buildFooter(isInProgress, appState, conflictingApp),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget _buildProgressSection(AppModel app) {
    final isDone = app.status == 'installed';
    final progress = isDone ? 1.0 : (app.installProgress ?? 0.0);
    final status = isDone
        ? 'Installation Completed'
        : (app.installStatus ?? 'Installing...');

    String progressText = status;
    if (!isDone && app.downloadedBytes != null && app.totalBytes != null) {
      progressText =
          '$status (${_formatBytes(app.downloadedBytes!)} / ${_formatBytes(app.totalBytes!)})';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progressText,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Installation Logs',
            style: TextStyle(
              fontSize: AppTextSize.xxs,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117), // GitHub Dark
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.builder(
              reverse: false,
              itemCount: app.installLogs.length,
              itemBuilder: (context, index) {
                final log = app.installLogs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFFC9D1D9),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isInProgress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Image.asset(
              'assets/images/${AppBrandResolver.iconFileName(widget.app.appId, groupName: widget.app.groupName)}.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(AppBrandResolver.fallbackIcon(widget.app.appId), size: 18, color: AppBrandResolver.iconColor(widget.app.appId)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isUpdate
                      ? 'Update ${widget.app.name}'
                      : 'Install ${widget.app.name}',
                  style: const TextStyle(
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isInProgress
                      ? (widget.isUpdate
                            ? 'Updating ${widget.app.name}...'
                            : 'Installing ${widget.app.name}...')
                      : (widget.isUpdate
                            ? 'Updating to patch version'
                            : 'Select version to install'),
                  style: TextStyle(
                    fontSize: AppTextSize.xxs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSelection(
    AppVersionInfo versionInfo,
    AppModel? conflictingApp,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Version:',
            style: TextStyle(
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable version list with max height
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 240,
            ), // ~80vh equivalent (3-4 items visible)
            child: SingleChildScrollView(
              child: Column(
                children: versionInfo.versions
                    .map(
                      (version) => _buildVersionOption(
                        version,
                        ltsLabel: versionInfo.ltsLabel(version),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (conflictingApp != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cannot install ${widget.app.name} because ${conflictingApp.name} is already installed. Please uninstall it first.',
                      style: const TextStyle(
                        fontSize: AppTextSize.xxs,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading available versions...',
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load versions',
            style: TextStyle(
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTextSize.xxs,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Delay to avoid modifying provider during build
              Future(() {
                ref
                    .read(appVersionsProvider(widget.app.appId).notifier)
                    .refresh();
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionOption(String version, {String? ltsLabel}) {
    final isSelected = _selectedVersion == version;
    final hasLts = ltsLabel != null && ltsLabel.isNotEmpty;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVersion = version;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      version,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSize.sm,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasLts) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        ltsLabel == 'LTS' ? 'LTS' : 'LTS · $ltsLabel',
                        style: const TextStyle(
                          fontSize: AppTextSize.xxs,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    bool isInProgress,
    AppModel appState,
    AppModel? conflictingApp,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!isInProgress) ...[
            OutlinedButton(
              onPressed: widget.onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                side: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: conflictingApp != null
                  ? null
                  : () {
                      widget.app.selectedVersion = _selectedVersion;
                      widget.onInstall();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text(
                widget.isUpdate
                    ? 'Update to ${_selectedVersion == 'latest' ? 'Latest' : _selectedVersion}'
                    : 'Install ${_selectedVersion == 'latest' ? 'Latest' : _selectedVersion}',
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else
            ElevatedButton(
              onPressed: appState.status == 'installed' ? widget.onClose : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.status == 'installed'
                    ? AppColors.success
                    : AppColors.textMuted,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text(
                appState.status == 'installed'
                    ? 'Finish'
                    : (widget.isUpdate ? 'Updating...' : 'Installing...'),
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
