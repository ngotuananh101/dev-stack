# Plan: Replace Notepad++ with an in-app code editor (lazy rendering, large-file safe)

## Goal
Remove Notepad++ entirely (the bundled 8.1 MB `npp.zip`, `NotepadService`, the
runtime extraction at startup) and replace every "Open in Notepad++" surface
with an in-app code editor that:
- syntax-highlights by file type,
- renders lazily so multi-MB files don't freeze the UI (your decision),
- persists via the existing data-layer providers (no new write paths),
- routes hosts saves through the existing elevated `HostsRepository.saveHostsRaw`
  (UAC handled).

`flutter_code_editor: ^0.3.5` + `flutter_highlight` + `highlight` are already
in `pubspec.yaml` but unused — we adopt them here. No new package is strictly
required for the editor itself; the large-file strategy is the question (see
§3).

## Current state (verified)
- `lib/core/services/notepad_service.dart` — `ensureExtracted()`,
  `notepadPath`, `openFile(path)`. Bundled asset `assets/bin/npp.zip` (8.1 MB),
  declared via `assets/bin/` folder entry in `pubspec.yaml:98`.
- 4 `NotepadService.openFile` call sites:
  1. `lib/features/apps/presentation/widgets/app_settings_modal.dart:258` —
     app config file (`_getConfigFilePath()`). Header "Edit Config" button
     (line 371) + big "Open in Notepad++" button in config tab (line 784).
  2. `lib/features/hosts/presentation/hosts_page.dart:21` — hosts.
  3. `lib/features/settings/presentation/settings_page.dart:1109` — hosts.
  4. `lib/features/sites/presentation/sites_page.dart:130` — hosts.
- `lib/main.dart:36` — `await NotepadService.ensureExtracted();` at startup.
- App-config tab in `app_settings_modal.dart` (`_buildConfigTab` 697-807) has
  NO inline editor — only a path display + NPP button. `_loadConfig()` is a
  no-op stub.
- Per-app config writers already exist as inline editors (plain `TextField`)
  in `edit_site_modal.dart` `_ConfigTab`/`_SslTab` (vhost/SSL) and via
  `*_settings_provider.saveConfig` (webserver/mongodb/redis/meilisearch/
  elasticsearch/rustfs). These already validate domain (N19) and write via
  the data layer.
- `HostsRepository.saveHostsRaw` already does direct-write → elevated
  `runElevatedPowerShell(Copy-Item ...)` fallback (UAC). `HostsNotifier` has
  `save()` + `updateText()` + `isAdmin()`.
- NO size guard exists anywhere.
- Config file types & paths resolved by `_getConfigFilePath()` (lines 167-227):
  php.ini, config.inc.php (pma), my.ini, postgresql.conf, nginx.conf,
  httpd.conf, redis.windows.conf, mongod.cfg, rustfs/config.json, config.toml,
  elasticsearch.yml.

## Design decisions (confirmed with user)
1. **Large files**: always load fully, use an editor with lazy/virtualized
   rendering so multi-MB files don't freeze. (No read-only cutoff, no NPP
   fallback.)
2. **Hosts**: inline editor + Save button. Saves route through the existing
   elevated `HostsRepository.saveHostsRaw` (UAC dialog shown when not admin).

## Architecture

### New shared widget: `lib/shared/widgets/code_editor/config_code_editor.dart`
A reusable `ConfigCodeEditor` Consumer widget:
```
ConfigCodeEditor({
  required File file,                 // or path + read/write callbacks
  required Language language,         // flutter_code_editor Language.*
  String? readOnlyReason,            // null => editable
  Future<bool> Function(String content) onSave,  // routes to provider
  String saveLabel,
})
```
Behavior:
- Reads file content on `initState` (async, with loading indicator).
- `CodeController(text: ..., language: language)` + `CodeField` (lazy line
  rendering — `flutter_code_editor` only builds visible lines + gutter).
- Toolbar: file path (monospace), Reload, Save (calls `onSave`), dirty-state
  indicator (unsaved changes → confirm before tab close/reload).
- Ctrl+S bound to Save.
- Size guard: if `file.lengthSync() > kLargeFileBytes` (e.g. 2 MB), still
  load (per decision 1) but show a non-blocking banner "Large file (N MB) —
  editor may be slow". This is UX feedback, NOT a hard cutoff.
- Encoding: detect BOM; for hosts use `systemEncoding` (non-ASCII hostnames);
  for others UTF-8. Reuse `HostsRepository.readHostsRaw` decode logic.

### New shared helper: `lib/shared/widgets/code_editor/language_for.dart`
```
Language languageForConfigPath(String path)  // .ini/.cfg → text or ini,
                                            // .conf → nginx/apache heuristic,
                                            // .php → php, .json → json,
                                            // .toml → toml, .yml/.yaml → yaml,
                                            // hosts → bash (closest) or text
```
`flutter_code_editor` ships: text, php, json, yaml, bash, nginx is NOT a
built-in mode — fall back to `text` for .conf if no nginx mode. (Confirm at
implementation time; `text` with no highlight is acceptable fallback.)

### Large-file lazy rendering (the user's explicit requirement)
`flutter_code_editor`'s `CodeField` is already lazy: it renders only the
visible viewport of lines via a `ScrollablePositionedList`-style approach,
NOT a `ListView` of all lines. So a 5 MB file (≈50k lines) loads the string
into memory (cheap — a few MB) but only paints the visible ~40 lines.
- Memory: `String` of N MB is fine up to low tens of MB.
- Paint: viewport-only → no jank regardless of file size.
- Caveat: `CodeController` parses/highlights on `fullText` setter — for very
  large files highlight parsing can be the bottleneck, not rendering. Mitigation:
  for files > `kLargeFileBytes`, set language to `Language.text` (skip
  highlight parsing) but keep lazy rendering. Best of both: never freezes,
  still scrolls instantly. This is the concrete realization of "lazy
  rendering for large files" without a virtualized-editor package.

