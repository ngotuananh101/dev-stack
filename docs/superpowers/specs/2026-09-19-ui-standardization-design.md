# UI Standardization & Unified Terminal Log Viewer Design

## Context & Motivation

As DevStack has grown with support for multiple runtimes, services, databases, tunnels, and recently CLI Sites, the user interface has diverged in several key areas:
1. **Log Viewers**: `SiteLogsModal` (developed for CLI Sites) introduced a clean, modern terminal aesthetic with rich controls (auto-scroll toggle, copy all, clear buffer, open file in OS, monospace error highlighting). Conversely, `LogsPage` (main logs screen), `ServiceLogsModal` (app service logs), and `TunnelLogsModal` (tunnel logs) each implemented isolated, inconsistent UI containers, lacking standard controls and having styling discrepancies.
2. **Buttons**: Inconsistent sizes (varying between 32px, 36px, 40px, and custom paddings), mismatched border radiuses (4px, 6px, 8px), and inconsistent color roles (mixing `#00D4FF` and `#58A6FF` for Primary CTAs).
3. **Action Icon Buttons**: Table actions in `SiteTable`, `CompactAppsTable`, and `DatabaseTable` each hand-crafted their own `_buildActionButton`, `_buildIconButton`, or `_buildServiceButton` with distinct paddings and hover behaviors.
4. **Input Fields**: Redundant `_buildTextField` methods implemented in almost every modal (`AddSiteModal`, `EditSiteModal`, `AddDatabaseModal`, `AddRedisKeyModal`, `CreateTunnelModal`), lacking a unified design token base in `AppTheme`.

This design establishes a coherent design token standard, extracts core reusable UI widgets (`TerminalLogView`, enhanced `AppButton`, `AppIconButton`, `AppTextField`), and rolls them out across the entire application.

---

## Design Specifications

### 1. Design Tokens & Visual Hierarchy

#### A. Border Radius Tokens (`AppRadius`)
A clean developer-tool aesthetic with sharp, restrained radii:
- `AppRadius.xs = 4.0`: Badges, compact action icon buttons in tables.
- `AppRadius.sm = 6.0`: Standard interactive controls (buttons, text inputs, dropdowns).
- `AppRadius.md = 8.0`: Cards, panels, modal dialog windows.

#### B. Color Hierarchy Alignment
- **Primary CTA Color**: `AppColors.primary` (`#58A6FF`, crisp blue with white text).
- **Secondary / Surface**: `AppColors.surfaceLight` (`#21262D`) with `AppColors.border` (`#30363D`).
- **Terminal Dark Background**: `#1E1E1E` (Dark charcoal editor canvas).
- **Terminal Header Background**: `#252526` with bottom border `1px solid #333333`.

#### C. Typography & Sizing in Inputs & Buttons
- Compact control height (`sm`): `32px` (toolbars, secondary table controls).
- Standard control height (`md`): `36px` (modal forms, default inputs, action buttons).
- Large control height (`lg`): `40px` (hero CTAs, prominent landing forms).

---

### 2. Core Shared Components (`lib/shared/widgets/`)

#### A. `TerminalLogView` (`lib/shared/widgets/terminal_log_view.dart`)
A unified, high-performance terminal log viewer component that supports both Modal dialogs and full-screen page embed:
- **Parameters**:
  - `title`: String (e.g. "Logs: mysite.test" or "nginx.log").
  - `icon`: IconData (default: `LucideIcons.terminal`).
  - `lines`: List of log strings.
  - `onClear`: Optional callback to clear buffer.
  - `onCopy`: Optional callback (defaults to built-in copy with toast).
  - `onOpenFile`: Optional callback to launch OS native log file.
  - `onClose`: Optional callback (renders close button if non-null).
  - `isModal`: bool (default: true; if false, adjusts border and background for page embedding).
  - `statusWidget`: Optional Widget (e.g. running/stopped pill or PID info).
- **Features**:
  - Auto-scroll toggle button with color indicator (active: `AppColors.success`, inactive: `AppColors.textMuted`).
  - Automatic error/warn/info syntax highlighting in monospace:
    - Error (`[ERROR]`, `Error:`, `Exception`): `#F48771`.
    - Warning (`[WARN]`, `Warning:`): `AppColors.warning` (`#D29922`).
    - Info / System (`[INFO]`, `Started`): `AppColors.primary` (`#58A6FF`).
    - Default: `#CCCCCC`.
  - Empty state message: "No logs yet..."

