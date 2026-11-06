# Incremental Builder Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Linux PHP and Redis availability complete across sparse builder releases, and prevent incomplete discovery from replacing the published catalog.

**Architecture:** Share one complete historical builder index between all PHP minors and Redis. Independently paginate each stable release's assets, then apply version URLs and hashes from the selected archive. Propagate builder failures to the existing CLI failure boundary; always materialize output files after a successful catalog update.

**Tech Stack:** Node.js 24, built-in fetch/fs, node:test with VM-loaded production code and temporary directories, existing GitHub Actions workflow.

**Spec:** The user's approved in-chat proposal to fix historical PHP/Redis discovery, asset pagination, publication on API failure, and missing outputs on unchanged runs (2026-11-06).

## Global Constraints

- Work only in DevStack; the Redis builder is currently building and must not be changed or dispatched.
- PHP: `php-<patch>-glibc-full-x86_64-<16hex-build-id>.tar.gz`.
- Redis: `redis-<patch>-musl-x86_64-<16hex-build-id>.tar.gz`. Choose fully static musl rather than glibc with an unknown host floor.
- Retain every supported patch; the newest public release's build wins per exact version.
- Accept archive URLs only from the exact builder repository on HTTPS GitHub, with matching asset identity.
- Successful absence of Redis assets is valid; drafts/prereleases, source archives and package-manager fallbacks never enable Redis.
- An HTTP, schema, or pagination failure during builder discovery must abort generation, not publish an empty/partial fallback.
- Preserve existing non-builder and Windows fallback behavior; Apache/PostgreSQL stay unavailable on Linux.
- Use offline network fixtures and temporary catalog directories only; do not access the live Isar DB/cache.
- Do not install dependencies, run downloaded binaries, mutate Gist, dispatch Actions, commit, merge or push without separate user authorization.
- Execute inline on `fix/incremental-builder-catalog`; no new worktree without user consent.

## Review Focus

- Asset URLs must match the exact asset filename/build identity, not merely its PHP/Redis version.
- Pagination must not forward the GitHub token to another origin, repository, endpoint or credential-bearing URL.
- Later asset-page errors must invalidate the whole index even after discovering usable bundles.
- A successful empty index must not resurrect a previous Redis/PHP build.
- Fresh-checkout unchanged runs must create both expected output files without changing their timestamps.

---

### Task 1: Complete shared builder discovery

**Files:** Modify `assets/data/update.js` and `test/assets/update_php.test.js`; create `test/assets/update_builder.test.js` and `test/assets/updater_test_helpers.cjs`.

**Interfaces:** Consume GitHub release/asset arrays and Link pagination. Produce `fetchersLinux.php(prefix)` and `fetchersLinux.redis()` returning `{ versions, sha256 }`, using one cached complete index. Apply the same structured result to Linux PHP and Redis; preserve checksums only for the identical URL.

- [x] Write tests using real catalog generation for sparse Redis-only/PHP-only releases, history pages and separate asset pages. Assert exact version maps and hashes, newest build selection, all patches, supported target only and safe empty availability.
- [x] Run `node --test test/assets/*.test.js`; observe the intended missing Redis/asset-pagination failures before production edits.
- [x] Implement complete shared discovery, strict archive identity and portable Redis application/fallback, retaining PHP behavior.
- [x] Run the whole Node suite; expect all discovery and existing PHP regressions to pass (later-task RED tests may remain isolated until their task).

### Task 2: Fail closed on incomplete discovery

**Files:** Modify `assets/data/update.js`, `.github/workflows/update-apps.yml`, and `test/assets/update_builder.test.js`.

**Interfaces:** Consume Task 1's shared builder promise. Builder fetch/schema/pagination errors propagate through `updatePlatformCatalog(...)` and `main()` to exit status 1; non-builder errors still use existing fallback. Actions supplies `GITHUB_TOKEN` with read-only repository contents permission.

- [x] Write tests for initial/later release HTTP errors, later assets-page failure, malformed release/assets, repeated/malformed/off-origin pagination and token forwarding boundaries. Assert rejection and unchanged/absent output, rather than a degraded successful catalog.
- [x] Verify the full-generator failure test is RED because current code swallows errors.
- [x] Propagate Linux portable-builder errors; reject incomplete scans before output write. Add the Actions token environment and read-only contents permission.
- [x] Run all Node tests; expect no degraded/partial catalog to be written, and Windows/non-builder fallback to remain green.

