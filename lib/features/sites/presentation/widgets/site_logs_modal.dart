import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../../../core/config/app_config.dart';
import '../../../../shared/utils/modal_sizing.dart';
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
  /// Keep a bounded local copy aligned with the manager's default tail
  /// (CircularLogBuffer caps at 1,000 lines). Trimming on append avoids
  /// per-line list copies that grow with the retained history.
  static const int _maxLines = 1000;
  final List<String> _lines = [];

  /// Bumped on every append so the viewer sees changes even when the list
  /// length stays pinned at [_maxLines].
  int _revision = 0;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    final manager = ref.read(cliProcessManagerProvider);
    _lines.addAll(manager.getLogBuffer(widget.site.id));
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines);
    }

    _subscription = manager.getLogStream(widget.site.id).listen((line) {
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

  void _clearLogs() {
    ref.read(cliProcessManagerProvider).clearLogs(widget.site.id);
    setState(() {
      _lines.clear();
      _revision++;
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
    final dims = modalDimensions(context, ModalSize.xl);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: dims.insetPadding,
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: TerminalLogView(
          title: 'Logs: ${widget.site.domain}',
          lines: _lines,
          revision: _revision,
          isModal: true,
          onClear: _clearLogs,
          onOpenFile: _openLogFile,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
