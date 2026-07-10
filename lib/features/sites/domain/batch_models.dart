/// Phase of a running batch operation.
enum BatchPhase { processing, finalizing }

/// Snapshot of batch progress for the progress dialog.
class BatchProgress {
  final int current;
  final int total;
  final String currentLabel;
  final BatchPhase phase;

  const BatchProgress({
    required this.current,
    required this.total,
    required this.currentLabel,
    required this.phase,
  });

  double get fraction => total == 0 ? 0.0 : current / total;
}

/// Outcome summary of a batch operation.
class BatchResult {
  final int succeeded;
  final int skipped;
  final List<String> failed;
  final bool cancelled;

  const BatchResult({
    this.succeeded = 0,
    this.skipped = 0,
    this.failed = const [],
    this.cancelled = false,
  });
}

/// Cooperative cancellation flag shared between the UI and a batch operation.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Input describing one site to create in a batch.
class BatchSiteSpec {
  final String domain;
  final String rootDir;
  final String siteType;
  final String? phpAppId;
  final bool useSsl;

  const BatchSiteSpec({
    required this.domain,
    required this.rootDir,
    required this.siteType,
    this.phpAppId,
    this.useSsl = false,
  });
}
