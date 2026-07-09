# Cross-Shell Bin Shims Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make commands linked into `C:\Ponta\bin` run from PowerShell, cmd, Git Bash, MSYS2, Cygwin, and WSL-style bash shells.

**Architecture:** Replace single `.bat` shims with `.bat`, `.cmd`, and extensionless POSIX shell wrappers. Do not create active `.ps1` shims because PowerShell can prefer `.ps1` over `.cmd` and block execution under default execution policy. Removal still deletes legacy `.ps1` shims from prior builds.

**Tech Stack:** Flutter/Dart, Windows batch wrappers, POSIX shell wrappers.

## Global Constraints

- Target shells: PowerShell, cmd, Git Bash, MSYS2, Cygwin, and WSL-style bash shells.
- Active generated shim files: `<command>.bat`, `<command>.cmd`, and extensionless `<command>`.
- Do not generate active `<command>.ps1` files.
- Remove legacy `<command>.ps1` files during shim recreation/removal.
- Preserve stdout, stderr, arguments, and exit code.
- MySQL remains passwordless and keeps `--initialize-insecure`.
- Do not commit unless the user explicitly asks.

---

## File Structure

- Modify: `lib/core/services/path_service.dart`
  - PATH management, shim helper content, shim creation, symmetric deletion, npm global cleanup.
- Modify: `lib/features/apps/data/app_installer_service.dart`
  - Composer cross-shell wrappers and Composer uninstall cleanup.
- Modify: `lib/features/settings/data/settings_provider.dart`
  - Base directory migration rewrites `.bat`, `.cmd`, extensionless shims, and legacy `.ps1` files.
- Test: `test/core/services/path_service_shim_test.dart`
  - Unit coverage for shim path list and wrapper content.

---

### Task 1: Add shim helpers and tests

**Files:**
- Modify: `lib/core/services/path_service.dart`
- Create: `test/core/services/path_service_shim_test.dart`

**Deliverables:**
- `PathService.shimPathsFor(String binDir, String commandName)` returns `.bat`, `.cmd`, and extensionless paths.
- `PathService.windowsBatchShimContent(String targetPath)` writes batch content forwarding `%*` and `exit /b %ERRORLEVEL%`.
- `PathService.shellShimContent(String targetPath)` writes LF shebang wrapper, forwards `"$@"`, converts Windows paths for WSL, and routes `.cmd`/`.bat` targets through `cmd.exe /c` under WSL.

**Verification:**
```bash
flutter test --no-pub test/core/services/path_service_shim_test.dart
```

---

### Task 2: Create active shim set

**Files:**
- Modify: `lib/core/services/path_service.dart`

**Deliverables:**
- `_createShimSet(String commandName, String targetPath)` writes:
  - `<command>.bat`
  - `<command>.cmd`
  - extensionless `<command>`
- `_createShimSet` deletes legacy `<command>.ps1` before writing active shims.
- `addAppToPath()` creates shim sets for app id, CLI name, `npm`, `npx`, and `corepack`.

**Verification:**
```bash
flutter test --no-pub test/core/services/path_service_shim_test.dart
flutter analyze --no-pub
```

---

### Task 3: Delete shim sets symmetrically

**Files:**
- Modify: `lib/core/services/path_service.dart`
- Modify: `lib/features/apps/data/app_installer_service.dart`

**Deliverables:**
- `_deleteShimSet(String commandName)` deletes `.bat`, `.cmd`, extensionless, and legacy `.ps1` files.
- `removeAppFromPath()` deletes shim sets for app id and CLI name.
- Node cleanup deletes shim sets for `npm`, `npx`, `corepack`, keeps `node.exe` handling, and cleans only npm-global wrappers whose content references `node_modules`.
- Composer install creates `.bat`, `.cmd`, and extensionless wrappers; uninstall removes those plus legacy `composer.ps1`.

**Verification:**
```bash
flutter test --no-pub test/core/services/path_service_shim_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

---

### Task 4: Cross-shell verification

**Manual verification when `C:\Ponta\bin` exists:**
```bash
powershell -NoProfile -Command "node --version; exit $LASTEXITCODE"
cmd /c "node --version"
bash -lc "node --version"
```

If Node is unavailable, use another installed CLI command such as PHP.

**Automated fallback verification:**
```bash
flutter test --no-pub test/core/services/path_service_shim_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

---

## Self-Review

- Spec coverage: active `.bat`, `.cmd`, extensionless creation; legacy `.ps1` cleanup; Node and Composer handling; migration coverage; verification.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: helper names match implementation.
