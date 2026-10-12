import 'package:flutter/material.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../../../shared/utils/modal_sizing.dart';
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
    final dims = modalDimensions(context, ModalSize.xl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: dims.insetPadding,
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: TerminalLogView(
          title: 'Logs - $tunnelName',
          lines: logs,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
