import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/window_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';

const double kAppHeaderHeight = 36.0;
const double kWindowCaptionButtonWidth = 46.0;

class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _isMaximized = false;
  ListenerId? _windowListenerId;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // The window may not be discoverable yet when this builds on Windows, so
    // the listener is attached once it exists. `whenCurrentWindow` runs the
    // callback immediately when the window is already there.
    whenCurrentWindow((window) {
      if (_disposed) return;
      final isMaximized = window.isMaximized;
      _windowListenerId = window.addListener(_onWindowEvent);
      // Immediately, inside initState, the first build picks this up anyway;
      // on Windows the window is adopted later, and then the icon has to be
      // redrawn to match.
      if (mounted && isMaximized != _isMaximized) {
        setState(() => _isMaximized = isMaximized);
      } else {
        _isMaximized = isMaximized;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    final listenerId = _windowListenerId;
    if (listenerId != null) {
      currentWindow()?.removeListener(listenerId);
    }
    super.dispose();
  }

  // nativeapi reports a restore for both "no longer maximized" and "no longer
  // minimized", so the new state is read back from the window rather than
  // inferred from the event alone.
  void _onWindowEvent(WindowEvent event) {
    switch (event) {
      case WindowMaximizedEvent():
      case WindowRestoredEvent():
        final isMaximized = currentWindow()?.isMaximized ?? false;
        if (mounted && isMaximized != _isMaximized) {
          setState(() => _isMaximized = isMaximized);
        }
      default:
        break;
    }
  }

  void _handleMinimize() {
    currentWindow()?.minimize();
  }

  void _handleMaximizeToggle() {
    final window = currentWindow();
    if (window == null) return;
    if (_isMaximized) {
      window.unmaximize();
    } else {
      window.maximize();
    }
  }

  void _handleClose() {
    // `close()` asks the window's close listeners first, which is where
    // WindowService decides between hiding to the tray and quitting.
    currentWindow()?.close();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kAppHeaderHeight,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.0)),
      ),
      child: Row(
        children: [
          _buildBrand(),
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox(height: kAppHeaderHeight, width: double.infinity),
            ),
          ),
          _buildWindowControls(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/icon.png', width: 16, height: 16),
          const SizedBox(width: 8),
          const Text(
            'Ponta DevStack',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTextSize.xs,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: LucideIcons.minus,
          tooltip: 'Minimize',
          onTap: _handleMinimize,
        ),
        _WindowControlButton(
          icon: _isMaximized ? LucideIcons.copy : LucideIcons.square,
          tooltip: _isMaximized ? 'Restore' : 'Maximize',
          iconSize: _isMaximized ? 12.0 : 13.0,
          onTap: _handleMaximizeToggle,
        ),
        _WindowControlButton(
          icon: LucideIcons.x,
          tooltip: 'Close',
          isClose: true,
          onTap: _handleClose,
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 14.0,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isHovering
        ? (widget.isClose ? AppColors.error : AppColors.surfaceLight)
        : Colors.transparent;

    final iconColor = _isHovering
        ? (widget.isClose ? AppColors.textOnColor : AppColors.textPrimary)
        : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: bgColor,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox(
              width: kWindowCaptionButtonWidth,
              height: kAppHeaderHeight,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
