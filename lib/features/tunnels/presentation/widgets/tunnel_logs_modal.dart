import 'package:flutter/material.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../domain/tunnel_session.dart';

class TunnelLogsModal extends StatelessWidget {
  final String tunnelName;
  final TunnelSession? session;

  const TunnelLogsModal({
    super.key,
    required this.tunnelName,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final logs = session?.logs ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: 800,
        height: 500,
        child: TerminalLogView(
          title: 'Logs - $tunnelName',
          lines: logs,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
