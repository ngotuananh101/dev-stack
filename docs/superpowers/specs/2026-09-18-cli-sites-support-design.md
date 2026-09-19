# Design Spec: CLI Sites Support (Node.js, Bun, Deno, Custom CLI Apps)

**Date:** 2026-09-18  
**Status:** Approved by User  
**Author:** Claude Code & Ngo Tuan Anh  

---

## 1. Overview & Objectives

Currently, DevStack supports three site types: `php`, `static`, and `proxy`. Modern web development frequently requires running runtime applications via command line interfaces (e.g., Node.js with Next.js/Vite/Express, Bun, Deno, Python FastAPI/Flask, Go, etc.) running on a local port.

This feature introduces full-lifecycle CLI application management within DevStack:
1. **Managed Process Lifecycle**: Start, stop, restart, and monitor background CLI processes with cross-platform process tree termination (preventing orphaned/zombie processes).
2. **Reverse Proxy & WebSocket Support**: Automated Nginx, Apache, and Caddy virtual host generation forwarding traffic from a local custom domain (e.g., `my-app.test`) to the application's local port, complete with full WebSocket and HTTP/1.1 Upgrade support for Hot Module Reloading (HMR).
3. **Live Terminal Logging**: Capture stdout/stderr in a real-time circular memory buffer (~1,000 lines) viewable in an integrated live log terminal modal, while simultaneously appending to physical log files.
4. **Convenient Presets**: Fast scaffolding with presets for Node.js (npm/pnpm/yarn), Bun, Deno, and Custom commands.

---

## 2. Architecture & Components

```
+-------------------------------------------------------------+
|                        DevStack UI                          |
|  +------------------+  +---------------+  +---------------+  |
|  |   Add/Edit Site  |  |   SiteTable   |  | SiteLogsModal |  |
|  |  (CLI Presets)   |  | (Start/Stop)  |  |  (Live Stream)|  |
|  +--------+---------+  +-------+-------+  +-------+-------+  |
+-----------|--------------------|------------------|---------+
            |                    |                  |
            v                    v                  v
+-------------------------------------------------------------+
|                SitesProvider & CliProcessManager            |
|  - Manages Isar SiteModel (siteType: 'cli', command, port)  |
|  - Process lifecycle: start, stop, restart, autoStart       |
|  - Process tree kill (POSIX setsid/kill, Windows taskkill)   |
|  - Memory circular buffer + Disk log file append            |
+------------------------------+------------------------------+
                               |
            +------------------+------------------+
            |                                     |
            v                                     v
+-----------------------+             +-----------------------+
|  Webserver Generator  |             | System Process Spawn  |
|  - Nginx Config       |             | - Node.js (npm/pnpm)  |
|  - Apache Config      |             | - Bun / Deno          |
|  - Caddy Config       |             | - Custom CLI Commands |
| (Reverse Proxy + HMR) |             +-----------------------+
+-----------------------+
```

---

## 3. Data Model Changes (`SiteModel`)

In `lib/features/sites/domain/site_model.dart`:
* `siteType`: Support `'cli'` as a valid type in addition to `'php'`, `'static'`, `'proxy'`.
* `command` (`String?`): Start command executed in `rootDir` (e.g., `npm run dev`, `bun dev`).
* `port` (`int?`): The internal local port the CLI app binds to (e.g., `3000`, `5173`, `8000`).
* `autoStart` (`bool`, default: `false`): Whether DevStack automatically launches the process on boot.

Run `build_runner` to regenerate `site_model.g.dart`.

---

## 4. Webserver Reverse Proxy Configurations

When `siteType == 'cli'`, the site forwards traffic to `http://127.0.0.1:$port`.

### 4.1. Nginx (`NginxConfigBuilder`)
Includes HTTP/1.1 and WebSocket upgrade headers for modern frontend dev servers:
```nginx
location / {
    proxy_pass http://127.0.0.1:<PORT>;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
}
```

### 4.2. Apache (`ApacheConfigBuilder`)
Includes proxy directives and websocket tunnel handling:
```apache
RewriteEngine On
RewriteCond %{HTTP:Upgrade} =websocket [NC]
RewriteRule /(.*)           ws://127.0.0.1:<PORT>/$1 [P,L]
RewriteCond %{HTTP:Upgrade} !=websocket [NC]
RewriteRule /(.*)           http://127.0.0.1:<PORT>/$1 [P,L]

ProxyPassReverse / http://127.0.0.1:<PORT>/
```

### 4.3. Caddy (`CaddyConfigBuilder`)
Caddy natively handles WebSockets in `reverse_proxy`:
```json
{
  "handler": "reverse_proxy",
  "upstreams": [{"dial": "127.0.0.1:<PORT>"}]
}
```

