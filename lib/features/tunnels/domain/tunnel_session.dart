enum TunnelStatus {
  stopped,
  downloadingBinary,
  connecting,
  running,
  error,
}

class TunnelSession {
  final int tunnelId;
  final TunnelStatus status;
  final String? publicUrl;
  final String? webInspectorUrl;
  final double downloadProgress;
  final String? errorMessage;
  final int? pid;
  final DateTime? connectedAt;
  final List<String> logs;

  const TunnelSession({
    required this.tunnelId,
    this.status = TunnelStatus.stopped,
    this.publicUrl,
    this.webInspectorUrl,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.pid,
    this.connectedAt,
    this.logs = const [],
  });

  TunnelSession copyWith({
    TunnelStatus? status,
    String? publicUrl,
    String? webInspectorUrl,
    double? downloadProgress,
    String? errorMessage,
    int? pid,
    DateTime? connectedAt,
    List<String>? logs,
  }) {
    return TunnelSession(
      tunnelId: tunnelId,
      status: status ?? this.status,
      publicUrl: publicUrl ?? this.publicUrl,
      webInspectorUrl: webInspectorUrl ?? this.webInspectorUrl,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      pid: pid ?? this.pid,
      connectedAt: connectedAt ?? this.connectedAt,
      logs: logs ?? this.logs,
    );
  }
}
