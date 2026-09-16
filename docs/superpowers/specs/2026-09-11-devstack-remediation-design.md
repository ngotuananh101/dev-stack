# Design Specification: DevStack System Hardening & Audit Findings Remediation

- **Date**: 2026-09-11
- **Status**: Proposed / Pending Review
- **Author**: Antigravity (Pair programming with Ponta)
- **Target Branch**: `dev`
- **Scope**: Security privilege boundaries, process lifecycle & orphan prevention, credential vault persistence, runtime installation, catalog network integrity, and error boundaries.

---

## 1. Executive Summary

A comprehensive multi-agent audit of the DevStack codebase (Flutter desktop for Windows x64 and Linux x64) identified 15 concrete, verified findings spanning security privilege boundaries, subprocess lifecycle management, credential storage, file permissions, and catalog download integrity.

This design specification details the technical architecture and remediation steps organized into **four self-contained phases**, each corresponding to an isolated, testable Pull Request (PR) adhering to the principle: **"Rủi ro trước — Một PR mỗi phase"** (Risk-first, one PR per phase).

### Summary of Phases:
1. **Phase 1 (PR 1)**: Linux Privilege Boundary Hardening & Command Injection Remediation (High/Medium Security).
2. **Phase 2 (PR 2)**: Process Lifecycle, Concurrency & Graceful Shutdown Orchestration (Process Leak & Stability).
3. **Phase 3 (PR 3)**: Secret Persistence Encryption Boundary & Linux Runtime Permissions (Storage & Correctness).
4. **Phase 4 (PR 4)**: Catalog Network Integrity, Global Async Error Boundaries & Code Health (Supply Chain & Cleanliness).

---

## 2. Re-audited Findings Matrix

| Finding ID | Component | Calibrated Severity | Root Cause | Target PR |
|---|---|---|---|---|
| **1.1** | `PackageCommandValidator` | **MEDIUM** (regression risk) | Newline filter added in `3ef2e17` lacks negative unit tests. | PR 1 |
| **1.2** | `PackageCommandValidator` | **HIGH** | Allowlist contains 20 binaries (including `chmod`, `chown`, `ln`, `sed`, `wget`). Real catalog uses only 8. `curl` options unconstrained. | PR 1 |
| **1.3a** | `AppInstallerService` | **MEDIUM** | Temporary script `/tmp/ponta-pkg-*/install.sh` executed by root via `pkexec sh`. Vulnerable to same-UID TOCTOU replacement during Polkit prompt. | PR 1 |
| **1.3b** | `SslService` | **HIGH** | User-owned binary `~/.ponta/bin/mkcert` executed under root via `pkexec sh -c`. Size-only check permits trojan substitution. | PR 1 |
| **1.4** | `AppInstallerService` | **MEDIUM** | `setLinuxCapabilityForWebserver` allows system binaries by `p.basename` without symlink resolution or directory validation. | PR 1 |
| **1.5** | `SiteTable` | **MEDIUM** | `buildTerminalLaunchSpec` interpolates paths directly into PowerShell and Bash command strings, vulnerable to `$()` evaluation. | PR 1 |
| **1.6** | `AppSettings` & `TunnelModel` | **MEDIUM** | ngrok and Cloudflare tokens stored as raw plaintext in `default.isar`. | PR 3 |
| **2.1** | `WindowService` & `SettingsPage` | **HIGH** | Exit paths (tray quit, window close without minimize, post-migration restart) kill the UI without terminating active tunnels, leaving orphan processes. | PR 2 |
| **2.2** | `CloudflareDriver` | **MEDIUM** | Regex only matches `*.trycloudflare.com`. Token-based named tunnels with custom domains never transition to `running`. | PR 2 |
| **2.3** | `TunnelManagerService` | **HIGH** | Double-start race spawns duplicate processes; download/spawn phase cannot be cancelled; UI hides Stop/Cancel button in intermediate states. | PR 2 |
| **2.4** | `TunnelManagerService` | **MEDIUM** | `ManagedBackgroundProcess` streams decode UTF-8 without `allowMalformed: true` and lack `onError` handlers. | PR 2 |
| **3.1** | `AppInstallerService` | **MEDIUM** | ZIP extraction and raw copies yield 0644 mode. `ensureLinuxPermissions` runs `chmod -R u+rwX` which does not set `+x` on regular files. | PR 3 |
| **3.2** | `PathService` | **LOW-MEDIUM** | `npm config set prefix` fails silently because child process PATH lacks node directory; return value exitCode is unchecked. | PR 3 |
| **3.3** | Catalog & `update.js` | **MEDIUM** | MariaDB download URLs use unencrypted `http://`. Remote checksum verification pipeline is dormant due to empty catalog hashes. | PR 4 |
| **4.1** | `main.dart` | **MEDIUM** | Missing `runZonedGuarded`, `FlutterError.onError`, and `PlatformDispatcher.instance.onError`. Autostart tunnel loop lacks per-tunnel isolation. | PR 4 |
| **4.2** | `update.js` & `win32_window.cpp` | **LOW** | SonarQube S3776 Cognitive Complexity (17/15) in `fetchGithubReleases`. C++17 `memcpy` vs C++20 `bit_cast`. | PR 4 |

