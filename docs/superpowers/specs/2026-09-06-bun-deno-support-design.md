# Architecture Design: Bun and Deno Runtime Support & Isolated Global Package Management

- **Date:** 2026-09-06
- **Status:** Approved
- **Target Systems:** Windows (x64) & Linux (x64)
- **Author:** DevStack Architecture Team

---

## 1. Overview & Context

DevStack is a developer environment manager on Windows and Linux designed to run and isolate multiple web servers (Nginx, Apache, Caddy), databases (MySQL, MariaDB, PostgreSQL, MongoDB, Redis), and programming runtimes (PHP, Python/pyenv, Node.js).

As JavaScript/TypeScript ecosystems evolve, **Bun** and **Deno** have become major modern runtimes:
- **Bun**: Ultra-fast all-in-one JavaScript/TypeScript runtime, bundler, test runner, and package manager (`bun`, `bunx`).
- **Deno**: Secure-by-default runtime for JavaScript and TypeScript with built-in toolchains (`deno`).

Currently, Node.js global packages are configured to install directly into `C:\Ponta\bin` via `npm config set prefix binDir -g`. Over time, this mixes runtime-installed binaries with DevStack's own shims, posing risks of naming collisions, accidental deletion during uninstallation, or permission conflicts.

### Goals
1. Provide first-class support for downloading, installing, versioning, and shimming **Bun** and **Deno** on both Windows (x64) and Linux (x64).
2. Isolate global package directories for all three JavaScript runtimes (**Node.js/NPM**, **Bun**, and **Deno**) by directing them to standard user global locations and appending those directories to the User `PATH`, keeping `C:\Ponta\bin` (and `~/.local/share/ponta/bin`) clean and dedicated solely to DevStack shims.
3. Automatically update releases through `update.js` using GitHub API releases with Semantic Versioning (latest patch per minor).
4. Provide official branding (icons and colors) in the DevStack UI.

---

## 2. Architecture & Components

```
+-------------------------------------------------------------+
|                      DevStack UI                            |
| (AppsPage, AppVersionModal, CompactAppsTable, CategoryBar)   |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                     Catalog Layer                           |
|   assets/data/apps.json & apps-linux.json                   |
|   assets/data/update.js (GitHub Release Fetchers)           |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                   AppInstallerService                       |
|   - Download payload (ZIP) with SHA256 checksums            |
|   - _extractPayload (_installFromZip)                       |
|   - _flattenDirectory (un-nest bun-windows-x64/)            |
|   - ensureLinuxPermissions (chmod +x bun / deno)            |
|   - _configureRuntimes (post-install preparation)           |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
|                       PathService                           |
|   - Manage Core Shims / Symlinks in DevStack binDir:        |
|       * bun, bunx                                           |
|       * deno                                                |
|       * node, npm, npx, corepack                            |
|   - Manage Isolated Global Package PATH Entries (User PATH):|
|       * NPM:  %APPDATA%\npm           / ~/.npm-global/bin   |
|       * Bun:  %USERPROFILE%\.bun\bin  / ~/.bun/bin          |
|       * Deno: %USERPROFILE%\.deno\bin / ~/.deno/bin         |
+-------------------------------------------------------------+
```

---

## 3. Detailed Design

### 3.1 Catalog & Version Automation (`update.js`)

#### App Definitions
Add `bun` and `deno` to `COMMON_APP_DEFINITIONS`:

```javascript
bun: {
  id: "bun",
  name: "Bun",
  description: "Fast all-in-one JavaScript runtime & toolkit.",
  category: "runtime",
  group_name: "bun",
  repo: "oven-sh/bun",
},
deno: {
  id: "deno",
  name: "Deno",
  description: "A modern, secure runtime for JavaScript and TypeScript.",
  category: "runtime",
  group_name: "deno",
  repo: "denoland/deno",
}
```

