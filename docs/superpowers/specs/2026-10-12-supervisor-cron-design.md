# Supervisor & Cronjob — Design

**Date:** 2026-10-12
**Status:** Approved (design)
**Area:** `lib/features/supervisor`, `lib/features/cron`

## Problem

DevStack manages stack apps (PHP, MySQL, Nginx…), CLI sites, and tunnels, but
offers no way to:

1. **Keep an arbitrary long-running process alive.** A queue worker
   (`php artisan queue:work`), a Node worker, a websocket server, or a
   `npm run dev` process dies silently on a crash and is never restarted. The
   existing `CliProcessManager` starts/stops processes but has **no watchdog** —
   on natural exit it just settles to `stopped`.
2. **Run a command on a schedule.** There is no cron/scheduler primitive
   anywhere in the codebase (no `Timer.periodic`, no cron parser). Users must
   fall back to OS-level schedulers configured by hand.

Both are standard features of local dev-environment tools (Laragon ships both a
Supervisor and a Cron/Scheduler). This design adds both as first-class
DevStack features.

## Scope decisions

| Decision | Choice | Rationale |
|---|---|---|
| When does Cron run? | **In-app only** (runs while DevStack is open, including minimized to tray) | Portable across Windows/Linux, no elevation, no per-OS backends. OS-level integration is explicitly a future phase; the scheduler is structured so a backend can be swapped in later. |
| Sidebar placement | **Two separate tabs** (`Supervisor`, `Cron`) | Matches Laragon; clear separation of concepts. |
| Supervisor vs CLI sites | **Separate, generic feature** | Keeps the `SiteModel`/site concept clean; avoids risk to the shipping sites feature. `CliProcessManager` is a *pattern* to mirror, not to extend. |
| Cron expression support | **Full 5-field + presets** | `*` `,` `-` `/`, plus `@hourly @daily @weekly @monthly @yearly` and quick presets in the form. |

**Artifact note:** Supervisor and Cron are two independent subsystems, but they
share the same plumbing edits (Isar schema registration, `NavigationTab` enum,
sidebar, `main.dart` routing). They are delivered as **one spec → one plan →
one PR** to avoid merge conflicts on those shared files.

## Prior art in the codebase

| Component | File | How it is reused |
|---|---|---|
| `CliProcessManager` | `lib/features/sites/data/cli_process_manager.dart` | Direct template for the Supervisor: `setsid`/`taskkill` process-tree spawn, `CircularLogBuffer` (1000 lines), per-program log file, broadcast `statusStream`, `ref.onDispose`. |
| `TunnelManagerService` | `lib/features/tunnels/data/tunnel_manager_service.dart` | Template for the service layer: `Map<id, Session>` + broadcast `sessionsStream` + Isar persistence + `Provider` with `ref.onDispose`. |
| `BackgroundProcess` | `lib/core/services/background_process.dart` | `run`/`start`/`stopManaged`; no-console spawn on Windows. Used by the Cron scheduler to run one-shot commands. |
| `TerminalLogView` | `lib/shared/widgets/terminal_log_view.dart` | Reused for both log modals. |
| `AppButton`, `AppModalHeader`, `modal_sizing` | `lib/shared/widgets`, `lib/shared/utils/modal_sizing.dart` | All new UI. |

## Part A — Supervisor

### A.1 Domain model — `lib/features/supervisor/domain/supervisor_program.dart`

```dart
@collection
class SupervisorProgram {
  int id = 0;                          // isar.<col>.autoIncrement() on insert
  @Index(unique: true)
  late String name;
  late String command;                 // e.g. "php artisan queue:work"
  late String workingDir;
  String environmentJson = '{}';       // extra env vars, merged over parent env
  bool autoStart = false;              // start when the app opens
  bool autoRestart = true;             // watchdog on/off
  int maxRestarts = 5;                 // max restarts within the window
  int restartWindowSeconds = 60;       // rolling window for maxRestarts
  int restartDelaySeconds = 2;         // base backoff delay
  bool enabled = true;                 // master switch (disabled = never starts)
  DateTime? createdAt;
}
```

`environmentJson` follows the existing `*Json` convention (see
`AppModel.packageManagerCommandsJson`, `TunnelModel`), keeping Isar schema flat.

### A.2 Manager — `lib/features/supervisor/data/supervisor_manager.dart`

Mirrors `CliProcessManager` and adds a watchdog.

**Public API**

```dart
Future<bool> start(SupervisorProgram program);
Future<bool> stop(int programId);
Future<bool> restart(SupervisorProgram program);
Future<void> startAll();
Future<void> stopAll();

bool isRunning(int programId);
int? getPid(int programId);
SupervisorStatus statusOf(int programId);

List<String> getLogBuffer(int programId);
Stream<String> getLogStream(int programId);
void clearLogs(int programId);

Stream<int> get statusStream;   // broadcast: program ids whose status changed
void dispose();
```