---

## 3. Architecture & Core Invariants

1. **Zero User-Mutable Payloads Executed by Root (No Mutable Root Code)**:
   - Root will never execute binaries or shell scripts residing in user-writable directories (`~/.ponta/bin/`, `/tmp/`).
   - Package manager commands must be streamed directly via `stdin` to elevated shells (`sudo -n sh -s` or `pkexec sh -s`) without temporary disk files.
   - `mkcert` is never executed under root; system CA trust installation is handled via native system trust tools (`update-ca-certificates` / `update-ca-trust`) operating on validated certificate files written to system anchor paths.

2. **Strict Cryptographic Boundary at Data Storage Layer**:
   - The embedded database (`default.isar`) stores **only ciphertext** (prefixed with `ENC:<iv>:<ciphertext>:<tag>`).
   - Domain models (`TunnelModel`, `AppSettings`), Riverpod state providers, UI components, and CLI drivers handle **only plaintext**.
   - Decryption occurs at query boundary (clone-and-decrypt); encryption occurs at write boundary (clone-and-encrypt). In-memory state objects are never mutated in place.

3. **Complete Subprocess Lifecycle & Exit Barrier**:
   - Every subprocess spawn sequence must be cancelable at any stage (binary download, process spawn, connection negotiation).
   - No application exit path may terminate the parent process until all child subprocesses have exited or been forcefully terminated with an exit barrier timeout.

4. **Static Command Templates for Terminal Spawning**:
   - Dynamic user parameters (file paths, directories) must be transported exclusively via environment variables (`DEVSTACK_SITE_PATH`, `DEVSTACK_PHP_DIR`), never through string interpolation in shell command lines.

---

## 4. Phase 1: Linux Privilege Boundary & Command Injection Remediation

### 4.1. Unit Test Suite & Allowlist Hardening in `PackageCommandValidator`
- **File**: [lib/features/apps/data/package_command_validator.dart](lib/features/apps/data/package_command_validator.dart)
- **Test File**: [test/features/apps/data/package_command_validator_test.dart](test/features/apps/data/package_command_validator_test.dart)
- **Specification**:
  1. Add comprehensive test cases for multi-line control characters: `\n`, `\r`, `\v`, `\f`, `\r\n`. Ensure any occurrence in commands returns an error.
  2. Reduce `_allowedBinaries` from 20 to the strict set of 8 binaries required by [assets/data/apps-linux.json](assets/data/apps-linux.json):
     ```dart
     static const Set<String> _allowedBinaries = {
       'apt-get',
       'add-apt-repository',
       'dpkg',
       'dnf',
       'curl',
       'tee',
       'echo',
       'systemctl',
     };
     ```
  3. Remove unused attack surface binaries: `chmod`, `chown`, `ln`, `sed`, `mkdir`, `touch`, `wget`, `yum`, `rpm`, `gpg`, `apt`, `apt-key`.
  4. Constrain `curl` arguments:
     - Require URLs to start with `https://`.
     - When file output flags (`-o`, `-O`, `-sSLo`, `--output`) are present, enforce that the target path matches `^/tmp/[a-zA-Z0-9_.-]+$`. Reject arbitrary file destinations.