## Implementation tasks (sequential, TDD where logic is pure)

### Phase 1 — Shared editor component
1. **RED**: `test/shared/widgets/config_code_editor_test.dart`
   - `languageForConfigPath` mapping (pure function — fully testable):
     `php.ini`→ini/text, `nginx.conf`→nginx-or-text, `httpd.conf`→...,
     `config.json`→json, `config.toml`→toml, `elasticsearch.yml`→yaml,
     `redis.windows.conf`→text, hosts→text/bash.
   - `pickLanguageForLargeFile(Language, int bytes)` pure helper:
     returns `Language.text` when `bytes > kLargeFileBytes`, else the given
     language. (This is the lazy-rendering-for-large-files decision encoded
     as a testable rule.)
2. **GREEN**: implement `language_for.dart` + `languageForConfigPath` +
   `pickLanguageForLargeFile`. Run tests green.
3. Build `ConfigCodeEditor` widget (no test — presentational; exercised via
   widget_test smoke if cheap).
4. `dart format` + `flutter analyze`.

### Phase 2 — App config tab (replace NPP call site #1)
5. Refactor `app_settings_modal.dart`:
   - `_loadConfig()` actually reads the file content (via the resolved
     `_getConfigFilePath()`) into a controller, with size-aware language pick.
   - Replace the "Open in Notepad++" button + path-only display with
     `ConfigCodeEditor` (file = resolved path, language =
     `languageForConfigPath`, `onSave` writes the file directly — these are
     arbitrary user-edited app configs, write verbatim with the existing
     `saveConfig` pattern; no domain to validate).
   - Remove `_openInNotepadPlusPlus()` and the header "Edit Config" button
     (or repoint it to scroll to the editor).
6. Verify analyze + existing tests.

### Phase 3 — Hosts editor (replace NPP call sites #2,#3,#4)
7. `hosts_page.dart`: replace the NPP launch pad with `ConfigCodeEditor`
   bound to `HostsNotifier` (read via `readHostsRaw`, `onSave` =
   `HostsNotifier.save()` which already elevates). Keep Ctrl+S. Show admin
   hint via `isAdmin()`; on save failure surface "Relaunch as Admin / UAC
   was declined".
8. `settings_page.dart`: `_editHostsFile` → open the hosts editor (reuse the
   same hosts page or a shared dialog) instead of NPP.
9. `sites_page.dart`: "Edit Hosts" toolbar button → open hosts editor dialog
   instead of NPP.
10. Extract a shared `HostsEditorDialog`/route so all 3 entry points share
    one implementation.

### Phase 4 — Remove Notepad++
11. Delete `lib/core/services/notepad_service.dart`.
12. Remove `ensureExtracted()` call from `lib/main.dart:36` + import.
13. Delete `assets/bin/npp.zip` (8.1 MB) — keeps `mkcert.exe`.
14. Leave `pubspec.yaml` `assets/bin/` entry (mkcert still needed). Confirm
    no orphaned `npp` references remain: `grep -ri "notepad\|npp" lib/
    test/ pubspec.yaml` returns nothing user-facing (only comments if any).
15. Run full `flutter analyze` + `flutter test`. All green.

### Phase 5 — Verification
16. Manual smoke (user): open app config tab → edit → save → reopen;
    hosts edit → save (test both admin and non-admin elevation paths);
    large file (e.g. paste a 5 MB hosts) → scrolls without freeze.
17. Optional: add a widget smoke test that `ConfigCodeEditor` mounts and
    renders given a temp file.

## Large-file handling — concrete (answers "kế hoạch xử lý file lớn")
- Threshold constant: `kLargeFileBytes = 2 * 1024 * 1024` (2 MB).
- Under threshold: full syntax highlight + lazy paint.
- Over threshold: `Language.text` (skip highlight parse) + lazy paint →
  never freezes, instant scroll. A banner informs the user.
- File read is async with a spinner; the `String` in memory is fine for
  tens of MB.
- No package beyond what's in pubspec is required. IF during implementation
  the `flutter_code_editor` viewport proves not lazy enough for >10 MB files,
  the fallback is `code_text_field` or a custom virtualized `ListView` of
  lines — but try `flutter_code_editor` first (it's already a dependency).

## Packages
- **No new package needed** for the core plan — `flutter_code_editor`,
  `flutter_highlight`, `highlight` are already declared (currently dead
  weight). You said you can install packages if needed; the only candidate
  would be a virtualized editor if `flutter_code_editor` can't handle
  >10 MB files acceptably. Defer that decision until after Phase 1 proves
  the editor out.

## Risk / scope notes
- `flutter_code_editor` 0.3.5 API surface: confirm `CodeField`/`CodeController`
  signatures at implementation time (0.x version).
- Hosts encoding (systemEncoding) must round-trip — reuse
  `HostsRepository.readHostsRaw` decode and `saveHostsRaw` encode; do NOT
  re-implement in the editor.
- Don't touch the already-working inline editors in `edit_site_modal.dart`
  and the per-app `*_settings_provider.saveConfig` — only the NPP call sites
  change.
- No commit/push unless asked; leave working tree dirty.
