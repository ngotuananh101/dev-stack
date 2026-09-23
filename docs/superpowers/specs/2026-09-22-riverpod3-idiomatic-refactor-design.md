# Riverpod 3 / isar_plus / nativeapi Idiomatic Refactor Design

## Context & Motivation

The migration to Riverpod 3, isar_plus, and tray_manager 0.7 landed in
`d1f032f` with the codebase compiling and the test suite green. It got there
partly by *configuring the new libraries to keep matching the old code* rather
than by changing the code to match the new libraries. Four such compromises
remain, and one of them is not a compromise at all but a real design bug that
the new tooling merely exposed.

This design removes all of them:

1. A `build.yaml` override that restores Riverpod 2's provider naming.
2. The system tray wired through `package:tray_manager/legacy.dart` under a
   file-level `ignore_for_file: deprecated_member_use`.
3. `StateNotifier` — moved out of Riverpod 3's main export — in the tunnels
   feature.
4. Ten `only_use_keep_alive_inside_keep_alive` warnings, which are the
   analyzer correctly reporting that long-lived providers depend on
   short-lived ones.

The goal is that a reader familiar with Riverpod 3 finds nothing surprising:
default generator naming, no deprecated imports, no `legacy.dart`, and zero
analyzer findings.

## Scope

**In scope:** the four items above, plus the two `avoid_public_notifier_properties`
findings in `ssl_service.dart` that share a file with item 4's work and would
otherwise leave `dart analyze` dirty.

**Out of scope:** the `file_picker` 13 / `package_info_plus` 10 upgrade (blocked
upstream on `launch_at_startup` shipping a `win32_registry` 3.x release); the
four pre-existing Linux-on-Windows test failures; any change to the tray's
user-visible behaviour.

## Current state

Verified against the working tree at `d1f032f`:

| # | Artifact | Detail |
|---|---|---|
| 1 | `build.yaml` | Sets `provider_name_strip_pattern: ""` on the `riverpod_generator` builder |
| 2 | `lib/core/services/window_service.dart:11` | `import 'package:tray_manager/legacy.dart';` + `ignore_for_file: deprecated_member_use` |
| 3 | `lib/features/tunnels/data/tunnels_provider.dart:207` | `import 'package:flutter_riverpod/legacy.dart';` — the only remaining consumer |
| 4 | `dart analyze` | 10 × `only_use_keep_alive_inside_keep_alive` + 2 × `avoid_public_notifier_properties` |

`tray_manager 0.7.0`'s pubspec depends only on `nativeapi ^0.3.0`, and its
`lib/tray_manager.dart` is a bare re-export of `nativeapi` symbols. The legacy
API is a bridge over `nativeapi.TrayIcon` and is documented as "will be removed
in a future release". `nativeapi 0.3.0` and `cnativeapi 0.3.0` are already in
`pubspec.lock` as transitive dependencies, and `cnativeapi` is already in both
`windows/flutter/generated_plugins.cmake` and the Linux equivalent as an FFI
plugin — so calling `nativeapi` directly needs no new native wiring.

## Item 1 — Delete `build.yaml`, rename to the Riverpod 3 convention

### Decision

Delete `build.yaml` entirely and rename the nine notifier classes that carry a
redundant `Notifier` suffix.

`riverpod_generator` 4 defaults `provider_name_strip_pattern` to `Notifier$`
(added in `3.0.0-dev.18`). The pattern applies to the **class name** before the
`Provider` suffix is appended. Keeping a class called `SettingsNotifier` under
the default therefore yields `settingsProvider`, not `settingsNotifierProvider`
— which is exactly why the override existed.

Renaming the class to `Settings` produces the same `settingsProvider` while
also removing the suffix that Riverpod 3's convention treats as noise. The
class name and the provider name then agree, and no `build.yaml` is needed.

### The nine renames

| Current class | New class | Resulting provider | Call sites |
|---|---|---|---|
| `AppsNotifier` | `Apps` | `appsProvider` | 51 |
| `SettingsNotifier` | `Settings` | `settingsProvider` | 18 |
| `SitesNotifier` | `Sites` | `sitesProvider` | 15 |
| `ErrorNotifier` | `AppError` | `appErrorProvider` | 9 |
| `RedisNotifier` | `Redis` | `redisProvider` | 7 |
| `DatabasesNotifier` | `Databases` | `databasesProvider` | 6 |
| `PyenvNotifier` | `Pyenv` | `pyenvProvider` | 5 |
| `SystemInfoNotifier` | `SystemInfoState` | `systemInfoStateProvider` | 3 |
| `HostsNotifier` | `Hosts` | `hostsProvider` | 2 |

116 provider call sites across 27 files in `lib/` and `test/`. (A raw grep for
the nine identifiers returns 134; the extra 18 are inside generated `.g.dart`
files, which are regenerated rather than hand-edited.)

