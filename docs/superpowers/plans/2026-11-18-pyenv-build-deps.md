# Pyenv Build Dependencies Prompt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Before a pyenv Python install builds, detect missing system build libraries, ask the user's permission with the exact command shown, install them elevated, and only then build Python.

**Architecture:** Mirror the SSL `nss-tools` flow exactly: a testable static `ensure*` function with every outside dependency injected, per-distro package tables resolved from `/etc/os-release`, elevation through `BackgroundProcess.runElevated` (pkexec), ask-once declines in a JSON file, and the permission prompt through `AppDialogs.showPermissionRequest`. Work happens in the main checkout via BVPD (no isolated worktree: the BVPD tools are project-scoped to this checkout, as with all prior work on this project).

**Tech Stack:** Dart / Flutter 3.50.0, `flutter_test`, existing `SslService` helpers, `BackgroundProcess.runElevated`.

**Spec:** `docs/superpowers/specs/2026-11-18-pyenv-build-deps-design.md`

## Global Constraints

- Linux only: on Windows `ensureBeforeInstall` returns `true` immediately (pyenv-win does not build from source).
- No new dependencies.
- Every package-manager command is non-interactive (`-y` / `--noconfirm`); pkexec gives the process no terminal to answer a prompt on.
- No privileged command runs without the user first seeing its exact command line in `AppDialogs.showPermissionRequest` (ALLOW/CANCEL; dismissing counts as no).
- Declines live in a JSON file under `AppConfig.dataDir`, never in Isar (an Isar schema change resets the database).
- Only packages whose probe is missing are installed, never the whole wiki list blindly.
- A distro the map does not know returns null: log the manual hint and proceed to the Python install; never run a guessed command.
- `flutter analyze` on touched files is clean except the pre-existing `material.dart` → `material_ui` deprecation infos.
- Existing SSL behavior is unchanged: its tests still pass unmodified in intent (only the `packageInstallArgs` call shape changes, Task 2).

## Review Focus

- The user cancels the pkexec authentication dialog (exit 126/127): the failure message must say the authentication was cancelled, and no decline is recorded — they did not decline the install, so the next Install asks again. (Task 4 test: `cancelling the authentication dialog records no decline`.)
- The package manager exits 0 but the headers are still missing afterwards: the flow must report failure and abort the Python build, never claim success. (Task 4 test: `reports failure when headers are still missing after a successful install`.)
- The user declines one missing set, then a different set is missing later: the flow asks again — the decline key is the missing set, not a single flag. (Task 4 test: `asks again when a different set of libraries is missing`.)
- A distro the map does not know, or no pkexec on the machine: no command is run and no prompt is shown; the Python install proceeds and the manual hint is logged. (Task 4 test: `unknown distro runs nothing and proceeds`.)
- The index refresh fails (mirror lock, no network) but the install could still work: the refresh failure is logged and the install is still attempted, exactly as the SSL flow does. (Task 4 test: `a failed index refresh still attempts the install`.)

---

## File Structure

- Create `lib/core/services/pyenv_build_deps.dart` — `PyenvBuildDeps`: per-distro package table with probes, missing-package detection, the testable static `ensureBuildDeps` flow, and the instance wrapper `ensureBeforeInstall` the modal calls. One responsibility: deciding and installing pyenv build dependencies.
- Create `lib/core/services/pyenv_build_deps_declines.dart` — `PyenvBuildDepsDeclines`: the ask-once store, mirroring `SslInstallDeclines` (same JSON shape, path `pyenv/declines.json`, key = the sorted missing package names joined with `,`).
- Create `test/core/services/pyenv_build_deps_test.dart` — table, probe, and flow tests, mirroring `ssl_service_linux_test.dart` and `ssl_certutil_install_test.dart`.
- Create `test/core/services/pyenv_build_deps_declines_test.dart` — declines tests, mirroring `ssl_install_declines_test.dart`.
- Modify `lib/core/services/ssl_service.dart` — generalize `packageInstallArgs` to a package list; make `_describeCommand` public as `describeCommand`. Nothing else in SSL changes.
- Modify `test/core/services/ssl_service_linux_test.dart` — the install-command test passes a list.
- Modify `lib/features/apps/presentation/widgets/pyenv_manage_modal.dart` — `_install` runs the ensure flow before `installVersion`.

