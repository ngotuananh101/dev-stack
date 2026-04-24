import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../apps/data/apps_provider.dart';
import '../../apps/domain/app_model.dart';

// Provider to list available log files
final logFilesProvider = FutureProvider<List<File>>((ref) async {
  final dir = Directory(AppConfig.logsDir);
  if (!await dir.exists()) return [];

  final entities = await dir.list().toList();
  return entities
      .whereType<File>()
      .where((f) => f.path.endsWith('.log'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path)); // Latest first
});

// Provider to read file content
final logFileContentProvider = FutureProvider.family<List<String>, String>((
  ref,
  path,
) async {
  final file = File(path);
  if (!await file.exists()) return ['Error: File not found'];
  return await file.readAsLines();
});

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  String? _selectedId; // Can be appId (service) or filePath (file)
  bool _isService = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteLogFile(String path) async {
    await AppDialogs.showConfirm(
      context: context,
      title: 'Delete Log File',
      text: 'Are you sure you want to delete ${p.basename(path)}?',
      confirmBtnText: 'DELETE',
      onConfirm: () async {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            ref.invalidate(logFilesProvider);
            setState(() {
              _selectedId = null; // Reset selection to trigger auto-fallback
            });
            if (mounted) {
              AppDialogs.showToast(context, 'File deleted successfully');
            }
          }
        } catch (e) {
          if (mounted) {
            AppDialogs.showToast(context, 'Error deleting file: $e', isError: true);
          }
        }
      },
    );
  }

  void _copyToClipboard(List<String> logs) {
    final text = logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    AppDialogs.showToast(context, 'Logs copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsNotifierProvider);
    final logFilesAsync = ref.watch(logFilesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: appsAsync.when(
        data: (apps) {
          final serviceApps = apps.where((a) => a.isService && a.isInstalled).toList();
          final logFiles = logFilesAsync.value ?? [];

          // 1. Check if the current selection is still valid
          bool isValid = false;
          if (_selectedId != null) {
            if (_isService) {
              isValid = serviceApps.any((a) => a.appId == _selectedId);
            } else {
              isValid = logFiles.any((f) => f.path == _selectedId);
            }
          }

          // 2. If invalid or null, reset to the first available option
          if (!isValid) {
            if (serviceApps.isNotEmpty) {
              _selectedId = serviceApps.first.appId;
              _isService = true;
            } else if (logFiles.isNotEmpty) {
              _selectedId = logFiles.first.path;
              _isService = false;
            } else {
              _selectedId = null;
              _isService = true;
            }
          }

          // 3. Early return if everything is empty
          if (_selectedId == null) {
            return const Center(
              child: Text(
                'No logs available (Install a service or check logs dir)',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          AppModel? currentApp;
          List<String> currentLogs = [];
          String currentTitle = 'Console';

          if (_isService) {
            currentApp = serviceApps.firstWhere(
              (a) => a.appId == _selectedId,
              orElse: () => serviceApps.first,
            );
            currentLogs = currentApp.serviceLogs;
            currentTitle = '${currentApp.name.toLowerCase()}.log';
          } else {
            final fileContent = ref.watch(
              logFileContentProvider(_selectedId ?? ''),
            );
            currentLogs = fileContent.value ?? ['Loading...'];
            currentTitle = p.basename(_selectedId ?? 'unknown.log');
          }

          return Column(
            children: [
              // Compact Top Header with Select
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'LOGS',
                      style: TextStyle(
                        fontSize: AppTextSize.xxs,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Compact Grouped Dropdown
                    Container(
                      height: 36, // Slightly taller for larger text
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedId,
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          style: const TextStyle(
                            fontSize: AppTextSize.xs, // Increased from xxs
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                          onChanged: (value) {
                            if (value == null || value.startsWith('header_')) {
                              return;
                            }
                            setState(() {
                              _selectedId = value;
                              _isService = serviceApps.any(
                                (a) => a.appId == value,
                              );
                            });
                          },
                          items: [
                            // Group: Live Services
                            const DropdownMenuItem<String>(
                              enabled: false,
                              value: 'header_services',
                              child: Text(
                                'LIVE SERVICES',
                                style: TextStyle(
                                  fontSize: 10, // Slightly larger header
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            ...serviceApps.map(
                              (app) => DropdownMenuItem<String>(
                                value: app.appId,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, // Slightly larger dot
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: app.serviceStatus == 'running'
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      app.name,
                                      style: const TextStyle(
                                        fontSize: AppTextSize
                                            .xs, // Increased from xxs
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Group: System Log Files
                            const DropdownMenuItem<String>(
                              enabled: false,
                              value: 'header_files',
                              child: Text(
                                'SYSTEM LOG FILES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            if (logFiles.isEmpty)
                              const DropdownMenuItem<String>(
                                enabled: false,
                                value: 'no_files',
                                child: Text(
                                  '  (No files)',
                                  style: TextStyle(
                                    fontSize: AppTextSize.xs,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ...logFiles.map(
                              (file) => DropdownMenuItem<String>(
                                value: file.path,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      p.basename(file.path),
                                      style: const TextStyle(
                                        fontSize: AppTextSize.xs,
                                      ), // Increased from xxs
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Compact Action Buttons
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => ref.invalidate(logFilesProvider),
                          tooltip: 'Refresh Files',
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          label: 'COPY',
                          onTap: () => _copyToClipboard(currentLogs),
                        ),
                        if (_isService) ...[
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: 'CLEAR',
                            color: AppColors.error,
                            onTap: () {
                              setState(() {
                                currentApp?.serviceLogs.clear();
                              });
                            },
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.delete_forever_rounded,
                            label: 'DELETE',
                            color: AppColors.error,
                            onTap: () => _deleteLogFile(_selectedId!),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Full Width Terminal (Immersive)
              Expanded(
                child: Container(
                  color: const Color(0xFF010409), // GitHub Darker
                  child: Column(
                    children: [
                      // Status Bar / Info Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        color: const Color(0xFF161B22),
                        child: Row(
                          children: [
                            Icon(
                              _isService
                                  ? Icons.terminal_rounded
                                  : Icons.description_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentTitle,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'UTF-8',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Lines: ${currentLogs.length}',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Terminal Output
                      Expanded(
                        child: SelectionArea(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            itemCount: currentLogs.length,
                            itemBuilder: (context, index) {
                              final log = currentLogs[index];
                              final isError = log.contains('[ERROR]');
                              final isSystem =
                                  log.contains('Service started') ||
                                  log.contains('Service exited');

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isError
                                        ? AppColors.error
                                        : isSystem
                                        ? AppColors.primary
                                        : const Color(0xFFE6EDF3),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading logs: $e')),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textMuted,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
