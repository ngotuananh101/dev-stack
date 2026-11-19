# Dim Input Placeholders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all input placeholders the approved white 35% color without dimming entered text or unrelated UI.

**Architecture:** Add a dedicated `AppColors.textPlaceholder` constant. Use it in the global input theme and all existing explicit hint styles; leave other style properties and tokens unchanged.

**Tech Stack:** Flutter/Dart, material_ui, flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-19-dim-input-placeholders-design.md`

## Global Constraints

- `AppColors.textPlaceholder = Color(0x59FFFFFF)` (white, approximately 35% after 8-bit alpha rounding).
- Preserve entered text, labels, icons, disabled text, subtitles, backgrounds, borders, font sizes, and input behavior.
- Do not modify the shared `textMuted` token.
- No dependencies, service changes, app launches, or host port bindings; use unit/widget tests and static analysis.
- Do not commit or push without a new explicit user request.

## Review Focus

- Default-theme inputs: rendered hints inherit the placeholder color when no override exists.
- Shared input states: focused/empty hints are dim; entered and disabled text retain existing colors.
- Search overrides: Sites, Databases (including Redis), and PHP extension search use the new color, while icons stay unchanged.
- Site template input: hint is dim without changing entered template text.
- Editor search: both Find and Replace hints are dim; editor content and search input text remain unchanged.

---

### Task 1: Apply and test the dedicated placeholder color

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/shared/widgets/app_text_field.dart`
- Modify: `lib/features/sites/presentation/sites_page.dart`
- Modify: `lib/features/databases/presentation/databases_page.dart`
- Modify: `lib/features/apps/presentation/widgets/app_settings_modal.dart`
- Modify: `lib/features/settings/presentation/settings_page.dart`
- Modify: `lib/shared/widgets/code_editor/config_code_editor.dart`
- Test: `test/core/theme/app_theme_tokens_test.dart`
- Test: `test/shared/widgets/app_text_field_test.dart`
- Test: `test/features/sites/presentation/sites_page_toolbar_test.dart`
- Test: `test/features/databases/presentation/databases_page_actions_test.dart`
- Test: `test/features/apps/presentation/widgets/app_settings_modal_extensions_test.dart`
- Test: `test/features/settings/presentation/settings_page_input_test.dart`
- Test: `test/shared/widgets/code_editor/config_code_editor_test.dart`

**Interfaces:**
- Consumes: existing `AppTheme.darkTheme`, `AppTextField`, and feature widget test harnesses.
- Produces: `static const Color AppColors.textPlaceholder`, used exclusively for placeholder text.

- [x] **Step 1: Write failing regression tests**

Assert existing theme and input hint styles equal `const Color(0x59FFFFFF)` before introducing the token. Add a rendered default-theme `TextField` test and shared-field empty/focused/entered/disabled checks. In existing feature harnesses, inspect the real search/template `TextField` decorations and assert the same exact color. Open the editor's Find and Replace UI and assert both hint colors. Preserve assertions for input text (`AppColors.textPrimary`), icons (`AppColors.textMuted`), disabled text (`AppColors.textMuted`), and hint size (12px). Tests must exercise widget behavior, not source-code matching.

- [x] **Step 2: Verify RED**

Run the seven test files above together with `flutter test`. Confirm the new hint-color assertions fail because the actual color is opaque white, not due to harness errors.

- [x] **Step 3: Implement the token and hint changes**

Add `static const Color textPlaceholder = Color(0x59FFFFFF);` beside the text tokens in `app_colors.dart`. Replace only the `AppColors.textMuted` color inside all eight existing `hintStyle` blocks with `AppColors.textPlaceholder`. Do not change any other uses of `textMuted`.

- [x] **Step 4: Verify GREEN and the full suite**

Run the seven targeted test files, `flutter test`, and `flutter analyze`. Expected: all active tests pass and analysis reports no issues. Record skips or failures faithfully. Run `dart format` only on changed Dart files, then `git diff --check`.

- [x] **Step 5: Review and report**

Review the complete diff for accidental non-placeholder color changes and remaining explicit hint overrides. Have one fresh reviewer inspect the completed change. Report verification and changed scope. Leave changes uncommitted until the user asks to commit/push.

### Follow-up: Resolve Reported Warnings and Review Minors

Authorized by the user on 2026-11-19 after review.

- [x] Add disabled/prefilled input coverage with actual `EditableText` assertions.
- [x] Reproduce dialog failures without the legacy Flutter localization bridge.
- [x] Build app alerts with `material_ui`, preserve public API/illustrations/button semantics, and remove private localization imports from app and tests.
- [x] Cover Enter/Escape, explicit confirmation, permission denial, and repeated confirmation route safety; targeted 32 tests pass.
- [x] Verify `flutter analyze` reports no issues without suppression.
- [x] Provide and verify offline test font fixtures with awaited font work.
- [x] Run complete test suite, analyzer, and whitespace checks after font patch.
- [x] Complete targeted independent review and report exact outcomes; do not commit/push automatically.

Follow-up verification outcome: complete suite `1229 passed, 3 skipped` (all three skips are pre-existing platform guards: Isar native library, non-Linux PostgreSQL installers, and openssl availability); full `flutter analyze` reports `No issues found`; `git diff --check` clean; zero font-download, no-invoker, Fontconfig, or framework-exception diagnostics in the suite log. The targeted dialog reviewer found no Critical/Important/Minor defects and confirmed the change is ready within its scope; `main.dart` was outside that reviewer's scope but is covered by the clean full-repository analysis.
