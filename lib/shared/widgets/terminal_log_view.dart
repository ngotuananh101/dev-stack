import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';
import '../utils/app_dialogs.dart';
import 'app_icon_button.dart';
import 'app_modal_header.dart';

/// A bottom-anchored, lazily built log viewer.
///
/// Performance notes — these are the reasons the widget is shaped this way:
///
/// * The list is `reverse: true`, so offset 0 *is* the tail. Opening a log
///   therefore needs no `jumpTo(maxScrollExtent)`: with a lazy builder and no
///   `itemExtent`, Flutter cannot know `maxScrollExtent` without building and
///   laying out **every** row, which is what made the first open of a large
///   log freeze for seconds. A reversed list starts at its own origin, so the
///   first frame builds only the visible rows.
/// * `SelectionArea` + a plain `Text` replaces a `SelectableText` per line.
///   `SelectableText` spins up a full `EditableText` / `RenderEditable` /
///   text-input pipeline per row, which is far more expensive than a `Text`
///   under one shared selection scope.
/// * Absurdly long lines are clipped for rendering. A single multi-megabyte
///   line would otherwise produce one enormous paragraph on every frame; the
///   full line is still what "Copy all" and text selection read from.
class TerminalLogView extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> lines;

  /// Optional monotonic counter for callers whose `lines` list is stable and
  /// capped in length, so a new line neither changes the identity nor the
  /// length. Without it, auto-scroll cannot tell that anything was appended.
  final int revision;
  final VoidCallback? onClear;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenFile;
  final VoidCallback? onClose;
  final Widget? statusWidget;
  final bool isModal;
  final String emptyMessage;

  /// When false, the header row (title + actions) is not rendered. The
  /// Logs page uses this: auto-scroll and copy live in the page header
  /// instead, so the viewer is just the log list.
  final bool showHeader;

  /// Controlled auto-scroll state. When [onAutoScrollChanged] is given,
  /// the page owns the flag; otherwise the viewer keeps its own state.
  final bool autoScroll;
  final ValueChanged<bool>? onAutoScrollChanged;

  /// Maximum characters rendered per row. Longer lines are truncated; the
  /// copy action still uses the complete text.
  static const int maxRenderedLineLength = 4000;

  const TerminalLogView({
    super.key,
    required this.title,
    this.icon = LucideIcons.terminal,
    required this.lines,
    this.revision = 0,
    this.onClear,
    this.onCopy,
    this.onOpenFile,
    this.onClose,
    this.statusWidget,
    this.isModal = true,
    this.emptyMessage = 'No logs available yet.',
    this.showHeader = true,
    this.autoScroll = true,
    this.onAutoScrollChanged,
  });

  @override
  State<TerminalLogView> createState() => _TerminalLogViewState();
}

class _TerminalLogViewState extends State<TerminalLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrollInternal = true;

  /// Controlled when the caller passes [TerminalLogView.onAutoScrollChanged];
  /// otherwise the viewer owns the flag.
  bool get _autoScroll => widget.onAutoScrollChanged != null
      ? widget.autoScroll
      : _autoScrollInternal;

  void _toggleAutoScroll() {
    final next = !_autoScroll;
    if (widget.onAutoScrollChanged != null) {
      widget.onAutoScrollChanged!(next);
    } else {
      setState(() => _autoScrollInternal = next);
    }
    if (next) _scrollToTail();
  }

  double get _tailOffset => 0; // `reverse: true` puts the tail at offset 0.

  @override
  void didUpdateWidget(TerminalLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        widget.revision != oldWidget.revision ||
        widget.lines.length != oldWidget.lines.length ||
        !identical(widget.lines, oldWidget.lines);
    if (_autoScroll && changed) {
      // Cheap and idempotent in a reversed list: no maxScrollExtent lookup,
      // so this never forces a full layout of the list.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTail());
    }
    // Controlled auto-scroll turned back on (e.g. from the Logs page
    // header): jump to the tail even if no new line arrived.
    if (widget.autoScroll && !oldWidget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTail());
    }
  }

  void _scrollToTail() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.hasPixels && position.pixels != _tailOffset) {
      _scrollController.jumpTo(_tailOffset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _defaultCopy() {
    Clipboard.setData(ClipboardData(text: widget.lines.join('\n')));
    AppDialogs.showToast(context, 'Logs copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (widget.showHeader) _buildHeader(),
        Expanded(child: _buildLogContent()),
      ],
    );

    if (!widget.isModal) {
      return Container(color: AppColors.background, child: body);
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
        AppIconButton(
          icon: _autoScroll
              ? LucideIcons.arrowDownCircle
              : LucideIcons.pauseCircle,
          tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          onPressed: _toggleAutoScroll,
          color: _autoScroll ? AppColors.success : AppColors.textMuted,
        ),
        if (widget.onClear != null)
          AppIconButton(
            icon: Icons.clear_all,
            tooltip: 'Clear',
            onPressed: widget.onClear,
          ),
        AppIconButton(
          icon: Icons.copy,
          tooltip: 'Copy all',
          onPressed: widget.onCopy ?? _defaultCopy,
        ),
        if (widget.onOpenFile != null)
          AppIconButton(
            icon: LucideIcons.fileText,
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
            fontSize: AppTextSize.xs,
          ),
        ),
      );
    }

    final count = widget.lines.length;
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.all(12),
        itemCount: count,
        // Keep a little extra materialised around the viewport so a wheel
        // notch doesn't show an empty strip before the next rows build.
        scrollCacheExtent: const ScrollCacheExtent.pixels(600),
        itemBuilder: (context, index) {
          // Row 0 sits at the bottom: index 0 is the newest line.
          final line = widget.lines[count - 1 - index];
          return Text(
            line.length > TerminalLogView.maxRenderedLineLength
                ? '${line.substring(0, TerminalLogView.maxRenderedLineLength)}…'
                : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: AppTextSize.xs,
              color: _colorFor(line),
              height: 1.4,
            ),
          );
        },
      ),
    );
  }

  static Color _colorFor(String line) {
    if (line.contains('[ERROR]') || line.contains('Error:')) {
      return AppColors.error;
    }
    if (line.contains('[WARN]') || line.contains('Warning:')) {
      return AppColors.warning;
    }
    return AppColors.textPrimary;
  }
}
