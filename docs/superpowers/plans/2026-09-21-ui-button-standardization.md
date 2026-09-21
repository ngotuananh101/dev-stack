# UI Button Standardization (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuẩn hoá toàn bộ 78 button thô còn lại (ElevatedButton/FilledButton/OutlinedButton/TextButton với styleFrom cục bộ) sang `AppButton`/`AppIconButton` và bổ sung `textButtonTheme` + `filledButtonTheme` còn thiếu vào `AppTheme`, nhằm đồng nhất kích thước, bo góc (`AppRadius.sm = 6px`) và màu sắc trên toàn ứng dụng.

**Architecture:** Mở rộng `AppButton` thêm 2 param tuỳ chỉnh (`backgroundColor`, `textColor`) để giữ nguyên ý đồ thiết kế của các button dùng màu đặc thù (ví dụ Install màu `AppColors.success`). Sau đó chuyển từng file từng nhóm: footer modal (Cancel=C ghost/outline, Submit=C primary), CTA (C primary + icon), action icon (AppIconButton), và button dùng màu động (AppButton với backgroundColor tuỳ chỉnh). Cuối cùng bổ sung theme config còn thiếu để mọi button không được chuyển (nếu còn) vẫn fallback chuẩn.

**Tech Stack:** Flutter / Dart, Material 3, shared widgets `AppButton`/`AppIconButton` (đã có), design tokens `AppColors`/`AppRadius`/`AppTextSize`.

**Spec:** `docs/superpowers/plans/2026-09-19-ui-standardization.md` (đợt 1 — làm nền tảng component). Đợt 2 này mở rộng phạm vi cover nốt các file đợt 1 chưa chạm tới.

## Global Constraints

