# Bulk Site Create/Delete Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bulk site create/delete fast by deferring shared finalization (hosts write, state refresh, webserver restart) to run once, running per-site SSL/vhost work in bounded parallel, and adding a progress dialog with Cancel.

**Architecture:** Split `SitesNotifier`'s single-site methods into per-site "core" work vs a shared `_finalize()` step. New `addSitesBatch` / `deleteSitesBatch` methods persist DB changes in one transaction, fan out per-site file/SSL work through a bounded worker-pool helper (concurrency 8), then finalize once. A new `BatchProgressDialog` shows live progress and a Cancel button.

**Tech Stack:** Flutter, Riverpod (riverpod_generator), Isar, `flutter_test`.

## Global Constraints

- All file paths in code use complete absolute Windows paths where the existing code does; follow existing patterns in each file.
- Concurrency for bulk SSL/vhost work is **8**, hardcoded (no Settings option).
- Preserve existing single-site `addSite` / `deleteSite` behavior exactly.
- Match existing styling conventions: `AppColors`, `AppTextSize`, `lucide_icons`.
- Isar `SiteModel.domain` has a `@Index(unique: true)` — batch inserts must not create duplicate domains.
- Pure units (models, `runBounded`, `resolveDomainFromTemplate`) must have zero Flutter/Isar/Process dependencies so they are unit-testable.

---

### Task 1: Domain→template pure function

Extract the inline template→domain mapping (currently `sites_page.dart:352-362`) into a pure, testable function.

**Files:**
- Create: `D:\Source\ponta\dev-stack\lib\features\sites\domain\site_domain_utils.dart`
- Test: `D:\Source\ponta\dev-stack\test\features\sites\site_domain_utils_test.dart`

