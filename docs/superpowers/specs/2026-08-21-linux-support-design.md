# Design Document: Linux OS Support for Ponta DevStack

**Date:** 2026-08-21  
**Status:** Approved  
**Topic:** Cross-platform Linux Desktop Support for DevStack  

---

## 1. Overview & Objectives

DevStack was initially created and optimized for Windows. This document outlines the architecture, implementation details, and packaging workflow to make DevStack a first-class citizen on **Linux (Ubuntu, Debian, Fedora, Arch, etc.)** while preserving 100% backward compatibility and architectural integrity with Windows.

### Core Goals
- **Native User Experience**: Clean desktop integration using Flutter Linux Desktop (GTK 3), System Tray (AppIndicator), and Polkit (`pkexec`) authentication.
- **Independent User-Space Architecture**: Defaults to `~/.ponta` for zero-friction installation without requiring root privileges for standard operations.
- **Dedicated Portable Linux Catalog**: Separate `apps-linux.json` featuring portable tarballs and binaries unpacked via system `tar` with full permission and symlink preservation.
- **Robust Process & Service Control**: Full lifecycle management using standard POSIX signals (`SIGTERM`, `SIGKILL`), process groups, and elevation via `pkexec`.

---

## 2. Directory Structure & Paths (`AppConfig`)

### OS-Aware Base Directories
| Operating System | Default Base Directory | Subdirectories |
| :--- | :--- | :--- |
| **Windows** | `C:\Ponta` | `apps\`, `bin\`, `logs\`, `www\`, `certs\`, `vhosts\`, `data\` |
| **Linux** | `~/.ponta` (or `$XDG_DATA_HOME/ponta`) | `apps/`, `bin/`, `logs/`, `www/`, `certs/`, `vhosts/`, `data/` |

### Path Resolution
`AppConfig` dynamically determines the default directory based on `Platform.isLinux` vs `Platform.isWindows`. All path concatenations across the codebase use `p.join(...)` or forward slashes rather than hardcoded Windows backslashes (`\`).

```dart
static String get defaultBaseDir {
  if (Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, '.ponta');
  }
  return 'C:\\Ponta';
}
```

---

## 3. Process Execution & Privilege Escalation (`BackgroundProcess`)

### Standard Background Processes
* **Windows**: Wraps execution in `wscript.exe` and PowerShell scripts to suppress console windows.
* **Linux**:
  * Uses Dart `Process.start` / `Process.run` directly with `ProcessStartMode.normal` or `ProcessStartMode.detachedWithStdio`.
  * Preserves environment variables and standard I/O streams.

### Process Teardown & Killing
* Graceful shutdown: Sends `ProcessSignal.sigterm` to the child or its process group (`kill -TERM -$PGID`).
* Force shutdown: If unresponsive after 3 seconds, escalates to `ProcessSignal.sigkill` (`kill -KILL -$PGID`).
* Port conflict inspection: Uses `ss -tulpn` or `lsof -i :<port>` instead of Windows `netstat -ano`.

### Elevated Privileges (`runElevated`)
When modifying protected system resources (e.g. `/etc/hosts` or installing mkcert CA root):
1. **Primary GUI Escalation**: Uses `pkexec <command>` (Polkit) to invoke the desktop's native authentication dialog.
2. **Fallback**: If `pkexec` is not available, falls back to `sudo -S` or desktop askpass helpers (`zenity --password`, `kdialog --password`).

---

## 4. PATH Management, Shims & SSL (`PathService`, `HostsRepository`, `SslService`)

### 1. PATH Persistence (`PathService`)
* Ensures `~/.ponta/bin` is in the user's `$PATH`.
* Checks shell profile files: `~/.bashrc`, `~/.zshrc`, `~/.profile`.
* Appends `export PATH="$HOME/.ponta/bin:$PATH"` if absent.

### 2. Binary Shims & Symlinks
* On Linux, instead of generating `.bat`/`.cmd` files:
  * Creates executable POSIX shell wrappers (`chmod 755`) or direct filesystem symlinks (`Link.createSync`) in `~/.ponta/bin/<app_name>`.
  * For Node.js: Configures global prefix via `npm config set prefix ~/.ponta/bin -g`.

### 3. Hosts File (`HostsRepository`)
* **File Target**: `/etc/hosts` (instead of `C:\Windows\System32\drivers\etc\hosts`).
* **Writing Flow**:
  1. Attempts direct write (if running as root or write permissions exist).
  2. Fallback: Writes modified content with PONTA delimiter comments to `/tmp/ponta_hosts_temp` and executes:
     ```bash
     pkexec cp /tmp/ponta_hosts_temp /etc/hosts
     ```
  3. Deletes the temporary file.

### 4. Local SSL / CA Root (`SslService`)
* Integrates Linux `mkcert` binary under `assets/bin/linux/mkcert` (or uses installed system `mkcert`).
* Automatically runs `chmod +x` on the binary.
* Trust store installation: Invokes `pkexec <mkcertPath> -install`.

---

## 5. App Catalog & Installer (`apps-linux.json`, `AppInstallerService`)

### Catalog Structure (`assets/data/apps-linux.json`)
Catalog tailored for Linux binaries/tarballs:
* `exec_file`: `bin/node`, `bin/nginx`, `caddy`, `bin/mysqld`, `sbin/php-fpm` (ELF binaries instead of `.exe`).
* `cli_file`: Command-line executable entry (e.g. `bin/node`, `bin/php`, `bin/caddy`).
* `versions`: Official upstream Linux x64 tarball / gzip / xz download URLs.

### Extraction via System `tar`
* When downloading `.tar.gz`, `.tar.xz`, or `.tgz`:
  * Spawns `tar -xf <archive_file> -C <destination_dir>` (or `--strip-components=1` where applicable).
  * Fast extraction while preserving file modes, executable bits, and internal symbolic links.
* Automatically runs `chmod 755` on the primary executable and all binaries within `bin/` and `sbin/`.

---

## 6. Desktop Integration & Flutter Linux Runner

### 1. Flutter Linux Runner Files
Scaffolding standard Flutter Linux runner files:
* `linux/CMakeLists.txt`
* `linux/main.cc`
* `linux/my_application.h`, `linux/my_application.cc`

### 2. System Tray & Window Manager
* `window_manager`: Native GTK 3 desktop integration.
* `tray_manager`: Uses `libayatana-appindicator3` / `libappindicator3`.
* `launch_at_startup`: Generates `~/.config/autostart/ponta-dev-stack.desktop`.

### 3. Packaging & Distribution Targets
* **AppImage**: Primary zero-install portable single-file bundle.
* **Deb Package (`.deb`)**: Standard distribution package for Debian/Ubuntu systems with desktop launcher and icons.
* **Tarball (`.tar.gz`)**: Portable standalone distribution.

---

## 7. Testing & Verification Plan

1. **Unit & Logic Tests**:
   * Mock `Platform.isLinux` and test `AppConfig.defaultBaseDir`, `PathService.shimPathsFor`, and `HostsRepository.hostsPath`.
   * Test `apps-linux.json` catalog validation (ensures valid URLs and correct ELF executable filenames).
2. **Service Lifecycle Tests**:
   * Verify process start, stop, signals, and PID resolution under Linux mocking.
   * Verify `tar` unpack invocation and permission setting.
3. **End-to-End Build & Run**:
   * Run `flutter analyze` to ensure strict typing and zero lint warnings.
   * Verify Flutter Linux build target compatibility.
