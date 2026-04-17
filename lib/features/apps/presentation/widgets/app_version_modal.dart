import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import '../../data/app_version_provider.dart';

class AppVersionModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onInstall;
  final VoidCallback onClose;

  const AppVersionModal({
    super.key,
    required this.app,
    required this.onInstall,
    required this.onClose,
  });

  @override
  ConsumerState<AppVersionModal> createState() => _AppVersionModalState();
}

class _AppVersionModalState extends ConsumerState<AppVersionModal> {
  String _selectedVersion = 'latest';

  IconData _getAppIcon() {
    if (widget.app.appId.contains('python') || widget.app.appId.contains('pyenv')) {
      return Icons.code;
    } else if (widget.app.appId.contains('node')) {
      return Icons.javascript;
    } else if (widget.app.appId.contains('php')) {
      return Icons.code;
    } else if (widget.app.appId.contains('mysql')) {
      return Icons.storage;
    } else if (widget.app.appId.contains('nginx')) {
      return Icons.cloud;
    }
    return Icons.apps;
  }

  Color _getIconColor() {
    if (widget.app.appId.contains('python') || widget.app.appId.contains('pyenv')) {
      return const Color(0xFF3776AB);
    } else if (widget.app.appId.contains('node')) {
      return const Color(0xFF68A063);
    } else if (widget.app.appId.contains('php')) {
      return const Color(0xFF777BB4);
    } else if (widget.app.appId.contains('mysql')) {
      return const Color(0xFF4479A1);
    } else if (widget.app.appId.contains('nginx')) {
      return const Color(0xFF009639);
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(appVersionsProvider(widget.app.appId));

    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          const Divider(color: AppColors.border, height: 1),
          // Version selection with loading state
          versionsAsync.when(
            data: (versionInfo) => _buildVersionSelection(versionInfo),
            loading: () => _buildLoadingState(),
            error: (error, stack) => _buildErrorState(error.toString()),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Footer buttons
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getAppIcon(),
              size: 18,
              color: _getIconColor(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Install ${widget.app.name}',
                  style: const TextStyle(
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Select version to install',
                  style: TextStyle(
                    fontSize: AppTextSize.small,
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

  Widget _buildVersionSelection(AppVersionInfo versionInfo) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Version:',
            style: TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable version list with max height
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240), // ~80vh equivalent (3-4 items visible)
            child: SingleChildScrollView(
              child: Column(
                children: versionInfo.versions
                    .map((version) => _buildVersionOption(version))
                    .toList(),
              ),
            ),
          ),
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
              fontSize: AppTextSize.body,
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
            color: AppColors.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load versions',
            style: TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTextSize.small,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Delay to avoid modifying provider during build
              Future(() {
                ref.read(appVersionsProvider(widget.app.appId).notifier).refresh();
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionOption(String version) {
    final isSelected = _selectedVersion == version;
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
            Text(
              version,
              style: TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onClose,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              widget.app.selectedVersion = _selectedVersion;
              widget.onInstall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Install ${_selectedVersion == 'latest' ? 'Latest' : _selectedVersion}',
              style: const TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
