# Riverpod 3 / nativeapi Idiomatic Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the four places where the Riverpod 3 / isar_plus / tray_manager upgrade configured the *libraries* to match the old code, and change the *code* to match the new libraries instead — leaving zero analyzer findings.

**Architecture:** Four independent changes, each landing as its own commit. (1) Delete `build.yaml` and rename nine notifier classes so the generator's default `Notifier$` strip pattern produces the same provider names. (2) Convert the last `StateNotifier` in the codebase to a Riverpod 3 `Notifier`. (3) Declare eight providers `keepAlive` so the long-lived apps state graph stops depending on autoDispose state. (4) Replace the deprecated `tray_manager/legacy.dart` bridge with the `nativeapi` API it wraps.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4 · riverpod 3.4.3 · riverpod_annotation 4.0.7 · riverpod_generator 4.0.9 · riverpod_lint 3.1.9 · build_runner 2.16.1 · nativeapi 0.3.0 · isar_plus 1.3.9 · window_manager 0.5.1

**Spec:** `docs/superpowers/specs/2026-09-22-riverpod3-idiomatic-refactor-design.md`

## Global Constraints

- **Codegen command:** `dart run build_runner build --delete-conflicting-outputs` (build_runner 2.16.1). Run it after every change to a `@riverpod`/`@Riverpod` annotation or a notifier class name.
- **Never hand-edit `*.g.dart`.** They are regenerated. Two independent greps, both measured on this tree, give the shape of the rename:
  - The nine old **class names** as bare tokens: **176** occurrences in `lib` + `test`, of which **36** are in `.g.dart` files.
  - The nine old **provider identifiers**: **134** occurrences, of which **18** are in `.g.dart` files.
  
  Step 4's script excludes `.g.dart` by construction (it filters them out of the file list), so those 36 + 18 hits are left for codegen to rewrite.
- **The analyzer gate is `dart analyze`, not `flutter analyze`.** In this environment `flutter analyze` intermittently reports "No issues found!" while `dart analyze` stably reports the real findings. `dart analyze` is the source of truth; run `flutter analyze` only as the secondary check the spec lists.
- **Baseline before any work:** `dart analyze` reports exactly **12 issues** (10 × `only_use_keep_alive_inside_keep_alive`, 2 × `avoid_public_notifier_properties`), exit code 2. **Target:** 0 issues, exit code 0.
- **Generated provider naming** comes from `riverpod_analyzer_utils` `BuildYamlOptions.fromMap`: defaults are `provider_name_prefix: ''`, `provider_name_suffix: 'Provider'`, `provider_name_strip_pattern: 'Notifier$'`. The strip pattern is applied to the class name, then `prefix + (prefix.isEmpty ? baseName.lowerFirst : baseName.titled) + suffix`. So class `Settings` → `settingsProvider`; class `SystemInfoState` → `systemInfoStateProvider`.
- **`@Riverpod(keepAlive: true)` is how a codegen provider opts out of autoDispose.** Codegen providers are autoDispose by default (`isAutoDispose => !annotation.keepAlive`). In the generated file this shows up as `isAutoDispose: true` / `isAutoDispose: false`.
- **Do not disturb the `flutter_launcher_icons:` block** at `pubspec.yaml:76`. It is a legitimate top-level key that happens to sit immediately after `dev_dependencies` with no blank line. When editing `pubspec.yaml`, change only the one dependency line.
- **Commit order is 1 → 3 → 4 → 2** (item 2 last, because the tray is the only change the test suite cannot verify and must stay independently revertible). **Four commits total, one per item.**
- **Bash tool output in this environment is unreliable** — it frequently returns a summarized/hallucinated version of the command's output. Redirect to a file and read it back:
  ```bash
  some_command > /tmp/out.txt 2>&1; echo "exit=$?" >> /tmp/out.txt
  ```
  then use the Read tool on `/tmp/out.txt`. Use this for every verification command whose output you need to actually read.
- **Test suite:** 604 tests pass at baseline. Four pre-existing Linux-on-Windows failures (path separators, `.desktop` creation, `PathAccessException errno=32`) are unrelated and must stay failing-or-skipped exactly as they are; do not "fix" them.
- **Commit messages** end with:
  ```
  Co-Authored-By: Claude Code <noreply@anthropic.com>
  ```
- **Manual verification:** the tray behaviour in Task 4 is verified by hand by the user, not by the test suite. Task 4 is not complete until the user reports the manual check passed.

---

## File Structure

**Deleted**
- `build.yaml` — the `provider_name_strip_pattern: ""` override.

**Renamed classes (Task 1), one file each**
- `lib/features/apps/data/apps_provider.dart` — `AppsNotifier` → `Apps`
- `lib/features/settings/data/settings_provider.dart` — `SettingsNotifier` → `Settings`
- `lib/features/sites/data/sites_provider.dart` — `SitesNotifier` → `Sites`
- `lib/shared/providers/error_provider.dart` — `ErrorNotifier` → `AppError`
- `lib/features/databases/data/redis_provider.dart` — `RedisNotifier` → `Redis`
- `lib/features/databases/data/databases_provider.dart` — `DatabasesNotifier` → `Databases`
- `lib/features/apps/data/pyenv_provider.dart` — `PyenvNotifier` → `Pyenv`
- `lib/features/system/data/system_info_provider.dart` — `SystemInfoNotifier` → `SystemInfoState`
- `lib/features/hosts/data/hosts_provider.dart` — `HostsNotifier` → `Hosts`

**Rewritten (Task 2)**
- `lib/features/tunnels/data/tunnels_provider.dart` — `StateNotifierProvider` → `NotifierProvider`, drop the `legacy.dart` import.
- `test/features/tunnels/presentation/tunnels_page_test.dart` — mock + override.
- `test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart` — mock + 5 overrides.
- **New:** `test/features/tunnels/data/tunnel_sessions_provider_test.dart` — locks in the seed-from-`currentSessions` behaviour.

**Annotated (Task 3)**
- Eight providers gain `keepAlive: true`; `lib/core/services/ssl_service.dart` gets two members made private.
- **New:** `test/core/services/keep_alive_providers_test.dart` — asserts the new lifetimes.

**Rewritten (Task 4)**
- `lib/core/services/window_service.dart` — the whole tray section.
- `pubspec.yaml` — `tray_manager: 0.7.0` → `nativeapi: ^0.3.0`.

---

### Task 1: Delete `build.yaml` and rename the nine notifier classes

**Files:**
- Delete: `build.yaml`
- Modify: the 9 class files listed above, plus every call site. Measured on this tree, excluding generated files: **116 provider-identifier references across 27 files**, **127 `ClassName.member` static references across 18 files**, and **14 `group()` strings** naming an old class. The union of the files touched is **47**.

**Interfaces:**
- Consumes: nothing.
- Produces: nine classes named `Apps`, `Settings`, `Sites`, `AppError`, `Redis`, `Databases`, `Pyenv`, `SystemInfoState`, `Hosts`, each exposing the same public API as the class it replaces. Their generated providers become `appsProvider`, `settingsProvider`, `sitesProvider`, `appErrorProvider`, `redisProvider`, `databasesProvider`, `pyenvProvider`, `systemInfoStateProvider`, `hostsProvider`. Tasks 2, 3 and 4 depend on these names — Task 4's `window_service.dart` reads `appsProvider` and `settingsProvider` at ten sites, and Task 3's `appServiceManager` reads `logServiceProvider`.

**Why the rename is the same change as deleting `build.yaml`:** under the default `Notifier$` strip pattern, class `SettingsNotifier` already generates `settingsProvider` — which is *why* `build.yaml` existed (to get `settingsNotifierProvider` instead). Deleting `build.yaml` without renaming changes all 116 provider identifiers. Renaming the classes to `Settings` etc. makes the class name agree with the provider name, so the identifier a reader sees in the class and the one they see at the call site match.

- [ ] **Step 1: Record the baseline**

```bash
cd D:/Source/ponta/dev-stack
dart analyze > /tmp/t1_baseline.txt 2>&1; echo "exit=$?" >> /tmp/t1_baseline.txt
grep -c "" /tmp/t1_baseline.txt
```
Read `/tmp/t1_baseline.txt`. Expected: **12 issues found**, `exit=2`. Note the current provider identifiers so the post-change grep has something to compare against.

- [ ] **Step 2: Delete `build.yaml`**

```bash
cd D:/Source/ponta/dev-stack
git rm build.yaml
```
Expected: `rm 'build.yaml'`.

- [ ] **Step 3: Confirm none of the nine new class names is taken**

```bash
cd D:/Source/ponta/dev-stack
grep -rnE "^\s*(class|enum|typedef|mixin|extension)\s+(Apps|Settings|Sites|AppError|Redis|Databases|Pyenv|SystemInfoState|Hosts)\b" lib test --include=*.dart > /tmp/t1_collide.txt 2>&1
cat /tmp/t1_collide.txt
```
Expected: **no output**. If anything is listed, stop — the spec's collision analysis was wrong and a different name is needed.

