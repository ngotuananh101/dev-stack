# Update cloudflared and ngrok from the Tunnels page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "Update cloudflared" and "Update ngrok" buttons to the Tunnels page header, each re-downloading the latest binary for its provider, guarded while a tunnel of that provider is busy.

**Architecture:** UI-only change in `tunnels_page.dart` reusing the existing `TunnelDownloaderService.downloadBinary` as-is; no service changes. The page computes a per-provider busy flag from the tunnel list + sessions and passes them to the header; one shared tap handler downloads the tapped provider with spinner/toast/error feedback.

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0, flutter_riverpod, AppButton/AppDialogs, Dio-backed `TunnelDownloaderService`.

**Spec:** docs/superpowers/specs/2026-11-18-cloudflared-update-design.md

## Global Constraints

- Windows + Linux only, no macOS.
- No new dependencies.
- No `// ignore:` suppressions, no analysis_options exclusions, no weakening a test.
- Commit messages must not contain `;`.
- Patch-script technique: stage edits in a local script, upload it via BVPD `write_file`, run it with `run_command`, then delete it. Never re-run a whole script after a mid-run abort; write a second script with only the remaining edits.
- Reuse `downloadBinary('cloudflare')` as-is; do not modify `TunnelDownloaderService` or `TunnelManagerService`.
- Button exact values: labels `Update cloudflared` and `Update ngrok`, icon `LucideIcons.download`, style `AppButtonStyle.success`.
- Feedback copy exact, `<name>` is `cloudflared` or `ngrok`, `<Name>` is `Cloudflare` or `ngrok`: busy → info toast `Stop the running <Name> tunnel first, then update.`; success → toast `<name> updated to the latest version`; failure → `showErrorFrom` with title `Could not update <name>`.
- Analyze baseline: zero issues on touched files. Full suite must stay green (1202 passed / 3 skipped / 0 failed at plan time).

## Review Focus

1. A tunnel of the tapped provider running while the user taps its Update button — on Windows the running exe is file-locked, so replacing it fails with a raw OS error; the guard must stop the download before it starts. Task 1 pins it with a test asserting no download call and the busy toast when a cloudflared session is `running`, plus the same guard for ngrok.
2. A tunnel mid-download (`downloadingBinary`) when its provider's Update is tapped — two concurrent downloads race on the same temp file (`<provider>.download`); the busy guard must cover `downloadingBinary` too. Task 1 pins it with a test asserting no download call while a session is `downloadingBinary`.
3. The download failing (offline, GitHub down) — the button must stop spinning and the error must surface via `showError`, not be swallowed; the old binary stays in place because `downloadBinary` deletes the target only after a successful download. Task 1 pins the dialog; Task 2 verifies the old-binary property by reading the downloader code (no new test — the existing downloader tests cover the replace order).
4. The user navigates away mid-download — `setState` and toasts after the await must be guarded by `mounted`, or the page throws. No widget test pins this; Task 2's implementation step states the guard explicitly, and the reviewer checks it.
5. The tunnel list still loading when the page first builds — the header renders before `tunnelsAsync` has data; the busy computation must use `value` and never crash on a loading `AsyncValue`. Task 1 pins it with a test pumping the page in the loading state and tapping Update.

---

### Task 1: Widget tests for the Update buttons

**Files:**
- Modify: `test/features/tunnels/presentation/tunnels_page_test.dart`
- Read first: `test/features/tunnels/data/tunnel_downloader_service_test.dart` (reuse its fake-Dio / fake-downloader pattern for overriding `tunnelDownloaderServiceProvider`), `lib/features/tunnels/data/tunnels_provider.dart` (how `tunnelsStreamProvider` and `tunnelSessionsProvider` are overridden in tests)

**Interfaces:**
- Consumes: `TunnelDownloaderService.downloadBinary('cloudflare')` (existing, unmodified), `TunnelStatus` values `downloadingBinary`, `connecting`, `running`, `stopped`, `error`; `AppDialogs.showToast` / `showInfoToast` / `showErrorFrom`.
- Produces: failing tests that Task 2 makes pass: both buttons render; tap downloads the right provider; busy guard per provider; failure dialog; loading list.

