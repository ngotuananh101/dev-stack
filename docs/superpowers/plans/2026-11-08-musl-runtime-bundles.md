# musl-dynamic Linux Runtimes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DevStack discover, install and start PHP, Apache, PostgreSQL and Redis on Linux from `musl-dynamic` (Redis: static `musl`) builder bundles, and delete every code path that only served glibc, the Zonky jar or OS package-managed installs.

**Architecture:** The catalog producer (`assets/data/update.js`) gains a per-runtime asset-pattern table and fetchers for Apache and PostgreSQL. The Flutter installer gains a generic read-only bundle manifest reader that resolves launchers to `<root>/bin/<name>`, generates one isolated Apache `httpd.conf` from the bundle's own `conf/httpd.conf`, and initializes PostgreSQL through the existing `configureIsolatedPostgresql`. Legacy branches (Zonky, `system_package`, `install_method`, the system-PHP extension stack) are removed outright.

**Tech Stack:** Flutter/Dart (Riverpod, Isar, `package:archive`, `dio`), Node.js 24 (`node:test` + `vm` fixtures), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-08-musl-runtime-bundles-design.md`

## Global Constraints

- Accepted builder targets: `musl-dynamic` for `php`, `apache`, `postgresql`; `musl` (static) for `redis`. No other target is accepted anywhere.
- Asset name shapes: `php-<x.y.z>-musl-dynamic-x86_64-<16 hex>.tar.gz`, `apache-<x.y.z>-musl-dynamic-x86_64-<16 hex>.tar.gz`, `postgresql-<x.y[.z]>-musl-dynamic-x86_64-<16 hex>.tar.gz`, `redis-<x.y.z>-musl-x86_64-<16 hex>.tar.gz`.
- PostgreSQL versions have used two parts since v10 (`18.6`, `17.11`); its version group is `\d+(?:\.\d+)+`, the others `\d+\.\d+\.\d+`.
- Only `https://github.com/ngotuananh101/devstack-app-builder/releases/download/…` URLs are accepted, and the URL basename must equal the asset name.
- Builder discovery failure fails closed: abort the run, write no catalog. `GITHUB_TOKEN` goes only to `api.github.com` builder endpoints.
- No back-compatibility: glibc PHP directories, Zonky PostgreSQL directories and `system_package` records are not migrated and not supported.
- `LinuxDistroResolver.resolveUrl`, `resolveMongoDistro`, `detectCodename`, `parseOsRelease`, `detectVersionId` stay (MongoDB `{mongo_distro}` substitution).
- Windows behavior is out of scope: Windows fetchers, Windows Apache zip handling and Windows install paths are untouched.

## Review Focus

1. **A stale catalog entry for a removed glibc asset.** A user whose Gist/DB still lists `php-8.4.27-glibc-full-…` must see PHP as unavailable, never a download that 404s mid-install. (Task 2 pins fallback filtering; Task 11 pins the regenerated catalog.)
2. **Picking `libexec/` as the executable.** Both `bin/httpd` and `libexec/bin/httpd` exist and only the `bin/` shell launcher can run directly; a wrong pick yields `Exec format error` at start. (Task 8.)
3. **A generated `httpd.conf` that cannot start.** Self-include (`*.conf` matching `httpd.conf` itself) or a missing `LoadModule unixd_module` makes Apache exit immediately with a cryptic message. (Task 9.)
4. **`setcap` applied to the wrong file.** The kernel executes `lib/musl/ld-musl-x86_64.so.1`, so setting the capability on `bin/httpd` silently leaves port 80 unbindable. (Task 9.)
5. **A shared version regex that rejects PostgreSQL.** `2.4.70` and `18.6` are different shapes; one loose pattern must not accept `18` alone nor drop `18.6`. (Task 1.)

---

### Task 1: Catalog discovers four builder runtimes

**Files:**
- Modify: `assets/data/update.js` (builder constants ~line 350, `fetchBuilderReleaseIndex` ~line 458, `fetchersLinux` ~line 502)
- Test: `test/assets/updater_test_helpers.cjs`, `test/assets/update_php.test.js`, `test/assets/update_builder.test.js`

**Interfaces:**
- Produces: `BUILDER_BUNDLES: Array<{runtime: "php"|"apache"|"postgresql"|"redis", pattern: RegExp}>`, `fetchersLinux.apache()`, `fetchersLinux.postgresql()` — each returns `{versions: {[v]: url}, sha256: {[v]: hex}}`.
- Test helper produces: `bundleAsset(runtime, version, options)` plus `apacheAsset`, `postgresqlAsset` wrappers.

- [ ] **Step 1: Generalize the Node fixture helper**

In `test/assets/updater_test_helpers.cjs` replace `phpAsset`/`redisAsset` with a shared builder, keeping both old names working:

```js
const BUILDER_TARGETS = { php: "musl-dynamic", apache: "musl-dynamic", postgresql: "musl-dynamic", redis: "musl" };

function bundleAsset(runtime, version, options = {}) {
  const { tag = "runtimes-2026-11-06", build = "abcdef0123456789", hash = digest, name, url } = options;
  const target = options.target ?? `${BUILDER_TARGETS[runtime]}-x86_64`;
  const assetName = name ?? `${runtime}-${version}-${target}-${build}.tar.gz`;
  return {
    name: assetName,
    browser_download_url: url ?? bundleUrl(tag, assetName),
    ...(hash ? { digest: `sha256:${hash}` } : {}),
  };
}

const phpAsset = (version, options) => bundleAsset("php", version, options);
const redisAsset = (version, options) => bundleAsset("redis", version, options);
const apacheAsset = (version, options) => bundleAsset("apache", version, options);
const postgresqlAsset = (version, options) => bundleAsset("postgresql", version, options);
```

Export `apacheAsset`, `bundleAsset`, `postgresqlAsset` alongside the existing names. `phpAsset`'s old `variant` option is gone: call sites that need a foreign variant pass `{ target: "glibc-full-x86_64" }`.

- [ ] **Step 2: Point the PHP tests at musl-dynamic**

