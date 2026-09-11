# DevStack System Hardening & Audit Findings Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate privilege escalation vulnerabilities, command injection risks, process lifecycle leaks, unencrypted credentials at rest, and catalog network integrity gaps across Windows x64 and Linux x64 platforms.

**Architecture:** A 4-phase, risk-first remediation sequence structured as 4 self-contained PRs. Phase 1 hardens Linux privilege boundaries and shell launches; Phase 2 guarantees subprocess lifecycle containment and clean exit barriers; Phase 3 establishes an authenticated AES-GCM encryption boundary at the persistence layer and fixes Linux runtime file permissions; Phase 4 enforces catalog HTTPS, desktop global error boundaries, and code complexity cleanup.

**Tech Stack:** Flutter Desktop, Dart 3.x, Riverpod 2.x, Isar NoSQL, Cryptography (AES-GCM-256 via LocalSecretVault), Dio (CancelToken), Linux PolicyKit/sudo, POSIX Shell/PowerShell.

**Spec:** [docs/superpowers/specs/2026-09-11-devstack-remediation-design.md](docs/superpowers/specs/2026-09-11-devstack-remediation-design.md)

## Global Constraints

- Never execute user-mutable files (`~/.ponta/bin/`, `/tmp/`) under root elevation.
- Never pass unescaped or interpolated dynamic variables in shell command strings; use static command templates and environment variables.
- Raw Isar records store only ciphertext (`ENC:<iv>:<cipher>:<tag>`); domain models, Riverpod state, UI widgets, and CLI drivers consume only detached plaintext.
- Every subprocess start sequence must be cancelable and guarded against concurrent duplicate spawning.
- All tests must pass (`flutter test`) and `flutter analyze` must produce 0 issues after each task.
- End git commit messages with: `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

---

## Phase 1: Linux Privilege Boundary & Command Injection Remediation (PR 1)

### Task 1: Comprehensive Negative Test Suite for `PackageCommandValidator`

**Files:**
- Modify: `test/features/apps/package_command_validator_test.dart:130-132`
- Target: `lib/features/apps/data/package_command_validator.dart:99-103`

**Interfaces:**
- Consumes: `PackageCommandValidator.validate(String command)` -> `String?`
- Produces: Regression protection verifying rejection of `\n`, `\r`, `\v`, `\f`, CRLF in catalog commands.

- [ ] **Step 1: Write failing negative tests for control characters**

In `test/features/apps/package_command_validator_test.dart`, inside `group('rejected commands (negative cases)', ...)`:

```dart
test('rejects commands with vertical whitespace and newline injection', () {
  const newlineCases = [
    'apt-get update\nrm -rf /',
    'apt-get update\r\nrm -rf /',
    'apt-get update\rrm -rf /',
    'apt-get update\vrm -rf /',
    'apt-get update\frm -rf /',
    'sudo apt-get install -y foo\ncat /etc/shadow',
  ];

  for (final cmd in newlineCases) {
    final result = PackageCommandValidator.validate(cmd);
    expect(
      result,
      contains('newline or vertical whitespace'),
      reason: 'Command "$cmd" should be rejected for containing newline/vertical whitespace',
    );
  }
});
```

- [ ] **Step 2: Run test to verify it executes against current implementation**

Run: `flutter test test/features/apps/package_command_validator_test.dart`
Expected: PASS (verifying HEAD commit `3ef2e17` implementation holds and prevents regressions).

- [ ] **Step 3: Commit test suite**

```bash
git add test/features/apps/package_command_validator_test.dart
git commit -m "test(apps): add negative tests for newline injection in PackageCommandValidator

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Restrict `PackageCommandValidator` Allowlist & Enforce `curl` Security

**Files:**
- Modify: `lib/features/apps/data/package_command_validator.dart:20-46, 130-146`
- Modify: `test/features/apps/package_command_validator_test.dart`

**Interfaces:**
- Consumes: `apps-linux.json` command catalog.
- Produces: Fail-closed binary allowlist restricted strictly to 8 binaries: `apt-get`, `add-apt-repository`, `dpkg`, `dnf`, `curl`, `tee`, `echo`, `systemctl`. Rejection of `chmod`, `chown`, `ln`, `sed`, `wget`, arbitrary `curl -o` destinations, and unencrypted HTTP curl requests.

- [ ] **Step 1: Write the failing tests for removed binaries and curl constraints**

Add to `test/features/apps/package_command_validator_test.dart`:

```dart
test('rejects removed administrative binaries (chmod, chown, ln, sed, wget)', () {
  expect(PackageCommandValidator.validate('chmod +x /tmp/evil'), contains('not in the allowed list'));
  expect(PackageCommandValidator.validate('chown root:root /tmp/evil'), contains('not in the allowed list'));
  expect(PackageCommandValidator.validate('ln -s /etc/shadow /tmp/shadow'), contains('not in the allowed list'));
  expect(PackageCommandValidator.validate('sed -i "s/a/b/" /etc/hosts'), contains('not in the allowed list'));
  expect(PackageCommandValidator.validate('wget https://example.com/file'), contains('not in the allowed list'));
});

test('curl enforces https and safe /tmp destination for output flags', () {
  expect(
    PackageCommandValidator.validate('curl http://example.com/pkg.deb'),
    contains('curl only allows https:// URLs'),
  );
  expect(
    PackageCommandValidator.validate('curl -sSLo /etc/cron.d/pwn https://example.com/pwn'),
    contains('Target file for curl must be in /tmp/'),
  );
  expect(
    PackageCommandValidator.validate('curl -o /usr/bin/pwn https://example.com/pwn'),
    contains('Target file for curl must be in /tmp/'),
  );
  expect(
    PackageCommandValidator.validate('curl -sSLo /tmp/pkg.deb https://example.com/pkg.deb'),
    isNull,
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/package_command_validator_test.dart`
Expected: FAIL (`chmod` currently allowed, `curl` constraints not implemented).