### 4.2. Stdin-Based Package Manager Execution (`runElevatedWithStdin`)
- **Files**:
  - [lib/core/services/background_process.dart](lib/core/services/background_process.dart)
  - [lib/features/apps/data/app_installer_service.dart](lib/features/apps/data/app_installer_service.dart)
- **Specification**:
  1. Add `BackgroundProcess.runElevatedWithStdin`:
     ```dart
     static Future<ProcessResult> runElevatedWithStdin(
       String executable,
       List<String> arguments, {
       required String input,
     })
     ```
  2. On Linux:
     - Check if passwordless sudo is available: `sudo -n true`.
     - If available: spawn `Process.start('sudo', ['-n', 'sh', '-s', ...args])`.
     - Otherwise: spawn `Process.start('pkexec', ['sh', '-s', ...args])`.
     - Write `input` to `process.stdin` via `utf8.encode`, then call `await process.stdin.close()`.
     - Await stdout and stderr streams concurrently; collect output and return `ProcessResult`.
  3. In `AppInstallerService._runLinuxPackageCommands`:
     - Eliminate creation of `/tmp/ponta-pkg-*/install.sh`.
     - Assemble command pipeline string into memory buffer.
     - Execute via `runElevatedWithStdin('sh', ['-s'], input: scriptContent)`.

### 4.3. Unprivileged `mkcert` & Direct System Trust Installation
- **File**: [lib/core/services/ssl_service.dart](lib/core/services/ssl_service.dart)
- **Test File**: [test/core/services/ssl_service_linux_test.dart](test/core/services/ssl_service_linux_test.dart)
- **Specification**:
  1. `mkcert` binary execution:
     - `mkcert` runs **only as the current desktop user** with environment variable `TRUST_STORES=nss`. This installs the CA to browser NSS stores (Firefox, Chrome) without root privileges.
  2. System trust store installation:
     - Locate user's `rootCA.pem` from `CAROOT` (`~/.local/share/mkcert/rootCA.pem`).
     - Read file and verify PEM header: `-----BEGIN CERTIFICATE-----`.
     - Determine distro certificate anchor path:
       * Debian / Ubuntu: `/usr/local/share/ca-certificates/ponta-dev-stack-root-ca.crt`
       * RHEL / Fedora / CentOS: `/etc/pki/ca-trust/source/anchors/ponta-dev-stack-root-ca.pem`
     - Pipe certificate bytes via `runElevatedWithStdin('tee', [anchorPath], input: certPemContent)`.
     - Run elevated `chmod` setting mode `0644` on anchor file.
     - Run elevated update tool:
       * Debian / Ubuntu: `/usr/sbin/update-ca-certificates`
       * RHEL / CentOS: `/usr/bin/update-ca-trust extract`
  3. System trust store uninstallation:
     - Remove the anchor file using elevated `rm -f <anchorPath>`.
     - Run the distro update tool (`update-ca-certificates --fresh` or `update-ca-trust extract`).
     - Run `mkcert -uninstall` as the unprivileged user with `TRUST_STORES=nss`.
  4. Eliminate `buildElevatedMkcertArgs` running `pkexec sh -c ... "$2" "$3"`.

### 4.4. Strict Symlink Resolution & Path Whitelist in `setLinuxCapabilityForWebserver`
- **File**: [lib/features/apps/data/app_installer_service.dart](lib/features/apps/data/app_installer_service.dart)
- **Specification**:
  1. Resolve canonical path: `final canonicalPath = await File(executablePath).resolveSymbolicLinks();`.
  2. If `allowSystemBinaries == true`:
     - Enforce allowed system directories:
       ```dart
       const allowedDirs = [
         '/usr/sbin',
         '/usr/bin',
         '/usr/local/sbin',
         '/usr/local/bin',
       ];
       ```
     - Validate that `p.dirname(canonicalPath)` matches one of `allowedDirs`.
     - Validate that `p.basename(canonicalPath)` belongs to `{'apache2', 'httpd', 'caddy', 'nginx'}`.
  3. If `allowSystemBinaries == false`:
     - Enforce `p.isWithin(AppConfig.appsDir, canonicalPath)`.