- `test/assets/update_php.test.js:13`: `function asset(version, target = 'musl-dynamic-x86_64', build = 'abcdef0123456789')`.
- `test/assets/update_php.test.js:166`: the rejected variants become `'glibc-full-x86_64'`, `'glibc-minimal-x86_64'`, `'glibc-full-aarch64'`, `'musl-full-x86_64'`.

- [ ] **Step 3: Write the failing assertion that Apache and PostgreSQL are discovered**

Append to `test/assets/update_builder.test.js`:

```js
test("Apache and PostgreSQL are discovered from musl-dynamic bundles", async (t) => {
  const apache = apacheAsset("2.4.70", { tag: "runtimes-2026-11-08" });
  const pg = postgresqlAsset("18.6", { tag: "runtimes-2026-11-08" });
  const network = githubNetwork({
    releasePages: [[release(1, { tag: "runtimes-2026-11-08" })]],
    assetsByRelease: { 1: [apache, pg] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  const [a, p] = await Promise.all([u.fetchersLinux.apache(), u.fetchersLinux.postgresql()]);
  assert.deepEqual(plain(a.versions), { "2.4.70": apache.browser_download_url });
  assert.deepEqual(plain(p.versions), { "18.6": pg.browser_download_url });
  assert.deepEqual(plain(p.sha256), { "18.6": digest });
});

test("Apache and PostgreSQL ignore glibc, static-musl and aarch64 bundles", async (t) => {
  const network = githubNetwork({
    releasePages: [[release(1, { tag: "runtimes-2026-11-08" })]],
    assetsByRelease: { 1: [
      apacheAsset("2.4.70", { target: "glibc-x86_64" }),
      apacheAsset("2.4.71", { target: "musl-x86_64" }),
      postgresqlAsset("18.6", { target: "musl-dynamic-aarch64" }),
      { name: "postgresql-18.6.tar.gz", browser_download_url: "https://example.com/pg.tar.gz" },
    ] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));
  assert.deepEqual(plain((await u.fetchersLinux.apache()).versions), {});
  assert.deepEqual(plain((await u.fetchersLinux.postgresql()).versions), {});
});
```

- [ ] **Step 4: Run the Node suite and confirm the new tests fail**

Run: `docker run --rm -v "$PWD":/w -w /w node:24 node --test test/assets/update_builder.test.js test/assets/update_php.test.js`
Expected: FAIL — `u.fetchersLinux.apache is not a function`, and the PHP tests fail on the `musl-dynamic` fixture.

- [ ] **Step 5: Implement the per-runtime pattern table**

In `assets/data/update.js` replace the two patterns and `BUILDER_BUNDLES`:

```js
// Every builder-produced runtime is musl-based: musl-dynamic for the ones that
// link libc, static musl for Redis. No other target is accepted.
const BUILDER_BUNDLES = [
  { runtime: "php", pattern: /^php-(\d+\.\d+\.\d+)-musl-dynamic-x86_64-([a-f0-9]{16})\.tar\.gz$/ },
  { runtime: "apache", pattern: /^apache-(\d+\.\d+\.\d+)-musl-dynamic-x86_64-([a-f0-9]{16})\.tar\.gz$/ },
  // PostgreSQL has used two-part versions since v10 (18.6, 17.11).
  { runtime: "postgresql", pattern: /^postgresql-(\d+(?:\.\d+)+)-musl-dynamic-x86_64-([a-f0-9]{16})\.tar\.gz$/ },
  { runtime: "redis", pattern: /^redis-(\d+\.\d+\.\d+)-musl-x86_64-([a-f0-9]{16})\.tar\.gz$/ },
];
```

Then:
- `fetchBuilderReleaseIndex`: initialize `index` from the table — `Object.fromEntries(BUILDER_BUNDLES.map(({ runtime }) => [runtime, { versions: {}, sha256: {} }]))`.
- `fetchersLinux`: add `apache()` and `postgresql()` next to `redis()`, both `selectBuilderRuntime(await builderRuntimeIndex("<runtime>"), () => true)`.
- `isBuilderBacked`: `["php", "apache", "postgresql", "redis"].includes(portableBundleRuntime(app))`.
- `portableBundleRuntime`: add `if (app.id === "apache" && app.exec_file === "httpd") return "apache";` and `if (app.id === "postgresql" && app.exec_file === "postgres") return "postgresql";`.
- `PORTABLE_BUNDLE_ASSETS`: derive from the table — `Object.fromEntries(BUILDER_BUNDLES.map(({ runtime, pattern }) => [runtime, pattern]))`.
- Delete the now-stale comment above `PHP_BUNDLE_ASSET` (`Only fully static musl Redis bundles…`, which no longer describes the code).

- [ ] **Step 6: Run the Node suite and confirm it passes**

