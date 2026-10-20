# Narrow Window: Responsive Tables + Toolbars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every data table and page toolbar usable down to ~700px total window width (no window minimum size, fixed 240px sidebar that becomes collapsible to ~64px icon-only).

**Architecture:** A pure, unit-tested width-measurement function (`measureRowActions`/`rowActionsOverflow` already built) drives a shared `RowActionMenu` widget that shows buttons inline or collapses them into a single `…` `PopupMenuButton` — one breakpoint for all 6 tables. Each table wraps its row in a `LayoutBuilder`, subtracts the fixed column widths it owns (`_operateReservedWidth`) to get the action budget, and delegates rendering to `RowActionMenu`. Horizontal-scroll "minWidth floors" are deleted entirely. Page toolbars collapse onto a shared `_overflowToolbar` helper using `Wrap`. The sidebar grows a Riverpod `sidebarProvider` (collapsed bool), an `AnimatedContainer` width, and a toggle button wired into `MainScreen`'s `Row`.

**Tech Stack:** Flutter desktop (stable), Riverpod 3.4.3 codegen (`@Riverpod`/`@riverpod`), `window_manager`, `lucide_icons_flutter`, `flutter_lints`.

**Spec:** The binding decision set provided by the user (overflow `…` button; ~700px target; collapsible sidebar; 3 toolbar dropdowns). Existing shared widgets `lib/shared/utils/action_row_layout.dart` + `lib/shared/widgets/row_action_menu.dart` carry the measurement + rendering decisions. Verified against Flutter SDK source: an overflowing `Row` raises `FlutterError` (asserts fail tests) and does NOT re-layout children — so the shared menu must run BEFORE flex children go negative.

## Global Constraints
- Do NOT set any window minimum size (`WindowOptions.minimumSize` or `setMinimumSize` must not be added); the user explicitly ruled this out.
- Target usable width ~700px window. Sidebar collapses 240px -> ~64px (icon-only). AppHeader is 36px tall; page padding is 24px horizontal each side.
- Visual language unchanged when there is room: buttons render exactly as before (AppButton/AppIconButton), only collapse to `…` when the measured cluster is too wide.
- New shared code must be pure Dart (no Flutter rendering) where it is a width function — unit-testable without `flutter test`.
- `dart run build_runner build --delete-conflicting-outputs` after adding any `@riverpod`/`@Riverpod` provider (codegen), OR a hand-written provider so no generation is required for `sidebar_provider`.
- Every `flutter analyze` run during the plan must report 0 issues; the full suite (862 tests) must pass before each commit except where a task's own tests are in-flight.

## Review Focus
- Width-estimation drift under `textScaleFactor`/font scaling: the pure function uses a fixed `kRowActionCharWidth = 6.5` advance; if a label is wider, the menu collapses a hair early (acceptable — actions stay reachable). No test is needed for the drift itself because the existing `action_row_layout_test.dart` already pins the formula's exact arithmetic.
- Double-decision desync in the Tunnel PUBLIC URL cell: the URL text and its URL-cell actions must be driven by the SAME overflow decision as the row's OPERATE actions. If they ever collapse independently, the URL could be ellipsized while a button is still shown inline (visual mismatch) or, worse, the URL actions get orphaned. Pin this with the tunnel narrow test asserting the URL text is visible AND the copy/link icons are absent together.
- The Database table currently has NO vertical scroll; a long table at narrow width must not overflow vertically. Pin with a tall-data `DatabaseTable` widget test at a surface height, asserting no exception.
- Sidebar state persistence across hot reload and across app launch (must read persisted value, not default-false every build). Pin with a sidebar widget test that overrides the provider.

---

### Task 0: Restore a compiling baseline

