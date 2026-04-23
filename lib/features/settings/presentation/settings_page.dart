import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../apps/data/apps_provider.dart';
import '../data/settings_provider.dart';
import 'widgets/system_info_modal.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final appsAsync = ref.watch(appsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: settingsAsync.when(
        data: (settings) {
          final installedPhps = appsAsync.valueOrNull
                  ?.where((a) => a.isInstalled && a.groupName == 'php')
                  .toList() ??
              [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSection(
                  title: 'Site Configuration',
                  icon: LucideIcons.globe,
                  children: [
                    _buildDropdownSetting(
                      title: 'Default PHP Version',
                      subtitle: 'Choose which PHP version to use as system default',
                      value: settings.defaultPhpVersion,
                      items: installedPhps.map((a) => a.appId).toList(),
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(defaultPhpVersion: val),
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
                    const Divider(color: AppColors.border, height: 32),
                    _buildSwitchSetting(
                      title: 'Auto Create Site',
                      subtitle: 'Automatically create site when a new app is installed',
                      value: settings.autoCreateSite,
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(autoCreateSite: val),
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
                      subtitle: 'Launch DevStack automatically when you sign in',
                      value: settings.autoStartWithWindows,
                      onChanged: (val) => ref
                          .read(settingsNotifierProvider.notifier)
                          .updateField(autoStartWithWindows: val),
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
          activeColor: AppColors.accent,
          activeTrackColor: AppColors.accent.withOpacity(0.2),
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
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppTextSize.xs,
                          ),
                        ),
                      ))
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
        Container(
          width: 200,
          child: TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.fromPosition(
                  TextPosition(offset: value.length)),
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

  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
    );
  }

  void _showSystemInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SystemInfoModal(),
    );
  }
}