### Task 1: Per-distro package table and missing-package detection

**Files:**
- Create: `lib/core/services/pyenv_build_deps.dart`
- Test: `test/core/services/pyenv_build_deps_test.dart`

**Interfaces:**
- Consumes: `LinuxDistroResolver.parseOsRelease` (parses `/etc/os-release` content into a map); `BackgroundProcess.run` for `which` probes.
- Produces: `PyenvBuildDeps.buildDepsFor({String? osReleaseId, String? osReleaseIdLike})` returning `({String packageManager, List<({String package, String probe})> deps})?`; `PyenvBuildDeps.missingPackages(List<({String package, String probe})> deps, {Future<bool> Function(String probe)? probeExists})` returning `Future<List<String>>` of missing package names, in table order.

**Probe rule (pinned):** a probe is a header path (`/usr/include/openssl/ssl.h`) or `which:<binary>` (`which:gcc`). The default `probeExists` returns `File(probe).existsSync()` for paths and runs `which` for `which:` probes. A package whose probe cannot be confirmed against the real package contents is left out of the auto-install list and named in the manual hint instead.

**Tables (from the pyenv wiki "Suggested build environment", verified 2026-11-18):**
- dnf (ID or ID_LIKE contains `fedora`, `rhel`, or `centos`): manager `dnf`; packages `make, gcc, zlib-devel, bzip2, bzip2-devel, readline-devel, sqlite, sqlite-devel, openssl-devel, tk-devel, libffi-devel, xz-devel, libuuid-devel, gdbm-devel, libnsl2-devel`.
- apt-get (ID or ID_LIKE contains `debian` or `ubuntu`): manager `apt-get`; packages `make, build-essential, libssl-dev, zlib1g-dev, libbz2-dev, libreadline-dev, libsqlite3-dev, wget, curl, llvm, libncursesw5-dev, xz-utils, tk-dev, libxml2-dev, libxmlsec1-dev, libffi-dev, liblzma-dev`.
- zypper / pacman / apk: confirm their lists from the pyenv wiki during this task; a family whose list cannot be confirmed returns null (manual-hint path).

- [ ] **Step 1: Write the failing tests**

```dart
test('fedora resolves the wiki dnf list', () {
  final deps = PyenvBuildDeps.buildDepsFor(
    osReleaseId: 'fedora',
    osReleaseIdLike: '',
  );
  expect(deps?.packageManager, equals('dnf'));
  expect(
    deps?.deps.map((d) => d.package),
    containsAll(['openssl-devel', 'readline-devel', 'gdbm-devel']),
  );
});

test('ubuntu resolves the wiki apt-get list', () {
  final deps = PyenvBuildDeps.buildDepsFor(
    osReleaseId: 'ubuntu',
    osReleaseIdLike: 'debian',
  );
  expect(deps?.packageManager, equals('apt-get'));
  expect(
    deps?.deps.map((d) => d.package),
    containsAll(['libssl-dev', 'libreadline-dev', 'tk-dev']),
  );
});

test('an unknown distro resolves to null', () {
  expect(
    PyenvBuildDeps.buildDepsFor(osReleaseId: 'gentoo', osReleaseIdLike: ''),
    isNull,
  );
});

test('missingPackages returns only the packages whose probe is absent', () async {
  final deps = [
    (package: 'openssl-devel', probe: '/usr/include/openssl/ssl.h'),
    (package: 'readline-devel', probe: '/usr/include/readline/readline.h'),
  ];
  final missing = await PyenvBuildDeps.missingPackages(
    deps,
    probeExists: (probe) async => probe.contains('openssl'),
  );
  expect(missing, equals(['readline-devel']));
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/pyenv_build_deps_test.dart`
Expected: FAIL — `PyenvBuildDeps` is not defined.

