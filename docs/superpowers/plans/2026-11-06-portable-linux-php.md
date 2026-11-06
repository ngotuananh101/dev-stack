# Portable Linux PHP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove package-manager installation flows, discover prebuilt Linux PHP URLs, and install/configure manifest-driven bundles with the standard archive pipeline.

**Architecture:** The Node updater consumes builder release assets. A focused Dart bundle reader supplies validated paths and module metadata to the existing installer and settings provider. Legacy platform branches remain separate.

**Tech Stack:** Node.js 24 built-ins, Dart/Flutter, existing Dio/crypto/path and Riverpod dependencies.

**Spec:** `docs/superpowers/specs/2026-11-06-portable-linux-php-design.md`

## Global Constraints

- Supported app architecture is amd64 only.
- Distribution variant: `glibc/full/x86_64`; manifest schema 1, runtime `php`, verification `PASSED`.
- No compilation or package installation on the user's machine.
- No workflow dispatch, release publication, or live Isar access. Commit/push and merge into `main` were explicitly authorized by the user on 2026-11-06 after verification.
- Windows and installed `system_package` PHP retain existing behavior.
- Execution is native in the current workspace, without dependency installation; retain the user's `QWEN.md` deletion.

## Review Focus

- Release API failure versus a successful empty index: preserve compatible old URLs only on failure.
- Multiple builds/patches and pagination: deterministic newest build, retain all published patches.
- Manifest paths escaping through symlinks or selecting `libexec` instead of launchers: fail before execution.
- Existing FPM config and roots containing spaces: preserve user files and valid quoted paths.
- Missing/corrupt shared modules and failed extension commands: surface errors without using a package driver.

---

### Task 0: Remove package-manager installation (scope update)

**Files:** Modify `assets/data/update.js`, `assets/data/apps-linux.json`, `lib/features/apps/data/app_installer_service.dart`, `apps_repository.dart`, `apps_provider.dart`, `lib/features/apps/domain/app_model.dart`, `linux_php_extension_manager.dart`, `linux_php_extension_driver.dart`, all three `php_extension_drivers`, and `package_command_validator.dart`; create a configuration-only `php_config_command_runner.dart`. Replace obsolete installation tests with rejection/configuration tests.

**Interfaces:** No catalog commands are parsed or stored. `install` rejects old `package_manager` requests before work. Legacy extension manager may configure only installed modules; its driver has no installCommands API. Missing version URLs yield no available version and disabled Install.

- [x] Write tests asserting old package-manager app requests execute no process, merged catalogs ignore shell commands/sentinels, updater outputs have no PM definitions, and missing system modules cannot install.
- [x] Run tests to verify current PM path/metadata fails the new requirements.
- [x] Remove PM installation helpers and command metadata; retain compatibility location sentinel and runtime config helpers. Replace extension elevation dependency with a configuration-only validated runner and remove distro install builders. Make Apache/Redis/PostgreSQL unavailable archive definitions without guessed URLs. Disable Install with no selected downloadable version.
- [x] Run focused tests and complete Flutter suite; existing installation-command tests are obsolete and replaced, discovery/configuration tests remain.

### Task 1: Release-based PHP catalog

**Files:** Modify `assets/data/update.js`, `assets/data/apps-linux.json`, `test/assets/linux_catalog_test.dart`, `lib/features/apps/data/apps_repository.dart`; create `test/assets/update_php.test.js`.

**Interfaces:** `fetchersLinux.php(prefix)` returns `{versions: Record<string,string>, sha256: Record<string,string>}`. `applyFetchedVersions`/`applyFallbackVersions` produce catalog `versions` and optional `sha256` maps. Empty archive PHP definitions merge to an empty `AppModel.versions`, not `latest`.

- [x] Write offline VM-based updater tests with hand-built GitHub pages. Assert available `8.4.27` and `8.4.26` URLs, skip wrong variants/drafts/prereleases, prefer newest build, reuse one paginated request sequence across minors, propagate HTTP/malformed-page failures, and preserve old compatible URLs/checksums only on fetch failure.
- [x] Run `node --test test/assets/update_php.test.js`; verify missing fetcher behavior fails.
- [x] Implement cached paginated PHP asset discovery, metadata application, stable all-patch sorting, safe fallback, and archive PHP definitions. Use GitHub's optional archive digest, never guessed URLs. Guard the script entrypoint for import/testing. Remove package-manager fields from all affected bundled Linux apps under Task 0; leave unavailable version maps empty.
- [x] Update catalog tests to validate merged PHP apps route to archive installation and unavailable entries have no synthetic installable version. Run Node and Flutter catalog tests.

### Task 2: Validated manifest and archive setup

**Files:** Create `lib/features/apps/data/php_runtime_bundle.dart`, `test/helpers/php_bundle_fixture.dart`, `test/features/apps/php_runtime_bundle_test.dart`, `test/features/apps/installer_php_bundle_test.dart`; modify `lib/features/apps/data/app_installer_service.dart`.

**Interfaces:** `PhpRuntimeBundle.load(String root)` returns nullable (only absent manifest) bundle with `version`, `pathFor(String key)`, `sharedModules`; `validateInstallation(String expectedVersion)` verifies module hashes. Installer exposes production `configurePhpBundle(AppModel app, String installPath, String version, void Function(String) logInfo)` and internally calls it before generic detection for manifest PHP. The helper validates, records exact launchers, tunes INI, repairs executable bits, and generates isolated FPM config; existing Composer follow-up remains outside it.