### Task 3: Materialize successful unchanged outputs

**Files:** Modify `assets/data/update.js` and `test/assets/update_builder.test.js`.

**Interfaces:** `updatePlatformCatalog(...)` always writes the requested output on success. Unchanged app data retains the previous `lastUpdated`; changed/new data gets a new timestamp.

- [x] Write a two-platform test with absent generated files and unchanged input; assert `new-apps.json` and `new-apps-linux.json` exist with identical apps and the literal previous timestamp. Also cover an existing output and a changed input.
- [x] Observe ENOENT/the missing output assertion before implementation.
- [x] Move output writing after timestamp selection, outside the changed-data branch.
- [x] Run all Node tests, full Flutter tests, analyzer, syntax and diff checks. Expect zero failures.
- [x] Run one fresh-context bounded review of the complete diff. Verify any important finding with a failing test before fixing.
- [x] Leave changes uncommitted on the fix branch and report verified results; no automatic publication or integration.

---

### Task 4: Configure installed portable Redis

**Files:** Modify `lib/features/apps/data/app_installer_service.dart`; create `test/features/apps/redis_installer_compatibility_test.dart`.

**Interfaces:** `_configureDatabases` gains a Linux-only `redis` branch calling the existing `configureIsolatedRedis(app, logInfo)`. That method writes `AppConfig.dataDir/redis/redis.conf` when absent, which is exactly the first candidate `AppServiceManager.argumentsForExecutable` picks for `redis-server`.

**Why:** The portable Redis archive ships `bin/redis-server` but no `redis.conf`, and `configureIsolatedRedis` had no call site outside its own test, so every installed Linux Redis exited immediately on start.

- [x] Write a test that runs the real `install()` flow over an in-memory tar.gz shaped like the builder's Redis archive (root folder `<asset-name>/`, `bin/redis-server`, `bin/redis-cli`), using only a temporary `AppConfig` base directory. Assert detection of both binaries and that `dataDir/redis/redis.conf` exists with `daemonize no`.
- [x] Run it; observe the config assertion failing while install reports success.
- [x] Add the guard `Platform.isLinux && app.appId == 'redis'` in `_configureDatabases`.
- [x] Re-run the Redis test, the existing isolated-config tests, the full Flutter suite, and the analyzer.

## Integration Review (2026-11-07)

The user explicitly authorized a fresh review followed by merging into `main`
and pushing if the review is acceptable. This supersedes Task 3's original
leave-uncommitted handoff, but does not authorize dispatching Actions, updating
the Gist, modifying the builder, or touching the live cache/Isar database.

- Fixed finding 1: archive identity must include the entire basename/build ID.
  Both PHP and Redis same-version/different-build tests failed with wrongly
  accepted URLs and hashes before the fix, then passed; Node suite: 38/38.
- Fixed finding 2: each release's asset pagination must stay on that release's
  exact assets pathname. The full-generator regression failed with a missing
  rejection before the fix, then passed without fetching the other release or
  writing a catalog; Node suite: 39/39.
- Ruling on finding 3: an old timestamp alone is not a defect when app data is
  unchanged; retaining it is the explicit Task 3 contract. Output-first loading
  and the tracked Windows output predate this branch. Keep both unchanged here;
  removing that file could change existing non-builder fallback availability.
  Cost if wrong: a separate catalog-baseline cleanup is required.
- Ruling on finding 4: do not introduce startup self-healing or automatic
  migration for Redis installed before this fix. The user disallowed automatic
  legacy migration, and this task owns installation/reinstallation only.
  Existing configurations remain untouched. Cost if wrong: an older installation
  missing `redis.conf` still needs explicit repair or reinstallation.
- Deferred minor (finding 5): pagination rejects repeated URLs but has no maximum
  page count or request deadline. Do not truncate complete builder history with
  an arbitrary cap. A faulty trusted API returning infinitely many distinct
  next links can keep the updater running until the CI job timeout; add a
  fail-closed deadline/budget as a separate hardening change if needed.
- No second review is required for these verified fixes: both important findings
  have witnessed RED-to-GREEN regression tests, followed by the full suite.