- [ ] **Step 3: Implement `buildDepsFor` and `missingPackages` in `lib/core/services/pyenv_build_deps.dart`**

Follow the family matching in `SslService.nssToolsPackageManager` (ID/ID_LIKE, lowercased, `contains`). Verify every probe path against the real package contents on the dev machine (BVPD file checks for the headers; `which` for the tools) before writing it into the table.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/pyenv_build_deps_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/pyenv_build_deps.dart test/core/services/pyenv_build_deps_test.dart
git commit -m "feat(pyenv): per-distro build-deps table and missing detection"
```

### Task 2: Generalize SslService package helpers for multi-package install

**Files:**
- Modify: `lib/core/services/ssl_service.dart`
- Modify: `test/core/services/ssl_service_linux_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `SslService.packageInstallArgs(String packageManager, List<String> packageNames, {bool assumeYes = true})` returning the same argv shapes as today with every name appended; `SslService.describeCommand(String executable, List<String> arguments)` — the current private `_describeCommand`, made public with the same quoting.

- [ ] **Step 1: Update the existing install-command test to the list form and add a multi-package case**

```dart
test('the install command never prompts', () {
  for (final manager in ['dnf', 'apt-get', 'pacman', 'apk', 'zypper']) {
    final args = SslService.packageInstallArgs(
      manager,
      ['nss-tools'],
      assumeYes: true,
    );
    expect(args, contains('nss-tools'), reason: manager);
    // (existing non-interactive-flag assertion, unchanged)
  }
});

test('the install command lists every package after the flag', () {
  final args = SslService.packageInstallArgs(
    'dnf',
    ['openssl-devel', 'readline-devel'],
    assumeYes: true,
  );
  expect(args, equals(['install', '-y', 'openssl-devel', 'readline-devel']));
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/ssl_service_linux_test.dart`
Expected: FAIL — `packageInstallArgs` takes a `String`, not a `List<String>`.

- [ ] **Step 3: Implement the generalization in `lib/core/services/ssl_service.dart`**

Change the `packageInstallArgs` signature and body (append all names, same per-manager argv shapes). Rename `_describeCommand` to `describeCommand`. Update the one `ensureCertutil` call site to pass `[package.packageName]` and to call `describeCommand`. No other SSL behavior changes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/ssl_service_linux_test.dart test/core/services/ssl_certutil_install_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze on the touched file**

Run: `flutter analyze lib/core/services/ssl_service.dart`
Expected: clean except the pre-existing `material.dart` deprecation infos.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/ssl_service.dart test/core/services/ssl_service_linux_test.dart
git commit -m "refactor(ssl): packageInstallArgs takes a package list; expose describeCommand"
```

### Task 3: Declines store for pyenv build deps

**Files:**
- Create: `lib/core/services/pyenv_build_deps_declines.dart`
- Test: `test/core/services/pyenv_build_deps_declines_test.dart`

**Interfaces:**
- Consumes: a file path (production: `p.join(AppConfig.dataDir, 'pyenv', 'declines.json')`).
- Produces: `PyenvBuildDepsDeclines(String path)` with `Future<Set<String>> read()`, `Future<bool> isDeclined(String key)`, `Future<void> decline(String key)`, `Future<void> clear()` — the same contract as `SslInstallDeclines`, including: a missing, unreadable, or corrupt file reads as an empty set; `_write` creates parent directories and never throws.

- [ ] **Step 1: Write the failing tests, mirroring `ssl_install_declines_test.dart`**

```dart
test('a declined key reads back as declined', () async {
  await declines.decline('openssl-devel,readline-devel');
  expect(
    await declines.isDeclined('openssl-devel,readline-devel'),
    isTrue,
  );
});