- [ ] **Step 4: Rename the nine classes**

`\b` matters here: it leaves `_EmptyAppsNotifier` alone (no word boundary before `AppsNotifier` inside it) while still rewriting `class AppsNotifier` and the generated mixin `_$AppsNotifier` (`$` is not a word character, so a boundary exists). Leaving `_EmptyAppsNotifier` named as-is is intentional — it is a test-local name, and only its `extends` clause needs to change.

```bash
cd D:/Source/ponta/dev-stack

rename_symbol() {
  local old="$1" new="$2"
  for f in $(grep -rl --include=*.dart "$old" lib test | grep -v '\.g\.dart$'); do
    sed -i "s/\b${old}\b/${new}/g" "$f"
  done
}

# class names
rename_symbol AppsNotifier       Apps
rename_symbol SettingsNotifier   Settings
rename_symbol SitesNotifier      Sites
rename_symbol ErrorNotifier      AppError
rename_symbol RedisNotifier      Redis
rename_symbol DatabasesNotifier  Databases
rename_symbol PyenvNotifier      Pyenv
rename_symbol SystemInfoNotifier SystemInfoState
rename_symbol HostsNotifier      Hosts

# provider identifiers (lowercase first letter, so no overlap with the above)
rename_symbol appsNotifierProvider       appsProvider
rename_symbol settingsNotifierProvider   settingsProvider
rename_symbol sitesNotifierProvider      sitesProvider
rename_symbol errorNotifierProvider      appErrorProvider
rename_symbol redisNotifierProvider      redisProvider
rename_symbol databasesNotifierProvider  databasesProvider
rename_symbol pyenvNotifierProvider      pyenvProvider
rename_symbol systemInfoNotifierProvider systemInfoStateProvider
rename_symbol hostsNotifierProvider      hostsProvider
```

This also rewrites the 127 static-member references (`DatabasesNotifier.validateIdentifier` → `Databases.validateIdentifier`) and the 14 `group('DatabasesNotifier.dropFailed')`-style strings, because both are spelled with the old class name.

- [ ] **Step 5: Verify no old identifier survives outside generated files**

```bash
cd D:/Source/ponta/dev-stack
grep -rnE "\b(AppsNotifier|SettingsNotifier|SitesNotifier|ErrorNotifier|RedisNotifier|DatabasesNotifier|PyenvNotifier|SystemInfoNotifier|HostsNotifier)\b" lib test --include=*.dart | grep -v '\.g\.dart$' > /tmp/t1_leftover.txt 2>&1
grep -rnE "\b(appsNotifierProvider|settingsNotifierProvider|sitesNotifierProvider|errorNotifierProvider|redisNotifierProvider|databasesNotifierProvider|pyenvNotifierProvider|systemInfoNotifierProvider|hostsNotifierProvider)\b" lib test --include=*.dart | grep -v '\.g\.dart$' >> /tmp/t1_leftover.txt 2>&1
cat /tmp/t1_leftover.txt
```
Expected: no output. (`_EmptyAppsNotifier` is not matched — `\b` requires a non-word character before `AppsNotifier`, and `y` is a word character.)

- [ ] **Step 6: Regenerate**

```bash
cd D:/Source/ponta/dev-stack
dart run build_runner build --delete-conflicting-outputs > /tmp/t1_gen.txt 2>&1; echo "exit=$?" >> /tmp/t1_gen.txt
```
Read `/tmp/t1_gen.txt`. Expected: `exit=0`, and a `[INFO] Succeeded after ...`.

- [ ] **Step 7: Verify the generated provider names**

```bash
cd D:/Source/ponta/dev-stack
grep -hn "^final .*Provider = \|^final .*Provider\b" lib/features/apps/data/apps_provider.g.dart lib/features/settings/data/settings_provider.g.dart lib/features/sites/data/sites_provider.g.dart lib/shared/providers/error_provider.g.dart lib/features/databases/data/redis_provider.g.dart lib/features/databases/data/databases_provider.g.dart lib/features/apps/data/pyenv_provider.g.dart lib/features/system/data/system_info_provider.g.dart lib/features/hosts/data/hosts_provider.g.dart > /tmp/t1_names.txt 2>&1
cat /tmp/t1_names.txt
```
Expected to see exactly these declarations:
`appsProvider`, `settingsProvider`, `sitesProvider`, `appErrorProvider`, `redisProvider`, `databasesProvider`, `pyenvProvider`, `systemInfoStateProvider`, `hostsProvider`.

- [ ] **Step 8: Analyze**

```bash
cd D:/Source/ponta/dev-stack
dart analyze > /tmp/t1_analyze.txt 2>&1; echo "exit=$?" >> /tmp/t1_analyze.txt
```
Read it. Expected: the same **12 issues** as Step 1 — the same rules at the same places, but with new symbol names in the messages. Anything *new* is a mistake in this task. (Exit code is still 2 at this point; Tasks 3 and 4 clear the findings.)

- [ ] **Step 9: Run the full test suite**

```bash
cd D:/Source/ponta/dev-stack
flutter test > /tmp/t1_test.txt 2>&1; echo "exit=$?" >> /tmp/t1_test.txt
tail -20 /tmp/t1_test.txt
```
Expected: 604 passing, plus the 4 pre-existing Linux-on-Windows failures — unchanged from baseline.

- [ ] **Step 10: Commit**

```bash
cd D:/Source/ponta/dev-stack
git add -A
git commit -m "$(cat <<'EOF'
refactor(riverpod): drop build.yaml and rename notifiers to the riverpod 3 convention

riverpod_generator 4 strips a trailing "Notifier" from the class name before
appending the "Provider" suffix, so `SettingsNotifier` already generated
`settingsProvider`. build.yaml overrode that with an empty strip pattern to
keep the Riverpod 2 names the call sites were written against.

Rename the nine classes that carried the redundant suffix instead, so the
class name and the provider name agree and the override is unnecessary.

ErrorNotifier -> AppError (Error collides with dart:core)
SystemInfoNotifier -> SystemInfoState (collides with the domain model)

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Convert `TunnelSessionsNotifier` from `StateNotifier` to `Notifier`

**Files:**
- Modify: `lib/features/tunnels/data/tunnels_provider.dart:1-52`
- Modify: `test/features/tunnels/presentation/tunnels_page_test.dart:66-81`
- Modify: `test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart:236-253` and the five `overrideWith` calls at lines 66, 101, 142, 181, 214
- Create: `test/features/tunnels/data/tunnel_sessions_provider_test.dart`

**Interfaces:**
- Consumes: `tunnelManagerServiceProvider` (`Provider<TunnelManagerService>`), `TunnelManagerService.currentSessions` (`Map<int, TunnelSession>`), `TunnelManagerService.sessionsStream` (`Stream<Map<int, TunnelSession>>`).
- Produces: `tunnelSessionsProvider` becomes `NotifierProvider<TunnelSessionsNotifier, Map<int, TunnelSession>>`, constructed as `TunnelSessionsNotifier.new`. `TunnelSessionsNotifier` gains `Map<int, TunnelSession> build()` and keeps `Future<void> start(TunnelModel)`, `Future<void> stop(int)`, `Future<void> delete(int)`. **`overrideWith` now takes a zero-argument factory** — verified against `riverpod-3.4.3/lib/src/core/provider/notifier_provider.dart:432`, `Override overrideWith(NotifierT Function() create)` — so every test call site changes from `overrideWith((ref) => Mock())` to `overrideWith(() => Mock())`.

**Two facts that drive the shape:**
1. `NotifierProvider` takes a zero-argument factory, so the manager cannot be constructor-injected. It comes from `ref.watch` inside `build()`.
2. `TunnelManagerService._sessionsController` is a **broadcast** `StreamController` (`tunnel_manager_service.dart:60`), so `sessionsStream` replays nothing on listen. `build()` must **return `_manager.currentSessions`** — the legacy `StateNotifier` seeded its `super(...)` the same way. Returning an empty map and waiting for the first event would show an empty list until the next state change.

- [ ] **Step 1: Write the failing test**

Create `test/features/tunnels/data/tunnel_sessions_provider_test.dart`:

```dart
import 'package:dev_stack/features/tunnels/data/tunnel_downloader_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
import 'package:dev_stack/features/tunnels/data/tunnels_provider.dart';
import 'package:dev_stack/features/tunnels/domain/tunnel_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reports the binary as already present so [TunnelManagerService.startTunnel]
/// skips the download step.
class _FakeDownloader extends TunnelDownloaderService {
  _FakeDownloader()
      : super(baseDirResolver: () => '', isWindowsResolver: () => true);

