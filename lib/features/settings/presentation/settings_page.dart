import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/services/notepad_service.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../apps/data/apps_provider.dart';
import '../../sites/data/sites_provider.dart';
import '../../../core/services/ssl_service.dart';
import '../data/settings_provider.dart';
import 'widgets/system_info_modal.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isMigrating = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final appsAsync = ref.watch(appsNotifierProvider);
    final sslAsync = ref.watch(sslServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: settingsAsync.when(
        data: (settings) {
          final installedPhps =
              appsAsync.valueOrNull
                  ?.where((a) => a.isInstalled && a.groupName == 'php')
                  .toList() ??
              [];

          final currentDefaultPhp = installedPhps
              .where((a) => a.isDefault)
              .map((a) => a.appId)
              .firstOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSection(
                  title: 'Paths & Directories',
                  icon: LucideIcons.folderCog,
                  children: [
                    _buildPathSetting(
                      title: 'Base Directory',
                      subtitle:
                          'Root directory for all Ponta data, apps, logs, and configs',
                      value: settings.baseDir,
                      onBrowse: () => _browseBaseDir(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Site Configuration',
                  icon: LucideIcons.globe,
                  children: [
                    _buildActionSetting(
                      title: 'Edit Hosts File',
                      subtitle: 'Open Windows hosts file in Notepad++',
                      icon: LucideIcons.fileText,
                      actionLabel: 'Edit',
                      onTap: () => _editHostsFile(context),
                    ),
                    const Divider(color: AppColors.border, height: 32),
                    _buildDropdownSetting(
                      title: 'Default PHP Version',
                      subtitle:
                          'Choose which PHP version to use as system default',
                      value: currentDefaultPhp,
                      items: installedPhps.map((a) => a.appId).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(appsNotifierProvider.notifier)
                              .changeDefaultPhp(val);
                        }
                      },
                      placeholder: 'No PHP version installed',
                    ),
                    const Divider(color: AppColors.border, height: 32),
                    _buildTextFieldSetting(
                      title: 'Auto Create Site Template',
                      subtitle: 'Template for new site domain names',
                      value: settings.siteTemplate,
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(siteTemplate: val),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Application Behavior',
                  icon: LucideIcons.monitor,
                  children: [
                    _buildSwitchSetting(
                      title: 'Minimize to System Tray',
                      subtitle: 'Keep app running in background when closed',
                      value: settings.minimizeToTray,
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(minimizeToTray: val),
                    ),
                    const Divider(color: AppColors.border, height: 32),
                    _buildSwitchSetting(
                      title: 'Auto Start on Windows',
                      subtitle:
                          'Launch DevStack automatically when you sign in',
                      value: settings.autoStartWithWindows,
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(autoStartWithWindows: val),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Network Access',
                  icon: LucideIcons.network,
                  children: [
                    _buildSwitchSetting(
                      title: 'Allow LAN Access',
                      subtitle:
                          'Bind webservers to 0.0.0.0 so other devices on your '
                          'network can reach local sites and phpMyAdmin.\n'
                          'Off (default) binds to 127.0.0.1 only — recommended '
                          'unless you need to test from another device.',
                      value: settings.allowLanAccess,
                      onChanged: (val) async {
                        await ref
                            .read(settingsNotifierProvider.notifier)
                            .updateField(allowLanAccess: val);
                        if (!mounted) return;

                        // Rewrite global and per-site configs first, then restart
                        // installed webservers once with the new bind address.
                        await ref
                            .read(appsNotifierProvider.notifier)
                            .reconfigureWebservers(restartRunning: false);
                        if (!mounted) return;
                        await ref
                            .read(sitesNotifierProvider.notifier)
                            .regenerateAllVhosts(restartWebserver: false);
                        if (!mounted) return;
                        await ref
                            .read(appsNotifierProvider.notifier)
                            .restartRunningWebservers();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'System Information',
                  icon: LucideIcons.info,
                  children: [
                    _buildActionSetting(
                      title: 'View System Details',
                      subtitle: 'OS, Hardware, and environment configuration',
                      icon: LucideIcons.externalLink,
                      onTap: () => _showSystemInfo(context),
                    ),
                    const Divider(color: AppColors.border, height: 32),
                    _buildStatusSetting(
                      title: 'Root Certificate',
                      subtitle:
                          'Status of custom SSL root certificate (mkcert)',
                      status: sslAsync.when(
                        data: (installed) =>
                            installed ? 'Installed' : 'Not Installed',
                        loading: () => 'Checking...',
                        error: (e, s) => 'Error',
                      ),
                      isSuccess: sslAsync.valueOrNull == true,
                      actions: sslAsync.valueOrNull == true
                          ? [
                              _StatusAction(
                                label: 'Reinstall',
                                color: AppColors.accent,
                                onTap: () => _handleSslAction(
                                  'Reinstall',
                                  () => ref
                                      .read(sslServiceProvider.notifier)
                                      .initializeRootCA(),
                                ),
                              ),
                              _StatusAction(
                                label: 'Uninstall',
                                color: AppColors.error,
                                onTap: () => _confirmUninstall(context),
                              ),
                            ]
                          : [
                              _StatusAction(
                                label: 'Install',
                                color: AppColors.accent,
                                onTap: () => _handleSslAction(
                                  'Install',
                                  () => ref
                                      .read(sslServiceProvider.notifier)
                                      .initializeRootCA(),
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
      ),
    );
  }

  Future<void> _browseBaseDir(BuildContext context) async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Base Directory',
      initialDirectory: AppConfig.baseDir,
    );

    if (result == null || result == AppConfig.baseDir) return;
    if (!context.mounted) return;

    _changeBaseDir(context, result);
  }

  Future<void> _changeBaseDir(BuildContext context, String newDir) async {
    final oldDir = AppConfig.baseDir;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 22),
            SizedBox(width: 12),
            Text(
              'Change Base Directory',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From: $oldDir',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: AppTextSize.xs,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'To: $newDir',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: AppTextSize.xs,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Copy all data from the old directory to the new one\n'
              '• Rewrite all config files (nginx, apache, php.ini, etc.)\n'
              '• Update database records (installed apps, sites)\n'
              '• Update Windows PATH environment variable\n'
              '• Require an app restart to apply changes',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The old directory will NOT be deleted automatically.',
                      style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Migrate & Change'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isMigrating = true);

    try {
      final notifier = ref.read(settingsNotifierProvider.notifier);

      // Migrate data
      final sourceExists = Directory(oldDir).existsSync();
      if (sourceExists) {
        final success = await notifier.migrateBaseDir(oldDir, newDir);
        if (!success && context.mounted) {
          AppDialogs.showToast(
            context,
            'Migration failed. Base directory was NOT changed.',
            isError: true,
          );
          setState(() => _isMigrating = false);
          return;
        }
      }

      // Persist new baseDir
      await notifier.updateField(baseDir: newDir);

      setState(() => _isMigrating = false);

      if (!context.mounted) return;

      // Show restart required dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(LucideIcons.refreshCw, color: AppColors.accent, size: 22),
              SizedBox(width: 12),
              Text(
                'Restart Required',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.md,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Base directory has been changed to:\n$newDir\n\n'
            'Please restart the application for changes to take effect.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.sm,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Restart Later',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Stop running services gracefully before tearing down the
                // process. exit(0) alone skips stopAllServicesQuietly() and
                // orphans detached webservers (nginx/apache) holding their
                // ports, which then conflict with the new base directory on
                // the next launch.
                try {
                  await ref
                      .read(appsNotifierProvider.notifier)
                      .stopAllServicesQuietly();
                } catch (_) {}
                if (ctx.mounted) Navigator.of(ctx).pop();
                exit(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Restart Now'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showToast(context, 'Error: $e', isError: true);
        setState(() => _isMigrating = false);
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: AppTextSize.xxl,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your local development preferences and system behavior',
          style: TextStyle(
            fontSize: AppTextSize.sm,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accent),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accent,
          activeTrackColor: AppColors.accent.withValues(alpha: 0.2),
          inactiveThumbColor: AppColors.textSecondary,
          inactiveTrackColor: AppColors.surfaceLight,
        ),
      ],
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String placeholder,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTextSize.xs,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              dropdownColor: AppColors.surfaceLight,
              icon: const Icon(LucideIcons.chevronDown, size: 16),
              hint: Text(
                placeholder,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.xs,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldSetting({
    required String title,
    required String subtitle,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 200,
          child: TextFormField(
            key: ValueKey('$title-$value'),
            initialValue: value,
            onChanged: onChanged,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextSize.xs,
              fontFamily: 'JetBrainsMono',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPathSetting({
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onBrowse,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppTextSize.xs,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.folder,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: AppTextSize.xs,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _isMigrating ? null : onBrowse,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _isMigrating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : const Text(
                              'Browse',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_isMigrating) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Migrating data to new directory...',
                  style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    String? actionLabel,
  }) {
    if (actionLabel != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: AppTextSize.xs,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppTextSize.xs,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSetting({
    required String title,
    required String subtitle,
    required String status,
    required bool isSuccess,
    List<_StatusAction> actions = const [],
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: AppTextSize.xs,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSuccess
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSuccess
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSuccess ? AppColors.success : AppColors.error,
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: ElevatedButton(
                onPressed: action.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: action.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(action.label, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmUninstall(BuildContext context) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Uninstall Root Certificate?',
      text:
          'Warning: Uninstalling the root certificate will cause SSL errors for all local .test sites. Use this only if you know what you are doing.',
      confirmBtnText: 'UNINSTALL ANYWAY',
      onConfirm: () => _handleSslAction(
        'Uninstall',
        () => ref.read(sslServiceProvider.notifier).uninstallRootCA(),
      ),
    );
  }

  Future<void> _handleSslAction(
    String actionName,
    Future<void> Function() action,
  ) async {
    // Show an initial feedback toast (optional, but helps UX)
    AppDialogs.showToast(context, '$actionName SSL Root Certificate...');

    await action();
    if (!mounted) return;

    final sslState = ref.read(sslServiceProvider);
    if (sslState.hasError) {
      AppDialogs.showToast(
        context,
        'Failed to ${actionName.toLowerCase()} SSL.',
        isError: true,
      );
    } else {
      AppDialogs.showSuccess(
        context: context,
        title: 'Success',
        text:
            'Successfully ${actionName.toLowerCase()}ed SSL Root Certificate.',
      );
    }
  }

  void _showSystemInfo(BuildContext context) {
    showDialog(context: context, builder: (context) => const SystemInfoModal());
  }

  Future<void> _editHostsFile(BuildContext context) async {
    const hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
    final success = await NotepadService.openFile(hostsPath);
    if (!success && context.mounted) {
      AppDialogs.showToast(
        context,
        'Failed to open hosts file in Notepad++',
        isError: true,
      );
    }
  }
}

class _StatusAction {
  final String label;
  final Color color;
  final VoidCallback onTap;

  _StatusAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
}