- [x] Write temporary fixture tests asserting malformed schema/identity/version and unsafe or symlink-escaping paths fail; absent manifests return null; shared module hash mismatch fails installation.
- [x] Run the reader tests and observe the missing reader failure.
- [x] Implement the focused manifest reader with normalized contained paths and verified file types, module names/directives/hashes/duplicates/static overlap.
- [x] Write installer tests with both `bin` and `libexec` duplicate names, asserting recorded paths are `bin` launchers, `.ini` is tuned, FPM port is `9084`, log directory exists, user config is unchanged, and wrong version fails before process execution. Use test temp directories and existing `testRef`, never live DB.
- [x] Run installer tests to observe the missing setup behavior; integrate bundle detection/setup into the existing archive install pipeline, keeping Windows legacy setup and Composer intact. Quote FPM error-log paths for spaces.
- [x] Run manifest, installer and existing tar/permissions/FPM hook tests.

### Task 3: Bundle settings and toggles

**Files:** Modify `lib/features/apps/data/php_settings_provider.dart`; create `test/features/apps/php_bundle_settings_test.dart`.

**Interfaces:** Bundle settings use `PhpRuntimeBundle`; `toggleExtension` gains optional named process runner injection, preserving existing positional callers. Registry-only toggles invoke `<extension_manager> enable|disable <name> all` and return reload/restart information.

- [x] Write fixture-based tests for INI path/save, FPM scan enabled-state discovery, static omission, register-only validation, atomic CLI/FPM toggles and failed commands. Use a tiny fixture shell manager to exercise real file effects; use runner injection only for failure/reload boundaries. Include the legacy `.so` disable regression.
- [x] Run tests and confirm bundle paths/listing/toggle behavior is missing.
- [x] Implement bundle-only settings branches, parse active common/FPM INI directives, run the validated manager with argv, and reload a recorded FPM master using the existing helper. Propagate toggle failure and return a restart-needed note for reload failure or no PID. Extend the legacy regex to `.so` without changing Windows behavior.
- [x] Run all focused tests, then `node --test test/assets/update_php.test.js`, `flutter test --no-pub` and targeted `flutter analyze --no-pub`. Review the complete diff, report any unrelated baseline failures and the public-release availability limitation.

## Verification Record (2026-11-06)

- `flutter test --no-pub --reporter expanded`: 1099 passed, 0 failures after the final review fix pass.
- `node --test test/assets/update_php.test.js`: 12 passed, 0 failures.
- `dart analyze` for all changed/new Dart source and test files: no issues found.
- `git diff --check`: clean.
- Fresh-context whole-worktree review completed with four Important findings, all reproduced and fixed RED→GREEN: same-name process termination, symlinked launcher ancestors, post-install module corruption, and stale Linux catalog URL fallback. No Critical or deferred Minor findings. No second review was dispatched; the full suite verifies the single fix pass.
- Public-release discovery verified on 2026-11-06 after publication: release [`runtimes-20261106-initial-075657`](https://github.com/ngotuananh101/devstack-app-builder/releases/tag/runtimes-20261106-initial-075657) is public (not draft/prerelease). Workflow run `42184286167` succeeded in all 11 jobs, including eight PHP builds and publication; 24 uploaded assets cover PHP 8.2.35, 8.3.36, 8.4.27, and 8.5.12 for glibc/musl, full, x86_64. This supersedes the earlier no-release check of run `42158375357`.
- Real PHP 8.4.27 glibc/full/x86_64 archive and manifest downloaded through BrowserOS neo into separate fresh scratch directories. Their SHA256 values match GitHub asset digests; packaged and sidecar manifests match; archive path/type checks, executable regular launchers, and both shared-module hashes pass. The production `PhpRuntimeBundle.load` and `validateInstallation('8.4.27')` accept the extracted public bundle (`public-bundle-consumer.log`). No downloaded launcher, PHP/FPM binary, or extension manager was executed.
- Production updater verified offline against the complete captured public Releases API response: generated exactly four glibc/full/x86_64 PHP entries with matching patch URLs and SHA256 values, skipping musl and sidecars; release discovery reused one response across all minors (`public-catalog-consumer.log`). Generated output remains in scratch; the shipped catalog was not changed by this check.
- Full UI installation, real PHP/FPM execution, extension toggles against the downloaded runtime, oldest-glibc-host compatibility, and Windows/native elevation behavior remain unverified. Only the PHP 8.4 archive was downloaded and inspected; other patches were checked through release metadata and successful jobs. The existing application archive extraction implementation was not independently audited.

## Integration Authorization (2026-11-06)

The user explicitly requested pushing the feature, merging into `main`, and cleaning up afterward. Fresh pre-integration verification: full Flutter suite 1099/1099 passed, Node suite 12/12 passed, changed-file Dart analysis found no issues, and `git diff --check` was clean. Commit only feature source, tests, and documentation; preserve the user's unrelated working-tree deletion of `QWEN.md`. After the merged tree passes verification and both branches are pushed, remove the feature branch and this plan's scratch workspace; do not touch unrelated branches or worktrees.