  @override
  Future<bool> isBinaryDownloaded(String provider) async => true;

  @override
  String getBinaryPath(String provider) => 'fake_binary';
}

void main() {
  test('build() seeds from currentSessions and then follows sessionsStream',
      () async {
    final manager = TunnelManagerService(
      downloader: _FakeDownloader(),
      startProcessFn: (exec, args) async => FakeManagedProcess(0),
      stopProcessFn: (pid) async {},
    );
    addTearDown(manager.dispose);

    final container = ProviderContainer.test(
      overrides: [tunnelManagerServiceProvider.overrideWithValue(manager)],
    );

    // Nothing has started yet.
    expect(container.read(tunnelSessionsProvider), isEmpty);

    await manager.startTunnel(
      TunnelModel(
        id: 1,
        name: 'quick',
        provider: 'cloudflare',
        targetPort: 8080,
      ),
    );
    await container.pump();

    // The broadcast stream does not replay, so this only holds if build()
    // both seeded from currentSessions and subscribed before the emit.
    expect(container.read(tunnelSessionsProvider), contains(1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd D:/Source/ponta/dev-stack
flutter test test/features/tunnels/data/tunnel_sessions_provider_test.dart > /tmp/t2_fail.txt 2>&1; echo "exit=$?" >> /tmp/t2_fail.txt
tail -30 /tmp/t2_fail.txt
```
Expected: FAIL to compile — the test uses the target API (`NotifierProvider`-style `overrideWith` with a zero-argument closure, and `tunnelSessionsProvider` read as a plain `Map`), which `StateNotifierProvider` does not provide.

- [ ] **Step 3: Convert the provider**

Replace lines 1-52 of `lib/features/tunnels/data/tunnels_provider.dart` with:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import '../../../core/database/isar_provider.dart';
import '../domain/tunnel_model.dart';
import '../domain/tunnel_session.dart';
import 'tunnel_manager_service.dart';

final tunnelsStreamProvider = StreamProvider<List<TunnelModel>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield [];
    return;
  }

  yield* isar.tunnelModels.where().watch(fireImmediately: true);
});

final tunnelSessionsProvider =
    NotifierProvider<TunnelSessionsNotifier, Map<int, TunnelSession>>(
  TunnelSessionsNotifier.new,
);

class TunnelSessionsNotifier extends Notifier<Map<int, TunnelSession>> {
  late TunnelManagerService _manager;
  StreamSubscription<Map<int, TunnelSession>>? _subscription;

  @override
  Map<int, TunnelSession> build() {
    _manager = ref.watch(tunnelManagerServiceProvider);

    // sessionsStream is a broadcast stream, so it replays nothing on listen:
    // seed from the manager's current map and follow it from here.
    _subscription = _manager.sessionsStream.listen((sessions) {
      state = sessions;
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return _manager.currentSessions;
  }

  Future<void> start(TunnelModel tunnel) => _manager.startTunnel(tunnel);
  Future<void> stop(int tunnelId) => _manager.stopTunnel(tunnelId);
  Future<void> delete(int tunnelId) => _manager.deleteTunnel(tunnelId);
}
```

The `import 'package:flutter_riverpod/legacy.dart';` line and its explanatory comment are deleted; `Notifier` and `NotifierProvider` come from the main `flutter_riverpod.dart` export.

- [ ] **Step 4: Run the new test to verify it passes**

```bash
cd D:/Source/ponta/dev-stack
flutter test test/features/tunnels/data/tunnel_sessions_provider_test.dart > /tmp/t2_pass.txt 2>&1; echo "exit=$?" >> /tmp/t2_pass.txt
tail -20 /tmp/t2_pass.txt
```
Expected: `All tests passed!`

- [ ] **Step 5: Rewrite the mock in `tunnels_page_test.dart`**

Replace lines 66-81 with:

```dart
/// Minimal TunnelSessionsNotifier subclass for tests.
///
/// [build] deliberately does not call `super.build()`, so no real
/// [TunnelManagerService] is constructed — these tests only render, and
/// constructing the real manager would drag in the tunnel downloader, the log
/// service, and a real database. The base class's `_manager` is library-private
/// and assigned only inside `build()`, so a subclass in `test/` cannot read or
/// set it; the three actions are overridden instead.
class TunnelSessionsNotifierMock extends TunnelSessionsNotifier {
  TunnelSessionsNotifierMock(this._initial);

  final Map<int, TunnelSession> _initial;

  @override
  Map<int, TunnelSession> build() => _initial;

  @override
  Future<void> start(TunnelModel tunnel) => Future<void>.value();

  @override
  Future<void> stop(int tunnelId) => Future<void>.value();

  @override
  Future<void> delete(int tunnelId) => Future<void>.value();
}
```

Then delete the now-unused import on line 6 of the same file:

```dart
import 'package:dev_stack/features/tunnels/data/tunnel_manager_service.dart';
```

The old mock's `super(TunnelManagerService(...))` call was the only thing in this file that used it, so leaving it in place produces an `unused_import` warning — which would break the zero-issues gate in Step 9. The other two tunnel imports stay: `tunnel_model.dart` is needed for the `start(TunnelModel)` override and `tunnel_session.dart` for `Map<int, TunnelSession>` and the `TunnelSession(...)` literal in the second test.

```bash
cd D:/Source/ponta/dev-stack
grep -n "^import" test/features/tunnels/presentation/tunnels_page_test.dart > /tmp/t2_imports.txt 2>&1
cat /tmp/t2_imports.txt
```
Expected: eight imports — `material.dart`, `flutter_test`, `flutter_riverpod`, `tunnels_page.dart`, `tunnels_provider.dart`, `tunnel_model.dart`, `tunnel_session.dart`. `tunnel_manager_service.dart` must be gone.

- [ ] **Step 6: Update the two `overrideWith` calls in `tunnels_page_test.dart`**

`NotifierProvider.overrideWith` in riverpod 3.4.3 is `Override overrideWith(NotifierT Function() create)` — zero arguments. Every call site currently written as `overrideWith((ref) => …)` must lose the `ref` parameter. This is a two-character edit, not a sed: use the Edit tool.

Occurrence 1, at lines 16-18:

```dart
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({}),
          ),
```
becomes
```dart
          tunnelSessionsProvider.overrideWith(
            () => TunnelSessionsNotifierMock({}),
          ),
```

Occurrence 2, at lines 44-52:

```dart
          tunnelSessionsProvider.overrideWith(
            (ref) => TunnelSessionsNotifierMock({
              10: const TunnelSession(
                tunnelId: 10,
                status: TunnelStatus.running,
                publicUrl: 'https://myshop.trycloudflare.com',
              ),
            }),
          ),
```
becomes the same block with `(ref) =>` replaced by `() =>`.

Verify with:

```bash
cd D:/Source/ponta/dev-stack
grep -n "tunnelSessionsProvider.overrideWith" -A1 test/features/tunnels/presentation/tunnels_page_test.dart > /tmp/t2_ovr.txt 2>&1
cat /tmp/t2_ovr.txt
```
Expected: two hits, each followed by a line beginning `() =>`.

- [ ] **Step 7: Rewrite the mock and the five overrides in `site_tunnel_dialog_test.dart`**

Replace lines 236-253 with:

```dart
/// Minimal TunnelSessionsNotifier subclass for tests.
///
/// [build] deliberately does not call `super.build()`, so no real
/// [TunnelManagerService] is constructed here. The optional [manager] is what
/// the three action overrides forward to, so a test can assert on the manager's
/// own state after driving the dialog.
class TunnelSessionsNotifierMock extends TunnelSessionsNotifier {
  TunnelSessionsNotifierMock(this._initial, {TunnelManagerService? manager})
      : _manager = manager;

  final Map<int, TunnelSession> _initial;
  final TunnelManagerService? _manager;

  @override
  Map<int, TunnelSession> build() => _initial;

  @override
  Future<void> start(TunnelModel tunnel) =>
      _manager?.startTunnel(tunnel) ?? Future<void>.value();

  @override
  Future<void> stop(int tunnelId) =>
      _manager?.stopTunnel(tunnelId) ?? Future<void>.value();

  @override
  Future<void> delete(int tunnelId) =>
      _manager?.deleteTunnel(tunnelId) ?? Future<void>.value();
}
```

Then change the five `overrideWith` calls (lines 66, 101, 142, 181, 214) from `(ref) => ...` to `() => ...`. The fifth is the one that matters behaviourally:

```dart
          tunnelSessionsProvider.overrideWith(
            () => TunnelSessionsNotifierMock({}, manager: mockManager),
          ),
```

The behavioural test taps "Start Quick Tunnel (Cloudflare)", which reaches `ref.read(tunnelSessionsProvider.notifier).start(savedTunnel)` — the **mock's** override — and then asserts `mockManager.currentSessions` is non-empty. That assertion is why the mock needs the `manager:` parameter and why `start` forwards to it.

- [ ] **Step 8: Verify no `legacy.dart` import remains**

```bash
cd D:/Source/ponta/dev-stack
grep -rn "flutter_riverpod/legacy.dart\|StateNotifier" lib test --include=*.dart | grep -v '\.g\.dart$' > /tmp/t2_legacy.txt 2>&1
cat /tmp/t2_legacy.txt
```
Expected: no output.

- [ ] **Step 9: Regenerate and analyze**

```bash
cd D:/Source/ponta/dev-stack
dart run build_runner build --delete-conflicting-outputs > /tmp/t2_gen.txt 2>&1; echo "exit=$?" >> /tmp/t2_gen.txt
dart analyze > /tmp/t2_analyze.txt 2>&1; echo "exit=$?" >> /tmp/t2_analyze.txt
```
Read both. Expected: gen `exit=0`; analyze still **12 issues** (Task 3 clears them), with nothing new.

- [ ] **Step 10: Run the full test suite**

```bash
cd D:/Source/ponta/dev-stack
flutter test > /tmp/t2_test.txt 2>&1; echo "exit=$?" >> /tmp/t2_test.txt
tail -20 /tmp/t2_test.txt
```
Expected: 605 passing (604 + the new test), plus the same 4 pre-existing failures.

- [ ] **Step 11: Commit**

```bash
cd D:/Source/ponta/dev-stack
git add -A
git commit -m "$(cat <<'EOF'
refactor(tunnels): replace StateNotifier with Notifier

StateNotifier and StateNotifierProvider moved out of Riverpod 3's main export
into flutter_riverpod/legacy.dart. TunnelSessionsNotifier was the last consumer.

NotifierProvider takes a zero-argument factory, so the manager comes from
ref.watch inside build() rather than the constructor, and ref.onDispose
replaces the dispose() override. build() returns currentSessions because
sessionsStream is a broadcast stream and replays nothing on listen.

The test doubles move their initial state into a build() override, since a
notifier has no element to assign `state` on before it is built, and override
the three actions because the base class's `_manager` is library-private.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Keep the apps state graph and the log service alive

**Files:**
- Modify: `lib/features/apps/data/apps_provider.dart:22` and `:28`
- Modify: `lib/features/apps/data/app_installer_service.dart:28`
- Modify: `lib/features/apps/data/app_service_manager.dart` (no change needed — already `keepAlive`, listed for verification only)
- Modify: `lib/shared/providers/error_provider.dart:5`
- Modify: `lib/core/services/path_service.dart:12`
- Modify: `lib/features/apps/data/meilisearch_settings_provider.dart:9`
- Modify: `lib/features/apps/data/rustfs_settings_provider.dart:9`
- Modify: `lib/core/services/log_service.dart:13`
- Modify: `lib/core/services/ssl_service.dart:27` and `:45`
- Create: `test/core/services/keep_alive_providers_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks except the renamed providers from Task 1 (`appsNotifierProvider` → `appsProvider`, `errorNotifierProvider` → `appErrorProvider`, and the rest — this task's greps and code use the post-rename names).
- Produces: eight providers that are no longer autoDispose: `appsRepositoryProvider`, `appsProvider`, `appInstallerServiceProvider`, `appErrorProvider`, `pathServiceProvider`, `meilisearchSettingsProvider`, `rustFSSettingsProvider`, `logServiceProvider`. `SslService._isInstalled` and `SslService._mkcertPath` become private.

**Why these eight:** `only_use_keep_alive_inside_keep_alive` fires when a non-autoDispose provider invokes a generated autoDispose provider. Only two such dependencies exist — `WindowService` (keepAlive) reads `appsProvider` at nine sites, and `appServiceManager` (keepAlive) reads `logServiceProvider` at one. Marking `appsNotifier` keepAlive would move the warning onto *its* dependencies unless they are marked too, so the whole reachable set is declared. Each of the eight was checked for further dependencies:

| Provider | Reads | Already keepAlive? |
|---|---|---|
| `appsProvider` | `isarProvider`, `appsRepositoryProvider`, `appServiceManagerProvider`, `appInstallerServiceProvider`, `appErrorProvider`, `pathServiceProvider`, `meilisearchSettingsProvider`, `rustFSSettingsProvider` | isar ✓, appServiceManager ✓; the rest are in this task |
| `appsRepositoryProvider` | `isarProvider` | ✓ |
| `appInstallerServiceProvider` | `logServiceProvider` | in this task |
| `appErrorProvider` | *(nothing)* | — |
| `pathServiceProvider` | `logServiceProvider` | in this task |
| `meilisearchSettingsProvider` | *(nothing)* | — |
| `rustFSSettingsProvider` | *(nothing)* | — |
| `logServiceProvider` | *(nothing)* | — |

`logServiceProvider` returns the module-level `AppLogger` singleton and holds no per-listener state, so autoDispose was never meaningful.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/keep_alive_providers_test.dart`:

```dart
import 'package:dev_stack/core/services/log_service.dart';
import 'package:dev_stack/core/services/path_service.dart';
import 'package:dev_stack/features/apps/data/app_installer_service.dart';
import 'package:dev_stack/features/apps/data/meilisearch_settings_provider.dart';
import 'package:dev_stack/features/apps/data/rustfs_settings_provider.dart';
import 'package:dev_stack/shared/providers/error_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The apps state graph is read by `WindowService`, which is `keepAlive`, so its
/// dependencies have to be `keepAlive` too — otherwise
/// `only_use_keep_alive_inside_keep_alive` fires, correctly reporting that a
/// long-lived provider is reaching into short-lived state.
///
/// Each case listens to the provider, closes the subscription, and asserts the
/// provider is still alive. An autoDispose provider would have been released by
/// then.
///
/// The provider itself and the liveness check are both passed in as closures:
/// `ProviderBase` — the parameter type `ProviderContainer.exists` takes — is not
/// exported from `flutter_riverpod.dart`, so a helper cannot name it.
Future<void> expectKeptAlive(
  ProviderContainer container,
  ProviderSubscription<Object?> subscription,
  bool Function() isAlive,
) async {
  await container.pump();
  subscription.close();
  await container.pump();
  expect(isAlive(), isTrue);
}

void main() {
  test('logServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(logServiceProvider, (previous, next) {}),
      () => container.exists(logServiceProvider),
    );
  });

  test('appErrorProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(appErrorProvider, (previous, next) {}),
      () => container.exists(appErrorProvider),
    );
  });

  test('pathServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(pathServiceProvider, (previous, next) {}),
      () => container.exists(pathServiceProvider),
    );
  });

  test('appInstallerServiceProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(appInstallerServiceProvider, (previous, next) {}),
      () => container.exists(appInstallerServiceProvider),
    );
  });

  test('meilisearchSettingsProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(meilisearchSettingsProvider, (previous, next) {}),
      () => container.exists(meilisearchSettingsProvider),
    );
  });

  test('rustFSSettingsProvider stays alive', () async {
    final container = ProviderContainer.test();
    await expectKeptAlive(
      container,
      container.listen(rustFSSettingsProvider, (previous, next) {}),
      () => container.exists(rustFSSettingsProvider),
    );
  });
}
```

This file was written and run against the codebase before the plan was finalised, in both directions: at baseline it compiles cleanly and all six assertions fail with `Expected: true / Actual: <false>` (the providers are still autoDispose), and the mechanism was separately confirmed with a plain `Provider` (`exists=true` after the listener closes) versus a `Provider.autoDispose` one (`exists=false`). All six providers are cheap to construct — no database, no IO.

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd D:/Source/ponta/dev-stack
flutter test test/core/services/keep_alive_providers_test.dart > /tmp/t3_fail.txt 2>&1; echo "exit=$?" >> /tmp/t3_fail.txt
tail -30 /tmp/t3_fail.txt
```
Expected: FAIL — all six providers are still autoDispose, so `container.exists(...)` is `false` after the listener closes.