### Two names deviate from the obvious choice

- `ErrorNotifier` → `Error` would collide with `dart:core.Error`, which is in
  scope everywhere. **`AppError`** instead.
- `SystemInfoNotifier` → `SystemInfo` would collide with the domain model
  `lib/features/system/domain/system_info.dart` (`class SystemInfo`), imported
  by both `system_info_provider.dart` and `system_info_modal.dart`. The modal
  imports both the provider and the domain model, so a collision there is a
  hard error. **`SystemInfoState`** instead.

`AppError`, `SystemInfoState`, `Apps`, `Sites`, `Databases`, `Redis`, `Hosts`,
`Pyenv`, and `Settings` were each checked against every
`class`/`enum`/`typedef`/`mixin`/`extension` declaration in `lib/` and `test/`
and are free.

The remaining twelve annotated classes (`SslService`, `WindowService`,
`Navigation`, `RedisSettings`, `AppVersions`, `DbSettings`, `PhpSettings`,
`WebserverSettings`, `MongodbSettings`, `ElasticsearchSettings`,
`MeilisearchSettings`, `RustFSSettings`) already follow the convention and are
not renamed. Their generated provider names do not change.

### Static members move with the class

Six classes expose static members that tests and widgets call by class name.
These rename mechanically — 113 call sites across 18 files:

- `AppsNotifier.catalogUrl` → `Apps.catalogUrl` (3 sites)
- `SitesNotifier.*` → `Sites.*` (48 sites; `editableWebserverTypes`,
  `phpVersionFromAppId`, `validateDomain`, `validateProxyTarget`,
  `validateRootDir`, `vhostConfigPath`)
- `DatabasesNotifier.*` → `Databases.*` (46 sites; `decryptRecordPassword`,
  `dropFailed`, `encryptRecordPassword`, `escapeSqlPassword`,
  `grantIsForDatabase`, `mysqlSystemSchemas`, `postgresCliArgs`,
  `readPostgresPassword`, `redisDbIndex`, `renameUserSql`,
  `validateIdentifier`)
- `PyenvNotifier.*` → `Pyenv.*` (8 sites; `buildPyenvEnvironment`,
  `parseInstallableVersions`, `parseInstalledVersions`,
  `resolvePyenvExecutable`)
- `SettingsNotifier.replacePathPrefix` → `Settings.replacePathPrefix` (6 sites)
- `SystemInfoNotifier.collectPlatformInfo` → `SystemInfoState.collectPlatformInfo`
  (2 sites)

`RedisNotifier`, `HostsNotifier`, and `ErrorNotifier` have no static members
called by name. A further 14 occurrences of the old names are `group('...')`
description strings in tests; those are renamed too so the test output keeps
naming the class that actually exists.

15 of the 18 static-rename files are not otherwise touched by the provider
rename, so the two sets are disjoint enough that the provider rename is 27
files and the combined change is **42 files**.

`test/features/sites/presentation/widgets/cli_site_modal_test.dart` subclasses
`AppsNotifier` as `_EmptyAppsNotifier`; that `extends` clause renames too.

## Item 2 — System tray on `nativeapi`

### Decision

Drop `tray_manager` from `pubspec.yaml` and depend on `nativeapi: ^0.3.0`
directly. `tray_manager 0.7.0` is now only a re-export shim plus a deprecated
bridge; calling the shim keeps the app on the old API surface while adding an
indirection, and the bridge's own documentation says it will be removed.

### Tray icon lifecycle

`window_service.dart` gains a `TrayIcon?` field and creates it once:

```dart
final icon = TrayIcon.create();          // null if the native side failed
final image = ImageAsset.fromAsset(iconPath) ?? Image.fromFile(iconPath);
if (image != null) icon.icon = image;
icon.setTooltip('DevStack');             // Windows only, as before
icon.setVisible(true);
```

Icon resolution keeps the current platform branch:
`LinuxDesktopService.resolveIconPath()` on Linux, `assets/images/icon.ico` on
Windows. `ImageAsset.fromAsset` resolves a bundled asset path relative to
`Platform.resolvedExecutable`; `Image.fromFile` covers the absolute paths the
Linux resolver returns. This mirrors the legacy bridge's own lookup order.

### Events

Replace the `TrayListener` mixin with a single `addListener` call returning a
`ListenerId`, removed in `ref.onDispose`:

```dart
_trayListenerId = icon.addListener((event) {
  switch (event) {
    case TrayIconClickedEvent():
      windowManager.show();
    case TrayIconRightClickedEvent():
      icon.openContextMenu();
    case TrayIconDoubleClickedEvent():
      break;                              // legacy was a no-op too
  }
});
```