In `baseWindowsApps`:
- `makeBinaryApp(COMMON_APP_DEFINITIONS.bun, "bun.exe", "bun.exe")`
- `makeBinaryApp(COMMON_APP_DEFINITIONS.deno, "deno.exe", "deno.exe")`

In `baseLinuxApps`:
- `makeBinaryApp(COMMON_APP_DEFINITIONS.bun, "bun", "bun")`
- `makeBinaryApp(COMMON_APP_DEFINITIONS.deno, "deno", "deno")`

#### Fetcher Enhancements
Update GitHub release parsing in `fetchersWindows` and `fetchersLinux`:
1. **Tag Version Parsing**:
   Tags in `oven-sh/bun` use the prefix `bun-v1.2.4`. The tag cleaner regex is updated:
   `/^(bun-v|v|release-|redis-|redis|r(?=\d))/i`
2. **Asset Matching**:
   - **Bun (Windows)**: Matches `bun-windows-x64.zip` (excludes `baseline`, `profile`, `aarch64`).
   - **Bun (Linux)**: Matches `bun-linux-x64.zip` (excludes `musl`, `baseline`, `profile`, `aarch64`).
   - **Deno (Windows)**: Matches `deno-x86_64-pc-windows-msvc.zip`.
   - **Deno (Linux)**: Matches `deno-x86_64-unknown-linux-gnu.zip`.
3. **Version Grouping**:
   Filter with `sortVersionsObject` to pick the latest patch for each minor release line.

---

### 3.2 Installation & Runtime Configuration (`AppInstallerService`)

1. **Extraction**:
   Both runtimes deliver `.zip` archives for both Windows and Linux.
   `_extractPayload` routes them to `_installFromZip`.
