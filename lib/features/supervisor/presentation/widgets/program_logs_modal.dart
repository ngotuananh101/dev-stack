import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../data/supervisor_manager.dart';
import '../../domain/supervisor_program.dart';

/// Live log viewer for one supervised program. Subscribes to the manager's
/// per-program stream and keeps the buffered history as the initial frame.
class ProgramLogsModal extends StatefulWidget {
  final SupervisorManager manager;
  final SupervisorProgram program;

  const ProgramLogsModal({
    super.key,
    required this.manager,
    required this.program,
  });

  @override
  State<ProgramLogsModal> createState() => _ProgramLogsModalState();
}

class _ProgramLogsModalState extends State<ProgramLogsModal> {
  /// The modal keeps its own bounded copy of the stream: the manager's
  /// circular buffer caps at 1,000 lines, and `[..._lines, line]` per
  /// incoming line copies the whole list every time (quadratic once a chatty
  /// program fills the buffer). A queue with a matching cap keeps appends
  /// O(1) and the list the same size the underlying buffer would be.
  static const int _maxLines = 1000;
  final List<String> _lines = [];

  /// Bumped on every append so the viewer knows the stable list changed even
  /// when its length is pinned at [_maxLines].
  int _revision = 0;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _lines.addAll(widget.manager.getLogBuffer(widget.program.id));
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }
    _subscription = widget.manager.getLogStream(widget.program.id).listen((
      line,
    ) {
      if (!mounted) return;
      _lines.add(line);
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
      setState(() => _revision++);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.xl);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: dims.insetPadding,
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: TerminalLogView(
          title: 'Logs - ${widget.program.name}',
          lines: _lines,
          revision: _revision,
          onClear: () => setState(() {
            widget.manager.clearLogs(widget.program.id);
            _lines.clear();
            _revision++;
          }),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