### 4.5. Environment Variable Isolation in Site Terminal Launcher
- **File**: [lib/features/sites/presentation/widgets/site_table.dart](lib/features/sites/presentation/widgets/site_table.dart)
- **Test File**: [test/features/sites/presentation/widgets/site_table_test.dart](test/features/sites/presentation/widgets/site_table_test.dart)
- **Specification**:
  1. Refactor `SiteTable.buildTerminalLaunchSpec(sitePath, phpDir)`:
     - Return structure: `({String executable, List<String> arguments, Map<String, String> environment})`.
     - Pass variables via environment:
       ```dart
       final env = {
         'DEVSTACK_SITE_PATH': sitePath,
         'DEVSTACK_PHP_DIR': phpDir ?? '',
       };
       ```
  2. Static command templates:
     - **Windows (PowerShell)**:
       ```powershell
       if ($env:DEVSTACK_PHP_DIR) { $env:PATH = "$env:DEVSTACK_PHP_DIR;" + $env:PATH }
       Set-Location -LiteralPath $env:DEVSTACK_SITE_PATH
       Write-Host "Site Path: $env:DEVSTACK_SITE_PATH" -ForegroundColor DarkGray
       ```
     - **Linux (Bash)**:
       ```bash
       if [ -n "$DEVSTACK_PHP_DIR" ]; then export PATH="$DEVSTACK_PHP_DIR:$PATH"; fi
       cd "$DEVSTACK_SITE_PATH"
       echo "Site Path: $DEVSTACK_SITE_PATH"
       exec bash
       ```
  3. No string concatenation of `$sitePath` into shell command lines.

---

## 5. Phase 2: Tunnel Process Lifecycle, Concurrency & Exit Orchestration

### 5.1. Concurrency Control, Generation Tracking & Cancellation in `TunnelManagerService`
- **File**: [lib/features/tunnels/data/tunnel_manager_service.dart](lib/features/tunnels/data/tunnel_manager_service.dart)
- **Files**:
  - [lib/features/tunnels/data/services/tunnel_downloader_service.dart](lib/features/tunnels/data/services/tunnel_downloader_service.dart)
  - [lib/features/tunnels/domain/tunnel_session.dart](lib/features/tunnels/domain/tunnel_session.dart)
- **Specification**:
  1. State tracking:
     - Maintain `final Map<int, int> _tunnelGenerations = {};`
     - Maintain `final Map<int, CancelToken> _downloadCancelTokens = {};`
     - Maintain `final Map<int, Future<void>> _startingFutures = {};`
  2. In-flight start guard:
     - If `_startingFutures.containsKey(tunnel.id)`: return the existing future (idempotent start).
     - Assign new generation: `final gen = (_tunnelGenerations[tunnel.id] ?? 0) + 1; _tunnelGenerations[tunnel.id] = gen;`.
  3. Binary download cancellation:
     - Create Dio `CancelToken` and store in `_downloadCancelTokens[tunnel.id]`.
     - Pass `cancelToken` to `_downloader.downloadBinary(...)`.
     - Catch `DioException` of type `cancel`: update session status to `stopped`, clean up state.
  4. Post-spawn generation check:
     - After `_startProcess` yields a `Process` / `ManagedBackgroundProcess`:
     - If `_tunnelGenerations[tunnel.id] != gen` or session was marked `stopped`:
       * Immediately terminate process: `process.kill(ProcessSignal.sigkill)` or `stopManagedProcess()`.
       * Do not add to `_activeProcesses`.
  5. Immutable `copyWith` in `TunnelSession`:
     - Replace `value ?? this.value` with explicit clearable wrappers or sentinel objects for `publicUrl`, `errorMessage`, and `pid` to allow clearing on state transition.