`nativeapi` reports whole clicks, so the legacy bridge replayed each click as
`onTrayIconMouseDown` + `onTrayIconMouseUp`. Our code only ever implemented the
"down" half, so handling the click event directly preserves behaviour.

### Context menu

Replace the declarative `Menu`/`MenuItem` description with the native
construction API:

| Legacy | nativeapi |
|---|---|
| `Menu(items: [...])` | `Menu.create()` then `addItem` / `addSeparator` |
| `MenuItem(label:, disabled:)` | `MenuItem.createWithLabelAndType(label, MenuItemType.normal)`, then `isEnabled` |
| `MenuItem.separator()` | `Menu.addSeparator()` |
| `MenuItem.submenu(label:, submenu:)` | `MenuItemType.submenu` + `item.submenu = child` |
| `trayManager.setContextMenu(menu)` | `icon.setContextMenu(menu)` |
| `trayManager.popUpContextMenu()` | `icon.openContextMenu()` |

**The string-key dispatch protocol is dropped.** The current code encodes each
action as a `key` (`'show_app'`, `'quit_app'`, `'stop_all'`, `'stop:<appId>'`,
`'restart:<appId>'`) and decodes it in `onTrayMenuItemClick`. `nativeapi.MenuItem`
has no `key`; actions are bound by registering a listener per item and capturing
the intent in a closure. A small helper does this:

```dart
MenuItem _actionItem(Menu parent, String label, VoidCallback action,
    {bool enabled = true}) {
  final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal)!;
  item.isEnabled = enabled;
  _menuListeners.add(item.addListener((e) {
    if (e is MenuItemClickedEvent) action();
  }));
  parent.addItem(item);
  return item;
}
```

The menu contents (Show App, separator, "Running Services (n)" disabled header,
one submenu per running app with Restart/Stop, separator, Stop All Services,
separator, Quit) and the 500 ms debounce in `_updateTrayMenu` are unchanged.

### Ownership

`nativeapi` wrappers free their native handle from a `Finalizer` when collected,
and a listener only outlives the wrapper it was registered on. The menu is
rebuilt on every apps change, so a private `_TrayMenu` holder owns every
`Menu`, `MenuItem`, `Image`, and `ListenerId` created for the current menu and
releases them together. The previous holder is disposed via `Timer.run`, not
synchronously: a click callback runs inside the clicked item's own native
callback, so the item must outlive that call. The legacy bridge does the same
thing for the same reason.

### Unchanged

`_initAutoStart`, `onWindowClose`, `onWindowFocus`, `WindowListener`
registration, `windowManager.setPreventClose(true)`, the `settingsNotifier`
listener that re-runs auto-start, and the initial `_updateTrayMenu` call.

## Item 3 — `TunnelSessionsNotifier` as a Riverpod 3 `Notifier`

Delete the `flutter_riverpod/legacy.dart` import and convert:

```dart
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
    _subscription = _manager.sessionsStream.listen((s) => state = s);
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

Two details drive the shape:

- `NotifierProvider` takes a zero-argument factory, so the manager cannot be
  constructor-injected. It comes from `ref.watch` inside `build()`. `build()`
  returning early on the same dependency is what re-subscribes if the manager
  is ever replaced.
- `TunnelManagerService.sessionsStream` is a broadcast stream, so it replays
  nothing on listen. `build()` must return `_manager.currentSessions` rather
  than waiting for the first event; the legacy `StateNotifier` seeded its
  `super(...)` the same way.

`ref.onDispose` replaces the `dispose()` override; `Notifier` has no
`super.dispose()` to call.

### Test doubles

Two mocks subclass the notifier and assign `state` in their constructor, which
Riverpod 3 does not allow — a notifier has no element until it is built. Both
move the initial state into a `build()` override.

They must also override the three action methods. The base class's `_manager`
is library-private and is assigned only inside `build()`, so a subclass in
`test/` can neither read nor set it. Overriding the actions keeps the base
notifier free of test-only seams:

```dart
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

`build()` deliberately does **not** call `super.build()`, so no real
`TunnelManagerService` is ever constructed and no stream subscription is
installed. This matters for
`test/features/tunnels/presentation/tunnels_page_test.dart`, whose mock has no
manager at all and whose tests only render — constructing the real manager
would drag in `tunnelDownloaderServiceProvider`, `logServiceProvider`, and
`isarProvider` (a real database).

`test/features/sites/presentation/widgets/site_tunnel_dialog_test.dart` keeps
its optional `manager:` parameter. Its one behavioural test taps "Start Quick
Tunnel", which reaches
`ref.read(tunnelSessionsProvider.notifier).start(...)` — the mock's override —
and then asserts `mockManager.currentSessions` is non-empty. That test also
overrides `tunnelManagerServiceProvider` with the same instance, which is what
`SiteTunnelDialog._startQuickTunnel` calls `saveTunnel` on.

