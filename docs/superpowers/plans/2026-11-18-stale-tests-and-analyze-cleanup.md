# Stale Tests + Analyze Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The whole suite passes and `flutter analyze` reports zero issues, with the tests asserting the UI Ponta already approved.

**Architecture:** One real lib defect first — the 1px RowActionMenu overflow, which fails 15 tests across 6 files — then test-only updates for the remaining 22 tests (typography, sidebar, one supervisor menu expectation, theme/modal/header/button), then a mechanical import swap for the 112 analyze infos, then a full green verification. Each task is one commit on `main` (no worktree: BVPD tools are project-scoped to this checkout, as established in the pyenv build-deps work).

**Tech Stack:** Flutter 3.50.0 / Dart 3.14.0, flutter_test, material_ui 1.11.1 (already a dependency, `material_ui: ^1.10.0`).

**Spec:** `docs/superpowers/specs/2026-11-18-stale-tests-and-analyze-cleanup-design.md`

## Global Constraints

- Tests assert the current approved UI: table headers 10, row cells 10 except name columns at 12, status chips 8, version tag 8, sidebar 200 expanded / 64 collapsed with no toggle button (auto-collapse below 960), outline buttons (transparent fill, style-coloured text and border), Install Latest hidden until a version is picked, Restart only built when the program is running.
- No lint suppressions (`// ignore:` comments, `analysis_options.yaml` exclusions) and no UI reverts to satisfy an old test. A test is never weakened to pass (no tolerating the 1px overflow, no asserting less, no deleting a test that still covers real behavior).
- The material_ui swap is a pure import rename: `material_ui` is the same Material library under a new name, already a dependency; no API change is expected, and analyze plus the suite prove it.
- Every test change is verified by running that test file; the whole suite and analyze are verified at the end. A task is done only when its files are green.
- Git commit messages must not contain `;` (the BVPD `run_command` filter rejects semicolons); use commas.
- Patch scripts follow the established technique: stage the Python script in `/tmp` with `muse.write`, upload it into the project root with BVPD `write_file`, run it with `run_command` (`python3 <file>`), then delete it with a single-expression list comprehension. Scripts use exact-string `replace_once` with count asserts and print per-file change counts. If a patch script aborts mid-run, the edits before the failed assert ARE already applied — never re-run the whole script; write a second script with only the remaining edits.

## Review Focus

- A button label wider than the 12.25px/char estimate (e.g. `INSTALLING...`, all-caps, wide glyphs) under-measures and the cluster overflows again. Task 1 adds a unit test asserting `measureRowActions` covers the longest labelled button in the app, measured with `TextPainter` in the button's real text style.
- A table passing a different `firstGap`/`gap` to `planActionColumn` than `RowActionMenu` renders with would plan and render different widths. Task 1's verification runs the width-sweep file (real tables, real gaps) green.
- A `material.dart` import with a `show`/`hide` combinator or an `as` prefix breaks under a naive line swap. Task 6's probe script reports combinators and prefixes first; the swap preserves them; analyze plus the suite prove it.
- A file importing both `material.dart` and `widgets.dart` gains a redundant widgets import after the swap (`material_ui` exports widgets). Task 6's probe script lists co-imports; redundant widgets imports are removed where analyze flags them; analyze reports 0 issues.
- A version-modal state the availability test does not cover: non-empty catalog, selected version with no download URL. Task 5 adds a test asserting the Install button stays disabled or absent — read `app_version_modal.dart` first for the exact behavior.

---

### Task 1: Fix the 1px RowActionMenu overflow in lib

**Files:**
- Modify: `lib/shared/utils/action_row_layout.dart` (the measurement; the exact constant is determined by the probe in Step 2)
- Test: `test/shared/utils/action_row_layout_test.dart` (confirm the filename by listing `test/shared/utils/`; the `RowActionMenu` doc says the layout helpers are unit-tested)
- Verify: `test/shared/layouts/table_width_sweep_test.dart`, `test/features/cron/presentation/widgets/cron_table_alignment_test.dart`, `test/features/supervisor/presentation/widgets/supervisor_table_alignment_test.dart`, `test/features/tunnels/presentation/widgets/tunnel_table_alignment_test.dart`, `test/features/cron/presentation/widgets/cron_table_test.dart`, `test/features/supervisor/presentation/widgets/supervisor_table_test.dart`, `test/features/tunnels/presentation/widgets/tunnel_table_test.dart`

