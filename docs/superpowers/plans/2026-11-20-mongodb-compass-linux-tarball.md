# MongoDB Compass Linux Tarball Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and open standard MongoDB Compass on Linux from the official `linux-x64.tar.gz` while preserving server data during uninstall.

**Architecture:** Keep the existing per-version URL/checksum schema. Use a dedicated strict Compass Linux updater, retain the portable installer, and inject a shell-free GUI launcher. Publish a separate compatible-client Linux feed in workflow configuration while filtering Compass from the legacy feed; do not publish anything during this task.

**Tech Stack:** Dart/Flutter, Riverpod, Dio, Node.js built-in test runner, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-20-mongodb-compass-linux-tarball-design.md`

## Global Constraints

- Only `mongodb-compass-<version>-linux-x64.tar.gz`; no distro mapping or catalog schema change.
- No host service, package-manager, security-policy, or privileged operations; no app/service launch on the host.
- Never add `--no-sandbox`, root execution, desktop entries, or PATH commands.
- Keep Windows discovery/launch unchanged; never delete MongoDB Server data when removing Compass.
- Do not commit, push, publish the Gist, or trigger builds without a new user request.

## Review Focus

- Missing/truncated GitHub assets or digests: never select RHEL, editions, source archives, or mismatched URL/hash fallbacks (Task 1).
- A legacy cached catalog hides the bundled Compass entry: add only missing bundled Compass while preserving installed state and unrelated cached entries (Task 3).
- Paths containing spaces/metacharacters and failed process starts: launch directly on Linux and report errors without changing Windows or URL-based tools (Task 2).
- Uninstalling Compass with server data present: preserve sentinel files; MongoDB Server removal still removes its data (Task 2).
- Legacy clients consume the same feed: keep Compass out of the legacy payload while new clients use the full versioned feed (Task 3).

---

### Task 1: Strict official Linux catalog

**Files:** Modify `assets/data/update.js`, `assets/data/apps-linux.json`, `assets/data/new-apps-linux.json`; create `test/assets/update_compass.test.js`; modify `test/assets/linux_catalog_test.dart`.

**Interfaces:** Produces `fetchersLinux['mongodb-compass'](): Promise<{versions, sha256}>` using existing map shapes and base Linux metadata (`tool`, `database`, `MongoDB Compass`, no CLI).

- [x] Write failing offline tests for exact standard asset selection, valid digest pairing, skipped draft/prerelease/malformed/missing assets, release pagination, newest patch filtering, and Windows ZIP selection unchanged. Assert only valid exact URL/hash fallback pairs survive an empty/failed fetch.
- [x] Run `node --test test/assets/update_compass.test.js` and observe expected failures.
- [x] Implement a dedicated Compass fetcher and Compass-only fallback validation, preserving generic fetchers. Add the catalog entry with verified v1.53.2 URL and SHA-256.
- [x] Run the targeted Node tests and `flutter test test/assets/linux_catalog_test.dart`; then run all offline Node suites.

### Task 2: Safe GUI install, launch, and removal

**Files:** Create `lib/features/apps/data/app_launcher.dart`, `test/features/apps/app_launcher_test.dart`, `test/features/apps/installer_compass_test.dart`; modify `apps_provider.dart`, `app_installer_service.dart` under the same data directory.

**Interfaces:** `AppLauncher.open(String executablePath): Future<void>` with constructor-injected process launch functions and platform choice. Provider uses a normal Riverpod dependency for testability; Linux process starts detached without shell, Windows retains its previous command. Existing `AppInstallerService.install` and `delete` signatures stay unchanged.

- [x] Write failing tests covering Compass uninstall preserving a temporary server data sentinel, server uninstall deleting its own data, full mocked-download tarball installation with helpers, missing executable error, and checksum mismatch.
- [x] Write failing launcher tests with injected runners for Linux absolute path/working directory/argument list, Windows command, missing file, and propagated process errors. Add a provider integration test proving openApp routes through the launcher and app error state receives failures.
- [x] Observe failures; minimally implement launcher integration, exact server data ownership, and Compass missing executable validation.
- [x] Run targeted Flutter tests and existing extraction, permissions, cancellation, and provider suites.

### Task 3: Cache and safe feed rollout

**Files:** Modify `apps_repository.dart`, `apps_provider.dart`, `.github/workflows/update-apps.yml`, `README.md`, `test/features/apps/apps_repository_catalog_cache_test.dart`, `test/features/apps/catalog_url_test.dart`; create a small tested Node catalog publication helper under `assets/data/` and its test under `test/assets/` if needed.

**Interfaces:** Keep local cache and asset filenames unchanged. New Linux clients request `apps-linux-v2.json`; Windows requests `apps.json`. Workflow prepares a legacy Linux payload with Compass removed and publishes the full generated Linux file under the new filename.

- [x] Write failing tests for versioned remote filename selection, overlaying only missing bundled Compass into an older Linux cache, retaining installed state, avoiding duplicates, and filtering legacy publication without mutating the full catalog.
- [x] Observe failures, then implement narrowly scoped merge/publication logic. Do not change other app merge semantics or trigger publishing.
- [x] Update README to describe managed Linux Compass and distinguish tested integration from upstream availability.
- [x] Run cache, catalog URL, publication helper, and provider refresh tests.

### Task 4: Verification and review

**Files:** Update this checklist and implementation ledger; no unrelated code changes.

- [ ] Run full Node suites, Flutter tests, analyzer, and `git diff --check`. Record exact outcomes and skips.
- [ ] If feasible inspect the verified official archive in fresh temporary download/extraction directories without executing downloaded code. Do not start Docker if its daemon is unavailable. Runtime distro coverage may remain unverified; report that honestly instead of changing host settings.
- [ ] Request one independent whole-diff review without further implementation subagents. Address material findings with RED→GREEN tests and rerun the suite if fixes are needed.
- [ ] Leave changes uncommitted on the feature branch and report remaining runtime validation limits.
