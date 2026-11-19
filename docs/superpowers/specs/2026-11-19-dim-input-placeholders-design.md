# Dim Input Placeholders Design

Approved by the user on 2026-11-19.

## Intent

Make empty input placeholders much less prominent than entered text. The user approved white at 35% opacity for all input hints, including search fields and the editor's Find/Replace inputs.

## Goals and Constraints

- Introduce `AppColors.textPlaceholder = Color(0x59FFFFFF)` (white, approximately 35% after 8-bit alpha rounding).
- Apply it to the global `InputDecorationTheme`, `AppTextField`, and all explicit `hintStyle` overrides.
- Preserve entered text, labels, icons, disabled text, subtitles, backgrounds, borders, font sizes, and input behavior.
- Do not modify the shared `textMuted` token: it is also used outside placeholders.
- No dependencies, service changes, app launches, or host port bindings are needed. Verify with unit/widget tests and static analysis.

## Approaches

1. **Dedicated placeholder token across theme and overrides (selected):** one consistent value without changing other UI roles.
2. **Dim `textMuted` globally (rejected):** also dims icons, labels, and unrelated text.
3. **Change only the global theme (rejected):** existing explicit hint styles override it, leaving many placeholders unchanged.

## Scope

Update the color palette, theme, shared text field, Sites search, Databases search, PHP extension search, site template input, and editor Find/Replace fields. Add regression coverage using existing widget harnesses. No changes to dropdown empty-state copy or code syntax highlighting.

## Follow-up: Warning-Free Verification

The user requested fixing all reported warnings and review follow-ups on 2026-11-19.

- Add coverage for a disabled input with prefilled content and verify the actual editable text color and non-editability.
- Provide offline, test-only font fixtures for the real app theme. Keep production font loading unchanged, and await font work inside the test lifecycle rather than suppressing diagnostics.
- Remove the SDK-private Material localization imports by rendering app alerts with `material_ui`, the same library as the app. Preserve public `AppDialogs` call signatures, QuickAlert illustration assets, labels, colors, and confirmation behavior.
- Permission cancellation, Escape, barrier dismissal, or back navigation must deny permission. Repeated or late confirmations must not dismiss the page below an alert.
- Verify all tests and full-repository analyzer output. Do not hide lints or change host Fontconfig/system services to obtain clean output. Intentional negative-path application logs are not compiler or framework warnings.