### 5.2. Graceful Shutdown Barrier Across All Exit Paths
- **Files**:
  - [lib/core/services/window_service.dart](lib/core/services/window_service.dart)
  - [lib/features/settings/presentation/settings_page.dart](lib/features/settings/presentation/settings_page.dart)
  - [lib/features/tunnels/data/tunnel_manager_service.dart](lib/features/tunnels/data/tunnel_manager_service.dart)
- **Specification**:
  1. Add `Future<void> stopAll()` in `TunnelManagerService` and `TunnelSessionsNotifier`:
     - Invalidate all generations: cancel all active `_downloadCancelTokens`.
     - Identify all active PIDs in `_activeProcesses`.
     - Trigger SIGTERM / taskkill concurrently on all processes.
     - Wait with timeout (e.g. 3000ms): if processes do not exit, issue SIGKILL.
     - Clear `_activeProcesses` and update all sessions to `stopped`.
  2. Hook into `WindowService`:
     - In `onWindowClose` (when `minimizeToTray == false`):
       ```dart
       await ref.read(tunnelSessionsProvider.notifier).stopAll();
       await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
       await windowManager.destroy();
       ```
     - In `_handleTrayAction` (`quit_app`):
       ```dart
       await ref.read(tunnelSessionsProvider.notifier).stopAll();
       await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
       await windowManager.destroy();
       ```
  3. Hook into `SettingsPage` (post-migration restart):
     - Await `tunnelSessionsProvider.notifier.stopAll()` before `exit(0)`.

### 5.3. Stream Hardening & Exit Authority in `ManagedBackgroundProcess`
- **File**: [lib/features/tunnels/data/tunnel_manager_service.dart](lib/features/tunnels/data/tunnel_manager_service.dart)
- **Specification**:
  1. Use `const Utf8Decoder(allowMalformed: true)` on stdout and stderr streams.
  2. Attach `onError: (err, stack) => AppLogger.warning('Tunnel stream error: $err')` to both stream subscriptions.
  3. Process exit authority:
     - Do not rely on stream `onDone` to transition to `stopped`.
     - Transition to `stopped` exclusively upon completion of `process.exitCode`.

### 5.4. Cloudflare Named-Tunnel Running Transition & UI Controls
- **Files**:
  - [lib/features/tunnels/data/drivers/cloudflare_driver.dart](lib/features/tunnels/data/drivers/cloudflare_driver.dart)
  - [lib/features/tunnels/presentation/pages/tunnels_page.dart](lib/features/tunnels/presentation/pages/tunnels_page.dart)
  - [lib/features/tunnels/presentation/dialogs/site_tunnel_dialog.dart](lib/features/tunnels/presentation/dialogs/site_tunnel_dialog.dart)
- **Specification**:
  1. In `CloudflareDriver`:
     - Detect connection readiness logs:
       ```dart
       static final RegExp _registeredRegex = RegExp(r'Registered tunnel connection|Connection [a-f0-9-]+ registered');
       ```
     - In `handleLogLine`: if `_registeredRegex.hasMatch(logLine)`:
       * Mark status as `TunnelStatus.running`.
       * If tunnel has `customDomain` populated, set `publicUrl = 'https://${tunnel.customDomain}'`.
  2. UI controls:
     - Render active **Stop / Cancel** button during `TunnelStatus.downloadingBinary` and `TunnelStatus.connecting`.
     - Disable **Edit** action when tunnel status is not `stopped` or `error`.

---

## 6. Phase 3: Secret Persistence & Linux Runtime Permissions

### 6.1. Token Encryption Boundary with `LocalSecretVault`
- **Files**:
  - [lib/features/tunnels/data/security/tunnel_token_cipher.dart](lib/features/tunnels/data/security/tunnel_token_cipher.dart) (NEW)
  - [lib/features/tunnels/domain/tunnel_model.dart](lib/features/tunnels/domain/tunnel_model.dart)
  - [lib/features/settings/domain/app_settings.dart](lib/features/settings/domain/app_settings.dart)
  - [lib/features/settings/data/settings_provider.dart](lib/features/settings/data/settings_provider.dart)
  - [lib/features/tunnels/data/tunnel_manager_service.dart](lib/features/tunnels/data/tunnel_manager_service.dart)
  - [lib/features/tunnels/presentation/providers/tunnel_providers.dart](lib/features/tunnels/presentation/providers/tunnel_providers.dart)
