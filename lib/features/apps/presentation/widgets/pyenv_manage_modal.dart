import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/app_model.dart';
import '../../data/pyenv_provider.dart';

class PyenvManageModal extends ConsumerStatefulWidget {
  final AppModel app;
  final VoidCallback onClose;

  const PyenvManageModal({super.key, required this.app, required this.onClose});

  @override
  ConsumerState<PyenvManageModal> createState() => _PyenvManageModalState();
}

class _PyenvManageModalState extends ConsumerState<PyenvManageModal> {
  String? _installingVersion;
  List<String> _installableVersions = [];
  bool _isLoadingVersions = false;

  @override
  void initState() {
    super.initState();
    _loadInstallableVersions();
  }

  Future<void> _loadInstallableVersions() async {
    setState(() => _isLoadingVersions = true);
    try {
      final versions =
          await ref.read(pyenvNotifierProvider.notifier).getInstallableVersions();
      if (mounted) {
        setState(() {
          _installableVersions = versions;
          _isLoadingVersions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVersions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(pyenvNotifierProvider);

    return Container(
      width: 700,
      height: 600,
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
          Expanded(
            child: Row(
              children: [
                // Left: Installed Versions
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: _buildInstalledSection(stateAsync),
                  ),
                ),
                // Right: Installable Versions
                Expanded(
                  flex: 1,
                  child: _buildInstallableSection(stateAsync.value?.installedVersions ?? []),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            child: Icon(
              Icons.terminal_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Python Version Management',
                style: TextStyle(
                  fontSize: AppTextSize.base,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Powered by pyenv-win',
                style: TextStyle(
                  fontSize: AppTextSize.xxs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledSection(AsyncValue<PyenvState> stateAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'INSTALLED VERSIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: stateAsync.when(
            data: (state) {
              if (state.installedVersions.isEmpty) {
                return const Center(
                  child: Text(
                    'No versions installed',
                    style: TextStyle(color: AppColors.textMuted, fontSize: AppTextSize.xxs),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: state.installedVersions.length,
                itemBuilder: (context, index) {
                  final v = state.installedVersions[index];
                  final isActive = v == state.activeVersion;
                  return _buildVersionTile(v, isInstalled: true, isActive: isActive);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallableSection(List<String> installedVersions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AVAILABLE TO INSTALL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              if (_isLoadingVersions)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 14),
                  onPressed: _loadInstallableVersions,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingVersions && _installableVersions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _installableVersions.length,
                  itemBuilder: (context, index) {
                    final v = _installableVersions[index];
                    final isAlreadyInstalled = installedVersions.contains(v);
                    return _buildVersionTile(
                      v,
                      isInstalled: false,
                      isAlreadyInstalled: isAlreadyInstalled,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVersionTile(
    String version, {
    required bool isInstalled,
    bool isActive = false,
    bool isAlreadyInstalled = false,
  }) {
    final isInstalling = _installingVersion == version;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Text(
          version,
          style: const TextStyle(
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: isInstalling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isInstalled) ...[
                    if (isActive)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.textMuted),
                        onPressed: () => _setGlobal(version),
                        tooltip: 'Set as Global',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      onPressed: () => _uninstall(version),
                      tooltip: 'Uninstall',
                    ),
                  ] else if (!isAlreadyInstalled)
                    IconButton(
                      icon: const Icon(Icons.download, size: 16, color: AppColors.primary),
                      onPressed: () => _install(version),
                      tooltip: 'Install',
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.check, size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _install(String version) async {
    setState(() => _installingVersion = version);
    try {
      await ref.read(pyenvNotifierProvider.notifier).installVersion(version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Python $version installed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install Python $version: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _installingVersion = null);
    }
  }

  Future<void> _uninstall(String version) async {
    try {
      await ref.read(pyenvNotifierProvider.notifier).uninstallVersion(version);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to uninstall: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _setGlobal(String version) async {
    try {
      await ref.read(pyenvNotifierProvider.notifier).globalVersion(version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set Python $version as global')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set global: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