**Why:** The working tree is mid-edit; `site_table.dart` has malformed braces (lines 52-74: `Column`'s `]` + `)` closed a `;` short, orphaning `_buildHeader`/`_buildRow`), so `flutter test` cannot load `site_table_cli_test.dart`, `widget_test.dart`, or `site_terminal_command_test.dart`. Nothing else can be verified until it compiles.

**Files:**
- Fix: `lib/features/sites/presentation/widgets/site_table.dart` (brace structure of `build`, `_buildRow` signature, `_operateReservedWidth`/`_flexColumnMinWidth` placement as `static const` inside the class body).
- Do NOT change the `RowActionMenu` wiring that is already in `_buildRow` (lines 270-352) — only fix braces so it compiles; the row body, the `availableWidth - _operateReservedWidth` budget, and the existing narrow-row test expectations stay intact.

**Steps:**
- [ ] Run `flutter analyze lib/features/sites/presentation/widgets/site_table.dart` to confirm the brace errors.
- [ ] Fix the `build` return so `Column(...) -> );` closes the `LayoutBuilder` builder correctly (matching the compact_apps_table.dart structure that compiles).
- [ ] Run `flutter test test/features/sites/presentation/widgets/site_table_cli_test.dart` — expect the pre-existing narrow-row test to PASS (it already exists at line 215+ in the diff and asserts `moreHorizontal` present + `settings` absent + menu lists Logs/Share/Tunnel/Config/Delete/Start at 700px).
- [ ] Run `flutter test test/widget_test.dart test/features/sites/site_terminal_command_test.dart` — expect pass.
- [ ] Commit: `fix(sites): restore brace structure so SiteTable compiles`.

---

### Task 1: Database table — vertical scroll + row actions + ellipsis

**Why:** `database_table.dart` has NO `ListView` (eager `Column` children at 34-44 → vertical overflow), a Redis `DB INDEX` Text with no `overflow`/`maxLines` (line 119-123), the OPERATE cells force 2 × `AppIconButton` (64px) into `Expanded(flex:1)` with no slack, and a no-op `onPressed: () {}` Flush DB stub (line 151) that must still surface in the menu.

**Files:**
- Modify: `lib/features/databases/presentation/widgets/database_table.dart`
- Test: `test/features/databases/presentation/widgets/database_table_test.dart` (new)

**Changes:**
- Replace the eager `_buildTableRow` in a `Column` with an `Expanded -> ListView.builder` (`ClipRRect`/`Scrollbar` optional). Keep header identical.
- Wrap the whole table body in the same `LayoutBuilder` shim other tables use and pass `availableWidth` to `_buildTableRow`.
- Compute `_operateReservedWidth` = `2*16 (row pad) + 8 (between) + 8 (between) + 8 (gap) + 2*_flexColumnMinWidth`. `_flexColumnMinWidth = 120`.
- Replace both OPERATE `Row` cells with `RowActionMenu(availableWidth: availableWidth - _operateReservedWidth, actions: [...])` mirroring the existing inline buttons verbatim:
  - Redis branch: `[RowAction.icon('Flush DB', () {} /* keep stub */, icon: Icons.refresh_rounded), RowAction.icon('Clear Record', () => onDelete(db), icon: Icons.delete_outline_rounded)]` with `firstGap: 0, gap: 8`.
  - Non-Redis: `[RowAction.icon('Edit Database', () => onEdit(db), icon: Icons.edit_outlined), RowAction.icon('Delete', () => onDelete(db), icon: Icons.delete_outline_rounded)]` with `firstGap: 0, gap: 8`.
- Add `maxLines: 1, overflow: TextOverflow.ellipsis` to the Redis `DB INDEX` Text (119-123). Confirm all other Text nodes already have `overflow: ellipsis`.
- Note: a disabled-but-measured action (`onPressed: () {}`) keeps the `null`-vs-`(){}` semantics the shared `RowAction.icon(label, onPressed)` already handles via `onPressed == null`. Keep the stub as `() {}` (a real, no-op callback) to preserve "button is enabled but does nothing" — the existing test asserts it's not disabled.

**Tests:**
- `test/features/databases/presentation/widgets/database_table_test.dart`:
  - `renders headers and the empty state` at 1280x720.
  - `collapses operate buttons into a menu at a 700px window` — render `SizedBox(700x400)` inside `Padding(24)` (matches page chrome), pump, assert `find.byIcon(LucideIcons.moreHorizontal)` found, the inline icon buttons NOT found, tap menu, assert 'Edit Database' + 'Delete' present, tap Delete fires `onDelete`.
  - `redis db index text ellipsizes` — pass 50 redis records (force scroll) at 700x500 inside the page's `Padding(24)`+`Expanded`, assert no exception thrown (proves the `ListView` fix).
  - `Flush DB stub stays in the redis menu` — at narrow width, open redis menu, assert 'Flush DB' present.

- [ ] Implement changes to `database_table.dart`.
- [ ] Run new test + existing `databases_page_actions_test.dart`.
- [ ] Commit.

---

### Task 2: Sites page toolbar — collapse + search shrink

**Why:** `_buildHeader` (lines 89-118) is a `Row` with a 280px hard search + buttons that need ~500-642px; only ~412px of table width is available at 700px even with the sidebar collapsed, so the toolbar itself overflows before the table even renders.

**Files:**
- Modify: `lib/features/sites/presentation/sites_page.dart`
- The search `TextField` (lines 120-163): wrap `SizedBox(width: 280)` in `Expanded` so it shrinks; cap its `width` with `maxWidth` derived from remaining space — simplest is `SizedBox(width: 280)` -> `Expanded(child: SizedBox(...))` but `SizedBox` inside `Expanded` ignores the explicit width, so instead use `Expanded(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 280, maxWidth: ...)))` — cleaner: keep `width: 280` as a soft cap by making it `Flexible` and let ` TextField` decide; the lint-clean path is `Expanded(child: SizedBox(width: 280, ...))` is pointless, so wrap as `Expanded(child: TextField(...))` with `TextField` itself constrained by `BoxConstraints(maxWidth: 280, minHeight: 36, maxHeight: 36)`.

**Exact change for the search:**
- Replace `_buildSearchField`: `SizedBox(width: 280, height: 36, child: TextField(...))` → `Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280, minHeight: 36, maxHeight: 36), child: TextField(...)))`.

**Buttons grouping (sites toolbar):** group the leading buttons + delete into one `Wrap(spacing: 8, runSpacing: 8)` so on overflow they wrap below the title row instead of squeezing. Structure:
```
Row(
  crossAxisAlignment: CrossAxisAlignment.start,  // allow wrap
  children: [
    Wrap(spacing:8, runSpacing:8, children: [AddSite, BatchCreate, Delete]),
    Spacer(),
    _buildSearchField(),
  ],
)
```
This is preferred over `Flexible` for the buttons because `Wrap` keeps the search at a usable 280px when there's room and lets buttons stack when there isn't, exactly matching the user's "page toolbars" requirement without re-flowing button labels.

**Test:** `test/features/sites/presentation/widgets/sites_page_toolbar_test.dart` (new):
- At 700px surface (sidebar collapsed model), pump `SitesPage` minimal — but `SitesPage` needs providers. Instead, assert at the toolbar level by extracting `_buildHeader` is private. Use the existing `site_table_cli_test.dart` pattern: render full `SitesPage` under `ProviderScope` at `Size(700, 720)` and assert `find.text('Add Site')`, `find.text('Batch Create')` both present and no exception (overflow is a thrown error). A second assertion at 1400px confirms the same buttons render.

**Steps:**
- [ ] Implement `_buildSearchField` shrink + `Wrap` for buttons.
- [ ] Add test; run at 700 & 1400.
- [ ] Commit.

---

### Task 3: Databases page toolbar — collapse + search shrink

**Why:** `_buildActionHeader` (394-484) worst case ~750px (MySQL: Add DB + phpMyAdmin + HeidiSQL + Sync + status-button + 280 search) overflows below ~1050px. Same pattern as sites.

**Files:**
- Modify: `lib/features/databases/presentation/databases_page.dart`

**Changes:**
- Wrap the button cluster in `Wrap(spacing: 8, runSpacing: 8, children: [...])` up to and including `_buildServiceStatusButton()`. Keep `Spacer()` + `_buildSearchField(isRedis)` after it (the search already has a sibling pattern).
- `_buildSearchField` (616-619): `SizedBox(width: 280, height: 36)` → `Expanded`+`ConstrainedBox(maxWidth: 280)` exactly as sites.
- The `PopupMenuButton` service-status control is already compact; leave its inner structure (disabled header + divider + items) untouched.

**Test:** extend the existing `test/features/databases/presentation/databases_page_actions_test.dart` (do not delete its existing 1400px assertions):
- Add `testWidgets('toolbar wraps at a narrow window without overflow', ...)` at `Size(700, 720)`: pump the page under `ProviderScope` with the redis override already used there, assert `find.text('Sync DB')` and `find.byType(PopupMenuButton<String>)` present, no exception.

- [ ] Implement.
- [ ] Run.
- [ ] Commit.

---

### Task 4: Logs page — dropdown width + toolbar safety

**Why:** Header (160-341) is `LOGS / dropdown / [REFRESH CLEAR|DELETE]`; the `DropdownButton`'s `Container` has no width → collapses to zero. The action `Row` (REFRESH + CLEAR/DELETE) only overflows at very narrow widths.

**Files:**
- Modify: `lib/features/logs/presentation/logs_page.dart`

**Changes:**
- Wrap the dropdown `Container(height: 36, ...)` in `Expanded` so it takes the space between `LOGS` and the action `Row`. The `DropdownButton` itself already expands to its parent (`isExpanded` defaults to false but inside an `Expanded`→`Container`→`DropdownButtonHideUnderline`→`DropdownButton<String>` it fills the width — verify by running; if it doesn't fill, add `isExpanded: true`).
- The trailing `Row([REFRESH, CLEAR])` is already `mainAxisSize.min` and right-aligned by the surrounding `Row`'s default; wrap it in `Wrap(spacing: 8)` defensively so two short labels never overflow at <700px.
- Re-check: the header `Row` children are `Text('LOGS') + SizedBox(24) + Expanded(dropdown) + Spacer() + Wrap(REFRESH,CLEAR)`. The leading `LOGS` label is fixed; it stays.

**Test:** `test/features/logs/presentation/widgets/logs_page_toolbar_test.dart` (new) at `Size(700, 720)` under a minimal `ProviderScope` (apps provider override). Assert `find.text('REFRESH')` + one of the dropdown items (e.g. an installed service name) render and no exception is thrown. A narrower `Size(600, 720)` is the stress case.

- [ ] Implement dropdown `Expanded` + trailing `Wrap`.
- [ ] Add test.
- [ ] Commit.

---

### Task 5: Collapsible sidebar + provider + toggle

**Why:** `sidebar.dart` hard-cores `width: 240` (line 16) with no state. `main.dart` consumes `const Sidebar()` in a `Row` that never shrinks it.

**Files:**
- Create: `lib/shared/providers/sidebar_provider.dart` (NOT codegen — use `@Riverpod` only if the project's `build_runner` is reliable; otherwise a hand-rolled `StateProvider<bool>` so no regeneration is needed). Decision: use `@riverpod` (codegen matches `navigation_provider.dart` style and the project already runs `build_runner`). Body: `@Riverpod(keepAlive: true) bool sidebarIsCollapsed(SidebarIsCollapsedNotifier ...) => false;` — simplest form. Provide `toggle()` + `setCollapsed(bool)` + persistence via `WindowService`/`SharedPreferences`? The user said no minimum size but didn't ask for persistence; keep it ephemeral state to scope the plan. Decision: NO persistence (keeps the plan in-bounds; a follow-up can add `SharedPreferences` to `settings_provider.dart`).
- Modify: `lib/shared/layouts/sidebar.dart` (read `sidebarIsCollapsedProvider`, `AnimatedContainer(width: collapsed ? 64 : 240)`, icon-only mode shows `Icon` + `Tooltip(message: label)` and hides `Text(label)`).
- Modify: `lib/main.dart` (replace `const Sidebar()` with `const Sidebar()` still works since `ConsumerWidget` — but width animation needs `const`? No: `AnimatedContainer` needs runtime state, so `Sidebar` becomes a `ConsumerWidget` reading the provider; keep `const Sidebar()` in `main.dart` — `ConsumerWidget` can be `const` if it takes no constructor args, which it doesn't). Keep `main.dart`'s `Row` as-is; the sidebar's `AnimatedContainer` reports its own width, and the existing `Expanded(child: _buildPage)` fills the rest.
- Modify: `lib/shared/layouts/app_header.dart` — add a toggle button (chevron/icon) at the left of the header (after `_buildBrand`) that calls `ref.read(sidebarIsCollapsedProvider.notifier).toggle()`. Since `AppHeader` is a `StatefulWidget`, convert its toggle to use `ref` — make `_AppHeaderState` a `ConsumerState` (Riverpod `ConsumerStatefulWidget`).

**Exact sidebar rebuild:**
- `build` reads `final collapsed = ref.watch(sidebarIsCollapsedProvider);`
- Outer: `AnimatedContainer(duration: Duration(milliseconds: 200), curve: Curves.easeOut, width: collapsed ? 64 : 240, ...)`.
- `_buildNavItem`: `Row([Icon(size 18), if (!collapsed) SizedBox(width:12), if (!collapsed) Text(label)])` wrapped in a `Tooltip(message: label)` so icon-only hover still labels. When collapsed the `Tooltip` still works.
- The brand/title row in `AppHeader` is unaffected; the toggle button sits at the far-left next to the brand.

**Toggle button in AppHeader:** a `Tooltip('Collapse sidebar')` wrapping an `InkWell` rendering `Icon(collapsed ? LucideIcons.panelRight : LucideIcons.panelLeftClose, size: 16, color: textSecondary)` — placed as the first child of the header's `Row`, before `_buildBrand`. Requires `AppHeader` to read the provider → change `StatefulWidget` to `ConsumerStatefulWidget` and `State` to `ConsumerState`, add `import '../../shared/providers/sidebar_provider.dart'`.

**Test:** extend `test/shared/layouts/sidebar_test.dart`:
- At 1280px, assert `'Supervisor'` visible + `'Cron'` visible (existing).
- Add `testWidgets('collapses to icon-only at the toggle', ...)`: tap the toggle icon, assert the text labels disappear (`find.text('Supervisor')==0`) and a `Tooltip`-anchored icon remains; tap again, labels return.
- A non-visual unit test on the provider is unnecessary (Riverpod trivial); skip — the widget test covers the toggle + width.

- [ ] Add `sidebar_provider.dart`, run `flutter pub run build_runner build --delete-conflicting-outputs`.
- [ ] Rewrite `sidebar.dart`.
- [ ] Convert `AppHeader` + add toggle button.
- [ ] Keep `main.dart` `Row` untouched (sidebar self-sizes width).
- [ ] Add tests; run.
- [ ] Commit.

---

### Task 6: Integration — full narrow-window smoke test

**Why:** proves the whole stack (sidebar collapsed + tables collapsed + toolbar wrapped) at the 700px target with the real page chrome, not just isolated widgets.

**Test:** `test/widget_test.dart` (the file that renders `MyApp`) OR a new `test/narrow_window_smoke_test.dart`:
- `pumpWidget(MyApp(appVersion: '1.0.0'))` at `Size(700, 720)`, pump, advance 2 frames, assert no exception thrown. This compiles every page lazily? `MainScreen` builds `_buildPage(currentTab)` = `AppsPage` only initially — to exercise all tables, add a `group('narrow window full sweep', ...)` that navigates `navigationProvider` to each tab and pumps each; but most tables need heavy providers. Minimal viable: assert `MyApp` renders at 700px without a `FlutterError` — that already proves the AppHeader + sidebar + AppsPage (which nests `CompactAppsTable`) fit, because `runApp(ProviderScope(child: MyApp(...)))` at a 700x720 surface with the sidebar collapsed must lay out the whole thing without overflow.
- Add navigation-driven sub-asserts for the three tables that have existing narrow tests (sites, supervisor, tunnel, cron) by pumping each page under a `ProviderScope` at 700px — reuse the per-table test files from Tasks 0-1 rather than duplicating.

This task is mostly a verification harness; the real coverage lives in Tasks 1-4's table tests.

- [ ] Add `narrow_window_smoke_test.dart`; run; assert zero `FlutterError`s.
- [ ] Commit.

---

### Task 7: Final gate

- [ ] `dart run build_runner build --delete-conflicting-outputs` (regenerate all `*.g.dart`).
- [ ] `flutter analyze` → 0 issues.
- [ ] `flutter test` → all pass (existing 862 + new tests).
- [ ] Confirm no `setMinimumSize`/`minimumSize` call exists in `main.dart` or `window_service.dart` (negative check for the ruled-out constraint).

