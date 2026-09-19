import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../data/cli_process_manager.dart';
import '../../domain/site_model.dart';

class SiteLogsModal extends ConsumerStatefulWidget {
  final SiteModel site;

  const SiteLogsModal({super.key, required this.site});

  @override
  ConsumerState<SiteLogsModal> createState() => _SiteLogsModalState();
}

class _SiteLogsModalState extends ConsumerState<SiteLogsModal> {
  final List<String> _lines = [];
  StreamSubscription<String>? _subscription;

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
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
      child: SizedBox(
        width: 900,
        height: 600,
        child: TerminalLogView(
          title: 'Logs: ${widget.site.domain}',
          lines: _lines,
          isModal: true,
          onClear: _clearLogs,
          onOpenFile: _openLogFile,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