- [ ] **Step 1: Read the existing page test and downloader test, then write the failing tests**

Add to `tunnels_page_test.dart` (names exact):
```dart
testWidgets('Update cloudflared button downloads the latest binary', (tester) async { ... });
testWidgets('Update does not download while a Cloudflare tunnel is running', (tester) async { ... });
testWidgets('Update does not download while a Cloudflare tunnel is downloading its binary', (tester) async { ... });
testWidgets('Update shows an error dialog when the download fails', (tester) async { ... });
testWidgets('Update works while the tunnel list is still loading', (tester) async { ... });
testWidgets('Update ngrok button downloads the latest binary', (tester) async { ... });
testWidgets('Update ngrok does not download while an ngrok tunnel is running', (tester) async { ... });
testWidgets('Update ngrok shows an error dialog when the download fails', (tester) async { ... });
```
Assertions: the header contains `AppButton`s labelled `Update cloudflared` and `Update ngrok` next to `New Tunnel`; tapping the cloudflared button with no busy Cloudflare tunnel calls `downloadBinary('cloudflare')` exactly once and shows the toast `cloudflared updated to the latest version`; tapping it with a cloudflared session in `running` (and separately in `downloadingBinary`) calls download zero times and shows the info toast `Stop the running Cloudflare tunnel first, then update.`; a throwing downloader shows a dialog titled `Could not update cloudflared` and the button stops spinning; with the tunnel list loading, tapping still calls download once; the ngrok button mirrors this: tap calls `downloadBinary('ngrok')` once with toast `ngrok updated to the latest version`, a running ngrok session blocks it with the toast `Stop the running ngrok tunnel first, then update.`, and a throwing downloader shows a dialog titled `Could not update ngrok`. A running ngrok tunnel does NOT block the cloudflared button (and vice versa) — assert with one test where the ngrok session is `running` and the cloudflared button still downloads. Override `tunnelDownloaderServiceProvider` with a fake that records calls and either completes or throws, per test.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: FAIL — neither Update button exists yet. (Do not commit the failing tests on their own; Task 2's commit carries tests + implementation together.)

### Task 2: Implement the buttons and handler in `tunnels_page.dart`

**Files:**
- Modify: `lib/features/tunnels/presentation/tunnels_page.dart`
- Test: `test/features/tunnels/presentation/tunnels_page_test.dart` (from Task 1)

**Interfaces:**
- Consumes: Task 1 tests; `tunnelDownloaderServiceProvider`, `tunnelsStreamProvider`, `tunnelSessionsProvider`, `TunnelStatus`, `AppButton(isLoading:)`, `AppDialogs.showToast` / `showInfoToast` / `showErrorFrom`.
- Produces: the working buttons + shared handler; the per-provider busy computation.

- [ ] **Step 1: Add `_updating` state and the per-provider busy computation**

In `_TunnelsPageState`, add `final Set<String> _updating = {};`. In `build()`, compute one flag per provider via a small helper:
```dart
bool isProviderBusy(String provider) =>
    (tunnelsAsync.value ?? const <TunnelModel>[]).any((tunnel) =>
        tunnel.provider.toLowerCase() == provider &&
        const {TunnelStatus.downloadingBinary, TunnelStatus.connecting, TunnelStatus.running}
            .contains(sessions[tunnel.id]?.status));
```
Pass both flags to the header as `_buildHeader(isCloudflaredBusy: isProviderBusy('cloudflare'), isNgrokBusy: isProviderBusy('ngrok'))`.

- [ ] **Step 2: Add the buttons to `_buildHeader`**

Change the signature to `_buildHeader({required bool isCloudflaredBusy, required bool isNgrokBusy})`. Between the `SizedBox(width: 16)` and the `New Tunnel` button, add, in order, the cloudflared button, a `SizedBox(width: 8)`, the ngrok button, a `SizedBox(width: 8)`:
```dart
AppButton(
  label: 'Update cloudflared',
  icon: const Icon(LucideIcons.download, size: 16),
  style: AppButtonStyle.success,
  isLoading: _updating.contains('cloudflare'),
  onPressed: () => _updateBinary('cloudflare', isCloudflaredBusy),
)
AppButton(
  label: 'Update ngrok',
  icon: const Icon(LucideIcons.download, size: 16),
  style: AppButtonStyle.success,
  isLoading: _updating.contains('ngrok'),
  onPressed: () => _updateBinary('ngrok', isNgrokBusy),
)
```

- [ ] **Step 3: Implement `_updateBinary`**

```dart
Future<void> _updateBinary(String provider, bool isBusy) async {
  final displayName = provider == 'cloudflare' ? 'Cloudflare' : 'ngrok';
  final binaryName = provider == 'cloudflare' ? 'cloudflared' : 'ngrok';
  if (isBusy) {
    AppDialogs.showInfoToast(context, 'Stop the running $displayName tunnel first, then update.');
    return;
  }
  if (_updating.contains(provider)) return;
  setState(() => _updating.add(provider));
  try {
    await ref.read(tunnelDownloaderServiceProvider).downloadBinary(provider);
    if (!mounted) return;
    AppDialogs.showToast(context, '$binaryName updated to the latest version');
  } catch (e) {
    if (!mounted) return;
    await AppDialogs.showErrorFrom(context, e, title: 'Could not update $binaryName');
  } finally {
    if (mounted) setState(() => _updating.remove(provider));
  }
}
```
Note: `downloadBinary` takes the provider key lowercase (`'cloudflare'` / `'ngrok'`); the toast and error title use the binary name (`'cloudflared'` / `'ngrok'`); only the busy toast capitalizes the provider name (`Cloudflare`).
Read `TunnelDownloaderService.downloadBinary` once to confirm the old binary survives a failed download (target deleted only after a successful download) and note the finding in the ledger.

- [ ] **Step 4: Run the Task 1 tests to verify they pass**

Run: `flutter test test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: PASS, all tests including the eight new ones.

- [ ] **Step 5: Run `flutter analyze` on the touched file**

Run: `flutter analyze lib/features/tunnels/presentation/tunnels_page.dart test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tunnels/presentation/tunnels_page.dart test/features/tunnels/presentation/tunnels_page_test.dart
git commit -m "feat(tunnels): add Update cloudflared and Update ngrok buttons to the Tunnels page"
```

### Task 3: Final verification + docs commit

**Files:**
- Modify: none (verification only)
- Create (commit): `docs/superpowers/specs/2026-11-18-cloudflared-update-design.md`, `docs/superpowers/plans/2026-11-18-cloudflared-update.md`

**Interfaces:**
- Consumes: Task 2 commit.
- Produces: verified green suite + committed docs.

- [ ] **Step 1: Run the full suite**

Run the suite via the summary script (a Python script that runs `flutter test` and prints only the final summary line plus `[E]` lines, because `run_command` truncates long output).
Expected: `+1210 ~3 -0` or better (the eight new tests on top of the 1202 baseline), "All tests passed!"

Note: the first Step 1 run found the three-button header overflowing at the 720px minimum window (49px right, 298px bottom in the narrow test); fixed in a follow-up commit before the docs commit — `_buildHeader` is now a LayoutBuilder that stacks the header below 768px of content (see the design doc's Narrow windows bullet). The expected count above is the count with the fix in.

- [ ] **Step 2: Run full `flutter analyze`**

Run: `flutter analyze`
Expected: exactly 1 issue, the pre-existing documented `implementation_imports` info at `lib/main.dart:18:8`.

- [ ] **Step 3: Commit the design + plan docs**

```bash
git add docs/superpowers/specs/2026-11-18-cloudflared-update-design.md docs/superpowers/plans/2026-11-18-cloudflared-update.md
git commit -m "docs: design and plan for cloudflared update button"
```

- [ ] **Step 4: Append the completion line to the ledger**

Ledger: `.superpowers/sdd/2026-11-18-cloudflared-update/progress.md` — append `Task 3: complete (commits <base7>..<head7>, tests: flutter analyze -> <result>; flutter test -> <result>)` plus any Ruling lines recorded during execution.