- [ ] **Step 3: Update `PackageCommandValidator` allowlist and curl rules**

In `lib/features/apps/data/package_command_validator.dart`:
Replace `_allowedBinaries` with:
```dart
  static const Set<String> _allowedBinaries = {
    // Debian/Ubuntu package management
    'apt-get',
    'dpkg',
    'add-apt-repository',
    // RHEL/CentOS package management
    'dnf',
    // Repo keys, sources, downloads (restricted)
    'tee',
    'curl',
    'echo',
    // Service control (post-install hooks)
    'systemctl',
  };
```

Add safe temp target regex for curl:
```dart
  static final RegExp _allowedCurlTarget = RegExp(
    r'^/tmp/[a-zA-Z0-9_.-]+$',
  );
```

In `validate()` method, add curl argument checks:
```dart
      // Hardening for 'curl': enforce https and restrict output destinations to /tmp
      if (binary == 'curl') {
        final parts = segTrimmed.split(RegExp(r'\s+'));
        for (int i = 1; i < parts.length; i++) {
          final part = parts[i];
          if (part.startsWith('http://')) {
            return 'curl only allows https:// URLs';
          }
          if ((part == '-o' || part == '-O' || part == '--output' || part == '-sSLo') && i + 1 < parts.length) {
            final target = parts[i + 1];
            if (!_allowedCurlTarget.hasMatch(target)) {
              return 'Target file for curl must be in /tmp/ with a safe filename';
            }
          }
        }
      }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/package_command_validator_test.dart`