**Interfaces:**
- Consumes: `measureRowActions`, `rowActionsOverflow`, `planActionColumn`, `kRowActionCharWidth`, `kRowActionButtonPadding`, `kRowActionButtonIconWidth`, `kRowActionButtonIconGap`, `kRowActionIconWidth` from `lib/shared/utils/action_row_layout.dart`; `RowActionMenu` from `lib/shared/widgets/row_action_menu.dart`.
- Produces: a measurement that is never smaller than the real rendered cluster width, so every table that plans its action column with `planActionColumn` renders without overflow.

- [ ] **Step 1: Run the width-sweep file to confirm the failure**

Run: `flutter test test/shared/layouts/table_width_sweep_test.dart`
Expected: FAIL — `the tunnels table fits every window width` at 980px, `the supervisor table fits every window width` at 780px, `the cron table fits every window width` at 920px, each `A RenderFlex overflowed by 1.00 pixels on the right` from `Row` at `lib/shared/widgets/row_action_menu.dart:79`. The apps, sites and databases sweeps pass.

- [ ] **Step 2: Probe the real rendered width against the measurement**

Write a throwaway test file (e.g. `tmp_overflow_probe_test.dart` in the project root, deleted after this step) that pumps one failing cluster — a `RowActionMenu` with the cron running-row actions (`Run` button plus its icon actions) inside a `SizedBox` of the planned column width — and prints `tester.getSize` of the `AppButton` labelled `Run` and of the menu `Row`, next to `measureRowActions` for the same actions. The probe must establish which measured part is short and by how much. Candidates: `kRowActionCharWidth` (12.25) under-measures a label, or the button carries a structural +1 the measurement misses (every failing cluster has exactly one labelled button and overflows by exactly 1.00px). Delete the probe file when done.

- [ ] **Step 3: Fix the measurement in `lib/shared/utils/action_row_layout.dart`**

Change the constant the probe identifies so the measured width is never smaller than the real rendered width for any labelled button in use. Do not change `AppButton` or any table widget: the UI is correct, the estimate is short. If the probe shows the cause is structural rather than a constant, fix the measurement formula instead and say so in the commit message.

- [ ] **Step 4: Add a unit test for the longest label in use**

In the `action_row_layout` unit test file, add a test asserting `measureRowActions` for a cluster containing the longest labelled button in the app (`INSTALLING...`, 12 chars) is at least the width `TextPainter` measures for that label in the button's real text style (12px, w600). The test pins Review Focus 1.

- [ ] **Step 5: Run the sweep, alignment and content files to verify the fix**

Run: `flutter test test/shared/layouts/table_width_sweep_test.dart test/features/cron/presentation/widgets/cron_table_alignment_test.dart test/features/supervisor/presentation/widgets/supervisor_table_alignment_test.dart test/features/tunnels/presentation/widgets/tunnel_table_alignment_test.dart test/features/cron/presentation/widgets/cron_table_test.dart test/features/supervisor/presentation/widgets/supervisor_table_test.dart test/features/tunnels/presentation/widgets/tunnel_table_test.dart`
Expected: all green EXCEPT `supervisor_table_test.dart` still fails its one `collapses actions into one menu at a ~412px row` test (`Found 0 widgets with text "Restart"`) — that is Task 4, not this fix. If an alignment test still fails on a dx mismatch after the overflow is gone (supervisor demands exact equality, cron and tunnels allow 1px via `closeTo`), investigate the header-vs-row layout in that table file and fix the layout, not the tolerance.

- [ ] **Step 6: Run the layout unit tests**