test('clear forgets every decline', () async {
  await declines.decline('openssl-devel');
  await declines.clear();
  expect(await declines.read(), isEmpty);
});

test('a corrupt file reads as an empty set and never throws', () async {
  await File('${tempDir.path}/declines.json').writeAsString('not json');
  expect(await declines.read(), isEmpty);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/pyenv_build_deps_declines_test.dart`
Expected: FAIL — `PyenvBuildDepsDeclines` is not defined.

- [ ] **Step 3: Implement `PyenvBuildDepsDeclines` in `lib/core/services/pyenv_build_deps_declines.dart`**

Mirror `SslInstallDeclines` line for line except the path and the key convention (no `static const` keys: the caller passes the sorted missing package names joined with `,`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/pyenv_build_deps_declines_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/pyenv_build_deps_declines.dart test/core/services/pyenv_build_deps_declines_test.dart
git commit -m "feat(pyenv): ask-once declines store for build-deps prompts"
```

### Task 4: The ensure flow

**Files:**
- Modify: `lib/core/services/pyenv_build_deps.dart` (add `ensureBuildDeps` and `ensureBeforeInstall`)
- Test: `test/core/services/pyenv_build_deps_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1's `buildDepsFor` / `missingPackages`; Task 2's `packageInstallArgs` / `describeCommand`; Task 3's declines; `BackgroundProcess.runElevated`; `SslInstallPrompt`, `SslInstallProgress`, `InstallStatus` (defined in `ssl_service.dart`, reused as-is, no rename).
- Produces:

```dart
static Future<bool> ensureBuildDeps({
  required Future<bool> Function(SslInstallPrompt prompt) askPermission,
  required PyenvBuildDepsDeclines declines,
  required List<String> missingPackages,
  required ({String packageManager, List<String> packageNames})? package,
  required Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  ) runElevated,
  void Function(SslInstallProgress progress)? onProgress,
  required Future<List<String>> Function() missingAfterwards,
});
```

Returns `true` = proceed with the Python install (nothing missing, user declined, or install succeeded and the re-check is clean); `false` = abort (lib install failed, or headers still missing after install).

```dart
Future<bool> ensureBeforeInstall({
  required Future<bool> Function(SslInstallPrompt prompt) askPermission,
  void Function(SslInstallProgress progress)? onProgress,
});
```

Wires the real dependencies: reads `/etc/os-release` and parses it with `LinuxDistroResolver.parseOsRelease`, resolves `buildDepsFor`, computes `missingPackages` with the real `probeExists`, declines at `p.join(AppConfig.dataDir, 'pyenv', 'declines.json')`, `runElevated: BackgroundProcess.runElevated`. Returns `true` immediately on non-Linux and when `package` is null (unknown family: logs the manual hint — the pyenv wiki suggested-build-environment URL — via `AppLogger.warning` and proceeds).

**Flow (pinned, mirrors `SslService.ensureCertutil`):**

1. `missingPackages` empty → return `true` (no prompt, no commands).
2. Decline key = the missing package names sorted and joined with `,`; if declined → log and return `true`.
3. `package == null` → log the manual hint and return `true`.
4. Build the prompt: title `Install Python build libraries?`; message `Python needs the "<names>" packages to build. Without them the build fails or the new Python is missing features. This installs the packages system-wide.`; command = `describeCommand(packageManager, packageInstallArgs(packageManager, packageNames))` — the prompt shows the install command only (the refresh command runs first, elevated, without its own prompt, exactly as the SSL flow does).
5. `allowed = await askPermission(prompt)`; if `false` → record the decline key, return `true`.
6. `onProgress(starting, 'Installing <names>...')`; run refresh elevated (`packageRefreshArgs`); log its exit code; a non-zero refresh does NOT stop the install.
7. Run install elevated; log its exit code; if non-zero → `onProgress(failed, SslService.describeInstallFailure(names.join(', '), exitCode, detail: stderr))`, return `false`. Exit 126/127 means the authentication dialog was cancelled — `describeInstallFailure` already words that — and no decline is recorded.
8. Re-check: `missingAfterwards()`; if non-empty → `onProgress(failed, '<names> were installed, but the headers are still missing.')`, return `false`.
9. `onProgress(succeeded, '<names> installed.')`, return `true`.

- [ ] **Step 1: Write the failing tests, mirroring the `run()` harness in `test/core/services/ssl_certutil_install_test.dart`**

A `run()` helper that records prompts, elevated commands, progress events, and the declines file, with a fake `runElevated` returning `ProcessResult(0, exitCode, '', stderr)` and a fake `missingAfterwards`. Tests:

```dart
test('does nothing when nothing is missing', () async {
  final result = await run(answers: [true], missingPackages: []);
  expect(result.prompts, isEmpty);
  expect(result.commands, isEmpty);
  expect(result.proceed, isTrue);
});

test('asks before installing, and runs the install it showed', () async {
  final result = await run(answers: [true]);
  expect(result.prompts, hasLength(1));
  expect(result.prompts.single, contains('dnf install'));
  expect(result.prompts.single, contains('openssl-devel'));
  expect(result.commands.first.first, equals('dnf'));
  expect(result.proceed, isTrue);
});

test('declining records the key and proceeds', () async {
  final result = await run(answers: [false]);
  expect(result.declined, contains('openssl-devel,readline-devel'));
  expect(result.commands, isEmpty);
  expect(result.proceed, isTrue);
});

test('a declined set asks nothing', () async {
  final result = await run(
    answers: [true],
    alreadyDeclined: {'openssl-devel,readline-devel'},
  );
  expect(result.prompts, isEmpty);
  expect(result.proceed, isTrue);
});

test('asks again when a different set of libraries is missing', () async {
  final result = await run(
    answers: [true],
    alreadyDeclined: {'openssl-devel'},
    missingPackages: ['openssl-devel', 'readline-devel'],
  );
  expect(result.prompts, hasLength(1));
});

test('unknown distro runs nothing and proceeds', () async {
  final result = await run(answers: [true], package: null);
  expect(result.prompts, isEmpty);
  expect(result.commands, isEmpty);
  expect(result.proceed, isTrue);
});

test('a failed install returns false with the failure message', () async {
  final result = await run(answers: [true], exitCode: 1, stderr: 'lock');
  expect(result.proceed, isFalse);
  expect(result.progress.last.status, equals(InstallStatus.failed));
  expect(result.progress.last.message, contains('lock'));
});

test('cancelling the authentication dialog records no decline', () async {
  final result = await run(answers: [true], exitCode: 126);
  expect(result.proceed, isFalse);
  expect(result.progress.last.message, contains('cancelled'));
  expect(result.declined, isEmpty);
});

test('reports failure when headers are still missing after a successful install', () async {
  final result = await run(answers: [true], missingAfterwards: ['openssl-devel']);
  expect(result.proceed, isFalse);
  expect(result.progress.last.status, equals(InstallStatus.failed));
});

test('a failed index refresh still attempts the install', () async {
  final result = await run(answers: [true], refreshExitCode: 1);
  expect(result.commands, hasLength(2));
  expect(result.commands.last.first, equals('dnf'));
  expect(result.proceed, isTrue);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/pyenv_build_deps_test.dart`
Expected: FAIL — `ensureBuildDeps` is not defined.

- [ ] **Step 3: Implement `ensureBuildDeps` and `ensureBeforeInstall` in `lib/core/services/pyenv_build_deps.dart`**

Follow the pinned flow above, step for step. The prompt copy (title, message) is exactly as pinned in step 4.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/pyenv_build_deps_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze on the touched file**

Run: `flutter analyze lib/core/services/pyenv_build_deps.dart`
Expected: clean except the pre-existing `material.dart` deprecation infos (if any).

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/pyenv_build_deps.dart test/core/services/pyenv_build_deps_test.dart
git commit -m "feat(pyenv): ask permission and install missing build libraries before building Python"
```

### Task 5: Hook into the pyenv modal

**Files:**
- Modify: `lib/features/apps/presentation/widgets/pyenv_manage_modal.dart`

**Interfaces:**
- Consumes: Task 4's `PyenvBuildDeps().ensureBeforeInstall`.
- Produces: `_install` runs the ensure flow before `installVersion` and aborts on `false`.

- [ ] **Step 1: Wire the ensure flow into `_install`**

```dart
Future<void> _install(String version) async {
  setState(() => _installingVersion = version);
  try {
    final depsOk = await PyenvBuildDeps().ensureBeforeInstall(
      askPermission: (prompt) => AppDialogs.showPermissionRequest(
        context,
        title: prompt.title,
        message: prompt.message,
        command: prompt.command,
      ),
      onProgress: (progress) {
        if (!mounted) return;
        switch (progress.status) {
          case InstallStatus.succeeded:
            AppDialogs.showToast(context, progress.message);
          case InstallStatus.failed:
            AppDialogs.showError(
              context,
              title: 'Could not install build libraries',
              message: progress.message,
            );
          case InstallStatus.starting:
            break;
        }
      },
    );
    if (!depsOk) return;
    await ref.read(pyenvProvider.notifier).installVersion(version);
    if (mounted) {
      AppDialogs.showToast(context, 'Python $version installed successfully');
    }
  } catch (e) {
    // (existing error handling, unchanged)
  } finally {
    if (mounted) setState(() => _installingVersion = null);
  }
}
```

Imports to add: `../../../../core/services/pyenv_build_deps.dart` and `../../../../core/services/ssl_service.dart` (for `InstallStatus`).

- [ ] **Step 2: Run analyze on the touched file**

Run: `flutter analyze lib/features/apps/presentation/widgets/pyenv_manage_modal.dart`
Expected: clean except the pre-existing `material.dart` deprecation infos.

- [ ] **Step 3: Verify manually on the dev machine**

Open the pyenv modal and tap Install on a version: with all headers present (the dev machine, Fedora 45) no permission prompt appears and the install proceeds exactly as today. The prompt path itself cannot be exercised on this machine — it is covered by the Task 4 tests with fake dependencies.

- [ ] **Step 4: Commit**

```bash
git add lib/features/apps/presentation/widgets/pyenv_manage_modal.dart
git commit -m "feat(pyenv): ask to install missing build libraries before installing Python"
```

## Verification (after all tasks)

- `flutter analyze` on all touched files: clean except the pre-existing deprecation infos.
- `flutter test test/core/services/pyenv_build_deps_test.dart test/core/services/pyenv_build_deps_declines_test.dart test/core/services/ssl_service_linux_test.dart test/core/services/ssl_certutil_install_test.dart test/core/services/ssl_install_declines_test.dart`: all pass.
- `flutter test` (whole suite): passes.
- Manual check as in Task 5, Step 3.

## Self-Review

- **Spec coverage:** every spec line has a task — the hook (Task 5), the check (Task 1), the prompt (Task 4, exact copy pinned), the elevated install (Task 4), the ask-once declines (Tasks 3–4), the unknown-distro hint (Task 4), Linux-only (Task 4 wrapper), no Isar changes (Task 3).
- **Step scan:** each step names one action with a checkable result; no step carries an implementation body the signature and tests already determine.
- **Type consistency:** `packageInstallArgs` takes `List<String>` everywhere after Task 2; `ensureBuildDeps` consumes `({String packageManager, List<String> packageNames})?`, the same shape `buildDepsFor` produces minus the probes; `SslInstallPrompt` / `SslInstallProgress` / `InstallStatus` are the shared prompt/progress types in Tasks 4–5.
- **Review Focus:** each of the five failure modes has its test in Task 4.
- **Proportion:** the plan is longer than the short spec because it pins exact signatures, copy, and test names the spec leaves open — that is the plan's job — but it contains no implementation bodies.