- **Specification**:
  1. `TunnelTokenCipher`:
     ```dart
     class TunnelTokenCipher {
       static const String prefix = 'ENC:';
       final LocalSecretVault _vault;
       TunnelTokenCipher(this._vault);

       Future<String?> encryptToken(String? token) async {
         if (token == null || token.trim().isEmpty) return token;
         if (token.startsWith(prefix)) return token;
         final ciphertext = await _vault.encrypt(token.trim());
         return '$prefix$ciphertext';
       }

       Future<String?> decryptToken(String? storedValue) async {
         if (storedValue == null || storedValue.trim().isEmpty) return storedValue;
         if (!storedValue.startsWith(prefix)) return storedValue; // backward-compatibility with plaintext
         final rawCipher = storedValue.substring(prefix.length);
         return await _vault.decrypt(rawCipher);
       }
     }
     ```
  2. Domain model `clone()` methods:
     - Add `TunnelModel.clone()` and `AppSettings.clone()` to prevent in-place mutation of UI/Riverpod instances.
  3. Write operations:
     - In `TunnelManagerService.saveTunnel`: clone model -> encrypt `authToken` on clone -> write clone to Isar.
     - In `SettingsNotifier.updateField`: clone settings -> encrypt default tokens on clone -> write clone to Isar.
  4. Read operations:
     - In `tunnelsStreamProvider`: read from Isar -> clone models -> decrypt `authToken` -> yield plaintext to UI.
     - In `SettingsNotifier.build`: read from Isar -> clone -> decrypt default tokens -> expose plaintext in state.

### 6.2. Linux Executable Permission Flag Enforcement (`+x`)
- **File**: [lib/features/apps/data/app_installer_service.dart](lib/features/apps/data/app_installer_service.dart)
- **Specification**:
  1. In `_detectFiles` or immediate post-extraction hook:
     - Collect resolved executable paths (`execFilePath` and `cliFilePath`).
     - On Linux: execute `Process.run('chmod', ['u+x', execPath])` for each file.
     - Verify `exitCode == 0`; log warning if permission update fails.
  2. Fixes immediate execution failure of Bun, Deno, and Meilisearch after archive extraction.

### 6.3. Child PATH Injection for Linux `npm config set prefix`
- **File**: [lib/core/services/path_service.dart](lib/core/services/path_service.dart)
- **Specification**:
  1. In `PathService.configureLinuxShims`:
     - When invoking `Process.run(npmBin, ['config', 'set', 'prefix', ...])`:
     - Inject Node directory into PATH:
       ```dart
       final nodeDir = p.dirname(nodeBin);
       final currentPath = Platform.environment['PATH'] ?? '';
       final env = {'PATH': '$nodeDir:$currentPath'};
       final result = await Process.run(npmBin, ['config', 'set', 'prefix', targetPrefix], environment: env);
       if (result.exitCode != 0) {
         AppLogger.warning('Failed to configure npm prefix: ${result.stderr}');
       }
       ```
  2. Resolves `env: node: No such file or directory` failure under POSIX shebangs.

---

## 7. Phase 4: Catalog Network Integrity, Global Error Boundaries & Code Health

### 7.1. Catalog URL HTTPS Enforcement & Update Script Normalization
- **Files**:
  - [assets/data/apps.json](assets/data/apps.json)
  - [assets/data/new-apps.json](assets/data/new-apps.json)
  - [assets/data/update.js](assets/data/update.js)
  - [lib/features/apps/data/apps_repository.dart](lib/features/apps/data/apps_repository.dart)