---

## 5. Process Lifecycle Management (`CliProcessManager`)

Create `lib/features/sites/data/cli_process_manager.dart`:

### 5.1. Starting Processes
* Uses system shell to support complex commands (e.g. `npm run dev`, chaining, or scripts with args):
  - **Linux / macOS:** `Process.start('/bin/sh', ['-c', command], workingDirectory: rootDir, environment: env)`
  - **Windows:** `Process.start('cmd.exe', ['/c', command], workingDirectory: rootDir, environment: env)`
* Preserves and extends current `Platform.environment` so tools installed in user paths (`~/.nvm/`, `~/.bun/bin`, `~/.deno/bin`, `AppData\Roaming\npm`) are readily resolved.

### 5.2. Stopping Processes Cleanly (Process Tree Killing)
Killing a shell wrapper often leaves the actual node/bun child process running and holding the port.
* **Linux / macOS:** Run `kill -TERM -- -<pid>` or use `killProcessTree` to kill the entire process group. If still alive after 2 seconds, escalate to `kill -KILL -- -<pid>`.
* **Windows:** Execute `taskkill /F /T /PID <pid>` to terminate child processes along with the parent.

### 5.3. Log Buffering & Streaming
* Maintain an in-memory `CircularBuffer<String>` (capacity: 1,000 lines) per active `site.id`.
* Expose a `Stream<String>` or broadcast notifier per site so `SiteLogsModal` receives real-time output chunks.
* Concurrently append stdout/stderr lines into `<AppConfig.logsDir>/sites/<domain>.log`.

### 5.4. Auto-Start & App Shutdown Integration
* In `SitesNotifier.build()`: Look for sites with `siteType == 'cli' && autoStart == true` and trigger their startup in a microtask.
* In `WindowService` / app exit handler: Call `cliProcessManager.stopAll()` to cleanly shutdown all CLI child processes before terminating DevStack.

---

## 6. User Interface Design

### 6.1. Add & Edit Site Modals
1. **Site Type Selector:**
   Add `CLI App` (icon: `LucideIcons.terminal`, value: `'cli'`).
2. **CLI Configuration Section (visible when `siteType == 'cli'`):**
   * **Preset Dropdown:**
     - Node.js (npm): `npm run dev`, Port `3000`
     - Node.js (pnpm): `pnpm dev`, Port `3000`
     - Node.js (yarn): `yarn dev`, Port `3000`
     - Bun: `bun dev`, Port `3000`
     - Deno: `deno task dev`, Port `8000`
     - Custom: user-provided command
   * **Start Command Field:** Required validation, hint `npm run dev`.
   * **Port Field:** Integer validation (1–65535), hint `3000`.
   * **Root Directory:** Directory picker, must exist on filesystem.
   * **Auto-start with DevStack:** Switch/Checkbox (`autoStart`).

### 6.2. Site Table (`SiteTable`)
* **Type Column:** Display badge `CLI :3000` with terminal icon.
* **Status & Controls:**
  - Status indicator: Green badge `Running` with subtle pulse, or Grey `Stopped`.
  - Action buttons:
    - **Play / Stop** button (toggles running state).
    - **Restart** button (active only when running).
    - **View Logs** button (opens `SiteLogsModal`).

### 6.3. Live Logs Modal (`SiteLogsModal`)
* Terminal styled dialog (`#1E1E1E` background, Courier/Monospace font).
* Displays last 1,000 lines from memory buffer and streams incoming lines.
* Controls:
  - **Auto-scroll** toggle.
  - **Clear** output button.
  - **Copy all** button.
  - **Open log file** in system editor.

---

## 7. Testing Strategy

1. **Unit Tests for Webserver Builders:**
   - Verify Nginx config generates correct WebSocket upgrade headers and `proxy_pass http://127.0.0.1:$port`.
   - Verify Apache config generates correct `RewriteCond %{HTTP:Upgrade}` and `ProxyPassReverse`.
   - Verify Caddy config generates correct reverse_proxy block.
2. **Unit Tests for `CliProcessManager`:**
   - Starting a process records PID and changes status to running.
   - Stdout/stderr are correctly added to the memory buffer and stream.
   - Stopping process cleanly invokes process tree kill and updates state.
   - Port validation and command validation reject malformed inputs.
3. **Widget Tests:**
   - `AddSiteModal` correctly shows CLI options when CLI tab is selected.
   - Preset selection auto-fills command and port.
   - Form validation catches empty commands or invalid ports.
4. **Full Regression Test:**
   - Run `flutter test` across the entire test suite ensuring 100% pass rate.
