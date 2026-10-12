import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../../../core/services/background_process.dart';
import '../domain/cron_expression.dart';
import '../domain/cron_job.dart';

/// Outcome of one cron run.
class CronRunResult {
  final int exitCode;
  final String output;
  const CronRunResult({required this.exitCode, required this.output});
}

/// One entry in a job's in-memory run history.
class RunRecord {
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode; // null while the run is in flight
  final String output;

  const RunRecord({
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.output = '',
  });
}

typedef CronRunner = Future<CronRunResult> Function(CronJob job);
typedef CronClock = DateTime Function();
typedef CronJobLoader = Future<List<CronJob>> Function();
typedef CronJobUpdater = Future<void> Function(CronJob job);

final cronSchedulerProvider = Provider<CronSchedulerService>((ref) {
  // Late-bound Isar for the same reason as supervisorManagerProvider: the DB
  // opens asynchronously, and a `watch` here would rebuild (and stop) the
  // scheduler the moment it lands.
  final service = CronSchedulerService(
    isarResolver: () => ref.read(isarProvider).value,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Runs enabled [CronJob]s on their schedule, in-app only.
///
/// A single `Timer.periodic` calls [tick]; each tick fires every enabled job
/// whose next occurrence has arrived. A job whose previous run is still in
/// flight is skipped, so a long-running command can never stack. History is a
/// RAM ring buffer of [historyLimit] records per job — nothing is persisted
/// beyond the job's own last-run fields.
///
/// Jobs missed while the app was closed are not back-filled: the first time a
/// job is seen its next occurrence is computed forward from "now".
class CronSchedulerService {
  final CronRunner _runner;
  final CronClock _clock;
  final CronJobLoader _loadJobs;
  final CronJobUpdater _updateJob;
  final Isar? Function() _isarResolver;
  final Duration interval;

  /// Maximum run records retained per job (RAM only).
  final int historyLimit = 20;

  final Map<int, DateTime?> _nextRuns = {};
  final Set<int> _running = {};
  final Map<int, List<RunRecord>> _history = {};
  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  Timer? _timer;
  bool _ticking = false;
  bool _disposed = false;

  /// [isar] pins a fixed database (tests); [isarResolver] resolves one lazily
  /// (production), so a scheduler created before the async open still sees it.
  CronSchedulerService({
    CronRunner? runner,
    CronClock? clock,
    CronJobLoader? loadJobs,
    CronJobUpdater? updateJob,
    Isar? isar,
    Isar? Function()? isarResolver,
    this.interval = const Duration(seconds: 30),
  })  : _runner = runner ?? _defaultRunner,
        _clock = clock ?? DateTime.now,
        _loadJobs = loadJobs ?? (() async => const <CronJob>[]),
        _updateJob = updateJob ?? ((_) async {}),
        _isarResolver = isarResolver ?? (isar != null ? () => isar : () => null);

  Isar? get _isar => _isarResolver();

  Stream<int> get statusStream => _statusController.stream;

  bool isRunning(int jobId) => _running.contains(jobId);

  List<RunRecord> historyFor(int jobId) =>
      List.unmodifiable(_history[jobId] ?? const <RunRecord>[]);

  void _notify(int jobId) {
    if (!_statusController.isClosed) _statusController.add(jobId);
  }

  /// The real runner: one shell command, output captured.
  static Future<CronRunResult> _defaultRunner(CronJob job) async {
    final result = await BackgroundProcess.run(
      job.command,
      const [],
      runInShell: true,
      workingDirectory: job.workingDir.isEmpty ? null : job.workingDir,
    );
    final out = '${result.stdout}${result.stderr}'.trim();
    return CronRunResult(exitCode: result.exitCode, output: out);
  }

  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Loads the current jobs, from Isar when configured, else from the injected
  /// loader.
  Future<List<CronJob>> _jobs() async {
    final isar = _isar;
    if (isar != null) return isar.cronJobs.where().findAll();
    return _loadJobs();
  }

  Future<void> _persist(CronJob job) async {
    final isar = _isar;
    if (isar != null) {
      isar.write((_) => isar.cronJobs.put(job));
      return;
    }
    await _updateJob(job);
  }

  /// One scheduler pass: fire every due, enabled job. Called by the periodic
  /// timer and directly by tests.
  Future<void> tick() async {
    if (_disposed || _ticking) return;
    _ticking = true;
    try {
      final now = _clock();
      final jobs = await _jobs();

      final liveIds = <int>{};
      for (final job in jobs) {
        liveIds.add(job.id);
        if (!job.enabled) continue;
        if (!CronExpression.isValid(job.schedule)) continue;

        final expr = CronExpression.parse(job.schedule);
        if (!_nextRuns.containsKey(job.id)) {
          // First sighting: schedule forward from now (no back-fill).
          _nextRuns[job.id] = expr.nextOccurrence(now);
        }
        final next = _nextRuns[job.id];
        if (next == null) continue; // unsatisfiable schedule
        if (now.isBefore(next)) continue;

        // Advance past this occurrence before running, so a run that outlives
        // its interval cannot queue up a backlog of missed firings.
        _nextRuns[job.id] = expr.nextOccurrence(now);

        if (_running.contains(job.id)) continue; // no overlap

        // Fire without awaiting: a long-running command must not stall the
        // other due jobs in this same pass (the `_ticking` guard would
        // otherwise make the next periodic tick a no-op for its whole
        // duration). Per-job no-overlap is enforced by `_running`.
        unawaited(_execute(job));
      }

      // Drop bookkeeping for jobs that no longer exist.
      _nextRuns.removeWhere((id, _) => !liveIds.contains(id));
    } finally {
      _ticking = false;
    }
  }

  /// Runs [job] immediately, ignoring its schedule. No-op if it is already
  /// running.
  Future<void> runNow(CronJob job) async {
    if (_running.contains(job.id)) return;
    await _execute(job);
  }

  Future<void> _execute(CronJob job) async {
    _running.add(job.id);
    _notify(job.id);

    final startedAt = _clock();
    final record = RunRecord(startedAt: startedAt, output: '');
    _appendHistory(job.id, record);
    // A copy so the in-flight record can be replaced on completion.
    final index = _history[job.id]!.indexOf(record);

    job.lastRunAt = startedAt;
    job.lastStatus = 'running';
    await _persist(job);

    CronRunResult result;
    try {
      result = await _runner(job);
    } catch (e) {
      result = CronRunResult(exitCode: -1, output: 'Failed to run: $e');
    }

    final finishedAt = _clock();
    final success = result.exitCode == 0;

    _history[job.id]![index] = RunRecord(
      startedAt: startedAt,
      finishedAt: finishedAt,
      exitCode: result.exitCode,
      output: result.output,
    );

    _running.remove(job.id);

    job.lastStatus = success ? 'success' : 'failed';
    job.lastExitCode = result.exitCode;
    await _persist(job);

    _notify(job.id);
  }

  void _appendHistory(int jobId, RunRecord record) {
    final list = _history.putIfAbsent(jobId, () => <RunRecord>[]);
    list.insert(0, record); // newest first
    while (list.length > historyLimit) {
      list.removeLast();
    }
  }

  void dispose() {
    _disposed = true;
    stop();
    _running.clear();
    _history.clear();
    _nextRuns.clear();
    if (!_statusController.isClosed) _statusController.close();
  }
}