- **Specification**:
  1. Update 6 MariaDB download URLs in `apps.json` and `new-apps.json` from `http://` to `https://downloads.mariadb.org/...`.
  2. Update `fetchMariadbReleases` in `assets/data/update.js` to force `https://` protocol prefix.
  3. In `AppsRepository`: validate all catalog download URLs before loading into memory. Reject or upgrade unencrypted `http://` URLs (allowing only `https://` or `package_manager` sentinel).

### 7.2. Global Desktop Unhandled Async Error Boundaries
- **File**: [lib/main.dart](lib/main.dart)
- **Specification**:
  1. Wrap application initialization:
     ```dart
     void main() async {
       runZonedGuarded(() async {
         WidgetsFlutterBinding.ensureInitialized();
         FlutterError.onError = (details) {
           FlutterError.presentError(details);
           AppLogger.error('Flutter error: ${details.exceptionAsString()}', details.stack);
         };
         PlatformDispatcher.instance.onError = (error, stack) {
           AppLogger.error('Platform error: $error', stack);
           return true; // handled
         };
         ...
         runApp(const ProviderScope(child: DevStackApp()));
       }, (error, stack) {
         AppLogger.error('Zone unhandled error: $error', stack);
       });
     }
     ```
  2. Autostart tunnel loop isolation:
     - Wrap each tunnel autostart execution in individual `try/catch` blocks.
     - Query and decrypt models before passing to `TunnelManagerService`.

### 7.3. SonarQube Complexity Refactoring & C++ Standards Documentation
- **Files**:
  - [assets/data/update.js](assets/data/update.js)
  - [windows/runner/win32_window.cpp](windows/runner/win32_window.cpp)
- **Specification**:
  1. Refactor `fetchGithubReleases` in `update.js`:
     - Extract `_pickWindowsAsset(assets, repoPath)` and `_pickLinuxAsset(assets)` to reduce Cognitive Complexity below 15.
  2. Document code architecture decisions:
     - Keep CommonJS in `update.js` (standard Node.js tooling, avoids package.json module conflicts).
     - Keep `std::memcpy` in `win32_window.cpp` (preserves C++17 compatibility across Windows build runners).
     - Track SHA-256 catalog checksum verification in conditional backlog until upstream download URLs are pinned.

---

## 8. Verification & Testing Strategy

Each phase must satisfy strict automated verification before PR submission:

1. **Unit & Integration Tests**:
   - `test/features/apps/data/package_command_validator_test.dart`: verify negative tests for all control characters and binary whitelist enforcement.
   - `test/core/services/ssl_service_linux_test.dart`: verify unprivileged mkcert args and root trust anchor update commands.
   - `test/features/sites/presentation/widgets/site_table_test.dart`: verify environment variable isolation in terminal commands.
   - `test/features/tunnels/data/tunnel_manager_service_test.dart`: verify double-start idempotency, CancelToken propagation, and stopAll barrier.
   - `test/features/tunnels/data/security/tunnel_token_cipher_test.dart`: verify transparent encryption/decryption and backward compatibility.
2. **Static Analysis & Linting**:
   - `flutter analyze` must produce 0 issues.
   - Code formatting must adhere to `dart format`.
3. **Cross-Platform Sanity**:
   - Verify Windows execution paths remain unaffected while Linux execution paths activate hardened behavior.

---

## 9. Rollout Roadmap (PR Sequence)

```dot
digraph rollout {
  rankdir=LR;
  node [shape=box, style=rounded];
  
  PR1 [label="Phase 1 (PR 1)\nLinux Privilege Hardening\n& Command Injection"];
  PR2 [label="Phase 2 (PR 2)\nProcess Lifecycle, Concurrency\n& Exit Barrier"];
  PR3 [label="Phase 3 (PR 3)\nSecret Persistence\n& Linux Runtime +x"];
  PR4 [label="Phase 4 (PR 4)\nCatalog HTTPS, Error Boundaries\n& Code Health"];
  
  PR1 -> PR2 -> PR3 -> PR4;
}
```

- Each PR will be created from `dev`, tested against the full suite, and reviewed independently.
- No code implementation will begin until this specification document is formally reviewed.
