import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';
import 'app_modal_header.dart';

class TerminalLogView extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> lines;
  final VoidCallback? onClear;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenFile;
  final VoidCallback? onClose;
  final Widget? statusWidget;
  final bool isModal;
  final String emptyMessage;

  const TerminalLogView({
    super.key,
    required this.title,
    this.icon = LucideIcons.terminal,
    required this.lines,
    this.onClear,
    this.onCopy,
    this.onOpenFile,
    this.onClose,
    this.statusWidget,
    this.isModal = true,
    this.emptyMessage = 'No logs available yet.',
  });

  @override
  State<TerminalLogView> createState() => _TerminalLogViewState();
}

class _TerminalLogViewState extends State<TerminalLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(TerminalLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _defaultCopy() {
    Clipboard.setData(ClipboardData(text: widget.lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildLogContent()),
      ],
    );

    if (!widget.isModal) {
      return Container(
        color: AppColors.background,
        child: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );
  }

  Widget _buildHeader() {
    return AppModalHeader(
      icon: widget.icon,
      iconColor: AppColors.accent,
      title: widget.title,
      subtitleWidget: widget.statusWidget,
      actions: [
        IconButton(
          icon: Icon(
            _autoScroll ? LucideIcons.arrowDownCircle : LucideIcons.pauseCircle,
            size: 16,
            color: _autoScroll ? AppColors.success : AppColors.textMuted,
          ),
          tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          onPressed: () => setState(() => _autoScroll = !_autoScroll),
        ),
        if (widget.onClear != null)
          IconButton(
            icon: const Icon(Icons.clear_all, size: 16, color: AppColors.textSecondary),
            tooltip: 'Clear',
            onPressed: widget.onClear,
          ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
          tooltip: 'Copy all',
          onPressed: widget.onCopy ?? _defaultCopy,
        ),
        if (widget.onOpenFile != null)
          IconButton(
            icon: const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
            tooltip: 'Open log file',
            onPressed: widget.onOpenFile,
          ),
      ],
      onClose: widget.onClose,
    );
  }

  Widget _buildLogContent() {
    if (widget.lines.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: AppTextSize.sm,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isError = line.contains('[ERROR]') || line.contains('Error:');
        final isWarning = line.contains('[WARN]') || line.contains('Warning:');
        final isInfo = line.contains('[INFO]') || line.contains('Service started');

        Color textColor = AppColors.textPrimary;
        if (isError) {
          textColor = AppColors.error;
        } else if (isWarning) {
          textColor = AppColors.warning;
        } else if (isInfo) {
          textColor = AppColors.primary;
        }

        return SelectableText(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: AppTextSize.xs,
            color: textColor,
            height: 1.4,
          ),
        );
      },
    );
  }
}