**Status enum** (in-memory, not persisted):

```dart
enum SupervisorStatus { stopped, starting, running, stopping, restarting, fatal }
```

**Watchdog / auto-restart rules** (the core new logic):

- Each managed process carries an `explicitlyStopped` flag, set by `stop()` /
  `stopAll()` / `dispose()`. This distinguishes a *deliberate* stop from a
  *crash*.
- On `exitCode`, if `!explicitlyStopped && program.enabled && program.autoRestart`:
  1. Record the restart timestamp in a rolling window of
     `restartWindowSeconds`.
  2. If the count in the window exceeds `maxRestarts` → set status `fatal`,
     append a log line (`"Exceeded max restarts (N) in Ns — giving up"`), and
     **do not restart**.
  3. Otherwise schedule a restart after `restartDelaySeconds * 2^(attempts-1)`
     (exponential backoff, capped at 60 s), set status `restarting`, then
     re-spawn.
- If `explicitlyStopped` → settle to `stopped` (no restart).
- A fresh successful start resets the restart-window counter.

**Process spawn** reuses the exact `CliProcessManager` mechanics: on POSIX
`setsid /bin/sh -c "<command>"` (pid == pgid → `kill -9 -- -<pid>` kills the
tree); on Windows `cmd.exe /c "<command>"` with `taskkill /F /T /PID`. Output is
teed to a `CircularLogBuffer` (1000 lines), a broadcast stream, and a per-program
log file under `<baseDir>/logs/supervisor/<name>.log`.

**Provider:** `supervisorManagerProvider` — a `Provider<SupervisorManager>` with
`ref.onDispose(() => manager.dispose())`, like `cliProcessManagerProvider`.

### A.3 UI — `lib/features/supervisor/presentation/`

- `supervisor_page.dart` — header + table + auto-start wiring; a
  `StreamProvider`/`NotifierProvider` exposes programs (Isar watch, like
  `tunnelsStreamProvider`) and live status (from `statusStream`).
- `widgets/supervisor_table.dart` — columns: name, status chip, PID, uptime,
  actions (Start/Stop/Restart/Logs/Edit/Delete).
- `widgets/program_form_modal.dart` (`ModalSize.lg`) — create/edit: name,
  command, working dir (with folder picker), env vars (key/value editor),
  auto-start, auto-restart + max/window/delay, enabled.
- `widgets/program_logs_modal.dart` — `TerminalLogView` bound to
  `getLogBuffer`/`getLogStream`.

## Part B — Cronjob

### B.1 Domain model — `lib/features/cron/domain/cron_job.dart`

```dart
@collection
class CronJob {
  int id = 0;
  @Index(unique: true)
  late String name;
  late String schedule;        // "*/5 * * * *" or "@daily"
  late String command;
  late String workingDir;
  bool enabled = true;
  DateTime? lastRunAt;
  String? lastStatus;          // 'success' | 'failed' | 'running'
  int? lastExitCode;
  DateTime? createdAt;
}
```

### B.2 Expression parser — `lib/features/cron/domain/cron_expression.dart`

Pure, dependency-free, unit-testable.

```dart
class CronExpression {
  static bool isValid(String expression);
  static String? validate(String expression);   // null = ok, else message

  /// Next matching minute strictly after [from]. Null if none within the
  /// search horizon (4 years) — e.g. Feb 30.
  DateTime? nextOccurrence(DateTime from);

  /// Human-readable summary, e.g. "Every 5 minutes".
  String describe();
}
```

Supported grammar (5 fields: minute hour day-of-month month day-of-week):

- `*` any value
- `,` list (`1,15,30`)
- `-` range (`1-5`)
- `/` step (`*/5`, `0-30/10`)
- Presets: `@hourly @daily @midnight @weekly @monthly @yearly @annually`
- Standard cron DOW: `0` and `7` both = Sunday.
- Day-of-month and day-of-week are OR-combined when both are restricted
  (standard Vixie cron semantics).

`nextOccurrence` scans forward minute-by-minute from `from + 1 minute`, bounded
by a 4-year horizon to guarantee termination.

### B.3 Scheduler — `lib/features/cron/data/cron_scheduler_service.dart`

```dart
class CronSchedulerService {
  void start();                         // begins the periodic tick
  void stop();

  Future<void> runNow(CronJob job);     // manual trigger, ignores schedule
  bool isRunning(int jobId);            // a run in flight for this job

  Stream<int> get statusStream;         // job ids whose run state changed
  List<RunRecord> historyFor(int jobId);
  void dispose();
}

class RunRecord {
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode;                  // null while running
  final String output;                  // stdout + stderr, capped
}
```