2. **Directory Flattening (`_flattenDirectory`)**:
   Bun archives contain a top-level directory (`bun-windows-x64/` or `bun-linux-x64/`).
   The existing `_flattenDirectory` detects the single nested folder and renames contents into the application root (`C:\Ponta\apps\bun\` or `~/.local/share/ponta/apps/bun/`).
3. **Executable Detection (`_detectFiles`)**:
   Locates `bun.exe` / `bun` and `deno.exe` / `deno`.
4. **Linux Permissions**:
   Ensures `chmod 755` via `ensureLinuxPermissions`.
5. **Post-Installation Runtime Configuration (`_configureRuntimes`)**:
   - **Bun on Windows**: Ensure `bunx.exe` exists in `installPath` (copy or hardlink `bun.exe` to `bunx.exe`) so Windows shims or direct executions recognize `bunx`.

---

### 3.3 Path Management & Global Package Isolation (`PathService`)

To keep `binDir` (`C:\Ponta\bin` / `~/.local/share/ponta/bin`) clean, global packages for runtimes are stored in dedicated directories.

#### Global Package Directories

| Runtime | Windows Directory | Linux Directory | Configuration Command |
| :--- | :--- | :--- | :--- |
| **Node.js (NPM)** | `%APPDATA%\npm` | `~/.npm-global/bin` | Linux: `npm config set prefix ~/.npm-global -g`<br>Windows: default `%APPDATA%\npm` |
| **Bun** | `%USERPROFILE%\.bun\bin` | `~/.bun\bin` | Built-in default |
| **Deno** | `%USERPROFILE%\.deno\bin` | `~/.deno\bin` | Built-in default |

#### Adding to PATH (`addAppToPath`)

1. **Core Binaries Shimming in `binDir`**:
   - **Bun**:
     - Windows: Create shims for `bun` and `bunx` (`bun.cmd`, `bun.bat`, `bun` and `bunx.cmd`, `bunx.bat`, `bunx` pointing to `bun.exe`).
     - Linux: Create symlinks `bun` -> `installPath/bun` and `bunx` -> `installPath/bun`.
   - **Deno**:
     - Windows: Create shims for `deno` (`deno.cmd`, `deno.bat`, `deno` pointing to `deno.exe`).
     - Linux: Create symlink `deno` -> `installPath/deno`.
   - **Node.js**:
     - Windows: Create shims for `node`, `npm`, `npx`, `corepack` and symlink `node.exe`. Do NOT set npm prefix to `binDir`.
     - Linux: Create symlinks for `node`, `npm`, `npx`, `corepack`. Set npm prefix to `~/.npm-global`.

2. **User PATH Environment Variable Integration**:
   - Helper `ensureUserDirectoryInPath(String dir)`:
     - On Windows: Check `[Environment]::GetEnvironmentVariable("PATH", "User")`. If absent, append with `;` via `windowsSetUserEnvCommand`.
     - On Linux: Check `~/.profile` / `~/.bashrc` / `~/.zshrc`. If absent, add export statement.
   - When adding `nodejs` to PATH: add `%APPDATA%\npm` (Windows) or `~/.npm-global/bin` (Linux).
   - When adding `bun` to PATH: add `%USERPROFILE%\.bun\bin` (Windows) or `~/.bun/bin` (Linux).
   - When adding `deno` to PATH: add `%USERPROFILE%\.deno\bin` (Windows) or `~/.deno/bin` (Linux).

#### Removing from PATH (`removeAppFromPath`)

1. Delete runtime shims and symlinks from `binDir`:
   - `bun` and `bunx`.
   - `deno`.
   - `node`, `npm`, `npx`, `corepack`.
2. Helper `removeUserDirectoryFromPath(String dir)`:
   - On Windows: Remove the entry from User PATH environment variable and broadcast change.
   - On Linux: Clean profile entry if present.

---

### 3.4 UI & Brand Integration

1. **Brand Assets**:
   - `assets/images/bun.png`: Official Bun logo (transparent PNG).
   - `assets/images/deno.png`: Official Deno logo (transparent PNG).
2. **Icon Mapping (`_getIconFileName`)**:
   ```dart
   if (id.contains('bun')) return 'bun';
   if (id.contains('deno')) return 'deno';
   ```
3. **Brand Accent Colors (`_getIconColor`)**:
   - Bun: `Color(0xFFE5A83B)` (Warm golden bun tone).
   - Deno: `Color(0xFF70FFAF)` (Deno mint/green tone) or `Color(0xFF222222)`.

---

## 4. Security & Isolation Considerations

1. **Path Traversal Protection**:
   All archives (.zip) continue to pass through `_extractZip` which canonicalizes and validates path prefixes against `..` traversals.
2. **Executable Permissions on Linux**:
   Binaries are explicitly chmodded `0755` using POSIX permissions.
3. **No Sudo for Global Packages**:
   By using `~/.npm-global` on Linux instead of `/usr/local` or root-owned locations, `npm -g`, `bun add -g`, and `deno install -g` execute without requiring root/sudo privileges.
4. **Clean DevStack binDir**:
   No external packages or package-generated scripts pollute DevStack's central `bin` directory, preventing shim tampering or shadowing.

---

## 5. Testing Strategy

1. **Catalog Tests (`test/assets/bun_deno_catalog_test.dart`)**:
   - Verify `apps.json` and `apps-linux.json` contain valid `bun` and `deno` configurations.
   - Verify download URLs point to HTTPS GitHub releases.
   - Verify presence and readability of `assets/images/bun.png` and `assets/images/deno.png`.
2. **PathService Tests (`test/core/services/path_service_runtimes_test.dart`)**:
   - Verify shims generated for Bun include both `bun` and `bunx`.
   - Verify shims generated for Deno include `deno`.
   - Verify isolated global path resolution for NPM, Bun, and Deno across Windows and Linux.
   - Verify User PATH manipulation and cleanup.
3. **Installer Tests (`test/features/apps/installer_runtimes_test.dart`)**:
   - Verify directory flattening logic handles nested `bun-*` archives.
   - Verify post-install configuration creates `bunx.exe` on Windows.