- [ ] **Step 3: Mark the eight providers keepAlive**

Change `@riverpod` to `@Riverpod(keepAlive: true)` in each of these, leaving the declaration itself untouched.

Use the `0,/regex/` form rather than line numbers: it targets the *first* match, so the two edits to `apps_provider.dart` are ordered (first `appsRepository`, then `Apps`), and re-running it is a no-op instead of an error. Line numbers would be fragile here — Task 1's rename changed the lengths of the lines above, and `apps_provider.dart` has the two annotations at lines 21 and 27, not 22 and 28.

```bash
cd D:/Source/ponta/dev-stack

# apps_provider.dart has two: appsRepository first, then Apps (renamed in Task 1).
# Order matters — each call rewrites the first remaining bare @riverpod.
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/features/apps/data/apps_provider.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/features/apps/data/apps_provider.dart

sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/features/apps/data/app_installer_service.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/shared/providers/error_provider.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/core/services/path_service.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/features/apps/data/meilisearch_settings_provider.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/features/apps/data/rustfs_settings_provider.dart
sed -i '0,/^@riverpod$/s//@Riverpod(keepAlive: true)/' lib/core/services/log_service.dart
```

Verify each edit landed:

```bash
cd D:/Source/ponta/dev-stack
grep -n -B1 "^class Apps\b\|^Future<AppsRepository> appsRepository\|^AppInstallerService appInstallerService\|^class AppError\b\|^PathService pathService\|^class MeilisearchSettings\b\|^class RustFSSettings\b\|^LogService logService" lib/features/apps/data/apps_provider.dart lib/features/apps/data/app_installer_service.dart lib/shared/providers/error_provider.dart lib/core/services/path_service.dart lib/features/apps/data/meilisearch_settings_provider.dart lib/features/apps/data/rustfs_settings_provider.dart lib/core/services/log_service.dart > /tmp/t3_ann.txt 2>&1
cat /tmp/t3_ann.txt
```
Expected: every one of the eight declarations is preceded by `@Riverpod(keepAlive: true)`.