Run: `flutter test test/shared/utils/`
Expected: PASS. If the fix changed a pinned constant, update the unit test's expected value to the new constant in the same commit and say so in the message.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/utils/action_row_layout.dart test/shared/utils/action_row_layout_test.dart
git commit -m "fix(tables): measure action clusters 1px wider so inline rows never overflow"
```

### Task 2: Update the table typography tests to the documented sizes

**Files:**
- Modify: `test/shared/layouts/table_typography_test.dart` (only this file)

**Interfaces:**
- Consumes: the rendered sizes the tables actually produce (recorded below from the failure output — the ground truth of what each table renders).
- Produces: 13 tests asserting the current size palette instead of one uniform size.

- [ ] **Step 1: Run the file to confirm the failures**

Run: `flutter test test/shared/layouts/table_typography_test.dart`
Expected: FAIL — 13 tests. `renders at one size` reports the actual sets below; `a table header is distinguished by colour and weight only` reports header 10.0 vs cell 12.0; the empty-state tests report the actual sets below.

- [ ] **Step 2: Replace the one-size expectation with per-table documented sizes**

In the `renders at one size` loop, rename the test to `'the ${entry.key} table renders at the documented sizes'` and replace `{12.0}` with a per-table map:

```dart
const expectedSizes = <String, Set<double>>{
  'apps': {10.0, 12.0, 8.0},
  'sites': {10.0, 12.0},
  'tunnels': {10.0, 12.0, 8.0},
  'supervisor': {10.0, 12.0, 8.0},
  'cron': {10.0, 12.0, 8.0},
  'databases': {10.0, 12.0},
};
```

The palette is: headers 10, row cells 10, name columns 12, status chips 8, version tag 8. Update the file's doc comment (the "header, cells and actions all sit on the body size; the header is told apart by colour and weight, not by a smaller typeface" premise is obsolete) to state the palette. Keep the `reason` string, reworded to the palette.

- [ ] **Step 3: Fix the header test to the new hierarchy**

Rename `'a table header is distinguished by colour and weight only'` to `'a table header is smaller than its cells, and distinguished by colour and weight'`. Replace `expect(sizeOf(header), sizeOf(cell), reason: 'same size, no smaller label')` with `expect(sizeOf(header), 10.0)` and `expect(sizeOf(cell), 12.0)`. Keep the `FontWeight.w600` and the colour-differs expectations unchanged.

- [ ] **Step 4: Fix the empty-state tests with per-table sets**

In the empty-state loop, rename the test to `'the ${entry.key} table empty state sits on the documented sizes'` and replace `{12.0}` with:

```dart
const expectedEmptySizes = <String, Set<double>>{
  'apps': {10.0},
  'sites': {10.0},
  'tunnels': {10.0, 12.0},
  'supervisor': {10.0, 12.0},
  'cron': {10.0, 12.0},
  'databases': {10.0, 12.0},
};
```

- [ ] **Step 5: Run the file to verify it passes**

Run: `flutter test test/shared/layouts/table_typography_test.dart`
Expected: PASS — 13 tests.

- [ ] **Step 6: Commit**

```bash
git add test/shared/layouts/table_typography_test.dart
git commit -m "test(tables): assert the documented size palette, headers 10, cells 10, names 12, chips 8"
```

### Task 3: Rewrite the sidebar tests around the provider (no toggle button)

**Files:**
- Modify: `test/shared/layouts/sidebar_test.dart` (only this file)

**Interfaces:**
- Consumes: `Sidebar` from `lib/shared/layouts/sidebar.dart` (width `collapsed ? 64 : 200`); `sidebarCollapsedProvider` with `setCollapsed(bool)` from `lib/shared/providers/sidebar_provider.dart`; `navigationProvider` from `lib/shared/providers/navigation_provider.dart`. The toggle button is gone from the UI; collapse is driven through the provider, exactly how the existing nav test already reads the container with `ProviderScope.containerOf(find.byType(Sidebar).evaluate().first, listen: false)`.
- Produces: 4 tests proving the sidebar at 200/64px with labels/tooltips/nav working, driven the way the app drives collapse now.

- [ ] **Step 1: Run the file to confirm the failures**

Run: `flutter test test/shared/layouts/sidebar_test.dart`
Expected: FAIL — 4 tests. `starts expanded at 240px` reports `Expected <240> Actual <200.0>`; the other three fail finding `LucideIcons.panelLeftClose` / `panelLeftOpen`.

- [ ] **Step 2: Rewrite the four tests**

Keep the `host()` helper unchanged. In each test, drive collapse through the provider instead of tapping the removed toggle icon: read the container the way the nav test does (`ProviderScope.containerOf(find.byType(Sidebar).evaluate().first, listen: false)`) and call `container.read(sidebarCollapsedProvider.notifier).setCollapsed(true)` to collapse, `setCollapsed(false)` to expand, then `pumpAndSettle()`.

- `starts expanded at 240px with every nav label visible` → rename to `starts expanded at 200px with every nav label visible`: expect width `200`, `find.text('Apps')` and `find.text('Settings')` one widget each, and `find.byIcon(LucideIcons.panelLeftClose)` finds nothing (the toggle is gone).
- `collapses to 64px, keeps icons and tooltips` → collapse via `setCollapsed(true)`: expect width `64`, `find.text('Apps')` finds nothing, the `Tooltip` messages contain `'Apps'`, and `find.byIcon(LucideIcons.panelLeftOpen)` finds nothing.
- `expands again from collapsed` → `setCollapsed(true)`, pump, then `setCollapsed(false)`, pump: expect width `200` and `find.text('Apps')` one widget.
- `nav still switches tabs while collapsed` → collapse via `setCollapsed(true)` instead of tapping the toggle, then tap `find.byTooltip('Cron')` and expect `container.read(navigationProvider)` is `NavigationTab.cron`.

- [ ] **Step 3: Run the file to verify it passes**

Run: `flutter test test/shared/layouts/sidebar_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 4: Commit**