Run: `docker run --rm -v "$PWD":/w -w /w node:24 node --test test/assets/update_builder.test.js test/assets/update_php.test.js`
Expected: PASS, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add assets/data/update.js test/assets/updater_test_helpers.cjs test/assets/update_php.test.js test/assets/update_builder.test.js
git commit -m "feat(catalog): discover musl-dynamic php, apache and postgresql bundles"
```

---

### Task 2: Fallback keeps only builder-owned bundles for all four runtimes

**Files:**
- Modify: `assets/data/update.js` (`applyFallbackVersions`, ~line 1076)
- Test: `test/assets/update_builder.test.js`

**Interfaces:**
- Consumes: `portableBundleRuntime`, `PORTABLE_BUNDLE_ASSETS` from Task 1.

- [ ] **Step 1: Write the failing test**

```js
test("Apache and PostgreSQL fall back only to builder bundles that still match", async (t) => {
  const u = loadUpdater(async () => { throw Error("Unexpected network request"); }, fixtureDir(t));
  const good = apacheAsset("2.4.70");
  for (const [id, pattern] of [["apache", good], ["postgresql", postgresqlAsset("18.6")]]) {
    const app = u.baseLinuxApps.find((a) => a.id === id);
    const old = { apps: [{ id, versions: {
      [pattern.name.split("-")[1]]: pattern.browser_download_url,
      "9.9.9": "https://github.com/ngotuananh101/devstack-app-builder/releases/download/x/apache-9.9.9-glibc-x86_64-abcdef0123456789.tar.gz",
      latest: "https://example.com/source.tar.gz",
    } }] };
    u.applyFallbackVersions(app, old, null, "Linux");
    assert.deepEqual(Object.keys(app.versions), [pattern.name.split("-")[1]]);
    assert.equal(app.versions[Object.keys(app.versions)[0]], pattern.browser_download_url);
  }
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `docker run --rm -v "$PWD":/w -w /w node:24 node --test test/assets/update_builder.test.js`
Expected: FAIL — `versions` is `{}` for both apps because of the Linux blanking rule.

- [ ] **Step 3: Remove the Linux blanking rule**

Delete these lines from `applyFallbackVersions`:

```js
  // These Linux runtimes have no supported portable distribution yet.
  // Cached source/package archives must not make them installable again.
  if (platformName === "Linux" && ["apache", "postgresql"].includes(app.id)) return;
```

Nothing else changes: `portableBundleRuntime(app)` now covers all four runtimes, so the existing `builderBundleVersion(...) === version` filter applies to Apache and PostgreSQL too.

- [ ] **Step 4: Update the two tests that asserted the old behavior**

- `test/assets/update_php.test.js:114-143` — the `['Linux', {}]` row assumed Apache/Redis/PostgreSQL stay empty on Linux. Change the table to `['Linux', null]` and assert instead: for Linux, every surviving version URL `startsWith('https://github.com/ngotuananh101/devstack-app-builder/releases/download/')`; for Windows keep `{}`.
- `test/assets/update_php.test.js:82-85` — the base definitions for `apache`, `redis`, `postgresql` still ship `versions: {}`; keep this assertion unchanged.

- [ ] **Step 5: Run the Node suite**

Run: `docker run --rm -v "$PWD":/w -w /w node:24 node --test test/assets/update_builder.test.js test/assets/update_php.test.js`
Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add assets/data/update.js test/assets/update_builder.test.js test/assets/update_php.test.js
git commit -m "feat(catalog): preserve builder-owned apache and postgresql versions on fallback"
```

---

### Task 3: PHP bundles accept only `musl-dynamic`

**Files:**
- Modify: `lib/features/apps/data/php_runtime_bundle.dart:67-77`
- Test: `test/helpers/php_bundle_fixture.dart:46-53`, `test/features/apps/php_runtime_bundle_test.dart:30-47`

**Interfaces:**
- Produces: `PhpRuntimeBundle.load(String root)` returns `null` only when `manifest.json` is absent; a manifest whose `target != "musl-dynamic"` raises `FormatException`.

- [ ] **Step 1: Move the fixture to a musl-dynamic manifest**

In `test/helpers/php_bundle_fixture.dart`, replace `'target': 'glibc', 'profile': 'full',` with `'target': 'musl-dynamic',` and drop the `libexec/php*` files from the fixture (`bin/php`, `bin/php-fpm` are the only launchers), since only `bin/` is runnable now.

- [ ] **Step 2: Update the manifest-identity test**

In `test/features/apps/php_runtime_bundle_test.dart`, the rejection table keeps `schema_version`, `runtime`, `architecture`, `target`, `verification` but drops `profile`, and gains a positive-value case:

```dart
test('rejects a glibc target even when everything else is valid', () {
  editBundleManifest(root, (m) => m['target'] = 'glibc');
  expect(() => PhpRuntimeBundle.load(root.path), throwsFormatException);
});
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `flutter test test/features/apps/php_runtime_bundle_test.dart`
Expected: FAIL — `Unsupported portable PHP manifest identity.` for the musl fixture.

- [ ] **Step 4: Implement the musl-only identity check**

In `php_runtime_bundle.dart` replace the identity condition:

```dart
      if (data is! Map<String, dynamic> ||
          data['schema_version'] != 1 ||
          data['runtime'] != 'php' ||
          data['architecture'] != 'x86_64' ||
          data['target'] != 'musl-dynamic' ||
          data['verification'] != 'PASSED') {
```

`profile` is no longer read anywhere; no other check changes.

- [ ] **Step 5: Run the affected Flutter tests**

Run: `flutter test test/features/apps/php_runtime_bundle_test.dart test/features/apps/php_bundle_settings_test.dart test/features/apps/installer_php_bundle_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/apps/data/php_runtime_bundle.dart test/helpers/php_bundle_fixture.dart test/features/apps/php_runtime_bundle_test.dart
git commit -m "feat(php): accept only musl-dynamic runtime bundles"
```

---

### Task 4: Delete the Zonky PostgreSQL jar path

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (`isZonkyPgJar` ~line 209, install dispatch ~lines 320-334, `_extractPayload` ~line 479-500, `_installFromZonkyJar` ~line 557, `_extractZonkyJar` ~line 858)
- Delete: `test/features/apps/installer_linux_zonky_test.dart`

- [ ] **Step 1: Confirm nothing else references the Zonky path**

Run: `grep -rn "isZonky\|ZonkyJar\|zonky" lib test`
Expected: only `app_installer_service.dart` and `test/features/apps/installer_linux_zonky_test.dart`.

- [ ] **Step 2: Delete the test and the code**

- `rm test/features/apps/installer_linux_zonky_test.dart`
- Delete `isZonkyPgJar`, `_installFromZonkyJar`, `_extractZonkyJar`, the `isZonky` local in `install()`, the `isZonky` parameter of `_extractPayload` and its first `if (isZonky) …` branch, and the `.jar` download-extension special case. `isRawBinary` becomes `Platform.isLinux && !isTar && !isZip && !isExe`.

- [ ] **Step 3: Run the installer suite**

Run: `flutter test test/features/apps/`
Expected: PASS. If a remaining test imports the deleted file, delete that reference.

- [ ] **Step 4: Commit**

```bash
git add -A lib/features/apps/data/app_installer_service.dart test/features/apps
git commit -m "refactor(installer): remove the Zonky embedded-postgres jar path"
```

---

### Task 5: Delete `system_package` and `install_method`/`package_manager`

**Files:**
- Modify: `lib/features/apps/domain/app_model.dart:22,165`, `lib/features/apps/data/apps_repository.dart:83,134`, `lib/features/apps/presentation/widgets/app_version_modal.dart:68`, `lib/features/apps/data/app_installer_service.dart:294,2050,2801`, `lib/features/apps/data/apps_provider.dart:506`, `lib/features/apps/presentation/widgets/app_settings_modal.dart:217,453`, `lib/features/apps/data/php_settings_provider.dart:39-70`, `lib/features/apps/data/redis_settings_provider.dart:23,36`, `lib/features/apps/data/webserver_settings_provider.dart:22-29`
- Delete: `test/features/apps/php_ini_resolver_test.dart`
- Modify tests: `test/features/apps/apps_repository_test.dart`, `apps_repository_save_multiple_test.dart`, `apps_screen_switch_persistence_test.dart`, `apps_provider_uninstall_compatibility_test.dart`, `app_installer_data_dir_test.dart`, `isolated_service_configs_test.dart`, `systemctl_service_test.dart`, `installer_linux_package_manager_test.dart` (delete)

**Interfaces:**
- Produces: `AppModel` has no `installMethod` field; `resolvePhpIniPath(AppModel app, {bool? isLinux})` returns `PhpRuntimeBundle.load(location)!.pathFor('php_ini')` on Linux with a bundle, otherwise `<location>/php.ini`.

- [ ] **Step 1: Write the failing test for the simplified ini resolution**

Replace `test/features/apps/php_ini_resolver_test.dart` with `test/features/apps/php_ini_resolver_test.dart` (same path, new body):

```dart
import 'package:dev_stack/features/apps/data/php_settings_provider.dart';
import 'package:dev_stack/features/apps/domain/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  AppModel createApp({String appId = 'php82', String? location}) => AppModel(
    appId: appId,
    name: 'PHP',
    categories: ['runtime'],
    location: location,
  );

  test('Windows app resolves <location>/php.ini', () {
    final app = createApp(location: r'C:\dev-stack\apps\php\8.2');
    expect(resolvePhpIniPath(app, isLinux: false), p.join(r'C:\dev-stack\apps\php\8.2', 'php.ini'));
  });

  test('Linux app without a bundle resolves <location>/php.ini', () {
    final app = createApp(location: '/opt/custom/php82');
    expect(resolvePhpIniPath(app, isLinux: true), '/opt/custom/php82/php.ini');
  });

  test('no location resolves to null', () {
    expect(resolvePhpIniPath(createApp(), isLinux: true), isNull);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/apps/php_ini_resolver_test.dart`
Expected: the third case FAILS — `resolvePhpIniPath` currently returns `/etc/php/8.2/fpm/php.ini` for an app with no location because of the `system_package` branch. (If the file fails to compile first because `AppModel` still accepts the removed names, that is expected; continue to Step 3.)

- [ ] **Step 3: Remove the fields and branches**

- `app_model.dart`: delete the `installMethod` field, its constructor parameter, and the `// Retained only to reject legacy catalog installation methods.` comment.
- `apps_repository.dart`: the versions filter becomes `rawVersions is Map ? (Map<String, dynamic>.from(rawVersions)..removeWhere((_, url) => url is! String || !isSecureCatalogUrl(url))) : {}`; drop `installMethod: json['install_method']` from the `AppModel` construction.
- `app_version_modal.dart`: drop `&& widget.app.installMethod != 'package_manager'` from `canInstall`.
- `app_installer_service.dart`: delete the `installMethod == 'package_manager'` guard, the `systemPackageMarker` constant and its use in `delete()` (`if (path.isEmpty)` stays), and the `system_package` label branch in `app_settings_modal.dart`.
- `apps_provider.dart`: delete the `systemPackageMarker` branch in `uninstall` (the `installer.delete(...)` call becomes unconditional).
- `resolvePhpIniPath` becomes:

```dart
String? resolvePhpIniPath(AppModel app, {bool? isLinux}) {
  final location = app.location;
  if (location == null || location.isEmpty) return null;
  final onLinux = isLinux ?? Platform.isLinux;
  if (onLinux) {
    final bundle = PhpRuntimeBundle.load(location);
    if (bundle != null) return bundle.pathFor('php_ini');
  }
  return (onLinux ? p.posix : p.context).join(location, 'php.ini');
}
```

Delete `_extractPhpVersion` and the now-unused `fileExists` parameter, and update `resolvePhpIniFile` and `app_settings_modal.dart:189` to the new signature.
- `redis_settings_provider.dart` / `webserver_settings_provider.dart`: drop every `location == 'system_package'` condition together with the `/etc/httpd`, `/etc/apache2` fallbacks in `webserverConfigFileFor` (the isolated-config preference for Linux bundles is Task 9's job).

- [ ] **Step 4: Update the tests that used the removed names**

Delete `test/features/apps/installer_linux_package_manager_test.dart`. Remove `installMethod:` arguments and `system_package` fixtures from the remaining listed test files; in `apps_provider_uninstall_compatibility_test.dart` delete the two legacy-record tests (`uninstall forgets a legacy system record…` and the `system` parameterisation) and keep the managed-directory test without `app.installMethod`.

- [ ] **Step 5: Run the suite**

Run: `flutter test test/features/apps/ test/core/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "refactor: remove system_package installs and package_manager metadata"
```

---

### Task 6: Delete the system-PHP extension stack and distro family detection

**Files:**
- Delete: `lib/features/apps/data/linux_php_extension_driver.dart`, `linux_php_extension_manager.dart`, `linux_php_introspector.dart`, `lib/features/apps/data/php_extension_drivers/`, `lib/features/apps/data/package_command_validator.dart`, `lib/features/apps/data/php_config_command_runner.dart`
- Delete tests: `linux_php_extension_manager_test.dart`, `linux_php_introspector_test.dart`, `arch_php_extension_driver_test.dart`, `debian_php_extension_driver_test.dart`, `rhel_php_extension_driver_test.dart`, `php_settings_linux_branch_test.dart`, `package_command_validator_test.dart`, `php_config_command_runner_test.dart`, `test/features/apps/presentation/widgets/app_settings_modal_linux_extensions_test.dart`
- Modify: `lib/features/apps/data/php_settings_provider.dart` (drop `getLinuxExtensions`, `toggleLinuxExtension`, `_linuxPhpVersion`, three imports), `lib/core/services/linux_distro_resolver.dart` (drop `detectFamily`, `resolveValkeyDistro`; make `detectCodename` private)
- Modify test: `test/core/services/linux_distro_resolver_test.dart`

**Interfaces:**
- Produces: extension management exists only through `PhpRuntimeBundle.sharedModules` (`getExtensions`, `toggleExtension`).

- [ ] **Step 1: Write the failing test that the resolver kept only what MongoDB needs**

In `test/core/services/linux_distro_resolver_test.dart`, delete the `resolveValkeyDistro` and `detectFamily` groups and keep only `parseOsRelease`, `resolveUrl` (including both `{mongo_distro}` and `{version_id}` cases) and `resolveMongoDistro`.

- [ ] **Step 2: Record the guard's current output**

Run: `flutter test test/core/services/linux_distro_resolver_test.dart`
Expected: PASS. This suite is the guard that `resolveUrl`/`resolveMongoDistro` keep working across Step 4; keep it green.

- [ ] **Step 3: Delete the extension stack and its call sites**

`rm -rf` the ten files listed under **Delete**, then from `php_settings_provider.dart` remove `getLinuxExtensions`, `toggleLinuxExtension`, `_linuxPhpVersion`, and the imports of `linux_distro_resolver.dart`, `linux_php_extension_driver.dart`, `linux_php_extension_manager.dart`, `linux_php_introspector.dart`. In `app_settings_modal.dart`, the `_loadExtensions`/`_toggleExtension` callers already go through `getExtensions`/`toggleExtension`, so no UI change is needed.

- [ ] **Step 4: Trim the distro resolver**

Remove `detectFamily` and `resolveValkeyDistro`; rename `detectCodename` to a private `_detectCodename` and update its two internal callers (`_resolveMongoDistro` body and `resolveMongoDistro`); drop `@visibleForTesting` from `resolveMongoDistro` only if no test needs it — the trimmed test in Step 1 still calls it, so keep the annotation.

- [ ] **Step 5: Run the affected tests plus the whole suite**

Run: `flutter test`
Expected: PASS, no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "refactor(php): drop the system PHP extension stack and distro family detection"
```

---

### Task 7: Delete `findInstalledBinary` and `allowSystemBinaries`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (`setLinuxCapabilityForWebserver` ~line 1397-1440, `findInstalledBinary` ~line 2823)
- Modify test: `test/features/apps/installer_binary_resolver_test.dart`, `test/features/apps/installer_linux_capability_test.dart`

**Interfaces:**
- Produces: `setLinuxCapabilityForWebserver(String executablePath, Function(String) logInfo, {Future<ProcessResult> Function(String, List<String>)? runProcess, bool? isLinuxOverride})` — the only policy is containment in `AppConfig.appsDir`.

- [ ] **Step 1: Write the failing test**

Replace the `setLinuxCapabilityForWebserver with system binaries` group in `installer_binary_resolver_test.dart` with:

```dart
test('refuses any path outside the apps directory', () async {
  final logs = <String>[];
  var called = false;
  await installer.setLinuxCapabilityForWebserver(
    '/usr/sbin/httpd',
    logs.add,
    isLinuxOverride: true,
    runProcess: (executable, arguments) async {
      called = true;
      return ProcessResult(1, 0, '', '');
    },
  );
  expect(called, isFalse);
  expect(logs.any((l) => l.contains('outside')), isTrue);
});
```

Delete the two `allowSystemBinaries` cases from `installer_linux_capability_test.dart`.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/apps/installer_binary_resolver_test.dart`
Expected: FAIL — the test still names `allowSystemBinaries`, so it does not compile against the new signature. That is the intended red state for this task; Step 3 is the corresponding implementation.

- [ ] **Step 3: Remove the parameter and the resolver**

- Delete `allowSystemBinaries` from `setLinuxCapabilityForWebserver`, together with `isAllowedSystem` and the `{apache2, httpd, caddy, nginx}` allow-list; the guard becomes `if (!isInsideAppsDir) { logInfo('Warning: Executable path $executablePath is outside ${AppConfig.appsDir}, skipping capability setup for security'); return; }`.
- Delete `findInstalledBinary` entirely and the `group('findInstalledBinary', …)` block in its test.
- Update the doc comment on `setLinuxCapabilityForWebserver` to drop the `allowSystemBinaries` paragraph.

- [ ] **Step 4: Run the installer tests**

Run: `flutter test test/features/apps/installer_binary_resolver_test.dart test/features/apps/installer_linux_capability_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps
git commit -m "refactor(installer): drop system-binary capability and discovery helpers"
```

---

### Task 8: Resolve bundle launchers to `<root>/bin/<name>`

**Files:**
- Create: `lib/features/apps/data/runtime_bundle.dart`
- Create: `test/helpers/runtime_bundle_fixture.dart`
- Modify: `lib/features/apps/data/app_installer_service.dart` (`_detectFiles` ~line 978)
- Test: `test/features/apps/runtime_bundle_manifest_test.dart`, `test/features/apps/installer_bundle_detection_test.dart`

**Interfaces:**
- Produces:

```dart
class RuntimeBundleManifest {
  final String root;      // canonical install root
  final String runtime;   // 'apache' | 'postgresql'
  final String version;   // '2.4.70' | '18.6'
  final Set<String> launchers;             // bare names declared by the manifest
  static RuntimeBundleManifest? load(String root); // null when absent/not one of these runtimes
  bool declaresLauncher(String name);
  String launcherPath(String name);        // throws ArgumentError when not declared
}
```

- Test helper produces: `createApacheBundleFixture(Directory parent)` and `createPostgresqlBundleFixture(Directory parent)` returning the bundle root.

- [ ] **Step 1: Write the fixture helper**

`test/helpers/runtime_bundle_fixture.dart` builds, for Apache: `bin/httpd`, `bin/apachectl`, `libexec/bin/httpd`, `conf/httpd.conf` (a minimal copy of the producer's file containing `Define SRVROOT "${APACHE_SERVER_ROOT}"`, `ServerRoot "${SRVROOT}"`, `Listen 80`, `LoadModule mpm_event_module modules/mod_mpm_event.so`, `<IfModule unixd_module>`, `User daemon`, `Group daemon`, `DocumentRoot "${SRVROOT}/htdocs"` and `<Directory "${SRVROOT}/htdocs">`), and a `manifest.json` with `schema_version: 1`, `runtime: "apache"`, `target: "musl-dynamic"`, `apache: {version: "2.4.70"}`, `launchers: ["apachectl", "httpd"]`. For PostgreSQL: `bin/initdb`, `bin/postgres`, `bin/psql`, `libexec/bin/postgres`, and a manifest with `runtime: "postgresql"`, `postgresql: {version: "18.6", major: "18"}`, and `binaries: [{path: "libexec/bin/postgres"}, {path: "libexec/bin/initdb"}]` — note the PostgreSQL manifest lists no `bin/` paths and no `launchers` key.

- [ ] **Step 2: Write the failing manifest tests**

```dart
test('Apache launchers come from the launchers list', () {
  final m = RuntimeBundleManifest.load(root.path)!;
  expect(m.runtime, 'apache');
  expect(m.version, '2.4.70');
  expect(m.declaresLauncher('httpd'), isTrue);
  expect(m.launcherPath('httpd'), p.join(root.path, 'bin', 'httpd'));
});

test('PostgreSQL launchers come from the binaries list basenames', () {
  final m = RuntimeBundleManifest.load(root.path)!;
  expect(m.version, '18.6');
  expect(m.declaresLauncher('postgres'), isTrue);
  expect(() => m.launcherPath('absent'), throwsArgumentError);
});

test('a PHP or malformed manifest is not a runtime bundle', () {
  File(p.join(root.path, 'manifest.json')).writeAsStringSync('{"runtime":"php"}');
  expect(RuntimeBundleManifest.load(root.path), isNull);
});
```

And in `installer_bundle_detection_test.dart`:

```dart
test('detects the bin/ launcher, never the libexec ELF', () async {
  final detected = await installer.detectFiles(root.path, 'httpd', 'httpd', (_) {});
  expect(detected['exec'], p.join(root.path, 'bin', 'httpd'));
  expect(detected['cli'], p.join(root.path, 'bin', 'httpd'));
  File(p.join(root.path, 'bin', 'httpd')).deleteSync();
  final missing = await installer.detectFiles(root.path, 'httpd', 'httpd', (_) {});
  expect(missing['exec'], isNull, reason: 'libexec/bin/httpd is not runnable directly');
});
```

- [ ] **Step 3: Run and confirm failure**

Run: `flutter test test/features/apps/runtime_bundle_manifest_test.dart test/features/apps/installer_bundle_detection_test.dart`
Expected: FAIL — `runtime_bundle.dart` does not exist.

- [ ] **Step 4: Implement `RuntimeBundleManifest`**

`load` reads `<root>/manifest.json`; returns `null` when the file is absent, is not JSON, is not a map with `schema_version == 1`, or its `runtime` is not `"apache"`/`"postgresql"`. Launcher names: for `apache`, the `launchers` string list; for `postgresql`, `p.basename(entry['path'])` over the `binaries` objects. `version` comes from `data[runtime]['version']` and must match `^\d+(\.\d+)+$`, else `load` returns `null`. `root` is `Directory(root).resolveSymbolicLinksSync()`.

- [ ] **Step 5: Use it in `_detectFiles`**

Before the recursive listing, resolve declared launchers:

```dart
    final bundle = RuntimeBundleManifest.load(installPath);
    if (bundle != null) {
      for (final entry in {'exec': execName, 'cli': cliName}.entries) {
        final name = entry.value;
        if (name != null && bundle.declaresLauncher(name)) {
          final path = bundle.launcherPath(name);
          if (File(path).existsSync()) {
            result[entry.key] = path;
            logInfo('Detected ${entry.key}: $path');
          }
        }
      }
    }
```

then run the existing recursive search only for keys still `null`. Keep the existing `ensureLinuxExecutablePermissions` loop unchanged.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/apps/runtime_bundle_manifest_test.dart test/features/apps/installer_bundle_detection_test.dart test/features/apps/installer_php_bundle_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/apps/data/runtime_bundle.dart lib/features/apps/data/app_installer_service.dart test/helpers/runtime_bundle_fixture.dart test/features/apps
git commit -m "feat(installer): resolve bundle launchers from the runtime manifest"
```

---

### Task 9: Generate an isolated Apache config from the bundle

**Files:**
- Modify: `lib/core/config/apache_config_builder.dart` (add `buildBundleConfig`)
- Modify: `lib/features/apps/data/app_installer_service.dart` (Apache branch of `_configureWebserver` ~line 1655-1710; delete `configureIsolatedApache` ~line 2963)
- Modify: `lib/features/apps/data/webserver_settings_provider.dart`
- Test: `test/core/config/apache_config_builder_test.dart`, `test/features/apps/isolated_service_configs_test.dart`, `test/features/apps/webserver_config_path_test.dart`

**Interfaces:**
- Consumes: `RuntimeBundleManifest.load` (Task 8), `ApacheConfigBuilder.buildMainConfig`.
- Produces: `ApacheConfigBuilder.buildBundleConfig({required String initialContent, required String serverRoot, required String documentRoot, required String vhostsDir, required String logsDir, required bool allowLanAccess, required bool isSslInstalled, String? certPath, String? keyPath}) -> String`.

- [ ] **Step 1: Write the failing builder test**

In `test/core/config/apache_config_builder_test.dart`, feed the minimal producer-style conf described in Task 8 Step 1 and assert:

```dart
test('builds a runnable config from the producer bundle conf', () {
  final out = ApacheConfigBuilder.buildBundleConfig(
    initialContent: producerConf,
    serverRoot: '/opt/apps/apache/2.4.70',
    documentRoot: '/opt/www',
    vhostsDir: '/opt/vhosts/apache',
    logsDir: '/opt/logs',
    allowLanAccess: false,
    isSslInstalled: false,
  );
  expect(out, contains('Define SRVROOT "/opt/apps/apache/2.4.70"'));
  expect(out, contains('ServerRoot "\${SRVROOT}"'));
  expect(out, contains('DocumentRoot "/opt/www"'));
  expect(out, contains('LoadModule unixd_module modules/mod_unixd.so'));
  expect(out, contains('PidFile "/opt/logs/httpd.pid"'));
  expect(out, contains('ErrorLog "/opt/logs/apache_error.log"'));
  expect(out, contains('IncludeOptional "/opt/vhosts/apache/[a-zA-Z0-9]*.conf"'));
  expect(out, isNot(contains('IncludeOptional "/opt/vhosts/apache/*.conf"')));
  expect(RegExp(r'^Listen ', multiLine: true).allMatches(out).length, 1);
  expect(out, contains('Listen 127.0.0.1:80'));
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/core/config/apache_config_builder_test.dart`
Expected: FAIL — `buildBundleConfig` is not defined.

- [ ] **Step 3: Implement `buildBundleConfig`**

```dart
static String buildBundleConfig({ ... }) {
  var content = buildMainConfig(
    initialContent: initialContent,
    serverRoot: serverRoot,
    documentRoot: documentRoot,
    vhostsGlob: p.join(vhostsDir, '[a-zA-Z0-9]*.conf'),
    allowLanAccess: allowLanAccess,
    isSslInstalled: isSslInstalled,
    certPath: certPath,
    keyPath: keyPath,
  );
  content = _prependDirectives(content, [
    'PidFile "${_path(p.join(logsDir, 'httpd.pid'))}"',
    'ErrorLog "${_path(p.join(logsDir, 'apache_error.log'))}"',
    'LoadModule unixd_module modules/mod_unixd.so',
  ]);
  return content;
}
```

`_prependDirectives` replaces an existing `^ErrorLog`/`^PidFile` line when present and inserts the rest immediately after the `Define SRVROOT …` line (falling back to prepending when the line is absent). It never emits a directive whose exact text is already present, so calling it twice is idempotent. `p` is `package:path` — add the import to this file.

- [ ] **Step 4: Run the builder test**

Run: `flutter test test/core/config/apache_config_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Switch the installer's Apache branch to the generated file**

In `_configureWebserver`'s Apache branch: if `RuntimeBundleManifest.load(installPath)?.runtime == 'apache'`, then

- read `<installPath>/conf/httpd.conf` (never the `Apache24/` fallback — that is Windows only),
- write `ApacheConfigBuilder.buildBundleConfig(...)` to `<AppConfig.vhostsDir>/apache/_httpd.conf` (creating the directory, which `_configureWebserver` already does) instead of rewriting the bundle's own file,
- log `Generated isolated Apache configuration at: <path>`,
- `setLinuxCapabilityForWebserver(p.join(installPath, 'lib', 'musl', 'ld-musl-x86_64.so.1'))`.

Otherwise (Windows zip, no manifest) keep the current in-place rewrite of `conf/httpd.conf` unchanged. Delete `configureIsolatedApache` and its `IncludeOptional "*.conf"` test, replacing that test with an assertion that the installer writes `<vhosts>/apache/_httpd.conf` containing `include` of `[a-zA-Z0-9]*.conf` and `mod_unixd`. (Superseded during Task 9: the earlier `[!h]*.conf` form silently excluded every site whose domain begins with `h`, because site vhosts live in the same directory.)

- [ ] **Step 6: Prefer the isolated config in the settings editor**

In `webserverConfigFileFor`, for `apache` on Linux: return `<vhosts>/apache/_httpd.conf` when it exists, else the bundle's `conf/httpd.conf`. Add a test in `webserver_config_path_test.dart` covering both.

- [ ] **Step 7: Run the affected tests**

Run: `flutter test test/core/config/apache_config_builder_test.dart test/features/apps/isolated_service_configs_test.dart test/features/apps/webserver_config_path_test.dart test/features/apps/installer_apache_pma_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/config/apache_config_builder.dart lib/features/apps/data test/core/config test/features/apps
git commit -m "feat(apache): generate an isolated httpd.conf from the portable bundle"
```

---

### Task 10: Initialize PostgreSQL through `configureIsolatedPostgresql`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart` (`_configureDatabases` ~line 689-712, delete `_initializePostgresql` ~line 1249)
- Test: `test/features/apps/installer_postgresql_bundle_test.dart`

**Interfaces:**
- Consumes: `RuntimeBundleManifest` (Task 8), `configureIsolatedPostgresql(AppModel app, String version, String initdbPath, Function(String) logInfo, {runProcess, isLinux})` (existing).
- Produces: installing a PostgreSQL bundle yields `app.execFilePath == <root>/bin/postgres` and an initialized cluster at `AppConfig.dataDir/postgresql-<version>`.

- [ ] **Step 1: Write the failing end-to-end install test**

Model the test on `test/features/apps/redis_installer_compatibility_test.dart` (an `HttpClientAdapter` serving one tar.gz built with `package:archive`). Build the archive from `createPostgresqlBundleFixture`, but replace `bin/initdb` with a script that creates the `-D` directory and writes a `postgresql.conf`:

```sh
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-D" ]; then dir="$2"; shift 2; continue; fi
  shift
done
mkdir -p "$dir"
printf "listen_addresses = 'localhost'\n" > "$dir/postgresql.conf"
```

Assertions:

```dart
expect(app.execFilePath, p.join(installPath, 'bin', 'postgres'));
expect(File(p.join(installPath, 'bin', 'postgres')).existsSync(), isTrue);
final dataDir = p.join(AppConfig.dataDir, 'postgresql-18.6');
expect(File(p.join(dataDir, 'postgresql.conf')).readAsStringSync(), contains("listen_addresses = '127.0.0.1'"));
expect(File(p.join(dataDir, 'postgres.txt')).existsSync() || File(p.join(dataDir, 'postgres-password.txt')).existsSync(), isTrue);
```

Skip on non-Linux (`skip: !Platform.isLinux ? '…' : false`).

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/features/apps/installer_postgresql_bundle_test.dart`
Expected: FAIL — `_initializePostgresql` throws `PostgreSQL bin directory not found` / the data dir is never initialized by the fixture script, and `execFilePath` may resolve to `libexec/bin/postgres`.

- [ ] **Step 3: Swap the initializer**

In `_configureDatabases`, the PostgreSQL branch becomes:

```dart
    if (app.appId.contains('postgresql')) {
      onProgress?.call(0.96, 'Initializing PostgreSQL...');
      await configureIsolatedPostgresql(
        app,
        version,
        resolveDbTool(installPath, 'initdb'),
        logInfo,
      );
    }
```

Delete `_initializePostgresql` entirely; nothing else calls it.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/apps/installer_postgresql_bundle_test.dart test/features/apps/isolated_service_configs_test.dart test/features/apps/installer_db_init_paths_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps
git commit -m "feat(postgresql): initialize clusters through the portable bundle launcher"
```

---

### Task 11: Regenerate the catalogs and verify end to end

**Files:**
- Modify: `assets/data/apps-linux.json`, `assets/data/new-apps-linux.json` (and the Windows pair if the run changes it)
- Modify: `test/assets/linux_catalog_test.dart`, `docs/linux-support-notes.md`, `README.md`

**Interfaces:**
- Consumes: every earlier task.

- [ ] **Step 1: Regenerate against live GitHub**

Run: `docker run --rm -v "$PWD":/w -w /w node:24 sh -c 'node assets/data/update.js'`
Expected: exit 0, both `new-apps.json` and `new-apps-linux.json` written. If the builder scan fails, the run exits non-zero and writes nothing — do not hand-edit the catalog to work around it.

Then: `cp assets/data/new-apps-linux.json assets/data/apps-linux.json` (and the Windows pair if it changed).

- [ ] **Step 2: Verify the generated catalog**

```bash
python3 -I -c "
import json
d=json.load(open('assets/data/apps-linux.json'))
for a in d['apps']:
    if a['id'] in ('apache','php84','postgresql','redis'):
        print(a['id'], a['exec_file'], sorted(a['versions'])[:3])
"
```

Expected: `apache httpd [...]`, `php84 php-fpm [...]`, `postgresql postgres [...]`, `redis redis-server [...]` — each with at least one version whose URL is a builder `releases/download/` link.

- [ ] **Step 3: Update the catalog test**

In `test/assets/linux_catalog_test.dart`: the PHP URL regex becomes `r'php-\d+\.\d+\.\d+-musl-dynamic-x86_64-[a-f0-9]{16}\.tar\.gz$'`; the "unavailable runtimes" test is replaced by

```dart
test('builder runtimes are installable from musl bundles', () async {
  final apps = await loadApps();
  for (final id in ['apache', 'php84', 'postgresql', 'redis']) {
    final app = apps.firstWhere((a) => a['id'] == id);
    expect(app['versions'], isNotEmpty, reason: '$id must be installable');
    for (final url in (app['versions'] as Map).values) {
      expect(url, startsWith('https://github.com/ngotuananh101/devstack-app-builder/releases/download/'));
    }
  }
});
```

Add a PostgreSQL regex assertion `r'postgresql-\d+(?:\.\d+)+-musl-dynamic-x86_64-[a-f0-9]{16}\.tar\.gz$'`.

- [ ] **Step 4: Update the docs**

`docs/linux-support-notes.md`: replace the Apache ("intentionally ABSENT") and PostgreSQL (Zonky) bullets with "Apache and PostgreSQL ship as musl-dynamic portable bundles from `devstack-app-builder`", and delete the static-php-cli CLI-only limitation bullet (PHP now runs FPM from the bundle). `README.md:103`: drop the Zonky and package-manager (`apt`/`dnf`/`pacman`) claims, keeping the portable-bundle description.

- [ ] **Step 5: Run everything**

```bash
docker run --rm -v "$PWD":/w -w /w node:24 node --test test/assets/update_builder.test.js test/assets/update_php.test.js
flutter test
flutter analyze
```

Expected: Node `pass`, all `fail 0`; Flutter suite PASS; `flutter analyze` "No issues found!".

- [ ] **Step 6: Install all four runtimes for real**

Use a temporary `AppConfig` root (never the user's live one) and the production installer code path, driving it from a scratch Dart test or the app binary:

- PHP 8.4 → `php-fpm` config generated, FPM answers on its port.
- Redis → `redis-cli PING` returns `PONG`.
- PostgreSQL 18 → `psql --version` from the bundle, then start and stop the service.
- Apache → `httpd -t` prints `Syntax OK` against `<vhosts>/apache/_httpd.conf`, then serve a page under `unshare -r -n` (binding port 80 needs `CAP_NET_BIND_SERVICE`; this host has no passwordless sudo). Record the `setcap` warning line as the expected output when the capability cannot be granted.

Record the actual command output in the commit message body.

- [ ] **Step 7: Commit**

```bash
git add assets/data test/assets/linux_catalog_test.dart docs README.md
git commit -m "chore(catalog): regenerate Linux catalog for musl-dynamic bundles

Verified end to end on this host: PHP-FPM, Redis, PostgreSQL 18 and Apache
2.4.70 installed from the generated URLs and started successfully."
```