- [ ] **Step 4: Make the two `SslService` members private**

In `lib/core/services/ssl_service.dart`:
- Line 27: `bool get isInstalled => state.value ?? false;` → `bool get _isInstalled => state.value ?? false;`
- Line 45: `String get mkcertPath {` → `String get _mkcertPath {`
- Line 200: `if (!isInstalled) return;` → `if (!_isInstalled) return;`
- Every remaining `mkcertPath` reference inside the file (lines 111, 129, 218, 236, 259, 274, 281, 317, 318, 329, 345, 391, 401, 430) → `_mkcertPath`.

Both members exist only for internal use: `isInstalled` is read at line 200 only, and `mkcertPath` only within `ssl_service.dart`. External callers use `generateSiteCert`, `getSiteCertDir`, `getSiteCertPath`, `getSiteKeyPath` — none of which is affected.

Do **not** rename `SslService.mkcertAssetBasename` or `SslService.buildElevatedMkcertArgs` — both are `@visibleForTesting` statics called by `test/core/services/ssl_service_linux_test.dart`.

**A plain global sed is wrong here and will not compile.** `buildElevatedMkcertArgs` declares its own parameter `required String mkcertPath` (line 259), and its two call sites pass the getter's value through under that same label (`mkcertPath: mkcertPath`, lines 345 and 401). A global `s/\bmkcertPath\b/_mkcertPath/g` rewrites the *parameter name and both labels* as well, producing `_mkcertPath: _mkcertPath` — which no longer matches the `mkcertPath:` label the external test uses. This was verified by running the sed against a fixture of the real file before the plan was finalised.

So rename the getter and its call sites, but leave `buildElevatedMkcertArgs`'s signature and its named-argument labels alone:

```bash
cd D:/Source/ponta/dev-stack
# 1. Rename every mkcertPath EXCEPT inside the buildElevatedMkcertArgs body.
sed -i '/^  static ({String executable/,/^  }/!s/\bmkcertPath\b/_mkcertPath/g' lib/core/services/ssl_service.dart
# 2. Restore the two named-argument labels at its call sites.
sed -i 's/^\(\s*\)_mkcertPath: _mkcertPath,$/\1mkcertPath: _mkcertPath,/' lib/core/services/ssl_service.dart
# 3. isInstalled has no such conflict.
sed -i 's/\bisInstalled\b/_isInstalled/g' lib/core/services/ssl_service.dart
```

Note that `sed`'s `/start/,/end/!s/…/` form applies the substitution to every line *outside* the range, which is what step 1 needs. Verify the result:

```bash
cd D:/Source/ponta/dev-stack
grep -n "mkcertPath\|isInstalled\|buildElevatedMkcertArgs" lib/core/services/ssl_service.dart > /tmp/t3_ssl.txt 2>&1
cat /tmp/t3_ssl.txt
```

Expected, in this order — and check each of these three things:
1. Line 259 still reads `required String mkcertPath,` (**no underscore**).
2. Lines ~345 and ~401 still read `mkcertPath: _mkcertPath,` (**bare label, underscored value**).
3. The getter is `String get _mkcertPath {` and every other `mkcertPath` in the file is `_mkcertPath`. There must be **no** remaining bare `mkcertPath` outside those three positions.

- [ ] **Step 5: Run the new test to verify it passes**

```bash
cd D:/Source/ponta/dev-stack
flutter test test/core/services/keep_alive_providers_test.dart > /tmp/t3_pass.txt 2>&1; echo "exit=$?" >> /tmp/t3_pass.txt
tail -20 /tmp/t3_pass.txt
```
Expected: `All tests passed!`

- [ ] **Step 6: Regenerate and analyze — the primary gate**

```bash
cd D:/Source/ponta/dev-stack
dart run build_runner build --delete-conflicting-outputs > /tmp/t3_gen.txt 2>&1; echo "exit=$?" >> /tmp/t3_gen.txt
dart analyze > /tmp/t3_analyze.txt 2>&1; echo "exit=$?" >> /tmp/t3_analyze.txt
cat /tmp/t3_analyze.txt
```
Expected: gen `exit=0`; analyze reports **`No issues found!`** and `exit=0` — down from 12. This is the real gate for this task: the analyzer *is* the test for the `only_use_keep_alive_inside_keep_alive` half, and it also confirms the two `avoid_public_notifier_properties` findings are gone.

If new `only_use_keep_alive_inside_keep_alive` warnings appear elsewhere, the dependency table above was incomplete — add the newly-implicated provider to Step 3 rather than reverting.

- [ ] **Step 7: Confirm the generated `isAutoDispose` flags**

```bash
cd D:/Source/ponta/dev-stack
grep -n "isAutoDispose" lib/features/apps/data/apps_provider.g.dart lib/features/apps/data/app_installer_service.g.dart lib/shared/providers/error_provider.g.dart lib/core/services/path_service.g.dart lib/features/apps/data/meilisearch_settings_provider.g.dart lib/features/apps/data/rustfs_settings_provider.g.dart lib/core/services/log_service.g.dart > /tmp/t3_flags.txt 2>&1
cat /tmp/t3_flags.txt
```

Expected: **nine** lines, every one reading `isAutoDispose: false` — two from `apps_provider.g.dart` (one per annotated declaration) and one from each of the other six. For reference, the generated shape is:

```dart
final appsProvider = AppsProvider._();

final class AppsProvider
    ...
        isAutoDispose: false,
```

Before this task the same grep returns `isAutoDispose: true` for all nine (verified: `apps_provider.g.dart` lines 29 and 62, `log_service.g.dart` line 24 are all `true` at baseline). If any line still says `true`, the corresponding `@Riverpod(keepAlive: true)` edit in Step 3 did not land — re-check it rather than re-running codegen.

- [ ] **Step 8: Run the full test suite**

```bash
cd D:/Source/ponta/dev-stack
flutter test > /tmp/t3_test.txt 2>&1; echo "exit=$?" >> /tmp/t3_test.txt
tail -20 /tmp/t3_test.txt
```
Expected: 611 passing (605 + 6), plus the same 4 pre-existing failures.

- [ ] **Step 9: Commit**