#### B. Enhanced `AppButton` (`lib/shared/widgets/app_button.dart`)
- **Sizes**:
  - `AppButtonSize.sm`: height 32px, text 12px, padding horizontal 10px.
  - `AppButtonSize.md` (default): height 36px, text 13px, padding horizontal 14px.
  - `AppButtonSize.lg`: height 40px, text 14px, padding horizontal 18px.
- **Styles**:
  - `AppButtonStyle.primary`: Background `AppColors.primary`, text `Colors.white`.
  - `AppButtonStyle.secondary`: Background `AppColors.surfaceLight`, border `AppColors.border`, text `AppColors.textPrimary`.
  - `AppButtonStyle.outline`: Transparent background, border `AppColors.border`, text `AppColors.textPrimary`.
  - `AppButtonStyle.ghost`: Transparent background, no border, subtle hover highlight.
  - `AppButtonStyle.danger`: Background `AppColors.error.withOpacity(0.15)`, border `AppColors.error.withOpacity(0.4)`, text `AppColors.error`.
- **Properties**: `label`, `onPressed`, `icon`, `width`, `size`, `style`, `isLoading`.

#### C. `AppIconButton` (`lib/shared/widgets/app_icon_button.dart`)
A standardized icon action button for tables, toolbars, and modal headers:
- Size: 28x28px (`sm`) or 32x32px (`md`).
- Border radius: `AppRadius.xs` (4px).
- Styling: `AppColors.surfaceLight` background with `0.5px solid AppColors.border` (or translucent tinted background for status actions).
- Built-in `Tooltip`, smooth ink splash, consistent 14px/16px icon size.

#### D. `AppTextField` (`lib/shared/widgets/app_text_field.dart`)
A unified text field eliminating boilerplates across modals:
- Preconfigured with height 36px/40px, prefix/suffix icons, helper text, error text.
- Fill color `AppColors.surface`, border radius `AppRadius.sm` (6px), border `AppColors.border`, focused border `AppColors.primary`.
- Supports validator, controller, enabled state, password toggle, debounce.

---

### 3. Application Rollout Plan

#### Scope 1: Standardize Log Viewers
- Refactor `SiteLogsModal` to wrap `TerminalLogView`.
- Refactor `ServiceLogsModal` to use `TerminalLogView`, removing reversed list ordering, adding auto-scroll, copy, and clear.
- Refactor `TunnelLogsModal` to use `TerminalLogView`.
- Update `LogsPage` to embed `TerminalLogView` in page mode, modernizing the toolbar dropdown and actions.

#### Scope 2: Standardize Buttons & Action Icons across Views
- Replace custom icon buttons in `SiteTable`, `DatabaseTable`, and `CompactAppsTable` with `AppIconButton`.
- Modernize top-level action buttons in `SitesPage`, `DatabasesPage`, `TunnelsPage` with `AppButton(style: primary, size: md)`.

#### Scope 3: Standardize Modal Forms & Inputs
- Standardize inputs in `AddSiteModal` and `EditSiteModal` with `AppTextField` and action buttons with `AppButton`.
- Standardize inputs and buttons in `AddDatabaseModal`, `AddRedisKeyModal`, and `CreateTunnelModal`.

---

### 4. Verification & Testing

1. **Unit & Widget Tests**:
   - `test/shared/widgets/terminal_log_view_test.dart`: Test auto-scroll, clear, copy, rendering, error highlighting.
   - `test/shared/widgets/app_button_test.dart`: Test sizes, styles, tap events, loading states.
   - `test/shared/widgets/app_icon_button_test.dart`: Test tooltip, icon, tap event, sizing.
   - `test/shared/widgets/app_text_field_test.dart`: Test input, validation, decoration.
2. **Existing Test Suite Verification**:
   - Update and maintain existing modal tests (`site_logs_modal_test.dart`, `add_site_modal_cli_test.dart`, `edit_site_modal_cli_test.dart`, `site_table_cli_test.dart`).
   - Run full regression test: `flutter test` (all 588+ tests must pass).
3. **Static Analysis**:
   - `flutter analyze` with 0 issues.
4. **Desktop Compilation**:
   - `flutter build linux --debug` passes cleanly.
