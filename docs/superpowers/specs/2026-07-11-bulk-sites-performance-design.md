# Bulk Site Create/Delete Performance — Design

**Date:** 2026-07-11
**Status:** Approved (design)
**Area:** `lib/features/sites`

## Problem

Batch Create (`_handleBatchCreateSites`) and Bulk Delete (`_handleBulkDelete`) in
`lib/features/sites/presentation/sites_page.dart` process sites **one at a time** in a
sequential loop, calling the single-site `addSite` / `deleteSite` methods. Those methods
were designed for a single site and re-run expensive "finalize" work on every iteration.

### Root-cause bottlenecks

1. **Hosts file rewritten N times (worst offender).** `_updateHostsFile()` runs once per
   site (`sites_provider.dart:118` and `:206`). Each call reads all sites from Isar, reads
   the whole hosts file, and rewrites the entire `C:\Windows\System32\drivers\etc\hosts`.
   When the app is not elevated, each write spawns an elevated PowerShell process
   (`hosts_repository.dart:43`) — O(N) redundant system-file writes / potential UAC prompts.
2. **SSL cert generation is sequential.** Each SSL site spawns `mkcert.exe`
   (`ssl_service.dart:126`) plus a retry loop that sleeps up to `3×1s`
   (`sites_provider.dart:87-101`). Run serially, the time compounds.
3. **State refreshed N times.** Every `addSite`/`deleteSite` sets
   `state = AsyncValue.data(findAll())`, re-querying the DB and rebuilding the whole
   site table UI on each iteration.
4. **N separate Isar write transactions** instead of one batched transaction.

The existing loops already defer webserver restart (`restartWebserver: false`) but do **not**
defer the hosts update, state refresh, or parallelize SSL.

## Goals

- Make bulk create/delete substantially faster.
- Add a progress dialog with live feedback and a Cancel button.
- Preserve existing single-site behavior.

## Chosen approach

**Defer finalization + bounded parallelism** (Approach B). Rejected: A (defer only — leaves
SSL serial), C (isolate — high complexity, work is I/O/process-spawn bound, not CPU).

## Architecture — separate per-site work from shared finalization

Refactor `SitesNotifier` so per-site work and shared finalization are distinct:

- **`_addSiteCore(spec)`** — per-site only: validate domain, build `SiteModel`, generate SSL
  cert (with retry), write vhost files. Does **not** touch hosts, refresh state, or restart.
- **`_deleteSiteCore(site)`** — per-site only: remove vhost/ssl/logs files for one site.
- **`_finalize()`** — runs **once**: `_updateHostsFile()` + refresh state (`findAll`) +
  `restartWebservers()`.

Existing `addSite` / `deleteSite` keep current behavior = `core` + `_finalize()`.

New batch methods:

- `Future<BatchResult> addSitesBatch(List<BatchSiteSpec> specs, {ProgressCb? onProgress, CancelToken? cancel})`
- `Future<BatchResult> deleteSitesBatch(List<int> ids, {ProgressCb? onProgress, CancelToken? cancel})`

**DB batching:** single `writeTxn` using `putAll` (create) / `deleteAll` (delete) instead of
N transactions.

## Concurrency

Pure helper:

```dart
Future<List<R>> _runBounded<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item, int index) task, {
  CancelToken? cancel,
});
```

- Worker-pool semantics (not fixed chunks): up to `concurrency` tasks in flight; as one
  finishes, the next is admitted. A slow cert does not block the whole group.
- Checks `cancel` before admitting a new task → stops admitting, keeps completed results.
- Returns results in original index order for reporting.
- **Concurrency = 8, hardcoded** (no Settings option — not needed by users).

**Ordering:**
- Create: one `writeTxn` (`putAll`) first to persist sites, then fan out SSL + vhost writes.
- Delete: fan out file removals first, then one `writeTxn` (`deleteAll`).

**SSL retry change:** remove the fixed `3×sleep(1s)` loop. After `mkcert` returns, check
cert/key files exist; if missing, retry once immediately (no fixed sleep). `BackgroundProcess.run`
already awaits process exit, so files are normally present immediately.

## Progress, Cancel & data flow

### Models (pure, testable)

- `BatchProgress { int current; int total; String currentLabel; BatchPhase phase; }`
  where `BatchPhase = processing | finalizing`.
- `BatchResult { int succeeded; int skipped; List<String> failed; bool cancelled; }`
- `CancelToken { bool isCancelled; void cancel(); }`

### `BatchProgressDialog` (new widget)

`StatefulWidget`, opened via `showDialog(barrierDismissible: false)`, bound to a
`ValueNotifier<BatchProgress>`:

- Title (Creating / Deleting sites), `X / N` + percentage, determinate
  `LinearProgressIndicator`, current domain label.
- When `phase == finalizing`: show "Updating hosts & restarting webservers…" and hide Cancel
  (final phase is not cancellable).
- Cancel button → `token.cancel()`, label becomes "Cancelling…", button disabled.

Styled to match existing `AppColors` / `AppTextSize` conventions.

### Data flow (in `sites_page`)

1. User confirms → create `progressNotifier` + `token`, open `BatchProgressDialog`.
2. Call `notifier.addSitesBatch(specs, onProgress: (p) => progressNotifier.value = p, cancel: token)`.
3. Batch: one `writeTxn` (`putAll`) → `_runBounded(8, SSL+vhost, cancel)` updating progress
   per completed site → **always `_finalize()`** for whatever was processed (even on cancel),
   with `phase = finalizing`.
4. Done → close dialog → `showSuccess` summary: created X, skipped Y (duplicate domains),
   failed Z, (cancelled if applicable).

### Cancel semantics

Stop admitting new sites; already-created sites are **kept** and finalized (hosts write +
restart reflect what was actually done). Delete is symmetric — already-deleted sites stay
deleted.

### Error handling

- Per-site failure → collected into `failed`, batch continues.
- Hosts write failure (elevation fail) → reported in the summary dialog.

## Extracted pure logic for testing

- `resolveDomainFromTemplate(template, folderName)` — extract the inline template→domain
  mapping currently at `sites_page.dart:352-362`.
- Unit-testable units: `resolveDomainFromTemplate`, `_runBounded` (ordering + max
  concurrency + cancel), `CancelToken`.

## Components summary

1. `BatchProgress`, `BatchResult`, `BatchPhase`, `CancelToken` models.
2. `_runBounded` concurrency helper.
3. `resolveDomainFromTemplate` pure function.
4. `SitesNotifier`: `_addSiteCore`, `_deleteSiteCore`, `_finalize`, `addSitesBatch`,
   `deleteSitesBatch`; refactor `addSite`/`deleteSite` to reuse core + finalize.
5. `BatchProgressDialog` widget.
6. `sites_page` wiring for both batch create and bulk delete.

## Testing

- Unit tests for the pure units above (TDD).
- Manual verification: batch-create N folders and bulk-delete N sites, confirm single hosts
  write, single restart, working progress + cancel.

## Out of scope

- Settings option for concurrency (hardcoded 8).
- Running the batch in a separate isolate (Approach C).
- Any change to single-site UX.
