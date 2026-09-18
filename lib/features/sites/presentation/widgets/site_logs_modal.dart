import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/cli_process_manager.dart';
import '../../domain/site_model.dart';

class SiteLogsModal extends ConsumerStatefulWidget {
  final SiteModel site;

  const SiteLogsModal({super.key, required this.site});

  @override
  ConsumerState<SiteLogsModal> createState() => _SiteLogsModalState();
}

class _SiteLogsModalState extends ConsumerState<SiteLogsModal> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    final manager = ref.read(cliProcessManagerProvider);
    _lines.addAll(manager.getLogBuffer(widget.site.id));

    _subscription = manager.getLogStream(widget.site.id).listen((line) {
      if (!mounted) return;
      setState(() {
        _lines.add(line);
      });
      if (_autoScroll) {
        _scrollToBottom();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _clearLogs() {
    ref.read(cliProcessManagerProvider).clearLogs(widget.site.id);
    setState(() {
      _lines.clear();
    });
  }

  void _openLogFile() {
    final logFilePath = p.join(
      AppConfig.baseDir,
      'logs',
      widget.site.domain,
      'cli_app.log',
    );
    if (File(logFilePath).existsSync()) {
      if (Platform.isWindows) {
        Process.run('cmd.exe', ['/c', 'start', '', logFilePath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [logFilePath]);
      } else {
        Process.run('xdg-open', [logFilePath]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 900,
        height: 600,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildLogView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.terminal, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            'Logs: ${widget.site.domain}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _autoScroll ? LucideIcons.arrowDownCircle : LucideIcons.pauseCircle,
              size: 16,
              color: _autoScroll ? AppColors.success : AppColors.textMuted,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16, color: AppColors.textSecondary),
            tooltip: 'Clear',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            tooltip: 'Copy all',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
            tooltip: 'Open log file',
            onPressed: _openLogFile,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogView() {
    if (_lines.isEmpty) {
      return const Center(
        child: Text(
          'No logs yet. Start the CLI application to view output.',
          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        final isError = line.contains('[ERROR]') || line.contains('Error:');
        return SelectableText(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isError ? const Color(0xFFF48771) : const Color(0xFFCCCCCC),
            height: 1.4,
          ),
        );
      },
    );
  }
}