## Item 4 — Eight providers become `keepAlive`

`only_use_keep_alive_inside_keep_alive` fires when a non-autoDispose provider
invokes a generated autoDispose provider. Only two such dependencies exist:

- `WindowService` (`@Riverpod(keepAlive: true)`) reads `appsNotifierProvider`
  (autoDispose) at nine sites.
- `appServiceManager` (`@Riverpod(keepAlive: true)`) reads `logServiceProvider`
  (autoDispose) at one site.

### Decision

Mark the dependencies `keepAlive`. The apps state is already kept alive in
practice: `main.dart` watches `appsNotifierProvider.future` for the whole
lifetime of `MainScreen`, and `WindowService` — itself `keepAlive` — listens to
it. Declaring the fact removes the warnings without changing runtime behaviour,
which is what distinguishes this from weakening `WindowService` to satisfy the
linter.

`logServiceProvider` is the trivial case: it returns the module-level
`AppLogger` singleton and holds no per-listener state, so autoDispose was never
meaningful.

| Provider | File |
|---|---|
| `appsNotifier` | `lib/features/apps/data/apps_provider.dart` |
| `appsRepository` | `lib/features/apps/data/apps_provider.dart` |
| `appInstallerService` | `lib/features/apps/data/app_installer_service.dart` |
| `errorNotifier` | `lib/shared/providers/error_provider.dart` |
| `pathService` | `lib/core/services/path_service.dart` |
| `meilisearchSettings` | `lib/features/apps/data/meilisearch_settings_provider.dart` |
| `rustFSSettings` | `lib/features/apps/data/rustfs_settings_provider.dart` |
| `logService` | `lib/core/services/log_service.dart` |

`appsRepository`, `appInstallerService`, `errorNotifier`, `pathService`,
`meilisearchSettings`, and `rustFSSettings` are included because `appsNotifier`
now depends on them and would otherwise move the warning rather than remove it.
Each was checked for further dependencies; none reads an autoDispose provider.

### Public notifier properties

`ssl_service.dart` reports `avoid_public_notifier_properties` on two members
that exist only for internal use. Both become private:

- `bool get isInstalled` → `bool get _isInstalled` (used at line 200 only)
- `String get mkcertPath` → `String get _mkcertPath` (used within the file only)

`test/core/services/background_process_policy_test.dart` asserts that a
`Process.run(...mkcertPath` pattern does **not** match the file, so the rename
cannot break it. `test/core/services/ssl_service_linux_test.dart` passes
`mkcertPath:` as a *named parameter* to a different function, not to this
getter.

## Verification

1. `dart run build_runner build --delete-conflicting-outputs` — exit 0.
2. `dart analyze` — 0 issues (from 12).
3. `flutter analyze` — 0 issues.
4. `flutter test` — 604 passing. The four Linux-on-Windows failures
   (path separators, `.desktop` creation, `PathAccessException errno=32`) are
   pre-existing and unaffected.
5. `flutter build windows --debug` — succeeds.
6. **Tray behaviour is verified manually by the user**: left click shows the
   window, right click opens the context menu, Restart/Stop act on the correct
   service, Stop All Services stops every running service, Quit stops services
   and exits, and auto-start on login still works.

## Risks

- **The tray rewrite is the only item that cannot be verified by the test
  suite.** `window_service.dart` has no widget test; the tray is exercised only
  on a real desktop. The user accepted manual verification. The main behavioural
  risks are the menu rebuild's lifetime (mitigated by the `Timer.run` deferral
  described above) and the dropped double-click handler (which was already a
  no-op).
- **The item 1 rename touches 42 files and 229 call sites** (116 provider
  references across 27 files, 113 static-member references across 18 files).
  It is mechanical and the compiler catches every miss, but it is a large diff.
  It should land as its own commit so the tray and lifecycle changes stay
  reviewable.
- **Item 4 changes provider lifetime declarations.** The analysis in the
  previous section is that no runtime behaviour changes, but a mistake here
  would show up as state being retained that should have been released, not as
  a test failure. The chain was traced by hand from `WindowService` and
  `appServiceManager` outward.

## Commit strategy

Four commits, one per item, in the order 1 → 3 → 4 → 2:

1. `refactor(riverpod): drop build.yaml and rename notifiers to the riverpod 3 convention`
2. `refactor(tunnels): replace StateNotifier with Notifier`
3. `refactor(riverpod): keep alive the apps state graph and log service`
4. `refactor(tray): migrate window_service from tray_manager legacy to nativeapi`

Item 2 lands last because it is the only change whose correctness the test
suite cannot confirm; keeping it isolated makes it revertible on its own if the
manual tray check finds a problem.