- **Single `Timer.periodic(const Duration(seconds: 30))`.** On each tick,
  every `enabled` job whose `nextRunAt <= now` fires.
- **No overlap:** if a run for a job is still in flight, the tick skips that job
  (logged once), so a long-running command can never stack.
- Execution via `BackgroundProcess.run(command, [], runInShell: true,
  workingDirectory: job.workingDir)` capturing stdout/stderr/exitCode; update
  `lastRunAt`/`lastStatus`/`lastExitCode` in Isar.
- History: in-memory ring buffer, **20 records per job** (RAM only, matching the
  existing "process state is in-memory" convention).
- **In-app only:** the timer lives in the app process. Jobs missed while the app
  was closed are **not** back-filled — on startup the next occurrence is
  computed from "now" forward. This limitation is documented in the UI (a hint
  under the schedule field) and in `docs/`.
- Provider: `cronSchedulerProvider` (`Provider<CronSchedulerService>` with
  `ref.onDispose`), started from `main.dart` after the DB opens.

### B.4 UI — `lib/features/cron/presentation/`

- `cron_page.dart` — header + table; Isar-watch provider + status stream.
- `widgets/cron_table.dart` — columns: name, schedule (+ human description),
  last run, last status, enabled toggle, actions (Run now/History/Edit/Delete).
- `widgets/cron_form_modal.dart` (`ModalSize.lg`) — name, schedule (text field +
  preset dropdown: Every 5 min / Hourly / Daily / Weekly / Monthly), live
  validation + "Next run: …" preview, command, working dir, enabled.
- `widgets/run_history_modal.dart` — recent runs with status, duration, output.

## Part C — Shared plumbing

| Change | File |
|---|---|
| Register `SupervisorProgramSchema` + `CronJobSchema` | `lib/core/database/isar_provider.dart` (**both** the initial open and the corruption-recovery re-open schema lists) |
| `NavigationTab { …, supervisor, cron }` | `lib/shared/providers/navigation_provider.dart` |
| Two sidebar items | `lib/shared/layouts/sidebar.dart` |
| Two `case` branches | `lib/main.dart` → `MainScreen._buildPage` |
| Start scheduler + auto-start supervisor programs on launch | `lib/main.dart` (after DB open), mirroring existing tunnel/app auto-start |
| Clean shutdown | `lib/core/services/window_service.dart` — call `supervisorManager.stopAll()` and `cronScheduler.stop()` alongside the existing `cliProcessManager.stopAll()` |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` for the two new `@collection` `.g.dart` files |

## Part D — Testing

TDD (RED → GREEN) throughout.

- **`CronExpression` (pure, highest value):** `* * * * *`, `*/5 * * * *`,
  `0 9 * * 1-5`, `0 0 1 * *`, `0 0 * * 0` (Sunday), `@daily`, DOW `7` == Sunday,
  invalid expressions rejected, `nextOccurrence` across hour/day/month/year
  boundaries, Feb-30 → null.
- **Supervisor watchdog:** with a fake spawner (as
  `test/features/sites/cli_process_manager_test.dart` does) — verify restart on
  crash, **no** restart after explicit `stop()`, backoff timing, and
  `maxRestarts` exhaustion → `fatal`.
- **Cron scheduler:** inject a fake clock + fake runner — verify a due job runs,
  a not-due job does not, `enabled=false` is skipped, no overlap, history capped
  at 20.
- **Widget:** `supervisor_table` / `cron_table` render status + actions;
  `cron_form_modal` validates and previews next run.

## Part E — Risks & limitations

1. **App closed = Cron stops.** In-app only by decision; missed runs are not
   back-filled. Documented in the UI and docs.
2. **Arbitrary shell commands.** Same trust level as the existing CLI-sites
   feature (user-authored commands). No allowlist; documented only.
3. **Restart storms** are bounded by `maxRestarts`/`restartWindowSeconds` →
   `fatal`, so a crashing program cannot spawn processes unbounded.
4. **Orphaned children on abrupt app exit.** Pre-existing repo limitation (no
   PID files); mitigated on clean shutdown by `stopAll()` in `window_service`.

## Out of scope

- OS-level scheduling (Windows Task Scheduler, systemd timers, launchd).
- Cron second-granularity, `@reboot`, and named-timezone scheduling.
- Persistent run history beyond the 20-entry RAM ring buffer.
- Refactoring `CliProcessManager` to share a common base with the Supervisor.