```bash
git add test/shared/layouts/sidebar_test.dart
git commit -m "test(sidebar): drive collapse through the provider, width 200, no toggle button"
```

### Task 4: Fix the supervisor 412px menu expectation (Restart only exists when running)

**Files:**
- Modify: `test/features/supervisor/presentation/widgets/supervisor_table_test.dart` (only the `responsive actions` group)

**Interfaces:**
- Consumes: `SupervisorTable` from `lib/features/supervisor/presentation/widgets/supervisor_table.dart`; the `RowAction.icon` for Restart is only built `if (isRunning)` (lib change of 2026-11-17), so a stopped program's menu has no Restart and a running program's menu has no Start.
- Produces: the 412px collapse test asserting the menu for both states.

- [ ] **Step 1: Run the file to confirm the failure**

Run: `flutter test test/features/supervisor/presentation/widgets/supervisor_table_test.dart`
Expected: FAIL — 1 test, `collapses actions into one menu at a ~412px row`: `Expected exactly one matching candidate / Actual _TextWidgetFinder:<Found 0 widgets with text "Restart": []>`. (Assumes Task 1 is done; if Task 1 is not done yet, this file may also fail with the 1px overflow — run Task 1 first.)

- [ ] **Step 2: Split the 412px test into the stopped and running cases**

Keep the existing stopped-program case (statuses `const {}`, pids `const {}`): after opening the menu with `find.byIcon(LucideIcons.moreHorizontal)`, expect `find.text('Start')`, `find.text('View Logs')`, `find.text('Edit')`, `find.text('Delete')` one widget each, and drop the `find.text('Restart')` expectation — Restart is not built for a stopped program. Keep the `await tester.tap(find.text('Start').last); expect(started?.id, 1);` tail.

Add a second test, `collapses actions into one menu at a ~412px row while running`, identical except the table gets `statuses: const {1: SupervisorStatus.running}` and `pids: const {1: 4242}`: before opening the menu expect `find.text('Start')` finds nothing, after opening expect `find.text('Stop')`, `find.text('Restart')`, `find.text('View Logs')`, `find.text('Edit')`, `find.text('Delete')` one widget each, then tap `find.text('Stop').last` and expect the stop callback fired with id 1 (wire `onStop: (id) => stoppedId = id` for this case).

- [ ] **Step 3: Run the file to verify it passes**

Run: `flutter test test/features/supervisor/presentation/widgets/supervisor_table_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add test/features/supervisor/presentation/widgets/supervisor_table_test.dart
git commit -m "test(supervisor): 412px menu asserts Start without Restart when stopped, Stop with Restart when running"
```

### Task 5: Update the theme, version-modal, marketplace-header and button tests