**Interfaces:**
- Produces: `String resolveDomainFromTemplate(String template, String folderName)` — replaces the first matching placeholder (`[site-name]`, `{name}`, `{site-name}`) in `template` with `folderName`; if no placeholder present, returns `template` unchanged.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dev_stack/features/sites/domain/site_domain_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDomainFromTemplate', () {
    test('replaces [site-name] placeholder', () {
      expect(resolveDomainFromTemplate('[site-name].test', 'blog'), 'blog.test');
    });

    test('replaces {name} placeholder', () {
      expect(resolveDomainFromTemplate('{name}.local', 'shop'), 'shop.local');
    });

    test('replaces {site-name} placeholder', () {
      expect(resolveDomainFromTemplate('{site-name}.dev', 'api'), 'api.dev');
    });

    test('returns template unchanged when no placeholder', () {
      expect(resolveDomainFromTemplate('fixed.test', 'blog'), 'fixed.test');
    });

    test('replaces all occurrences of the matched placeholder', () {
      expect(
        resolveDomainFromTemplate('[site-name].[site-name].test', 'x'),
        'x.x.test',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/site_domain_utils_test.dart`
Expected: FAIL — `site_domain_utils.dart` not found / `resolveDomainFromTemplate` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
/// Resolves a site domain from a template by replacing the first matching
/// placeholder with [folderName]. Supported placeholders (checked in order):
/// `[site-name]`, `{name}`, `{site-name}`. If none is present, returns
/// [template] unchanged.
String resolveDomainFromTemplate(String template, String folderName) {
  if (template.contains('[site-name]')) {
    return template.replaceAll('[site-name]', folderName);
  } else if (template.contains('{name}')) {
    return template.replaceAll('{name}', folderName);
  } else if (template.contains('{site-name}')) {
    return template.replaceAll('{site-name}', folderName);
  }
  return template;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/site_domain_utils_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/domain/site_domain_utils.dart test/features/sites/site_domain_utils_test.dart
git commit -m "feat: extract resolveDomainFromTemplate pure function"
```

---

### Task 2: Batch models + CancelToken

Pure value types for progress reporting and cancellation.

**Files:**
- Create: `D:\Source\ponta\dev-stack\lib\features\sites\domain\batch_models.dart`
- Test: `D:\Source\ponta\dev-stack\test\features\sites\batch_models_test.dart`

**Interfaces:**
- Produces:
  - `enum BatchPhase { processing, finalizing }`
  - `class BatchProgress { final int current; final int total; final String currentLabel; final BatchPhase phase; const BatchProgress({required this.current, required this.total, required this.currentLabel, required this.phase}); double get fraction; }` — `fraction` returns `total == 0 ? 0.0 : current / total`.
  - `class BatchResult { final int succeeded; final int skipped; final List<String> failed; final bool cancelled; const BatchResult({this.succeeded = 0, this.skipped = 0, this.failed = const [], this.cancelled = false}); }`
  - `class CancelToken { bool get isCancelled; void cancel(); }`
  - `class BatchSiteSpec { final String domain; final String rootDir; final String siteType; final String? phpAppId; final bool useSsl; const BatchSiteSpec({required this.domain, required this.rootDir, required this.siteType, this.phpAppId, this.useSsl = false}); }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancelToken', () {
    test('starts not cancelled', () {
      expect(CancelToken().isCancelled, isFalse);
    });

    test('cancel() sets isCancelled', () {
      final token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  group('BatchProgress.fraction', () {
    test('is 0 when total is 0', () {
      const p = BatchProgress(
        current: 0,
        total: 0,
        currentLabel: '',
        phase: BatchPhase.processing,
      );
      expect(p.fraction, 0.0);
    });

    test('is current/total otherwise', () {
      const p = BatchProgress(
        current: 3,
        total: 6,
        currentLabel: 'a.test',
        phase: BatchPhase.processing,
      );
      expect(p.fraction, 0.5);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/batch_models_test.dart`
Expected: FAIL — `batch_models.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/sites/batch_models_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/domain/batch_models.dart test/features/sites/batch_models_test.dart
git commit -m "feat: add batch models and CancelToken"
```

---

### Task 3: Bounded worker-pool helper

Generic concurrency helper: run up to N tasks at once, preserve result order, stop admitting work when cancelled.

**Files:**
- Create: `D:\Source\ponta\dev-stack\lib\shared\utils\bounded_runner.dart`
- Test: `D:\Source\ponta\dev-stack\test\shared\utils\bounded_runner_test.dart`

**Interfaces:**
- Consumes: `CancelToken` from `batch_models.dart` (Task 2).
- Produces: `Future<List<R?>> runBounded<T, R>(List<T> items, int concurrency, Future<R> Function(T item, int index) task, {CancelToken? cancel})` — runs `task` over `items` with at most `concurrency` in flight; returns results indexed by original position. Items skipped due to cancellation (never started) have `null` at their index. A `task` that throws propagates (caller wraps per-item try/catch).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dev_stack/features/sites/domain/batch_models.dart';
import 'package:dev_stack/shared/utils/bounded_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runBounded', () {
    test('returns results in original order', () async {
      final items = [1, 2, 3, 4, 5];
      final results = await runBounded<int, int>(
        items,
        2,
        (item, index) async => item * 10,
      );
      expect(results, [10, 20, 30, 40, 50]);
    });

    test('never exceeds max concurrency', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final items = List.generate(20, (i) => i);
      await runBounded<int, int>(items, 4, (item, index) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return item;
      });
      expect(maxInFlight, lessThanOrEqualTo(4));
    });

    test('stops admitting new tasks after cancel', () async {
      final token = CancelToken();
      var started = 0;
      final items = List.generate(20, (i) => i);
      await runBounded<int, int>(
        items,
        2,
        (item, index) async {
          started++;
          if (started == 3) token.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return item;
        },
        cancel: token,
      );
      // Some tasks admitted before cancel; not all 20 should run.
      expect(started, lessThan(20));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/utils/bounded_runner_test.dart`
Expected: FAIL — `bounded_runner.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
import '../../features/sites/domain/batch_models.dart';

/// Runs [task] over [items] with at most [concurrency] tasks in flight at once,
/// using a worker-pool (as one task finishes the next is admitted). Results are
/// returned indexed by the item's original position. If [cancel] is triggered,
/// no further tasks are admitted; items that never started keep a `null` slot.
Future<List<R?>> runBounded<T, R>(
  List<T> items,
  int concurrency,
  Future<R> Function(T item, int index) task, {
  CancelToken? cancel,
}) async {
  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  final workerCount = concurrency < 1 ? 1 : concurrency;

  Future<void> worker() async {
    while (true) {
      if (cancel?.isCancelled ?? false) return;
      final index = nextIndex;
      if (index >= items.length) return;
      nextIndex++;
      results[index] = await task(items[index], index);
    }
  }

  final workers = <Future<void>>[];
  final count = workerCount < items.length ? workerCount : items.length;
  for (var i = 0; i < count; i++) {
    workers.add(worker());
  }
  await Future.wait(workers);
  return results;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/utils/bounded_runner_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/utils/bounded_runner.dart test/shared/utils/bounded_runner_test.dart
git commit -m "feat: add runBounded worker-pool helper"
```

---

### Task 4: Refactor SitesNotifier into core + finalize

Split single-site logic into per-site "core" methods and a shared `_finalize()`, keeping `addSite`/`deleteSite` behavior identical. No new features yet — this is a safe internal refactor.

**Files:**
- Modify: `D:\Source\ponta\dev-stack\lib\features\sites\data\sites_provider.dart`

**Interfaces:**
- Produces (private, used by Task 5):
  - `Future<SiteModel> _persistSite(BatchSiteSpec spec)` — validates domain, builds `SiteModel`, persists it in its own `writeTxn`, returns the stored site. (Used by single `addSite`.)
  - `Future<void> _generateSslWithRetry(SiteModel site)` — SSL cert generation + immediate single retry (no fixed sleep), disabling SSL on failure.
  - `Future<void> _finalize()` — `_updateHostsFile()` + refresh `state` + `restartWebservers()`.
- Preserves: existing public `addSite(...)`, `deleteSite(int id, {bool restartWebserver})` signatures and behavior.

- [ ] **Step 1: Add import for batch models**

At the top of `sites_provider.dart`, add with the other domain imports (after `import '../domain/site_model.dart';`):

```dart
import '../domain/batch_models.dart';
```

- [ ] **Step 2: Extract `_generateSslWithRetry` from `addSite`**

Replace the SSL block inside `addSite` (currently `sites_provider.dart:82-112`, the `if (useSsl) { ... for (int i = 0; i < 3; i++) { ... } ... }` section) with a call:

```dart
    if (useSsl) {
      await _generateSslWithRetry(site);
    }
```

Then add this new private method to the class (place it just below `addSite`):

```dart
  /// Generates the SSL cert for [site]; retries once immediately if the cert or
  /// key file is missing after mkcert returns. Disables SSL on the site (and
  /// persists that) if generation still fails.
  Future<void> _generateSslWithRetry(SiteModel site) async {
    final sslNotifier = ref.read(sslServiceProvider.notifier);
    final logger = ref.read(logServiceProvider);
    final isar = await ref.read(isarProvider.future);

    bool certPresent() {
      final certFile = File(sslNotifier.getSiteCertPath(site.domain));
      final keyFile = File(sslNotifier.getSiteKeyPath(site.domain));
      return certFile.existsSync() && keyFile.existsSync();
    }

    await sslNotifier.generateSiteCert(site.domain);
    if (!certPresent()) {
      logger.warning('Certificate missing for ${site.domain}, retrying once...');
      await sslNotifier.generateSiteCert(site.domain, force: true);
    }

    if (!certPresent()) {
      logger.error('Failed to generate SSL for ${site.domain}, disabling SSL');
      site.useSsl = false;
      await isar.writeTxn(() async {
        await isar.siteModels.put(site);
      });
    }
  }
```

- [ ] **Step 3: Extract `_finalize` and use it in `addSite`, `updateSite`, `deleteSite`**

Add this private method to the class (place it just above `_updateHostsFile`):

```dart
  /// Shared finalization run once after site changes: rewrite the hosts file,
  /// refresh provider state from the DB, and restart webservers.
  Future<void> _finalize({bool restartWebserver = true}) async {
    final isar = await ref.read(isarProvider.future);
    await _updateHostsFile();
    state = AsyncValue.data(
      await isar.siteModels.where().sortByCreatedAtDesc().findAll(),
    );
    if (restartWebserver) {
      await restartWebservers();
    }
  }
```

In `addSite`, replace the tail (currently the `// Update hosts file` + `_updateHostsFile()` + `// Refresh state` + `state = ...` + `if (restartWebserver) { ... }` block, `sites_provider.dart:114-128`) with:

```dart
    // Generate Vhost files
    await _generateVhostFiles(site);

    await _finalize(restartWebserver: restartWebserver);
```

In `deleteSite`, replace the tail (currently `// Update hosts file` + `_updateHostsFile()` + `state = ...` + `if (restartWebserver) { ... }`, `sites_provider.dart:205-215`) with:

```dart
      await _finalize(restartWebserver: restartWebserver);
```

In `updateSite`, replace the tail (currently `// Update hosts file` + `_updateHostsFile()` + `// Refresh state` + `state = ...` + `// Restart webservers` + `await restartWebservers();`, `sites_provider.dart:181-190`) with:

```dart
    await _finalize();
```

- [ ] **Step 4: Run existing tests and analyzer to verify no regressions**

Run: `flutter analyze lib/features/sites/data/sites_provider.dart`
Expected: No errors (warnings pre-existing elsewhere are fine).

Run: `flutter test`
Expected: All existing tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/data/sites_provider.dart
git commit -m "refactor: split SitesNotifier into per-site core and shared finalize"
```

---

### Task 5: Batch create/delete methods in SitesNotifier

Add `addSitesBatch` and `deleteSitesBatch` using one DB transaction + `runBounded` for SSL/vhost, then a single `_finalize()`.

**Files:**
- Modify: `D:\Source\ponta\dev-stack\lib\features\sites\data\sites_provider.dart`

**Interfaces:**
- Consumes: `BatchSiteSpec`, `BatchProgress`, `BatchPhase`, `BatchResult`, `CancelToken` (Task 2); `runBounded` (Task 3); `_generateSslWithRetry`, `_generateVhostFiles`, `_removeVhostFiles`, `_finalize` (Task 4).
- Produces:
  - `Future<BatchResult> addSitesBatch(List<BatchSiteSpec> specs, {void Function(BatchProgress)? onProgress, CancelToken? cancel})`
  - `Future<BatchResult> deleteSitesBatch(List<int> ids, {void Function(BatchProgress)? onProgress, CancelToken? cancel})`

- [ ] **Step 1: Add import for runBounded**

At the top of `sites_provider.dart`, add with the other imports:

```dart
import '../../../shared/utils/bounded_runner.dart';
```

- [ ] **Step 2: Implement `addSitesBatch`**

Add this method to the class (place it below `addSite`):

```dart
  /// Creates many sites efficiently: persists all new sites in one transaction,
  /// then generates SSL + vhost files in bounded parallel, then finalizes once
  /// (hosts write + state refresh + single webserver restart). Duplicate domains
  /// (already in DB or within [specs]) are skipped. Honors [cancel].
  Future<BatchResult> addSitesBatch(
    List<BatchSiteSpec> specs, {
    void Function(BatchProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final logger = ref.read(logServiceProvider);

    // Determine which specs are new (skip duplicates by domain).
    final existingDomains = (await isar.siteModels.where().findAll())
        .map((s) => s.domain)
        .toSet();
    final seen = <String>{};
    final toCreate = <SiteModel>[];
    var skipped = 0;

    for (final spec in specs) {
      if (!_isValidDomain(spec.domain) ||
          existingDomains.contains(spec.domain) ||
          !seen.add(spec.domain)) {
        skipped++;
        continue;
      }

      String? phpVersion;
      int? phpPort;
      if (spec.siteType == 'php' && spec.phpAppId != null) {
        final versionMatch = RegExp(r'\d+').firstMatch(spec.phpAppId!);
        phpVersion = versionMatch?.group(0) ?? '82';
        phpPort = _safePhpPort(spec.phpAppId);
      }

      toCreate.add(SiteModel(
        domain: spec.domain,
        rootDir: spec.rootDir,
        siteType: spec.siteType,
        phpVersion: phpVersion,
        phpPort: phpPort,
        useSsl: spec.useSsl,
        createdAt: DateTime.now(),
      ));
    }

    // Persist all new sites in one transaction.
    if (toCreate.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.siteModels.putAll(toCreate);
      });
    }

    // Fan out SSL + vhost generation (bounded).
    final total = toCreate.length;
    var completed = 0;
    final failed = <String>[];

    await runBounded<SiteModel, void>(
      toCreate,
      8,
      (site, index) async {
        try {
          if (site.useSsl) {
            await _generateSslWithRetry(site);
          }
          await _generateVhostFiles(site);
        } catch (e) {
          logger.error('Batch create failed for ${site.domain}: $e');
          failed.add(site.domain);
        } finally {
          completed++;
          onProgress?.call(BatchProgress(
            current: completed,
            total: total,
            currentLabel: site.domain,
            phase: BatchPhase.processing,
          ));
        }
      },
      cancel: cancel,
    );

    // Finalize once (even on cancel — reflect what was actually created).
    onProgress?.call(BatchProgress(
      current: completed,
      total: total,
      currentLabel: '',
      phase: BatchPhase.finalizing,
    ));
    await _finalize();

    return BatchResult(
      succeeded: completed - failed.length,
      skipped: skipped,
      failed: failed,
      cancelled: cancel?.isCancelled ?? false,
    );
  }
```

- [ ] **Step 3: Implement `deleteSitesBatch`**

Add this method to the class (place it below `deleteSite`):

```dart
  /// Deletes many sites efficiently: removes vhost/ssl/logs files in bounded
  /// parallel, deletes all rows in one transaction, then finalizes once.
  /// Honors [cancel] (already-deleted sites stay deleted).
  Future<BatchResult> deleteSitesBatch(
    List<int> ids, {
    void Function(BatchProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    final isar = await ref.read(isarProvider.future);
    final logger = ref.read(logServiceProvider);

    final sites = <SiteModel>[];
    for (final id in ids) {
      final site = await isar.siteModels.get(id);
      if (site != null) sites.add(site);
    }

    final total = sites.length;
    var completed = 0;
    final failed = <String>[];
    final removedIds = <int>[];

    await runBounded<SiteModel, void>(
      sites,
      8,
      (site, index) async {
        try {
          await _removeVhostFiles(site);
          removedIds.add(site.id);
        } catch (e) {
          logger.error('Batch delete failed for ${site.domain}: $e');
          failed.add(site.domain);
        } finally {
          completed++;
          onProgress?.call(BatchProgress(
            current: completed,
            total: total,
            currentLabel: site.domain,
            phase: BatchPhase.processing,
          ));
        }
      },
      cancel: cancel,
    );

    // Delete DB rows for successfully removed sites in one transaction.
    if (removedIds.isNotEmpty) {
      await isar.writeTxn(() async {
        await isar.siteModels.deleteAll(removedIds);
      });
    }

    onProgress?.call(BatchProgress(
      current: completed,
      total: total,
      currentLabel: '',
      phase: BatchPhase.finalizing,
    ));
    await _finalize();

    return BatchResult(
      succeeded: removedIds.length,
      skipped: 0,
      failed: failed,
      cancelled: cancel?.isCancelled ?? false,
    );
  }
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/sites/data/sites_provider.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/data/sites_provider.dart
git commit -m "feat: add addSitesBatch and deleteSitesBatch to SitesNotifier"
```

---

### Task 6: BatchProgressDialog widget

A modal dialog bound to a `ValueNotifier<BatchProgress>` with a Cancel button.

**Files:**
- Create: `D:\Source\ponta\dev-stack\lib\features\sites\presentation\widgets\batch_progress_dialog.dart`

**Interfaces:**
- Consumes: `BatchProgress`, `BatchPhase` (Task 2); `AppColors`, `AppTextSize`.
- Produces: `class BatchProgressDialog extends StatelessWidget` with constructor
  `const BatchProgressDialog({required this.title, required this.progress, required this.onCancel})`
  where `title` is `String`, `progress` is `ValueListenable<BatchProgress>`, `onCancel` is `VoidCallback`.

- [ ] **Step 1: Implement the widget**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../domain/batch_models.dart';

/// Modal dialog showing live batch progress with a Cancel button. Cancel is
/// hidden once the batch reaches the finalizing phase.
class BatchProgressDialog extends StatefulWidget {
  final String title;
  final ValueListenable<BatchProgress> progress;
  final VoidCallback onCancel;

  const BatchProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  @override
  State<BatchProgressDialog> createState() => _BatchProgressDialogState();
}

class _BatchProgressDialogState extends State<BatchProgressDialog> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<BatchProgress>(
            valueListenable: widget.progress,
            builder: (context, p, _) {
              final isFinalizing = p.phase == BatchPhase.finalizing;
              final percent = (p.fraction * 100).clamp(0, 100).toStringAsFixed(0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.md,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isFinalizing ? null : p.fraction,
                      minHeight: 8,
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFinalizing
                        ? 'Updating hosts & restarting webservers…'
                        : '${p.current} / ${p.total}  ($percent%)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isFinalizing && p.currentLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.currentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: AppTextSize.xs,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!isFinalizing)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelling
                            ? null
                            : () {
                                setState(() => _cancelling = true);
                                widget.onCancel();
                              },
                        child: Text(
                          _cancelling ? 'Cancelling…' : 'Cancel',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/sites/presentation/widgets/batch_progress_dialog.dart`
Expected: No errors. (If `AppTextSize.md` does not exist, use the closest existing size constant — check `lib/core/theme/app_text_size.dart`.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/sites/presentation/widgets/batch_progress_dialog.dart
git commit -m "feat: add BatchProgressDialog widget"
```

---

### Task 7: Wire batch delete in sites_page

Replace the sequential delete loop in `_handleBulkDelete` with `deleteSitesBatch` + progress dialog.

**Files:**
- Modify: `D:\Source\ponta\dev-stack\lib\features\sites\presentation\sites_page.dart`

**Interfaces:**
- Consumes: `deleteSitesBatch` (Task 5), `BatchProgressDialog` (Task 6), `BatchProgress`, `BatchPhase`, `CancelToken` (Task 2).

- [ ] **Step 1: Add imports**

At the top of `sites_page.dart`, with the other feature imports:

```dart
import '../domain/batch_models.dart';
import 'widgets/batch_progress_dialog.dart';
```

- [ ] **Step 2: Replace the `onConfirm` body in `_handleBulkDelete`**

Replace the `onConfirm: () async { ... }` body (currently `sites_page.dart:265-288`, the loop `for (final id in idsToDelete) { await sitesNotifier.deleteSite(...); }` through the success dialog) with:

```dart
      onConfirm: () async {
        final sitesNotifier = ref.read(sitesNotifierProvider.notifier);
        final idsToDelete = _selectedSiteIds.toList();
        final progress = ValueNotifier<BatchProgress>(
          BatchProgress(
            current: 0,
            total: idsToDelete.length,
            currentLabel: '',
            phase: BatchPhase.processing,
          ),
        );
        final token = CancelToken();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BatchProgressDialog(
            title: 'Deleting Sites',
            progress: progress,
            onCancel: token.cancel,
          ),
        );

        final result = await sitesNotifier.deleteSitesBatch(
          idsToDelete,
          onProgress: (p) => progress.value = p,
          cancel: token,
        );

        progress.dispose();
        setState(() => _selectedSiteIds.clear());

        if (mounted) {
          Navigator.of(context).pop(); // close progress dialog
          var text = 'Deleted ${result.succeeded} sites.';
          if (result.failed.isNotEmpty) {
            text += ' Failed: ${result.failed.length}.';
          }
          if (result.cancelled) text += ' (Cancelled)';
          AppDialogs.showSuccess(
            context: context,
            title: 'Bulk Delete Finished',
            text: text,
          );
        }
      },
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/sites/presentation/sites_page.dart`
Expected: No errors.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d windows`
Select 3+ sites → Delete → confirm. Expected: progress dialog shows X/N advancing, single webserver restart at the end, sites removed from table, summary dialog. Test Cancel mid-run on a larger batch: remaining sites are skipped, already-deleted ones stay deleted.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/sites_page.dart
git commit -m "feat: wire bulk delete to deleteSitesBatch with progress dialog"
```

---

### Task 8: Wire batch create in sites_page

Replace the sequential create loop in `_handleBatchCreateSites` with `addSitesBatch` + progress dialog, using `resolveDomainFromTemplate`.

**Files:**
- Modify: `D:\Source\ponta\dev-stack\lib\features\sites\presentation\sites_page.dart`

**Interfaces:**
- Consumes: `addSitesBatch` (Task 5), `BatchSiteSpec`, `BatchProgress`, `BatchPhase`, `CancelToken` (Task 2), `resolveDomainFromTemplate` (Task 1), `BatchProgressDialog` (Task 6).

- [ ] **Step 1: Add import for site_domain_utils**

At the top of `sites_page.dart`, with the other feature imports:

```dart
import '../domain/site_domain_utils.dart';
```

- [ ] **Step 2: Replace the `onConfirm` body in `_handleBatchCreateSites`**

Replace the `onConfirm: () async { ... }` body (currently `sites_page.dart:324-400`, from `final sitesNotifier = ...` through the `showSuccess` call) with:

```dart
        onConfirm: () async {
          final sitesNotifier = ref.read(sitesNotifierProvider.notifier);
          final apps = ref.read(appsNotifierProvider).value ?? [];

          // Get default PHP version (prioritize isDefault, then installed).
          final defaultPhpApp = apps.firstWhere(
            (a) => a.groupName == 'php' && a.isInstalled && a.isDefault,
            orElse: () => apps.firstWhere(
              (a) => a.groupName == 'php' && a.isInstalled,
              orElse: () => apps.firstWhere(
                (a) => a.groupName == 'php',
                orElse: () => apps.first,
              ),
            ),
          );
          final String defaultPhp =
              (defaultPhpApp.isInstalled && defaultPhpApp.groupName == 'php')
              ? defaultPhpApp.appId
              : 'static';

          final specs = subdirs.map((subdir) {
            final folderName = p.basename(subdir.path);
            return BatchSiteSpec(
              domain: resolveDomainFromTemplate(
                settings.siteTemplate,
                folderName,
              ),
              rootDir: subdir.path,
              siteType: 'php',
              phpAppId: defaultPhp,
              useSsl: true,
            );
          }).toList();

          final progress = ValueNotifier<BatchProgress>(
            BatchProgress(
              current: 0,
              total: specs.length,
              currentLabel: '',
              phase: BatchPhase.processing,
            ),
          );
          final token = CancelToken();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => BatchProgressDialog(
              title: 'Creating Sites',
              progress: progress,
              onCancel: token.cancel,
            ),
          );

          final result = await sitesNotifier.addSitesBatch(
            specs,
            onProgress: (pr) => progress.value = pr,
            cancel: token,
          );

          progress.dispose();

          if (mounted) {
            Navigator.of(context).pop(); // close progress dialog
            var message = 'Created ${result.succeeded} sites.';
            if (result.skipped > 0) {
              message += ' Skipped ${result.skipped} existing/invalid.';
            }
            if (result.failed.isNotEmpty) {
              message += ' Failed: ${result.failed.length}.';
            }
            if (result.cancelled) message += ' (Cancelled)';
            AppDialogs.showSuccess(
              context: context,
              title: 'Batch Creation Finished',
              text: message,
            );
          }
        },
```

- [ ] **Step 3: Remove now-unused code**

The old inline default-PHP lookup and per-folder loop are replaced above. Confirm no leftover unused local variables remain (e.g. old `existingSites`, `count`, `skipped`). Also confirm `AppLogger` import is still used elsewhere in the file; if it is now unused, remove `import 'package:dev_stack/core/services/log_service.dart';`.

Run: `flutter analyze lib/features/sites/presentation/sites_page.dart`
Expected: No errors, no "unused" warnings.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d windows`
Batch Create → pick a folder with 5+ subfolders. Expected: progress dialog advances X/N, single hosts write + single restart at the end, sites appear in table, summary shows created/skipped counts. Re-run on same folder → all skipped. Test Cancel mid-run.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/sites_page.dart
git commit -m "feat: wire batch create to addSitesBatch with progress dialog"
```

---

### Task 9: Full verification

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All PASS (including new `site_domain_utils_test`, `batch_models_test`, `bounded_runner_test`).

- [ ] **Step 2: Analyze whole project**

Run: `flutter analyze`
Expected: No new errors introduced by these changes.

- [ ] **Step 3: End-to-end manual verification**

Run: `flutter run -d windows`. Verify against the spec's goals:
- Batch create of N folders performs **one** hosts write and **one** webserver restart (observe logs / timing).
- Bulk delete of N sites likewise.
- Progress dialog shows live X/N + percentage and a working Cancel.
- Cancelled batches keep already-processed sites and finalize correctly.

- [ ] **Step 4: Final commit (if any cleanup)**

```bash
git add -A
git commit -m "chore: bulk site performance verification cleanup"
```

---

## Self-Review Notes

- **Spec coverage:** core/finalize split (Task 4), DB batching (Tasks 4–5), bounded parallel SSL/vhost concurrency=8 (Tasks 3,5), SSL retry-without-sleep (Task 4), progress+cancel dialog (Tasks 6–8), extracted pure units + tests (Tasks 1–3), summary reporting (Tasks 7–8). All spec sections mapped.
- **Type consistency:** `BatchProgress`/`BatchPhase`/`BatchResult`/`CancelToken`/`BatchSiteSpec` defined once (Task 2), consumed with matching signatures in Tasks 5–8. `runBounded` signature consistent (Tasks 3,5). `_finalize`/`_generateSslWithRetry` names consistent (Tasks 4,5).
- **Note for implementer:** `AppTextSize.md` in Task 6 is assumed; if absent, substitute the nearest existing constant from `lib/core/theme/app_text_size.dart`.