Expected: PASS (all positive, negative, and `apps-linux.json` catalog tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/package_command_validator.dart test/features/apps/package_command_validator_test.dart
git commit -m "feat(security): restrict PackageCommandValidator allowlist and enforce curl https/tmp limits

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Stdin-Based Package Execution via `runElevatedWithStdin`

**Files:**
- Modify: `lib/core/services/background_process.dart:167-200`
- Modify: `lib/features/apps/data/app_installer_service.dart:2650-2735`
- Modify: `test/features/apps/installer_linux_package_manager_test.dart`

**Interfaces:**
- Consumes: `BackgroundProcess.runElevatedWithStdin`
- Produces: Execution of package manager scripts directly via shell `stdin` (`sudo -n sh -s` / `pkexec sh -s`), completely eliminating `/tmp/ponta-pkg-*/install.sh`.

- [ ] **Step 1: Write failing tests in `installer_linux_package_manager_test.dart`**

Update `test/features/apps/installer_linux_package_manager_test.dart` to verify that execution does not write or reference `install.sh` files on disk, and passes script content via standard input:

```dart
test('executes package commands via stdin without creating install.sh', () async {
  final logInfoMsgs = <String>[];
  String? passedStdin;
  final executedCalls = <({String exec, List<String> args})>[];

  final result = await AppInstallerService.executePackageManagerCommands(
    commands: ['apt-get update'],
    logInfo: logInfoMsgs.add,
    logError: (_) {},
    isLinuxOverride: true,
    runProcessElevatedWithStdin: (exec, args, stdinInput) async {
      executedCalls.add((exec: exec, args: args));
      passedStdin = stdinInput;
      return ProcessResult(1, 0, 'Success', '');
    },
  );

  expect(result.exitCode, equals(0));
  expect(passedStdin, isNotNull);
  expect(passedStdin, contains('apt-get update'));
  expect(passedStdin, contains('#!/bin/sh'));
  expect(executedCalls.first.exec, equals('sh'));
  expect(executedCalls.first.args, equals(['-s']));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/installer_linux_package_manager_test.dart`
Expected: FAIL (`runProcessElevatedWithStdin` not yet accepted).

- [ ] **Step 3: Implement `runElevatedWithStdin` in `BackgroundProcess` and update `AppInstallerService`**

In `lib/core/services/background_process.dart`:
```dart
  /// Runs a command with elevation passing [input] via stdin.
  static Future<ProcessResult> runElevatedWithStdin(
    String executable,
    List<String> arguments, {
    required String input,
    bool? isLinux,
    void Function(String)? logInfo,
  }) async {
    final onLinux = isLinux ?? Platform.isLinux;
    if (!onLinux) {
      // Windows fallback via standard runElevated
      return runElevated(executable, arguments, isLinux: false, logInfo: logInfo);
    }

    bool canSudoNonInteractive = false;
    try {
      final sudoCheck = await Process.run('sudo', ['-n', 'true']);
      if (sudoCheck.exitCode == 0) canSudoNonInteractive = true;
    } catch (_) {}

    final List<String> spawnCmd;
    if (canSudoNonInteractive) {
      logInfo?.call('Executing via sudo (non-interactive)...');
      spawnCmd = ['sudo', '-n', executable, ...arguments];
    } else {
      logInfo?.call('Requesting system authorization via pkexec...');
      spawnCmd = ['pkexec', executable, ...arguments];
    }

    final process = await Process.start(spawnCmd.first, spawnCmd.sublist(1));
    process.stdin.write(input);
    await process.stdin.flush();
    await process.stdin.close();

    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;

    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }
```

In `lib/features/apps/data/app_installer_service.dart`:
Update `executePackageManagerCommands`:
- Remove creation of `tempDir` and `scriptFile`.
- Call `runProcessElevatedWithStdin ?? BackgroundProcess.runElevatedWithStdin`.
- Invoke `'sh'`, `['-s']`, with `input: scriptContent`.
- Remove `chmod 755` call.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/apps/installer_linux_package_manager_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/background_process.dart lib/features/apps/data/app_installer_service.dart test/features/apps/installer_linux_package_manager_test.dart
git commit -m "fix(security): execute Linux package manager scripts via stdin, eliminating /tmp install.sh

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Unprivileged `mkcert` & Direct System Trust Installation

**Files:**
- Modify: `lib/core/services/ssl_service.dart:204-345`
- Modify: `test/core/services/ssl_service_linux_test.dart`

**Interfaces:**
- Consumes: User's `rootCA.pem` generated by unprivileged `mkcert`.
- Produces: System trust installation by copying `rootCA.pem` to OS trust anchor directory (`/usr/local/share/ca-certificates/` on Debian or `/etc/pki/ca-trust/source/anchors/` on RHEL) via elevated `tee`, without ever running `mkcert` under root.

- [ ] **Step 1: Write failing tests in `ssl_service_linux_test.dart`**

Update `test/core/services/ssl_service_linux_test.dart`:
```dart
test('linux trust commands install CA to system anchor and run distro update tool', () {
  final debianSpec = SslService.buildSystemTrustInstallSpec(
    distroId: 'ubuntu',
    anchorFileName: 'ponta-root-ca.crt',
    isLinux: true,
  );
  expect(debianSpec.anchorPath, equals('/usr/local/share/ca-certificates/ponta-root-ca.crt'));
  expect(debianSpec.updateCommand.executable, equals('update-ca-certificates'));

  final rhelSpec = SslService.buildSystemTrustInstallSpec(
    distroId: 'rhel',
    anchorFileName: 'ponta-root-ca.pem',
    isLinux: true,
  );
  expect(rhelSpec.anchorPath, equals('/etc/pki/ca-trust/source/anchors/ponta-root-ca.pem'));
  expect(rhelSpec.updateCommand.executable, equals('update-ca-trust'));
  expect(rhelSpec.updateCommand.arguments, contains('extract'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/ssl_service_linux_test.dart`
Expected: FAIL (`buildSystemTrustInstallSpec` undefined).

- [ ] **Step 3: Implement unprivileged mkcert & system anchor installation**

In `lib/core/services/ssl_service.dart`:
1. Add `buildSystemTrustInstallSpec({required String distroId, required String anchorFileName, bool? isLinux})`.
2. In `initializeRootCA()`:
   - On Linux: Run `mkcert -install` **as normal unprivileged user** with `environment: {'TRUST_STORES': 'nss'}`.
   - Read `rootCA.pem` from `CAROOT` (`~/.local/share/mkcert/rootCA.pem`).
   - Validate that content starts with `-----BEGIN CERTIFICATE-----`.
   - Install certificate into OS trust store by streaming PEM content via `runElevatedWithStdin('tee', [spec.anchorPath], input: pemContent)`.
   - Run elevated `chmod 644 [spec.anchorPath]`.
   - Run elevated `spec.updateCommand.executable` with `spec.updateCommand.arguments`.
3. In `uninstallRootCA()`:
   - Remove anchor file via elevated `rm -f [spec.anchorPath]`.
   - Run elevated update tool to rebuild trust store.
   - Run unprivileged `mkcert -uninstall` with `TRUST_STORES=nss`.
4. Deprecate/remove `buildElevatedMkcertArgs` running `pkexec sh -c ... "$2" "$3"`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/ssl_service_linux_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/ssl_service.dart test/core/services/ssl_service_linux_test.dart
git commit -m "fix(security): install Root CA via native system anchors, eliminating elevated mkcert execution

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Strict Canonical Directory & Symlink Validation in `setLinuxCapabilityForWebserver`

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart:1210-1230`
- Modify: `test/features/apps/installer_linux_package_manager_test.dart`

**Interfaces:**
- Consumes: Target executable path on Linux.
- Produces: Validation that system binaries reside in `/usr/sbin`, `/usr/bin`, `/usr/local/sbin`, or `/usr/local/bin`, with all symbolic links resolved before checking.

- [ ] **Step 1: Write failing test in `installer_linux_package_manager_test.dart`**

```dart
test('setLinuxCapability rejects executables outside standard system directories', () async {
  expect(
    () => AppInstallerService.validateCapabilityExecutablePath(
      '/tmp/caddy',
      allowSystemBinaries: true,
    ),
    throwsA(isA<ArgumentError>()),
  );

  expect(
    () => AppInstallerService.validateCapabilityExecutablePath(
      '/home/user/apache2',
      allowSystemBinaries: true,
    ),
    throwsA(isA<ArgumentError>()),
  );

  final valid = AppInstallerService.validateCapabilityExecutablePath(
    '/usr/sbin/apache2',
    allowSystemBinaries: true,
  );
  expect(valid, equals('/usr/sbin/apache2'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/installer_linux_package_manager_test.dart`
Expected: FAIL (`validateCapabilityExecutablePath` undefined).

- [ ] **Step 3: Implement validation and symlink resolution**

In `lib/features/apps/data/app_installer_service.dart`:
```dart
  static String validateCapabilityExecutablePath(
    String executablePath, {
    required bool allowSystemBinaries,
  }) {
    final file = File(executablePath);
    final resolvedPath = file.resolveSymbolicLinksSync();
    final basename = p.basename(resolvedPath);
    final dirname = p.dirname(resolvedPath);

    if (allowSystemBinaries) {
      const allowedDirs = {
        '/usr/sbin',
        '/usr/bin',
        '/usr/local/sbin',
        '/usr/local/bin',
      };
      const allowedNames = {'apache2', 'httpd', 'caddy', 'nginx'};
      if (!allowedDirs.contains(dirname) || !allowedNames.contains(basename)) {
        throw ArgumentError('Executable "$resolvedPath" is not an allowed system webserver binary');
      }
    } else {
      if (!p.isWithin(AppConfig.appsDir, resolvedPath)) {
        throw ArgumentError('Executable "$resolvedPath" must reside within apps directory');
      }
    }
    return resolvedPath;
  }
```
Use `validateCapabilityExecutablePath` inside `setLinuxCapabilityForWebserver`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/apps/installer_linux_package_manager_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/installer_linux_package_manager_test.dart
git commit -m "fix(security): resolve symlinks and enforce system directory allowlist in setLinuxCapability

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Isolate Site Terminal Launch Parameters via Environment Variables

**Files:**
- Modify: `lib/features/sites/presentation/widgets/site_table.dart:338-384`
- Modify: `test/features/sites/site_terminal_command_test.dart`

**Interfaces:**
- Consumes: `sitePath`, `phpDir`, `domain`.
- Produces: Static command strings referencing `$env:DEVSTACK_SITE_PATH` (PowerShell) or `"$DEVSTACK_SITE_PATH"` (Bash), with paths passed exclusively through the process `environment` map.

- [ ] **Step 1: Update tests in `site_terminal_command_test.dart` to expect environment mapping**

In `test/features/sites/site_terminal_command_test.dart`:
```dart
test('builds Windows powershell spec with static template and environment variables', () {
  final spec = SiteTable.buildTerminalLaunchSpec(
    isLinux: false,
    sitePath: r'C:\Ponta\www\test$()_site',
    phpDir: r'C:\Ponta\apps\php83',
    domain: 'test.local',
  );

  expect(spec.environment['DEVSTACK_SITE_PATH'], equals(r'C:\Ponta\www\test$()_site'));
  expect(spec.environment['DEVSTACK_PHP_DIR'], equals(r'C:\Ponta\apps\php83'));
  // Command string must NOT contain raw unescaped sitePath
  expect(spec.arguments.last, isNot(contains(r'C:\Ponta\www\test$()_site')));
  expect(spec.arguments.last, contains(r'$env:DEVSTACK_SITE_PATH'));
});

test('builds Linux bash spec with static template and environment variables', () {
  final spec = SiteTable.buildTerminalLaunchSpec(
    isLinux: true,
    sitePath: '/home/user/.ponta/www/test$()_site',
    phpDir: '/home/user/.ponta/apps/php83',
    domain: 'test.local',
  );

  expect(spec.environment['DEVSTACK_SITE_PATH'], equals('/home/user/.ponta/www/test$()_site'));
  expect(spec.arguments.last, isNot(contains('/home/user/.ponta/www/test$()_site')));
  expect(spec.arguments.last, contains(r'"$DEVSTACK_SITE_PATH"'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/sites/site_terminal_command_test.dart`
Expected: FAIL (`environment` property not found on spec).

- [ ] **Step 3: Refactor `buildTerminalLaunchSpec` in `SiteTable`**

In `lib/features/sites/presentation/widgets/site_table.dart`:
Update `buildTerminalLaunchSpec` return type and implementation:
```dart
  static ({
    String executable,
    List<String> arguments,
    Map<String, String> environment,
    bool runInShell,
  }) buildTerminalLaunchSpec({
    required bool isLinux,
    required String sitePath,
    String? phpDir,
    required String domain,
  }) {
    final env = <String, String>{
      'DEVSTACK_SITE_PATH': sitePath,
      'DEVSTACK_PHP_DIR': phpDir ?? '',
      'DEVSTACK_DOMAIN': domain,
    };

    if (isLinux) {
      final bashScript =
          'if [ -n "\$DEVSTACK_PHP_DIR" ]; then export PATH="\$DEVSTACK_PHP_DIR:\$PATH"; fi; '
          'cd "\$DEVSTACK_SITE_PATH"; '
          'echo -e "\\e[36mDevStack Site Terminal\\e[0m - \\e[32m\$DEVSTACK_DOMAIN\\e[0m"; '
          'echo -e "\\e[90mSite Path: \$DEVSTACK_SITE_PATH\\e[0m"; '
          'exec bash';
      return (
        executable: 'x-terminal-emulator',
        arguments: ['-e', 'bash', '-c', bashScript],
        environment: env,
        runInShell: false,
      );
    } else {
      final psScript =
          'if (\$env:DEVSTACK_PHP_DIR) { \$env:PATH = "\$env:DEVSTACK_PHP_DIR;" + \$env:PATH }; '
          'Set-Location -LiteralPath \$env:DEVSTACK_SITE_PATH; '
          'Write-Host "DevStack Site Terminal - \$env:DEVSTACK_DOMAIN" -ForegroundColor Cyan; '
          'Write-Host "Site Path: \$env:DEVSTACK_SITE_PATH" -ForegroundColor DarkGray';
      return (
        executable: 'start',
        arguments: ['powershell', '-NoExit', '-Command', psScript],
        environment: env,
        runInShell: true,
      );
    }
  }
```
Update terminal launcher callsite in `SiteTable` to pass `spec.environment` into `Process.start` / `Process.run`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/sites/site_terminal_command_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sites/presentation/widgets/site_table.dart test/features/sites/site_terminal_command_test.dart
git commit -m "fix(security): isolate Site Terminal command line from path injection via environment variables

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Phase 2: Tunnel Process Lifecycle, Concurrency & Exit Orchestration (PR 2)

### Task 7: Concurrency Guard, Generation Tracking & CancelToken in `TunnelManagerService`

**Files:**
- Modify: `lib/features/tunnels/data/services/tunnel_downloader_service.dart:18-50`
- Modify: `lib/features/tunnels/data/tunnel_manager_service.dart:110-180, 275-305`
- Modify: `lib/features/tunnels/domain/tunnel_session.dart:32-60`
- Modify: `test/features/tunnels/data/tunnel_manager_service_test.dart`

**Interfaces:**
- Consumes: Dio `CancelToken`, generation counter per tunnel.
- Produces: Idempotent start calls, immediate download cancellation upon stop/delete, and discarding/killing of post-spawn orphan processes.

- [ ] **Step 1: Write failing concurrency tests**

In `test/features/tunnels/data/tunnel_manager_service_test.dart`:
```dart
test('startTunnel is idempotent when called concurrently for same tunnel', () async {
  // Call startTunnel twice immediately
  final future1 = service.startTunnel(mockTunnel);
  final future2 = service.startTunnel(mockTunnel);
  await Future.wait([future1, future2]);

  // Verify only 1 driver start was invoked
  expect(fakeDriver.startCallCount, equals(1));
});

test('stopTunnel during binary download cancels Dio request and resets state', () async {
  final startFuture = service.startTunnel(mockTunnelRequiringDownload);
  await pumpEventQueue();
  await service.stopTunnel(mockTunnelRequiringDownload.id);
  await startFuture;

  final session = service.getSession(mockTunnelRequiringDownload.id);
  expect(session?.status, equals(TunnelStatus.stopped));
  expect(fakeDownloader.wasCancelled, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement generation tracking & cancellation**

1. In `TunnelDownloaderService.downloadBinary`: accept `CancelToken? cancelToken` and pass to `_dio.download(..., cancelToken: cancelToken)`.
2. In `TunnelManagerService`:
   - Add `final Map<int, int> _generations = {};`
   - Add `final Map<int, CancelToken> _cancelTokens = {};`
   - Add `final Map<int, Future<void>> _startingFutures = {};`
   - In `startTunnel()`:
     * If `_startingFutures.containsKey(tunnel.id)`, return `_startingFutures[tunnel.id]!`.
     * Allocate generation: `final currentGen = (_generations[tunnel.id] ?? 0) + 1; _generations[tunnel.id] = currentGen;`
     * Create `final cancelToken = CancelToken(); _cancelTokens[tunnel.id] = cancelToken;`
     * After `_startProcess` returns: check if `_generations[tunnel.id] != currentGen`. If mismatched, kill the process immediately.
   - In `stopTunnel()`:
     * Cancel `_cancelTokens[tunnel.id]?.cancel('User stopped tunnel');`
     * Increment `_generations[tunnel.id]`.
3. In `TunnelSession.copyWith`: support clearing nullable properties (`publicUrl`, `errorMessage`, `pid`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/services/tunnel_downloader_service.dart lib/features/tunnels/data/tunnel_manager_service.dart lib/features/tunnels/domain/tunnel_session.dart test/features/tunnels/data/tunnel_manager_service_test.dart
git commit -m "feat(tunnels): guard against double-start and support download cancellation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: Graceful Shutdown Barrier Across All Exit Paths

**Files:**
- Modify: `lib/features/tunnels/data/tunnel_manager_service.dart:280-320`
- Modify: `lib/features/tunnels/presentation/providers/tunnel_providers.dart`
- Modify: `lib/core/services/window_service.dart:77-80, 201-208`
- Modify: `lib/features/settings/presentation/settings_page.dart:437-450`
- Test: `test/features/tunnels/data/tunnel_manager_service_test.dart`

**Interfaces:**
- Consumes: Active tunnel process map.
- Produces: `Future<void> stopAll()` awaiting full exit of all tunnel subprocesses before window destruction or process exit.

- [ ] **Step 1: Write failing test for `stopAll`**

In `test/features/tunnels/data/tunnel_manager_service_test.dart`:
```dart
test('stopAll terminates all active tunnels concurrently within timeout', () async {
  await service.startTunnel(tunnel1);
  await service.startTunnel(tunnel2);

  expect(service.activeProcessCount, equals(2));
  await service.stopAll();
  expect(service.activeProcessCount, equals(0));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: FAIL (`stopAll` undefined).

- [ ] **Step 3: Implement `stopAll` and wire into exit flows**

1. In `TunnelManagerService`:
   ```dart
   Future<void> stopAll() async {
     for (final token in _cancelTokens.values) {
       token.cancel('Shutting down application');
     }
     _cancelTokens.clear();

     final activePids = _activeProcesses.keys.toList();
     await Future.wait(activePids.map((id) => stopTunnel(id)));
   }
   ```
2. Expose in `TunnelSessionsNotifier`:
   ```dart
   Future<void> stopAll() async {
     await _manager.stopAll();
     state = {};
   }
   ```
3. In `WindowService`:
   - In `onWindowClose`:
     ```dart
     if (!settings.minimizeToTray) {
       await ref.read(tunnelSessionsProvider.notifier).stopAll();
       await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
       await windowManager.destroy();
     }
     ```
   - In `_handleTrayAction('quit_app')`:
     ```dart
     await ref.read(tunnelSessionsProvider.notifier).stopAll();
     await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
     await windowManager.destroy();
     ```
4. In `SettingsPage` ("Restart Now" button):
   ```dart
   onPressed: () async {
     try {
       await ref.read(tunnelSessionsProvider.notifier).stopAll();
       await ref.read(appsNotifierProvider.notifier).stopAllServicesQuietly();
     } catch (_) {}
     if (ctx.mounted) Navigator.of(ctx).pop();
     exit(0);
   }
   ```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/tunnel_manager_service.dart lib/features/tunnels/presentation/providers/tunnel_providers.dart lib/core/services/window_service.dart lib/features/settings/presentation/settings_page.dart test/features/tunnels/data/tunnel_manager_service_test.dart
git commit -m "fix(lifecycle): enforce tunnel shutdown barrier on tray quit, window close, and restart

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Stream Decoding Hardening & Exit Authority in `ManagedBackgroundProcess`

**Files:**
- Modify: `lib/features/tunnels/data/tunnel_manager_service.dart:235-265`
- Test: `test/features/tunnels/data/tunnel_manager_service_test.dart`

**Interfaces:**
- Consumes: Stdout/stderr byte streams from CLI subprocesses.
- Produces: Resilient decoding with `allowMalformed: true` and explicit `onError` handling; exit code is the sole authority for termination.

- [ ] **Step 1: Write test simulating malformed byte stream**

```dart
test('tunnel stream listener gracefully handles malformed bytes without throwing', () async {
  final malformedController = StreamController<List<int>>();
  // Emit invalid UTF-8 bytes: 0xC0, 0xAF
  malformedController.add([0xC0, 0xAF]);
  // Verify service doesn't crash on decoding
  expect(() => service.attachStreamDecoder(malformedController.stream), returnsNormally);
});
```

- [ ] **Step 2: Run test to verify it fails or exposes lack of allowMalformed**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: Verification of stream attachment.

- [ ] **Step 3: Update stream listeners**

In `lib/features/tunnels/data/tunnel_manager_service.dart`:
```dart
  if (process is ManagedBackgroundProcess) {
    subscriptions.add(
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            handleLine,
            onError: (err) => AppLogger.warning('Tunnel stdout stream error: $err'),
          ),
    );
    subscriptions.add(
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            handleLine,
            onError: (err) => AppLogger.warning('Tunnel stderr stream error: $err'),
          ),
    );
    process.exitCode.then(
      (code) => cleanupProcess(code),
      onError: (err) => cleanupProcess(null),
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/data/tunnel_manager_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/tunnel_manager_service.dart test/features/tunnels/data/tunnel_manager_service_test.dart
git commit -m "fix(tunnels): add allowMalformed and onError handlers to process stream decoding

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Cloudflare Named-Tunnel Running Transition & UI Action Controls

**Files:**
- Modify: `lib/features/tunnels/data/drivers/cloudflare_driver.dart:8, 30-50`
- Modify: `lib/features/tunnels/presentation/pages/tunnels_page.dart:180-220`
- Modify: `lib/features/tunnels/presentation/dialogs/site_tunnel_dialog.dart:150-180`
- Test: `test/features/tunnels/data/cloudflare_driver_test.dart`

**Interfaces:**
- Consumes: Cloudflared CLI logs for named tunnels (`Registered tunnel connection`).
- Produces: Transition to `TunnelStatus.running` for token-based custom domain tunnels, and UI action availability during connecting/downloading states.

- [ ] **Step 1: Write failing test in `cloudflare_driver_test.dart`**

```dart
test('parses connection registered log as running status for named tunnels', () {
  final driver = CloudflareDriver();
  final log = '2026-09-11T12:00:00Z INF Registered tunnel connection connIndex=0';
  expect(driver.isConnectionEstablished(log), isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/cloudflare_driver_test.dart`
Expected: FAIL (`isConnectionEstablished` undefined).

- [ ] **Step 3: Implement driver recognition and UI controls**

1. In `CloudflareDriver`:
   ```dart
   static final RegExp _registeredRegex = RegExp(r'Registered tunnel connection|Connection [a-f0-9-]+ registered');

   bool isConnectionEstablished(String logLine) => _registeredRegex.hasMatch(logLine);
   ```
   In `handleLogLine`: if `isConnectionEstablished(logLine)`, return running status with `publicUrl = tunnel.customDomain != null ? 'https://${tunnel.customDomain}' : null`.
2. In `TunnelsPage` and `SiteTunnelDialog`:
   - Render active **Stop / Cancel** button when session status is `downloadingBinary` or `connecting`.
   - Disable **Edit** button when status is not `stopped` or `error`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/presentation/tunnels_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/drivers/cloudflare_driver.dart lib/features/tunnels/presentation/pages/tunnels_page.dart lib/features/tunnels/presentation/dialogs/site_tunnel_dialog.dart
git commit -m "fix(tunnels): recognize Cloudflare named-tunnel connection and provide UI cancel button

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Phase 3: Secret Persistence & Linux Runtime Permissions (PR 3)

### Task 11: Create `TunnelTokenCipher` & Enforce Encryption Boundary

**Files:**
- Create: `lib/features/tunnels/data/security/tunnel_token_cipher.dart`
- Create: `test/features/tunnels/data/security/tunnel_token_cipher_test.dart`
- Modify: `lib/features/tunnels/domain/tunnel_model.dart:18-40`
- Modify: `lib/features/settings/domain/app_settings.dart:28-50`
- Modify: `lib/features/settings/data/settings_provider.dart:40-100`
- Modify: `lib/features/tunnels/data/tunnel_manager_service.dart:115-130`
- Modify: `lib/features/tunnels/presentation/providers/tunnel_providers.dart:15-45`

**Interfaces:**
- Consumes: `LocalSecretVault.encrypt` and `LocalSecretVault.decrypt`.
- Produces: Transparent cipher boundary (`ENC:...`) in Isar database; plaintext for domain models in memory.

- [ ] **Step 1: Write tests for `TunnelTokenCipher`**

Create `test/features/tunnels/data/security/tunnel_token_cipher_test.dart`:
```dart
test('encrypts plaintext token with ENC: prefix and decrypts back', () async {
  final cipher = TunnelTokenCipher(mockVault);
  final encrypted = await cipher.encryptToken('my-secret-token');
  expect(encrypted, startsWith('ENC:'));

  final decrypted = await cipher.decryptToken(encrypted);
  expect(decrypted, equals('my-secret-token'));
});

test('decryptToken returns legacy plaintext untouched for backward compatibility', () async {
  final cipher = TunnelTokenCipher(mockVault);
  final legacyPlaintext = await cipher.decryptToken('legacy-unencrypted-token');
  expect(legacyPlaintext, equals('legacy-unencrypted-token'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tunnels/data/security/tunnel_token_cipher_test.dart`
Expected: FAIL (`TunnelTokenCipher` not found).

- [ ] **Step 3: Implement `TunnelTokenCipher` and persistence boundary**

1. Create `lib/features/tunnels/data/security/tunnel_token_cipher.dart`:
   ```dart
   import 'package:dev_stack/core/security/local_secret_vault.dart';

   class TunnelTokenCipher {
     static const String prefix = 'ENC:';
     final LocalSecretVault _vault;
     TunnelTokenCipher(this._vault);

     Future<String?> encryptToken(String? token) async {
       if (token == null || token.trim().isEmpty) return token;
       if (token.startsWith(prefix)) return token;
       final encrypted = await _vault.encrypt(token.trim());
       return '$prefix$encrypted';
     }

     Future<String?> decryptToken(String? stored) async {
       if (stored == null || stored.trim().isEmpty) return stored;
       if (!stored.startsWith(prefix)) return stored;
       final cipher = stored.substring(prefix.length);
       return await _vault.decrypt(cipher);
     }
   }
   ```
2. Add `clone()` methods to `TunnelModel` and `AppSettings`.
3. In `saveTunnel()`: clone model -> encrypt `authToken` on clone -> save clone to Isar.
4. In `tunnelsStreamProvider`: read from Isar -> clone models -> decrypt `authToken` on clones -> emit plaintext models to UI/Riverpod.
5. In `SettingsNotifier`: clone settings -> encrypt default tokens on write; decrypt on read.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/tunnels/data/security/tunnel_token_cipher_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tunnels/data/security/tunnel_token_cipher.dart lib/features/tunnels/domain/tunnel_model.dart lib/features/settings/domain/app_settings.dart lib/features/settings/data/settings_provider.dart lib/features/tunnels/data/tunnel_manager_service.dart lib/features/tunnels/presentation/providers/tunnel_providers.dart test/features/tunnels/data/security/tunnel_token_cipher_test.dart
git commit -m "feat(security): encrypt tunnel tokens at rest in Isar database via LocalSecretVault

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: Enforce Linux Executable Permissions (`+x`) on Extracted Binaries

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart:500-520, 580-600`
- Test: `test/features/apps/app_installer_service_test.dart`

**Interfaces:**
- Consumes: Detected `execFilePath` and `cliFilePath` after archive extraction.
- Produces: Explicit `chmod u+x` execution ensuring Bun, Deno, and Meilisearch are executable immediately upon extraction.

- [ ] **Step 1: Write test for executable permission assignment**

```dart
test('invokes chmod u+x on detected executable paths on Linux', () async {
  final chmodCalls = <List<String>>[];
  await AppInstallerService.ensureLinuxExecutable(
    ['/path/to/bun', '/path/to/bunx'],
    runProcess: (exec, args) async {
      if (exec == 'chmod') chmodCalls.add(args);
      return ProcessResult(1, 0, '', '');
    },
  );
  expect(chmodCalls, contains(['u+x', '/path/to/bun']));
  expect(chmodCalls, contains(['u+x', '/path/to/bunx']));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/apps/app_installer_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement explicit `chmod u+x`**

In `lib/features/apps/data/app_installer_service.dart`:
```dart
  static Future<void> ensureLinuxExecutable(
    List<String> paths, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) async {
    final runner = runProcess ?? Process.run;
    for (final path in paths) {
      if (path.isNotEmpty && File(path).existsSync()) {
        try {
          await runner('chmod', ['u+x', path]);
        } catch (_) {}
      }
    }
  }
```
Call `ensureLinuxExecutable` right after archive extraction completes in `_detectFiles`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/apps/app_installer_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/apps/data/app_installer_service.dart test/features/apps/app_installer_service_test.dart
git commit -m "fix(apps): explicitly set +x permission on extracted binaries on Linux

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 13: Inject Node Directory into Child PATH for Linux `npm config set prefix`

**Files:**
- Modify: `lib/core/services/path_service.dart:614-630`
- Test: `test/core/services/path_service_test.dart`

**Interfaces:**
- Consumes: `nodeBin`, `npmBin`.
- Produces: Child process execution carrying `dirname(nodeBin)` in `PATH`, resolving `env: node: No such file or directory`.

- [ ] **Step 1: Write test for child PATH in `npm config set prefix`**

In `test/core/services/path_service_test.dart`:
```dart
test('configureLinuxNpmPrefix passes node directory in process environment PATH', () async {
  Map<String, String>? capturedEnv;
  await PathService.configureLinuxNpmPrefix(
    npmBin: '/apps/node20/bin/npm',
    nodeBin: '/apps/node20/bin/node',
    targetPrefix: '/home/user/.npm-global',
    runProcess: (exec, args, {environment}) async {
      capturedEnv = environment;
      return ProcessResult(1, 0, '', '');
    },
  );
  expect(capturedEnv?['PATH'], contains('/apps/node20/bin'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/path_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement child PATH injection**

In `lib/core/services/path_service.dart`:
```dart
  static Future<bool> configureLinuxNpmPrefix({
    required String npmBin,
    required String nodeBin,
    required String targetPrefix,
    Future<ProcessResult> Function(String, List<String>, {Map<String, String>? environment})? runProcess,
  }) async {
    final runner = runProcess ?? ((e, a, {environment}) => Process.run(e, a, environment: environment));
    final nodeDir = p.dirname(nodeBin);
    final currentPath = Platform.environment['PATH'] ?? '';
    final env = {'PATH': '$nodeDir:$currentPath'};

    try {
      final res = await runner(npmBin, ['config', 'set', 'prefix', targetPrefix, '-g'], environment: env);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/path_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/path_service.dart test/core/services/path_service_test.dart
git commit -m "fix(linux): inject Node directory into PATH when configuring npm prefix

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Phase 4: Catalog Network Integrity, Global Error Boundaries & Code Health (PR 4)

### Task 14: Enforce HTTPS for MariaDB in Catalog Files & `update.js`

**Files:**
- Modify: `assets/data/apps.json:516-521`
- Modify: `assets/data/new-apps.json:818-823`
- Modify: `assets/data/update.js:350-380`
- Modify: `lib/features/apps/data/apps_repository.dart:60-80`
- Test: `test/features/apps/data/apps_repository_test.dart`

**Interfaces:**
- Consumes: Catalog JSON files and release updater.
- Produces: Strict HTTPS URLs across all MariaDB catalog download links; rejection/upgrade of unencrypted HTTP links at catalog load time.

- [ ] **Step 1: Write test verifying no `http://` download URLs in catalog**

In `test/features/apps/data/apps_repository_test.dart`:
```dart
test('apps catalog contains zero unencrypted http download URLs', () async {
  final catalogFile = File('assets/data/apps.json');
  final content = await catalogFile.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;
  final apps = json['apps'] as List<dynamic>;

  for (final app in apps) {
    final downloadUrl = app['download_url'] as String?;
    if (downloadUrl != null && downloadUrl != 'package_manager') {
      expect(
        downloadUrl.startsWith('https://'),
        isTrue,
        reason: 'App ${app['id']} has insecure download URL: $downloadUrl',
      );
    }
  }
});
```

- [ ] **Step 2: Run test to verify it fails on MariaDB entries**

Run: `flutter test test/features/apps/data/apps_repository_test.dart`
Expected: FAIL (identifies 6 `http://downloads.mariadb.org` URLs).

- [ ] **Step 3: Update catalog files and `update.js`**

1. In `assets/data/apps.json` and `assets/data/new-apps.json`: change `http://downloads.mariadb.org` to `https://downloads.mariadb.org`.
2. In `assets/data/update.js`: enforce `https:` in MariaDB release URL mapping.
3. In `lib/features/apps/data/apps_repository.dart`: add URL validation warning or auto-upgrade in `mergeAppsCatalog`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/apps/data/apps_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/data/apps.json assets/data/new-apps.json assets/data/update.js lib/features/apps/data/apps_repository.dart test/features/apps/data/apps_repository_test.dart
git commit -m "fix(catalog): enforce HTTPS for MariaDB download URLs

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 15: Wrap Desktop Entry Point in `runZonedGuarded` & Global Error Dispatchers

**Files:**
- Modify: `lib/main.dart:28-105`

**Interfaces:**
- Consumes: Flutter application lifecycle & zone exceptions.
- Produces: Centralized capture of unhandled asynchronous exceptions in `AppLogger` and isolated autostart per tunnel.

- [ ] **Step 1: Check existing main.dart structure**

Review lines 28-105 of `lib/main.dart` to verify Riverpod initialization and autostart loops.

- [ ] **Step 2: Add `runZonedGuarded`, `FlutterError.onError`, and `PlatformDispatcher.instance.onError`**

In `lib/main.dart`:
```dart
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.error('Flutter framework error: ${details.exceptionAsString()}', details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Platform unhandled error: $error', stack);
      return true; // handled
    };

    // Initialize window and core services...
    runApp(const ProviderScope(child: DevStackApp()));
  }, (error, stack) {
    AppLogger.error('Root zone unhandled error: $error', stack);
  });
}
```

In tunnel autostart loop in `main.dart`:
```dart
for (final tunnel in autoStartTunnels) {
  try {
    // Decrypt model before passing to startTunnel
    final decrypted = await cipher.decryptModel(tunnel);
    await tunnelManager.startTunnel(decrypted);
  } catch (e, st) {
    AppLogger.error('Failed to autostart tunnel ${tunnel.name}: $e', st);
  }
}
```

- [ ] **Step 3: Run full analyzer and tests**

Run: `flutter analyze`
Run: `flutter test`
Expected: PASS with 0 issues.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(core): wrap desktop entry point in runZonedGuarded and isolate tunnel autostart

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 16: Refactor `update.js` Cognitive Complexity & Document Standards

**Files:**
- Modify: `assets/data/update.js:174-240`

**Interfaces:**
- Consumes: GitHub Releases API assets.
- Produces: Cognitive complexity below 15 for SonarQube S3776.

- [ ] **Step 1: Extract helper functions in `update.js`**

Extract `_pickWindowsAsset(assets, repoPath)` and `_pickLinuxAsset(assets)` out of `fetchGithubReleases`:
```javascript
function _pickWindowsAsset(assets, repoPath) {
  return assets.find(a => {
    const name = a.name.toLowerCase();
    if (!name.endsWith('.zip') && !name.endsWith('.exe')) return false;
    if (name.includes('arm64') || name.includes('32bit') || name.includes('ia32')) return false;
    return true;
  });
}

function _pickLinuxAsset(assets) {
  return assets.find(a => {
    const name = a.name.toLowerCase();
    return (name.includes('linux') || name.includes('unknown-linux-gnu')) &&
      (name.includes('x86_64') || name.includes('amd64')) &&
      (name.endsWith('.tar.gz') || name.endsWith('.zip'));
  });
}
```

- [ ] **Step 2: Run update script dry run or test**

Run: `node -c assets/data/update.js`
Expected: Syntax check passes with 0 errors.

- [ ] **Step 3: Commit**

```bash
git add assets/data/update.js
git commit -m "refactor(scripts): reduce cognitive complexity in update.js fetchGithubReleases

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 10. Verification Plan

### Automated Test Suite
- Run all unit tests: `flutter test`
- Run static analysis: `flutter analyze`

### Manual Verification Checklist
1. **Linux Privilege Boundaries**: Verify package manager commands run without `/tmp/install.sh` being written to disk.
2. **mkcert Local CA**: Verify `mkcert -install` runs without root privileges and adds Root CA to system store via `/usr/local/share/ca-certificates/`.
3. **Site Terminal**: Verify launching terminal on a path with `$()` does not trigger command execution.
4. **Tunnel Lifecycle**: Verify double-clicking Start does not create duplicate processes; verify closing app from tray cleanly kills `cloudflared` and `ngrok`.
5. **Credential Security**: Inspect `default.isar` on disk to verify stored tokens begin with `ENC:`.