**Files:**
- Modify: `test/core/theme/app_theme_tokens_test.dart`
- Modify: `test/features/apps/presentation/widgets/app_version_modal_availability_test.dart`
- Modify: `test/features/apps/presentation/widgets/marketplace_header_layout_test.dart`
- Modify: `test/shared/widgets/app_button_test.dart`

**Interfaces:**
- Consumes: `AppTheme.darkTheme` from `lib/core/theme/app_theme.dart` (ColorScheme `outline`/`outlineVariant` are `Colors.transparent` so the window frame stays borderless); `AppVersionModal` from `lib/features/apps/presentation/widgets/app_version_modal.dart` (the footer Install button renders only after a version is picked); `MarketplaceHeader` from `lib/features/apps/presentation/widgets/marketplace_header.dart` (refresh is an `AppIconButton` size md, tooltip `'Update App List'`); `AppButton` from `lib/shared/widgets/app_button.dart` (success style: transparent fill, `AppColors.success` text, 0.5 border).
- Produces: 4 tests asserting the current behavior of those four widgets.

- [ ] **Step 1: Run the four files to confirm the failures**

Run: `flutter test test/core/theme/app_theme_tokens_test.dart test/features/apps/presentation/widgets/app_version_modal_availability_test.dart test/features/apps/presentation/widgets/marketplace_header_layout_test.dart test/shared/widgets/app_button_test.dart`
Expected: FAIL — 1 test in each file. (The version-modal failure is `Bad state: No element` at the `tester.widget<AppButton>(installButton)` line; the header failure is `Found 0 widgets with type "IconButton"`; the button failure is `Expected Color successStrong / Actual Color transparent`.)

- [ ] **Step 2: Fix the theme-tokens test**

Read `lib/core/theme/app_theme.dart` first and confirm the values the theme sets for `dividerColor`, `colorScheme.outline` and `colorScheme.outlineVariant` (expected: `Colors.transparent` for outline/outlineVariant; confirm dividerColor from the theme). In `app_theme_tokens_test.dart`, rename `'AppTheme darkTheme keeps window-frame colours on the palette'` to `'AppTheme darkTheme keeps the window frame borderless'` and replace the three `expect(..., AppColors.border)` lines with the values the theme actually sets. Update the comment to state the intent: the frame is borderless by design, so outline/outlineVariant are transparent rather than the palette border.

- [ ] **Step 3: Fix the empty-catalog version-modal test**

In `app_version_modal_availability_test.dart`, in the `missing` branch only: the Install button does not exist when the catalog is empty (there is no version to pick, so the footer button never renders). Replace `expect(tester.widget<AppButton>(installButton).onPressed, isNull)` with `expect(installButton, findsNothing)` and keep the `expect(find.text('No downloadable versions available.'), findsOneWidget)` line. Leave the `selecting a downloadable patch enables installation` branch untouched.

- [ ] **Step 4: Add the non-downloadable-version case (Review Focus 5)**

Read `lib/features/apps/presentation/widgets/app_version_modal.dart` first for the exact behavior when a catalog version has no download URL, then add a separate `testWidgets` block after the loop in the same file: a non-empty catalog where the selected version has no entry in `downloadUrls`. Assert the real behavior (Install button disabled or absent — whichever the modal does). This pins the modal's behavior after the Install Latest change.

- [ ] **Step 5: Fix the marketplace-header test finder**

