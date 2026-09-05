# Linux Package Manager Isolation Master Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Apache, PostgreSQL, Redis, and PHP-FPM on Linux to use system package manager installation while running in user-space foreground mode with isolated configurations and data inside `~/.ponta`.

**Architecture:** 
1. Update `assets/data/apps-linux.json` and `update.js` to define package manager commands for `apache`, `postgresql`, `redis`, and disable default systemd daemons.
2. Refactor `AppInstallerService` to use a generalized binary locator (`_findInstalledBinary`), generate isolated configs (`php-fpm.conf`, `redis.conf`, `httpd.conf`), and initialize isolated database clusters.
3. Update `AppServiceManager` to run Apache, PostgreSQL, Redis, and PHP-FPM directly as foreground user processes with stdout/stderr log streaming and standard POSIX signal teardown.

**Tech Stack:** Dart 3.10+, Flutter Desktop, Riverpod, POSIX Process signals (`SIGTERM`, `SIGKILL`), APT / DNF.

**Spec:** `docs/superpowers/specs/2026-09-05-linux-package-manager-services-design.md`

## Global Constraints

- 100% backward compatibility on Windows (all existing Windows tests must continue to pass).
- No hardcoded paths; use `AppConfig.dataDir`, `AppConfig.vhostsDir`, `AppConfig.logsDir`, and `p.join`.
- All shell commands in catalog must pass `PackageCommandValidator.validateAll`.
- All services on Linux must run in user space without requiring systemctl for runtime lifecycle.

---

### Task 1: Update Linux App Catalog (`assets/data/apps-linux.json` & `update.js`)

**Files:**
- Modify: `assets/data/apps-linux.json`
- Modify: `assets/data/update.js`
- Test: `test/features/apps/data/package_command_validator_test.dart`

**Interfaces:**
- Consumes: Catalog definitions for `apache`, `postgresql`, `redis`, `php82`, `php83`, `php84`, `php85`.
- Produces: Validated JSON catalog entries with `install_method: "package_manager"` and `package_manager_commands`.

- [ ] **Step 1: Write test verifying that all Linux package manager commands pass security validation**

Add a test in `test/features/apps/data/package_command_validator_test.dart` checking that every command in `apps-linux.json` passes `PackageCommandValidator.validateAll`.

- [ ] **Step 2: Run test to verify current state**

Run: `dart test test/features/apps/data/package_command_validator_test.dart`
Expected: PASS for existing PHP commands.

- [ ] **Step 3: Update `assets/data/apps-linux.json` and `update.js`**

Add `apache` and convert `postgresql`, `redis`, and `php8x` in `apps-linux.json` and `update.js` with `package_manager_commands` including `systemctl disable --now <service>`.

- [ ] **Step 4: Run test to verify all catalog commands are valid**

Run: `dart test test/features/apps/data/package_command_validator_test.dart`
Expected: PASS

- [ ] **Step 5: Commit catalog changes**

```bash
git add assets/data/apps-linux.json assets/data/update.js test/features/apps/data/package_command_validator_test.dart
git commit -m "feat(catalog): convert apache, postgresql, redis, and php to package manager on linux"
```

---

### Task 2: Refactor `AppInstallerService` for Generalized Binary Detection & Isolated Configs

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Test: `test/features/apps/data/app_installer_service_test.dart`

**Interfaces:**
- Consumes: `AppModel`, `AppConfig`
- Produces: `_findInstalledBinary(String name, {List<String>? candidates})`, `_configureIsolatedPhpFpm(AppModel app, String port)`, `_configureIsolatedRedis(AppModel app)`

- [ ] **Step 1: Write unit tests for `_findInstalledBinary` and config generators**

Test multi-path search for `postgres`, `apache2`, `httpd`, `redis-server`, `php-fpm` and verify content of generated `php-fpm.conf` and `redis.conf`.

- [ ] **Step 2: Run test to verify failure**

Run: `dart test test/features/apps/data/app_installer_service_test.dart`
Expected: FAIL (methods not yet implemented).

- [ ] **Step 3: Implement `_findInstalledBinary` and post-install isolation hooks in `AppInstallerService`**

Implement general binary discovery, generating isolated configs in `~/.ponta/data` and `~/.ponta/vhosts`.

- [ ] **Step 4: Run tests to verify pass**

Run: `dart test test/features/apps/data/app_installer_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit installer service changes**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/data/app_installer_service_test.dart
git commit -m "feat(installer): add binary detection and config isolation for linux package manager apps"
```

---

### Task 3: Refactor `AppServiceManager` to Execute Services in Foreground Mode

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart`
- Test: `test/features/apps/data/app_service_manager_test.dart`

**Interfaces:**
- Consumes: `AppModel.execFilePath`, `argumentsForExecutable`
- Produces: Direct `BackgroundProcess` invocation for `apache2`, `httpd`, `postgres`, `redis-server`, and `php-fpm` in foreground mode.

- [ ] **Step 1: Write unit tests for executable arguments of Linux services**

Verify arguments generated for `apache2` (`-DFOREGROUND`), `postgres` (`-D`), `redis-server` (`<conf>`), and `php-fpm` (`-F -y <conf>`).

- [ ] **Step 2: Run tests to verify failure**

Run: `dart test test/features/apps/data/app_service_manager_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `AppServiceManager`**

Update `argumentsForExecutable` and remove systemctl start/stop bypasses so all services run directly under DevStack management.

- [ ] **Step 4: Run tests to verify pass**

Run: `dart test test/features/apps/data/app_service_manager_test.dart`
Expected: PASS

- [ ] **Step 5: Commit service manager changes**

```bash
git add lib/features/apps/data/app_service_manager.dart test/features/apps/data/app_service_manager_test.dart
git commit -m "feat(service_manager): run linux apache, postgres, redis, and php-fpm in foreground mode"
```

---

### Task 4: Full End-to-End Verification

**Files:**
- Test: All test suites in `test/`

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 2: Check analyzer and format**

Run: `dart analyze`
Expected: No issues found.

- [ ] **Step 3: Final commit and summary**

```bash
git add .
git commit -m "chore: complete linux package manager services isolation master plan"
```