- Border radius chuẩn cho button = `AppRadius.sm` (6.0px); icon button = `AppRadius.xs` (4.0px). KHÔNG dùng borderRadius > 8px cho button.
- Chiều cao chuẩn: `AppButtonSize.sm=32`, `md=36`, `lg=40`; `AppIconButtonSize.sm=28`, `md=32`.
- Primary CTA dùng `AppColors.primary` (#58A6FF) chữ trắng. Cancel/secondary dùng `ghost`/`outline`/`secondary`. Danger dùng `AppButtonStyle.danger`.
- Giữ nguyên mọi `onPressed`, `validator`, loading state, tooltip, semantics label. KHÔNG thay đổi hành vi/logic.
- Màu đặc thù (success/error động) phải được bảo toàn qua param `backgroundColor`/`textColor` mới, không ép về primary.
- Mỗi task kết thúc bằng `flutter analyze` 0 issues và test liên quan pass.

---

## Task 1: Mở rộng AppButton hỗ trợ màu tuỳ chỉnh + bổ sung theme config

**Files:**
- Modify: `lib/shared/widgets/app_button.dart` (thêm `backgroundColor`, `textColor` optional, ưu tiên cao nhất)
- Modify: `lib/core/theme/app_theme.dart` (thêm `textButtonTheme`, `filledButtonTheme`)

**Interfaces:**
- Consumes: `AppColors`, `AppRadius`, `AppTextSize` (đã có)
- Produces: `AppButton(backgroundColor: ..., textColor: ...)` — API mới cho các button dùng màu động (settings action.color, Install success)

- [ ] **Step 1: Thêm param tuỳ chỉnh vào AppButton**
  - Thêm `final Color? backgroundColor;` và `final Color? textColor;` vào constructor (default null).
  - Sửa `_getBackgroundColor`: nếu `backgroundColor != null` trả về nó (khi enabled), khi disabled trả về `backgroundColor.withValues(alpha:0.5)`.
  - Sửa `_getTextColor`: nếu `textColor != null` trả về nó (enabled), disabled trả về `AppColors.textMuted`.
- [ ] **Step 2: Bổ sung textButtonTheme + filledButtonTheme vào AppTheme**
  - Thêm `textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))))`.
  - Thêm `filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))))`.
- [ ] **Step 3: Analyze & test**
  - `flutter analyze lib/shared/widgets/app_button.dart lib/core/theme/app_theme.dart` → 0 issues.
  - `flutter test test/shared/widgets/app_button_test.dart` → pass.
- [ ] **Step 4: Commit**
  ```
  git add lib/shared/widgets/app_button.dart lib/core/theme/app_theme.dart
  git commit -m "feat(ui): extend AppButton with custom colors and add missing button themes"
  ```

## Task 2: Chuẩn hoá Sites (sites_page, add_site_modal, edit_site_modal, batch_progress_dialog, site_tunnel_dialog)

**Files:**
- Modify: `lib/features/sites/presentation/sites_page.dart` (4 button: Add Site CTA + batch button)
- Modify: `lib/features/sites/presentation/widgets/add_site_modal.dart` (2: footer)
- Modify: `lib/features/sites/presentation/widgets/edit_site_modal.dart` (8: footer, directory picker, service buttons)
- Modify: `lib/features/sites/presentation/widgets/batch_progress_dialog.dart` (1: TextButton close)
- Modify: `lib/features/sites/presentation/widgets/site_tunnel_dialog.dart` (4: FilledButton quick tunnel)

**Interfaces:**
- Consumes: `AppButton`, `AppIconButton` (Task 1 không đổi API cũ), `AppButtonStyle`/`AppButtonSize`
- Produces: sites UI đồng nhất

- [ ] **Step 1: sites_page.dart** — Chuyển "Add Site" CTA sang `AppButton(style: primary, icon, size: md)`. Batch-create button (raw ElevatedButton radius 8) → `AppButton(style: primary/outline, size: md)`.
- [ ] **Step 2: add_site_modal.dart** — Footer: Cancel → `AppButton(ghost)`, Create → `AppButton(primary, isLoading: _isSaving, icon: save)`.
- [ ] **Step 3: edit_site_modal.dart** — Directory picker (SizedBox h48 ElevatedButton) → `AppButton(style: secondary, icon: folderOpen, size: md)`. Footer 4 button → ghost/outline/primary tương ứng, giữ label & validator.
- [ ] **Step 4: batch_progress_dialog.dart** — TextButton close → `AppButton(ghost)` hoặc `AppIconButton` nếu icon-only.
- [ ] **Step 5: site_tunnel_dialog.dart** — FilledButton quick tunnel (2 nút) → `AppButton(primary, icon, size: md)` hoặc `AppButton(secondary)` theo ngữ cảnh.
- [ ] **Step 6: Analyze & test**
  - `flutter analyze lib/features/sites/...` → 0 issues.
  - `flutter test test/features/sites/` → pass (đặc biệt tunnel dialog test — LƯU Ý: 2 test này pre-existing fail, không liên quan).
- [ ] **Step 7: Commit**
  ```
  git add lib/features/sites/
  git commit -m "refactor(ui): standardize Sites buttons with AppButton"
  ```

## Task 3: Chuẩn hoá Apps (app_settings_modal, app_version_modal, compact_apps_table, compact_pagination, featured_banner)

**Files:**
- Modify: `lib/features/apps/presentation/widgets/app_settings_modal.dart` (4: OutlinedButton)
- Modify: `lib/features/apps/presentation/widgets/app_version_modal.dart` (8: TextButton/OutlinedButton/ElevatedButton, có nút Install màu success)
- Modify: `lib/features/apps/presentation/widgets/compact_apps_table.dart` (1: OutlinedButton)
- Modify: `lib/features/apps/presentation/widgets/compact_pagination.dart` (2: TextButton)
- Modify: `lib/features/apps/presentation/widgets/featured_banner.dart` (1: ElevatedButton FEATURED DEPLOYMENT)

**Interfaces:**
- Consumes: `AppButton` (có cả param màu tuỳ chỉnh từ Task 1)
- Produces: apps UI đồng nhất

- [ ] **Step 1: app_version_modal.dart** — Retry TextButton → `AppButton(ghost, icon: refresh)`. Footer: Close → `AppButton(ghost/outline)`, Install/Update → `AppButton(primary, backgroundColor: AppColors.success, textColor: white, icon: download)` giữ logic disabled. In-progress button → `AppButton(secondary)` disabled.
- [ ] **Step 2: app_settings_modal.dart** — 2 OutlinedButton → `AppButton(outline)` / `AppButton(ghost)` tương ứng.
- [ ] **Step 3: compact_apps_table.dart** — OutlinedButton (1) → `AppButton(outline, size: sm)` hoặc `AppIconButton`.
- [ ] **Step 4: compact_pagination.dart** — 2 TextButton (prev/next) → `AppIconButton` (icon arrow) hoặc `AppButton(ghost, size: sm)`.
- [ ] **Step 5: featured_banner.dart** — ElevatedButton FEATURED DEPLOYMENT → `AppButton(primary, size: lg)` giữ padding ngữ cảnh banner.
- [ ] **Step 6: Analyze & test**
  - `flutter analyze lib/features/apps/` → 0 issues.
  - `flutter test test/features/apps/` → pass.
- [ ] **Step 7: Commit**
  ```
  git add lib/features/apps/
  git commit -m "refactor(ui): standardize Apps buttons with AppButton"
  ```

## Task 4: Chuẩn hoá Databases + Tunnels + Settings + Shared

**Files:**
- Modify: `lib/features/databases/presentation/databases_page.dart` (6: _buildActionButton helper + Add DB CTA)
- Modify: `lib/features/databases/presentation/widgets/add_redis_key_modal.dart` (4: footer)
- Modify: `lib/features/tunnels/presentation/tunnels_page.dart` (4: FilledButton)
- Modify: `lib/features/settings/presentation/settings_page.dart` (10: action ElevatedButton động + dialog buttons)
- Modify: `lib/features/settings/presentation/widgets/system_info_modal.dart` (4: footer)
- Modify: `lib/shared/widgets/code_editor/config_code_editor.dart` (10: TextButton/OutlinedButton/ElevatedButton)

**Interfaces:**
- Consumes: `AppButton` (màu tuỳ chỉnh cho settings `action.color`), `AppIconButton`
- Produces: databases/tunnels/settings/shared đồng nhất

- [ ] **Step 1: databases_page.dart** — Chuyển `_buildActionButton` helper dùng AppButton (cho phpMyAdmin + các action). Add DB CTA đã chuẩn hoá đợt 1, kiểm tra lại.
- [ ] **Step 2: add_redis_key_modal.dart` — Footer Cancel → `AppButton(ghost)`, Add → `AppButton(primary, isLoading)`.
- [ ] **Step 3: tunnels_page.dart` — 2 FilledButton (new tunnel, connect) → `AppButton(primary, icon, size: md)`.
- [ ] **Step 4: settings_page.dart` — Action button (dùng `action.color` động) → `AppButton(backgroundColor: action.color, textColor: white, size: sm)`. Các dialog confirm buttons → `AppButton` (danger cho uninstall).
- [ ] **Step 5: system_info_modal.dart` — Footer OutlinedButton + ElevatedButton → ghost/primary.
- [ ] **Step 6: config_code_editor.dart` — 3 nhóm button (copy/clear TextButton, line numbers OutlinedButton, save ElevatedButton) → `AppButton`/`AppIconButton` tương ứng, giữ icon.
- [ ] **Step 7: Analyze & test**
  - `flutter analyze lib/features/databases/ lib/features/tunnels/ lib/features/settings/ lib/shared/widgets/code_editor/` → 0 issues.
  - `flutter test test/features/databases/ test/features/tunnels/ test/features/settings/ test/shared/` → pass.
- [ ] **Step 8: Commit**
  ```
  git add lib/features/databases/ lib/features/tunnels/ lib/features/settings/ lib/shared/widgets/code_editor/
  git commit -m "refactor(ui): standardize Databases, Tunnels, Settings, and CodeEditor buttons"
  ```

## Task 5: Full verification & cleanup

**Files:**
- Verify: toàn bộ `lib/`
- Verify: `git grep` không còn raw button styleFrom nào ngoài theme config

**Interfaces:**
- Consumes: mọi thay đổi Task 1-4
- Produces: xác nhận 100% chuẩn hoá

- [ ] **Step 1: Full analyze**
  - `flutter analyze` → 0 issues.
- [ ] **Step 2: Đếm remaining raw buttons**
  - `grep -rn "ElevatedButton\|FilledButton\|OutlinedButton\|TextButton" lib/ --include="*.dart" | grep -v "_test.dart" | grep -v "Theme"` → chỉ còn trong `app_theme.dart` (theme config).
- [ ] **Step 3: Full test suite**
  - `flutter test` → 595+ pass, chỉ 2 pre-existing fail (site_tunnel_dialog, không liên quan).
- [ ] **Step 4: Linux build**
  - `PKG_CONFIG_PATH="..." flutter build linux --debug` → success.
- [ ] **Step 5: Commit (nếu có cleanup nhỏ) hoặc báo cáo kết quả**