```bash
cd D:/Source/ponta/dev-stack
git add -A
git commit -m "$(cat <<'EOF'
refactor(riverpod): keep alive the apps state graph and log service

only_use_keep_alive_inside_keep_alive was reporting a real mismatch: WindowService
(keepAlive) reached into appsProvider (autoDispose) at nine sites, and
appServiceManager (keepAlive) into logService (autoDispose) at one.

The apps state was already kept alive in practice — main.dart watches
appsProvider.future for the lifetime of MainScreen, and WindowService listens to
it — so declaring it removes the warnings without changing runtime behaviour. The
rest of the reachable set is declared with it, since marking appsProvider
keepAlive alone would only move the warning onto its dependencies. logService
returns the AppLogger singleton and holds no per-listener state.

Also makes SslService.isInstalled and SslService.mkcertPath private; both were
file-internal, and avoid_public_notifier_properties was reporting them.

dart analyze: 12 issues -> 0.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Migrate the system tray from `tray_manager` legacy to `nativeapi`

**Files:**
- Modify: `pubspec.yaml:55` — `tray_manager: 0.7.0` → `nativeapi: ^0.3.0`
- Modify: `lib/core/services/window_service.dart` (the whole file)

**Interfaces:**
- Consumes: the Task 1 provider names `appsProvider` and `settingsProvider`; `AppModel`; `appServiceManagerProvider`; `cliProcessManagerProvider`; `LinuxDesktopService.resolveIconPath()`.
- Produces: `WindowService` still `@Riverpod(keepAlive: true)`, still mixing in `WindowListener`, still exposing the same `onWindowClose` / `onWindowFocus` overrides. The tray is now driven by a private `TrayIcon` field plus a private `_TrayMenu` holder class. No public API changes.

**API facts this task depends on** (all read from `nativeapi-0.3.0` and `tray_manager-0.7.0` in the pub cache, and the imports type-checked against this file's import set):

| Legacy (`tray_manager/legacy.dart`) | `nativeapi` |
|---|---|
| `trayManager.setIcon(path)` | `TrayIcon.create()` then `icon.icon = image` |
| `trayManager.setToolTip(s)` | `icon.setTooltip(s)` |
| `trayManager.setContextMenu(menu)` | `icon.setContextMenu(menu)` |
| `trayManager.popUpContextMenu()` | `icon.openContextMenu()` |
| `trayManager.addListener(this)` + `TrayListener` | `icon.addListener(cb)` → `ListenerId`, removed with `icon.removeListener(id)` |
| `Menu(items: [...])` | `Menu.create()`, then `addItem` / `addSeparator` |
| `MenuItem(label:, disabled:)` | `MenuItem.createWithLabelAndType(label, MenuItemType.normal)`, then `item.isEnabled` |
| `MenuItem.separator()` | `Menu.addSeparator()` |
| `MenuItem.submenu(label:, submenu:)` | `MenuItemType.submenu`, then `item.submenu = child` |
| `menuItem.key` dispatch | one `addListener` per item, intent captured in a closure |
| `onTrayIconMouseDown` | `TrayIconClickedEvent` |
| `onTrayIconRightMouseDown` | `TrayIconRightClickedEvent` |

`TrayIcon.create()`, `Menu.create()`, `MenuItem.createWithLabelAndType(...)`, `Image.fromFile(...)`, and `ImageAsset.fromAsset(...)` all return **nullable** — null means the native side failed. `nativeapi`/`cnativeapi` free the native handle from a `Finalizer` when the wrapper is collected, and a listener only outlives the wrapper it was registered on, so every wrapper and every `ListenerId` must stay reachable until the menu is replaced. The legacy bridge solved this with a `NativeMenuBinding` holder disposed via `Timer.run`; `_TrayMenu` below is the same pattern.

`cnativeapi` is already registered as an FFI plugin in both `windows/flutter/generated_plugins.cmake` and `linux/flutter/generated_plugins.cmake`, and `nativeapi` is already in `pubspec.lock` as a transitive dependency — so no new native wiring is needed. Dart 3.13.4 and Flutter 3.47.5 satisfy nativeapi's `sdk: ^3.13.0` / `flutter: >=3.47.0` floors.

- [ ] **Step 1: Swap the dependency**

In `pubspec.yaml`, replace line 55 (`  tray_manager: 0.7.0`) with:

```yaml
  nativeapi: ^0.3.0
```

Leave every other line alone — in particular do not touch the `flutter_launcher_icons:` block at line 76, which is a top-level key that legitimately follows `dev_dependencies` with no blank line.

```bash
cd D:/Source/ponta/dev-stack
flutter pub get > /tmp/t4_pubget.txt 2>&1; echo "exit=$?" >> /tmp/t4_pubget.txt
tail -5 /tmp/t4_pubget.txt
```
Expected: `exit=0`.

- [ ] **Step 2: Confirm the native plugin wiring is unchanged**

```bash
cd D:/Source/ponta/dev-stack
grep -n "cnativeapi\|tray_manager" windows/flutter/generated_plugins.cmake linux/flutter/generated_plugins.cmake pubspec.lock > /tmp/t4_plugins.txt 2>&1
cat /tmp/t4_plugins.txt
```
Expected: `cnativeapi` still listed in both `.cmake` files' `FLUTTER_FFI_PLUGIN_LIST`; **no `tray_manager` anywhere**; `nativeapi` and `cnativeapi` present in `pubspec.lock` with `dependency: "direct main"` and `dependency: transitive` respectively. If `cnativeapi` dropped out of the cmake lists, re-run `flutter pub get` — its presence follows from `nativeapi` being a dependency.

- [ ] **Step 3: Rewrite `lib/core/services/window_service.dart`**

Replace the whole file with:

```dart
import 'dart:io';
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/apps/domain/app_model.dart';
import '../../features/apps/data/apps_provider.dart';
import '../../features/apps/data/app_service_manager.dart';
import '../../features/settings/data/settings_provider.dart';
import 'package:dev_stack/core/services/log_service.dart';
import '../../features/sites/data/cli_process_manager.dart';
import 'linux_desktop_service.dart';

part 'window_service.g.dart';

@Riverpod(keepAlive: true)
class WindowService extends _$WindowService with WindowListener {
  Timer? _updateTimer;
  TrayIcon? _trayIcon;
  Image? _trayIconImage;
  ListenerId? _trayListenerId;
  _TrayMenu? _trayMenu;

  @override
  Future<void> build() async {
    windowManager.addListener(this);

    ref.onDispose(() {
      _updateTimer?.cancel();
      windowManager.removeListener(this);

      final listenerId = _trayListenerId;
      if (listenerId != null) {
        _trayIcon?.removeListener(listenerId);
      }
      _trayListenerId = null;

      _trayMenu?.dispose();
      _trayMenu = null;

      _trayIcon?.dispose();
      _trayIcon = null;
      _trayIconImage?.dispose();
      _trayIconImage = null;
    });

    // Prevent app from closing when X is pressed, we will handle it in onWindowClose
    await windowManager.setPreventClose(true);

    _initSystemTray();
    await _initAutoStart();

    // Lắng nghe thay đổi của apps để cập nhật Menu Tray
    ref.listen(appsProvider, (previous, next) {
      if (next.hasValue) {
        _updateTrayMenu(next.value!);
      }
    });

    // Lắng nghe thay đổi của settings để cập nhật Auto-start
    ref.listen(settingsProvider, (previous, next) {
      if (next.hasValue) {
        _initAutoStart();
      }
    });

    // Khởi tạo menu và auto-start lần đầu
    final initialApps = ref.read(appsProvider).value;
    if (initialApps != null) {
      _updateTrayMenu(initialApps);
    }
    _initAutoStart();
  }

  // --- Tray ---

  void _initSystemTray() {
    String iconPath = Platform.isWindows
        ? 'assets/images/icon.ico'
        : (Platform.isLinux
            ? LinuxDesktopService.resolveIconPath()
            : 'assets/images/icon.png');

    try {
      final icon = TrayIcon.create();
      if (icon == null) {
        AppLogger.error('Tray initialization failed: TrayIcon.create() returned null');
        return;
      }
      _trayIcon = icon;

      // ImageAsset.fromAsset resolves a bundled asset against
      // Platform.resolvedExecutable; Image.fromFile covers the absolute paths
      // the Linux resolver returns. Same lookup order the legacy bridge used.
      final image = ImageAsset.fromAsset(iconPath) ?? Image.fromFile(iconPath);
      if (image != null) {
        icon.icon = image;
        // The wrapper owns the native handle and frees it when collected, so it
        // has to stay reachable for as long as the tray icon does.
        _trayIconImage = image;
      }

      if (Platform.isWindows) {
        icon.setTooltip('DevStack');
      }
      icon.setVisible(true);

      // nativeapi reports whole clicks. The legacy bridge replayed each click as
      // mouseDown + mouseUp, and only the "down" half was ever implemented here,
      // so handling the click event directly preserves the old behaviour.
      _trayListenerId = icon.addListener((event) {
        switch (event) {
          case TrayIconClickedEvent():
            windowManager.show();
          case TrayIconRightClickedEvent():
            icon.openContextMenu();
          case TrayIconDoubleClickedEvent():
            break; // legacy was a no-op too
        }
      });
    } catch (e) {
      AppLogger.error('Tray initialization failed: $e');
    }
  }