In `marketplace_header_layout_test.dart`, replace `tester.getRect(find.byType(IconButton))` with `tester.getRect(find.byTooltip('Update App List'))` — the refresh control is an `AppIconButton`, not an `IconButton`, and the tooltip finder uniquely identifies it (the page's table rows contain other `AppIconButton`s). Update the comment: the refresh tap target is the 32px `AppIconButton` md, not the 48px `IconButton` tap target. Keep the `barRect.right ≈ refreshRect.left - 16` expectation and the 16px-gap reason unchanged.

- [ ] **Step 6: Fix the AppButton success test**

In `app_button_test.dart`, rename `'AppButton style success uses successStrong background and textOnColor'` to `'AppButton style success uses an outline with success text'`. Replace `expect(material.color, AppColors.successStrong)` with `expect(material.color, Colors.transparent)` and `expect(text.style!.color, AppColors.textOnColor)` with `expect(text.style!.color, AppColors.success)`.

- [ ] **Step 7: Run the four files to verify they pass**

Run: `flutter test test/core/theme/app_theme_tokens_test.dart test/features/apps/presentation/widgets/app_version_modal_availability_test.dart test/features/apps/presentation/widgets/marketplace_header_layout_test.dart test/shared/widgets/app_button_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add test/core/theme/app_theme_tokens_test.dart test/features/apps/presentation/widgets/app_version_modal_availability_test.dart test/features/apps/presentation/widgets/marketplace_header_layout_test.dart test/shared/widgets/app_button_test.dart
git commit -m "test(theme, modal, header, button): assert borderless frame, hidden Install, AppIconButton refresh, outline success"
```

### Task 6: Swap every material.dart import to material_ui and drop the unused import

**Files:**
- Modify: all 111 files importing `package:flutter/material.dart` (56 in `lib/`, 55 in `test/`) — mechanical, scripted
- Modify: `lib/shared/widgets/terminal_log_view.dart` — remove the unused `package:flutter/rendering.dart` import (line 2)
- Possibly modify: files importing both `material.dart` and `widgets.dart`, if analyze flags the widgets import as redundant after the swap

**Interfaces:**
- Consumes: `package:material_ui/material_ui.dart` (the same Material library under a new name; already a dependency, `material_ui: ^1.10.0`, and already imported in `lib/` — e.g. `text_theme_bridge.dart` — so no `flutter pub get` is needed; if analyze reports the package unavailable, run `flutter pub get` first).
- Produces: `flutter analyze` reporting 0 issues and the suite green.

- [ ] **Step 1: Probe the import surface**

Write and run a probe script that reports: (a) every file containing `package:flutter/material.dart` (expect 111: 56 lib + 55 test), (b) any of those imports carrying a `show`/`hide` combinator or an `as` prefix, (c) any of those files also importing `package:flutter/widgets.dart`, (d) any file already importing `package:material_ui/material_ui.dart`. Print the four lists; do not edit yet.

- [ ] **Step 2: Swap the imports**

With a patch script (exact-string replace, count asserts), replace the import line `import 'package:flutter/material.dart';` with `import 'package:material_ui/material_ui.dart';` in every file from Step 1(a), preserving any combinator or prefix from Step 1(b) after the new URI. In the same script, delete the line `import 'package:flutter/rendering.dart';` from `lib/shared/widgets/terminal_log_view.dart`. Do not touch any other import.

- [ ] **Step 3: Run analyze and remove newly redundant imports**

Run: `flutter analyze`
Expected: 0 issues, except possibly `unnecessary_import` for `package:flutter/widgets.dart` in files that imported both (material_ui exports widgets). If any appear, remove those widgets imports with a second patch script and re-run analyze until it reports 0 issues.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: all tests pass, 0 failures. (The count is higher than the old 1162 passing: Tasks 1–5 added the long-label unit test, the running-case supervisor test and the non-downloadable-version case.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: import material_ui instead of flutter material, drop unused rendering import"
```

### Task 7: Final verification and commit the docs

**Files:**
- Modify: none (verification only, plus the two docs if they are still uncommitted: `docs/superpowers/specs/2026-11-18-stale-tests-and-analyze-cleanup-design.md`, `docs/superpowers/plans/2026-11-18-stale-tests-and-analyze-cleanup.md`)

- [ ] **Step 1: Run the whole suite and analyze one final time**

Run: `flutter test` then `flutter analyze`
Expected: suite all green with 0 failures, analyze reports `No issues found!` (exit 0). If anything fails, it belongs to the task that owns that file — fix it there, not here.

- [ ] **Step 2: Confirm a clean tree and commit the docs**

Run: `git status --short`
Expected: clean except the two docs if they are not yet committed. Commit them if needed:

```bash
git add docs/superpowers/specs/2026-11-18-stale-tests-and-analyze-cleanup-design.md docs/superpowers/plans/2026-11-18-stale-tests-and-analyze-cleanup.md
git commit -m "docs: design and plan for stale tests and analyze cleanup"
```

- [ ] **Step 3: Report**

Report to Ponta: the suite is green, analyze is clean, the 1px overflow fix and what caused it, and the counts (37 tests fixed, 112 infos gone).
