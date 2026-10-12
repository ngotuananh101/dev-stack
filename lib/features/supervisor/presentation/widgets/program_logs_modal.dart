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
  late List<String> _lines;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _lines = widget.manager.getLogBuffer(widget.program.id);
    _subscription = widget.manager.getLogStream(widget.program.id).listen((line) {
      if (!mounted) return;
      setState(() => _lines = [..._lines, line]);
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
          onClear: () => setState(() {
            widget.manager.clearLogs(widget.program.id);
            _lines = const [];
          }),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