  void _updateTrayMenu(List<AppModel> apps) {
    _updateTimer?.cancel();
    _updateTimer = Timer(const Duration(milliseconds: 500), () {
      final icon = _trayIcon;
      if (icon == null) return;

      // Unlike the legacy Menu constructors, nativeapi's Menu.create() and
      // MenuItem.createWithLabelAndType() return null on failure and _TrayMenu
      // turns that into a StateError. This runs in a Timer callback, where an
      // escaping exception is an unhandled async error, so catch it the same way
      // _initSystemTray and _initAutoStart do.
      try {
        final manager = ref.read(appServiceManagerProvider);
        final runningApps = apps
            .where(
              (a) => a.isInstalled && a.isService && manager.isRunning(a.appId),
            )
            .toList();

        final menu = _TrayMenu();
        menu.addAction('Show App', windowManager.show);
        menu.addSeparator();
        menu.addLabel('Running Services (${runningApps.length})');

        for (final app in runningApps) {
          menu.addSubmenu(app.name, (submenu) {
            submenu.addAction('Restart', () => _restartService(app));
            submenu.addAction('Stop', () => _stopService(app));
          });
        }

        menu.addSeparator();
        menu.addAction(
          'Stop All Services',
          () => ref.read(appsProvider.notifier).stopAllServices(),
          enabled: runningApps.isNotEmpty,
        );
        menu.addSeparator();
        menu.addAction('Quit', _quit);

        final previous = _trayMenu;
        _trayMenu = menu;
        icon.setContextMenu(menu.root);

        // A click callback runs inside the clicked item's own native callback, so
        // the outgoing menu has to outlive the call that replaces it.
        if (previous != null) {
          Timer.run(previous.dispose);
        }
      } catch (e) {
        AppLogger.error('Tray menu update failed: $e');
      }
    });
  }

  Future<void> _quit() async {
    // Dừng tất cả dịch vụ nhưng không lưu trạng thái (giữ nguyên auto-start)
    await ref.read(appsProvider.notifier).stopAllServicesQuietly();
    // Stop all CLI site processes so spawned dev servers are reaped on quit.
    await ref.read(cliProcessManagerProvider).stopAll();
    await windowManager.destroy();
  }

  Future<void> _stopService(AppModel app) =>
      ref.read(appsProvider.notifier).stopService(app);

  Future<void> _restartService(AppModel app) =>
      ref.read(appsProvider.notifier).restartService(app);

  // --- Auto start ---

  Future<void> _initAutoStart() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String appName = packageInfo.appName.isNotEmpty
          ? packageInfo.appName
          : "Ponta DevStack";

      final appPath = Platform.isLinux
          ? (Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable)
          : Platform.resolvedExecutable;

      launchAtStartup.setup(
        appName: appName,
        appPath: appPath,
        args: ['--minimized'],
      );

      final settings = await ref.read(settingsProvider.future);
      if (settings.autoStartWithWindows) {
        await launchAtStartup.enable();
        AppLogger.info('Auto-start enabled with --minimized');
      } else {
        if (await launchAtStartup.isEnabled()) {
          await launchAtStartup.disable();
          AppLogger.info('Auto-start disabled');
        }
      }
    } catch (e) {
      AppLogger.error('Auto-start initialization failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    final settings = await ref.read(settingsProvider.future);
    if (settings.minimizeToTray) {
      await windowManager.hide();
    } else {
      // Dừng tất cả dịch vụ nhưng không lưu trạng thái (giữ nguyên auto-start)
      await ref.read(appsProvider.notifier).stopAllServicesQuietly();
      // Stop all CLI site processes so spawned dev servers are reaped on exit.
      await ref.read(cliProcessManagerProvider).stopAll();
      await windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    // Force a redraw if needed
  }
}

/// Owns every native wrapper created for one context menu.
///
/// `nativeapi` wrappers free their native handle when collected, and a listener
/// only outlives the wrapper it was registered on — so the menu, its items, and
/// their listener ids all have to stay reachable until the menu is replaced.
///
/// This mirrors the ownership pattern in `tray_manager`'s own `NativeMenuBinding`,
/// which is the reference implementation for wrapping this API. Two details from
/// it that matter here:
///
///  * `Menu.dispose()` does **not** free the items added to it, so items and
///    menus each need their own dispose pass. Skipping either leaks.
///  * Listeners are removed before anything is disposed, because a callback can
///    still fire while its item is alive.
///
/// The one deliberate difference: `NativeMenuBinding` keeps a single flat list
/// of menus and items across the whole tree, while this holder nests a child
/// `_TrayMenu` per submenu and disposes depth-first. Both free every wrapper
/// exactly once — the native handles are independent, so the order among them
/// does not matter — but nesting keeps each submenu's wrappers together, which
/// makes the structure easier to read than three parallel flat lists.
class _TrayMenu {
  _TrayMenu() {
    final menu = Menu.create();
    if (menu == null) {
      throw StateError('Unable to create the tray context menu');
    }
    root = menu;
    _menus.add(menu);
  }

  late final Menu root;

  final List<Menu> _menus = <Menu>[];
  final List<MenuItem> _items = <MenuItem>[];
  final List<_TrayMenu> _submenus = <_TrayMenu>[];
  final List<(MenuItem, ListenerId)> _listeners = <(MenuItem, ListenerId)>[];

  /// Adds a clickable row. The action is captured in the closure, which is why
  /// the old string-key dispatch protocol (`'stop:<appId>'`) is gone: a
  /// `nativeapi.MenuItem` has no key.
  MenuItem addAction(
    String label,
    void Function() action, {
    bool enabled = true,
  }) {
    final item = _newItem(label, MenuItemType.normal);
    item.isEnabled = enabled;
    _listeners.add((
      item,
      item.addListener((event) {
        if (event is MenuItemClickedEvent) action();
      }),
    ));
    root.addItem(item);
    return item;
  }

  /// A disabled row used as a heading, e.g. "Running Services (2)".
  void addLabel(String label) {
    final item = _newItem(label, MenuItemType.normal);
    item.isEnabled = false;
    root.addItem(item);
  }

  void addSubmenu(String label, void Function(_TrayMenu submenu) build) {
    final item = _newItem(label, MenuItemType.submenu);
    final submenu = _TrayMenu();
    build(submenu);
    item.submenu = submenu.root;
    _submenus.add(submenu);
    root.addItem(item);
  }

  void addSeparator() => root.addSeparator();

  MenuItem _newItem(String label, MenuItemType type) {
    final item = MenuItem.createWithLabelAndType(label, type);
    if (item == null) {
      throw StateError('Unable to create the tray menu item "$label"');
    }
    _items.add(item);
    return item;
  }

  void dispose() {
    for (final (item, listenerId) in _listeners) {
      item.removeListener(listenerId);
    }
    _listeners.clear();
    // Children first: a submenu's items and menu are freed before the item that
    // owns them, and every wrapper is disposed exactly once.
    for (final submenu in _submenus) {
      submenu.dispose();
    }
    _submenus.clear();
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    for (final menu in _menus) {
      menu.dispose();
    }
    _menus.clear();
  }
}
```

Behaviour that must be preserved exactly: the menu contents (Show App, separator, "Running Services (n)" disabled header, one submenu per running app with Restart/Stop, separator, Stop All Services, separator, Quit), the 500 ms debounce, the `--minimized` auto-start, the `setPreventClose(true)` call, and the `onWindowClose` / `onWindowFocus` handlers.

- [ ] **Step 4: Analyze**

```bash
cd D:/Source/ponta/dev-stack
dart analyze > /tmp/t4_analyze.txt 2>&1; echo "exit=$?" >> /tmp/t4_analyze.txt
cat /tmp/t4_analyze.txt
```
Expected: **`No issues found!`**, `exit=0`. If `Image` is reported as ambiguous, alias the import (`import 'package:nativeapi/nativeapi.dart' as nativeapi;` and qualify) — but this was checked before writing the plan against this exact import set and no ambiguity exists.

- [ ] **Step 5: Confirm no `tray_manager` reference remains**

```bash
cd D:/Source/ponta/dev-stack
grep -rn "tray_manager\|TrayListener\|trayManager\." lib test pubspec.yaml > /tmp/t4_leftover.txt 2>&1
cat /tmp/t4_leftover.txt
```
Expected: no output.

- [ ] **Step 6: Run the full test suite**

```bash
cd D:/Source/ponta/dev-stack
flutter test > /tmp/t4_test.txt 2>&1; echo "exit=$?" >> /tmp/t4_test.txt
tail -20 /tmp/t4_test.txt
```
Expected: 611 passing, plus the same 4 pre-existing failures. `window_service.dart` has no widget test, so this step confirms only that nothing else broke.

- [ ] **Step 7: Build for Windows**

```bash
cd D:/Source/ponta/dev-stack
flutter build windows --debug > /tmp/t4_build.txt 2>&1; echo "exit=$?" >> /tmp/t4_build.txt
tail -20 /tmp/t4_build.txt
```
Expected: `exit=0`. This is what proves `cnativeapi` still links.

- [ ] **Step 8: Hand off for manual tray verification**

Report to the user that the tray is ready to check by hand, and list exactly what to exercise:

1. Left-click the tray icon → the window shows.
2. Right-click the tray icon → the context menu opens.
3. Start a service, then right-click → it appears under "Running Services (1)" with a Restart/Stop submenu.
4. Restart on that submenu restarts **that** service.
5. Stop on that submenu stops **that** service.
6. "Stop All Services" stops every running service, and is greyed out when none are running.
7. Quit stops services and exits the process.
8. "Show App" shows the window.
9. Auto-start on login still works.

**Do not commit until the user confirms.** If a check fails, this task is the only thing to revert — that is why it lands last and alone.

- [ ] **Step 9: Commit (only after the manual check passes)**

```bash
cd D:/Source/ponta/dev-stack
git add -A
git commit -m "$(cat <<'EOF'
refactor(tray): migrate window_service from tray_manager legacy to nativeapi

tray_manager 0.7.0 is now only a re-export of nativeapi plus a deprecated 0.5.x
bridge, so depending on it meant depending on nativeapi through an indirection
that is documented as "will be removed in a future release".

Drop tray_manager and use nativeapi directly. cnativeapi was already registered
as an FFI plugin in both platform CMake files as a transitive dependency, so no
new native wiring is needed.

The string-key dispatch protocol goes away with it: nativeapi.MenuItem has no
key, so each action is bound by registering a listener on its item and capturing
the intent in a closure. A _TrayMenu holder owns every Menu, MenuItem, and
ListenerId for the current menu and releases them together via Timer.run, since
a click callback runs inside the clicked item's own native callback and the item
must outlive that call.

Behaviour is unchanged: same menu contents, same 500 ms debounce, same
auto-start and close handling. Verified manually.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

## End-to-end verification

After all four commits:

```bash
cd D:/Source/ponta/dev-stack
dart run build_runner build --delete-conflicting-outputs > /tmp/final_gen.txt 2>&1; echo "gen=$?" >> /tmp/final_gen.txt
dart analyze > /tmp/final_analyze.txt 2>&1; echo "analyze=$?" >> /tmp/final_analyze.txt
flutter analyze > /tmp/final_fanalyze.txt 2>&1; echo "fanalyze=$?" >> /tmp/final_fanalyze.txt
flutter test > /tmp/final_test.txt 2>&1; echo "test=$?" >> /tmp/final_test.txt
flutter build windows --debug > /tmp/final_build.txt 2>&1; echo "build=$?" >> /tmp/final_build.txt
```

| Check | Expected |
|---|---|
| `build_runner` | `gen=0` |
| `dart analyze` | `No issues found!`, `analyze=0` |
| `flutter analyze` | `No issues found!`, `fanalyze=0` |
| `flutter test` | 611 passing + the 4 pre-existing Linux-on-Windows failures, `test=1` |
| `flutter build windows --debug` | `build=0` |
| Tray | confirmed manually by the user |

And the structural end state the spec asks for:

```bash
cd D:/Source/ponta/dev-stack
ls build.yaml 2>&1                      # expect: No such file
grep -rn "legacy.dart" lib test         # expect: no output
grep -rn "tray_manager" lib test pubspec.yaml  # expect: no output
```

---

## Self-review notes

**Spec coverage.** Item 1 → Task 1 (delete `build.yaml`, nine renames, the 116 provider call sites, the 127 static-member call sites, the 14 `group()` strings, the `_EmptyAppsNotifier` `extends` clause, and the two deviating names `AppError` / `SystemInfoState`). Item 2 → Task 4 (dependency swap, icon lifecycle, events, context menu, dropped key protocol, `_TrayMenu` ownership with `Timer.run`, unchanged menu contents and debounce). Item 3 → Task 2 (`NotifierProvider`, `build()` returning `currentSessions`, `ref.onDispose`, both test doubles overriding `build()` plus all three actions). Item 4 → Task 3 (eight `keepAlive` providers, the two `SslService` members made private). The spec's commit order 1 → 3 → 4 → 2 is the task order 1 → 2 → 3 → 4. The spec's six verification steps are in End-to-end verification.

**Counts, re-measured on this tree rather than carried over.** The spec's figures for item 1 were partly wrong, and a first pass at this plan repeated two of them. All of the following were re-measured directly and the plan now states only these:

| Quantity | Measured |
|---|---|
| Nine old class names, bare tokens, `lib` + `test` | 176 (36 inside `.g.dart`) |
| Nine old provider identifiers, `lib` + `test` | 134 (18 inside `.g.dart`) |
| Provider-identifier references to rewrite, excluding generated | 116 across 27 files |
| `ClassName.member` static references, excluding generated | 127 across 18 files |
| `group()` strings naming an old class | 14 |
| Files in the union of those edits | 47 |
| Annotated classes in `lib` | 21 (9 renamed, **12** left alone) |
| `dart analyze` at baseline | 12 (10 + 2) |
| `flutter test` at baseline | 604 pass, 4 fail |

The two numbers that were wrong and are now fixed: the static-member count was stated as 113 and is 127, and the file union was stated as 42 and is 47. The 134 figure that appears in the constraints section is the *provider identifier* total, not the class-name total (176) — the earlier text conflated the two.

**One thing the plan adds that the spec did not state:** `NotifierProvider.overrideWith` takes a **zero-argument** factory in riverpod 3.4.3, so the seven existing test call sites written as `overrideWith((ref) => Mock())` do not merely need their mock rewritten — the closure arity changes too. This was verified against the riverpod source and with a throwaway probe test run against this codebase before the plan was written. It is Task 2, Steps 6 and 7.

**Bugs found by running the plan's own code before finalising it.** Every code block below was executed or compiled against this repository during planning; five defects were found and fixed, each of which would have cost a debugging cycle at execution time:

1. **`ProviderBase` is not exported from `flutter_riverpod.dart`** (confirmed against the barrel's `show` list). The Task 3 helper originally took a `ProviderListenable<Object?>` and called `container.exists(provider)` — `exists` takes `ProviderBase<Object?>`, and neither type is importable from the public API. The helper now takes the `ProviderSubscription` and a `bool Function()` closure. The corrected file compiles cleanly and fails all six assertions at baseline, exactly as the task expects.
2. **The SSL rename would not compile.** A global `s/\bmkcertPath\b/_mkcertPath/g` also rewrites `buildElevatedMkcertArgs`'s own `required String mkcertPath` parameter and its two `mkcertPath:` call-site labels, producing `_mkcertPath: _mkcertPath` — which no longer matches the label `test/core/services/ssl_service_linux_test.dart` passes. Verified by running the sed against a fixture of the real file. Step 4 now uses a range-excluding sed plus a targeted label restore, and lists the three positions to check by hand.
3. **Task 4's full-file rewrite used the pre-rename provider names** (`appsNotifierProvider`, `settingsNotifierProvider`) at ten sites, but Task 1 has already renamed them away — the file would not have compiled. All ten are now `appsProvider` / `settingsProvider`, and the two descriptive lines that carried the old names are corrected.
4. **The Task 3 test referenced `errorNotifierProvider`**, which Task 1 renames to `appErrorProvider`. Fixed, along with the dependency table's provider names.
5. **The rewritten mock in `tunnels_page_test.dart` orphans an import.** Its `super(TunnelManagerService(...))` call was the only user of `tunnel_manager_service.dart`; without removing that import the zero-issues gate in Step 9 is unreachable. Step 5 now says to delete it and verify the import list. (`site_tunnel_dialog_test.dart` is unaffected — its `_FakeDownloader` and the `mockManager` it builds keep the import in use.)

Also corrected: the `@riverpod` → `@Riverpod(keepAlive: true)` edits used line numbers that were wrong for `apps_provider.dart` (the annotations are at 21 and 27, not 22 and 28, and Task 1's rename shifts them anyway). They now use the idempotent `0,/regex/` form, which was tested for correctness and repeat-run safety.

**Mechanisms confirmed by probe, not inference.** A throwaway test proved the `ProviderContainer.test()` lifetime assertion distinguishes the two cases (`exists=true` for a plain `Provider`, `false` for `Provider.autoDispose`) and that all six target providers report `false` at baseline. A second probe ran Task 2's test verbatim against the real `TunnelManagerService` with a fake downloader and no isar, and it passed — confirming that `saveTunnel` tolerates a null isar and that seeding from `currentSessions` plus a broadcast-stream subscription produces the expected state. A third probe compiled the `_TrayMenu` class as written, and a fourth compiled the entire `nativeapi` symbol set Task 4 uses against the same import list — no ambiguity with `window_manager` or `dart:ui`, so the bare `Image` and `Menu` names resolve as intended. All probes were deleted; the working tree is clean.

**Type consistency.** The names used across tasks agree: Task 1 produces `appsNotifierProvider` → `appsProvider` etc., and Tasks 3 and 4 reference the new names. `_TrayMenu.addAction` / `addLabel` / `addSubmenu` / `addSeparator` / `dispose` are defined and used in the same task. `TunnelSessionsNotifierMock` has the same shape in both test files, differing only by the optional `manager:` parameter the dialog test needs.

**Deliberately not done.** The `file_picker` 13 / `package_info_plus` 10 upgrade stays blocked upstream on `launch_at_startup`. The four pre-existing Linux-on-Windows test failures are untouched. No change is made to the tray's user-visible behaviour.
