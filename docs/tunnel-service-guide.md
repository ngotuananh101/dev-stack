# Tunnel Service Guide

DevStack includes a unified **Tunnel Service** that lets you expose any local site or port to the public internet using either **Cloudflare Tunnel** or **ngrok**. Tunnels are managed from the **Tunnels** page in the sidebar, and 1-click sharing is available directly from the **Sites** table.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Cloudflare Quick Tunnels](#cloudflare-quick-tunnels)
3. [Cloudflare Named Tunnels](#cloudflare-named-tunnels)
4. [ngrok Tunnels](#ngrok-tunnels)
5. [Managing Tunnels in the Tunnels Page](#managing-tunnels-in-the-tunnels-page)
6. [1-Click Sharing from the Sites Table](#1-click-sharing-from-the-sites-table)
7. [Exposing Custom Ports vs DevStack Sites](#exposing-custom-ports-vs-devstack-sites)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The Tunnel subsystem is built around a **driver-based architecture** with three layers:

```
┌──────────────────────────────────────────────────────┐
│                     UI Layer                         │
│  TunnelsPage  |  CreateTunnelModal  |  QR/Logs modals │
│  SiteTunnelDialog (1-click from Sites table)          │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│               Service Layer                          │
│  TunnelManagerService (orchestrator)                 │
│  ├─ Downloads & manages tunnel binaries              │
│  ├─ Spawns tunnel processes via BackgroundProcess    │
│  ├─ Parses logs to extract public URLs & inspector   │
│  ├─ Tracks active sessions (status, URL, PID)        │
│  └─ Persists tunnel configs to Isar DB               │
│                                                      │
│  TunnelDownloaderService                             │
│  ├─ Downloads cloudflared or ngrok binary             │
│  └─ Extracts & sets permissions                     │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│                Driver Layer                          │
│  TunnelDriver (abstract interface)                    │
│  ├─ CloudflareDriver — parses *.trycloudflare.com     │
│  └─ NgrokDriver    — parses JSON logs, ngrok URLs     │
└──────────────────────────────────────────────────────┘
```

### Key Components

| Component | File | Description |
|---|---|---|
| `TunnelModel` | `lib/features/tunnels/domain/tunnel_model.dart` | Isar entity storing tunnel configuration (name, provider, target, tokens, auto-start) |
| `TunnelSession` | `lib/features/tunnels/domain/tunnel_session.dart` | Runtime state (status, public URL, PID, logs, download progress) |
| `TunnelDriver` | `lib/features/tunnels/domain/tunnel_driver.dart` | Abstract interface for provider-specific args and log parsing |
| `CloudflareDriver` | `lib/features/tunnels/data/drivers/cloudflare_driver.dart` | Cloudflare Tunnel driver |
| `NgrokDriver` | `lib/features/tunnels/data/drivers/ngrok_driver.dart` | ngrok driver |
| `TunnelManagerService` | `lib/features/tunnels/data/tunnel_manager_service.dart` | Orchestrator: downloads binaries, starts/stops processes, manages sessions |
| `TunnelDownloaderService` | `lib/features/tunnels/data/tunnel_downloader_service.dart` | Downloads and extracts cloudflared and ngrok binaries |
| `TunnelsPage` | `lib/features/tunnels/presentation/tunnels_page.dart` | Main management UI |
| `SiteTunnelDialog` | `lib/features/sites/presentation/widgets/site_tunnel_dialog.dart` | 1-click sharing popup from the Sites table |

### Data Flow

1. User creates a tunnel via `CreateTunnelModal` or clicks "Start Quick Tunnel" from the Sites table.
2. The tunnel config is saved to **Isar** (local database).
3. `TunnelManagerService.startTunnel()` checks if the binary is downloaded; if not, downloads it in the background with progress updates.
4. The driver builds command-line arguments for the tunnel binary.
5. `BackgroundProcess.start()` launches the binary silently (no console window).
6. stdout/stderr streams are parsed line-by-line by the driver to extract:
   - Public URL (e.g., `https://abc123.trycloudflare.com`)
   - Web inspector URL (ngrok only, e.g., `http://127.0.0.1:4040`)
   - Log lines (up to 500 retained per tunnel)
7. Session state updates are streamed via Riverpod to the UI in real time.

---

## Cloudflare Quick Tunnels

**Cloudflare Quick Tunnels** require **zero setup** — no Cloudflare account, no token, and no domain registration needed.

### How It Works

When you start a tunnel without an auth token, DevStack invokes `cloudflared` with:

```bash
cloudflared tunnel --url http://127.0.0.1:<PORT> --no-tls-verify
```

Cloudflare spins up an ephemeral tunnel and assigns you a **random subdomain** on `*.trycloudflare.com` (e.g., `https://purple-sun-123.trycloudflare.com`). This URL is valid as long as the tunnel process is running.

### Requirements

- **None.** No account or token required.
- The tunnel binary is automatically downloaded on first use.

### Creating a Quick Tunnel

From the **Tunnels** page:

1. Click **+ New Tunnel**.
2. Set **Provider** to **Cloudflare**.
3. Leave **Auth Token** empty (this makes it a Quick Tunnel).
4. Choose your target — either a DevStack site domain or a custom port (e.g., 3000, 8080).
5. Click **Create**, then **Start**.

From the **Sites** table:

1. Find your site in the table.
2. Click the **Share / Tunnel** icon (radio button) in the OPERATE column.
3. Click **Start Quick Tunnel (Cloudflare)** — the tunnel is created and started instantly.

### Characteristics

| Feature | Quick Tunnel |
|---|---|
| Account required | No |
| Token required | No |
| Public URL | Random `*.trycloudflare.com` subdomain |
| URL persistence | New URL each time you start |
| Custom domain | Not supported |

---

## Cloudflare Named Tunnels

**Cloudflare Named Tunnels** use a **Cloudflare Tunnel token** to establish a persistent, authenticated connection to your Cloudflare account.

### Prerequisites

1. Sign up for [Cloudflare](https://dash.cloudflare.com/) and add a domain.
2. Create a **Tunnel Token** in the Cloudflare dashboard under **Zero Trust > Networks > Tunnels**.
3. The token can be used across multiple DevStack tunnel configs.

### How It Works

With a token configured, DevStack invokes:

```bash
cloudflared tunnel run --token <YOUR_TUNNEL_TOKEN>
```

### Creating a Named Tunnel

From the **Tunnels** page:

1. Click **+ New Tunnel**.
2. Set **Provider** to **Cloudflare**.
3. Paste your **Tunnel Token** in the **Auth Token** field.
4. Configure your target (site domain or port).
5. Optionally set a **Custom Domain** if you have one configured in Cloudflare.
6. Click **Create**, then **Start**.

### Token Storage

Tokens are stored **locally** in the DevStack Isar database. They are not synced to any cloud service. You can also set a **default token** in **App Settings** under `cloudflareDefaultToken`, which is used as a fallback if the tunnel has no token configured.

### Characteristics

| Feature | Named Tunnel |
|---|---|
| Account required | Yes |
| Token required | Yes |
| Public URL | Choose your own (e.g., `https://my-app.example.com`) |
| URL persistence | Stable across restarts |
| Custom domain | Supported |

---

## ngrok Tunnels

**ngrok** exposes local servers behind NATs and firewalls using public URLs on `*.ngrok-free.app` (free tier) or custom domains (paid tiers).

### Authtoken Configuration

The **authtoken** authenticates your ngrok client against your ngrok account.

1. Sign up at [ngrok.com](https://ngrok.com/) and get your authtoken from the [ngrok dashboard](https://dashboard.ngrok.com/get-started/your-authtoken).
2. In DevStack, you can set the token in two ways:
   - **Per-tunnel**: Paste the token in the **Auth Token** field of `CreateTunnelModal`.
   - **Default token**: Set `ngrokDefaultToken` in **App Settings** — this is used as a fallback.

### How ngrok Starts

DevStack launches ngrok with:

```bash
ngrok http <PORT> --log=stdout --log-format=json --authtoken <TOKEN>
```

If a **Custom Domain** is configured, `--domain=<your-domain>` is added (requires a paid ngrok plan).

### Inspecting Requests

ngrok starts a local **Web Inspector** at `http://127.0.0.1:4040` by default. You can:

- View real-time HTTP request/response details
- Inspect request headers, bodies, and response data
- Replay requests
- Search and filter traffic

To open the inspector:

- When a tunnel is running, click the **Web Inspector** icon (monitor) in the tunnel card.
- Or navigate directly to `http://127.0.0.1:4040` in your browser.

### Characteristics

| Feature | ngrok |
|---|---|
| Account required | Yes (for authtoken) |
| Token required | Recommended (free URLs without token are temporary) |
| Public URL | Random `*.ngrok-free.app` subdomain |
| Inspector | `http://127.0.0.1:4040` |
| Custom domain | Supported (paid plans) |

---

## Managing Tunnels in the Tunnels Page

The **Tunnels** page (accessible via the sidebar `Tunnels` tab) is the central hub for all tunnel operations.

### Tunnel Card Layout

Each configured tunnel is represented as a card showing:

- **Name** — the tunnel's display name.
- **Provider** — Cloudflare (cloud icon) or ngrok (zap icon).
- **Target** — the site domain or port number.
- **Status chip** — current connection state.
- **Public URL** — the live external URL (when running).
- **Action buttons** — Start/Stop, Logs, Edit, Delete.

### Status Indicators

| Status | Chip Label | Description |
|---|---|---|
| `stopped` | Stopped | Tunnel is not running. Click **Start** to begin. |
| `downloadingBinary` | Downloading | The tunnel binary (cloudflared or ngrok) is being downloaded. |
| `connecting` | Connecting | The binary is running and establishing a connection. |
| `running` | Running | Tunnel is active. The public URL is available. |
| `error` | Error | Something went wrong. Check logs for details. |

### Available Actions

#### Start / Stop

- **Stopped** tunnels show a **Start** (green) button.
- **Running** tunnels show a **Stop** (red) button.
- While **Downloading** or **Connecting**, the Start/Stop button is disabled and a progress bar is shown.
- The **Auto start on app launch** setting automatically starts the tunnel when DevStack starts (must be running normally).

#### View Logs

Click the **Logs** icon (list) on any tunnel card to open the **Logs modal**, which displays up to 500 lines of stdout/stderr output from the tunnel process. This is useful for debugging connection issues.

#### QR Code

When a tunnel is running, click the **QR Code** icon to open the **QR modal**. This shows:

- A scannable QR code of the public URL.
- The URL text (clickable to open in browser).
- A **Copy Link** button.

#### Edit

Click the **Edit** icon (pencil) to open `CreateTunnelModal` pre-populated with the tunnel's current settings. Modify and save to update the configuration.

#### Delete

Click the **Delete** icon (trash) to remove the tunnel permanently. If the tunnel is running, it will be stopped first.

### Download Progress

When a tunnel binary needs to be downloaded (first-time use), a progress bar and the message "Downloading tunnel binary..." are shown. The download happens once and is cached locally at:

```
<base-dir>/bin/tunnels/cloudflared   (or cloudflared.exe on Windows)
<base-dir>/bin/tunnels/ngrok         (or ngrok.exe on Windows)
```

---

## 1-Click Sharing from the Sites Table

The **Sites** table includes a **Share / Tunnel** action (radio icon) in the OPERATE column for each site. Clicking it opens the `SiteTunnelDialog`, which provides a contextual quick-share workflow:

### No Existing Tunnel

If no tunnel is configured for the site, you see:

1. **Start Quick Tunnel (Cloudflare)** — Creates a new Cloudflare Quick Tunnel for this site using its PHP port, saves it, and starts it immediately. One click.
2. **Configure Tunnel** — Opens `CreateTunnelModal` pre-filled with the site's domain and port, letting you customize provider, token, or target type.

### Existing Tunnel (Running)

If a tunnel for this site is already running, you see:

- **Status chip** — Shows "RUNNING".
- **Public URL** — Full URL with copy and open-in-browser buttons.
- **QR Code** icon — Opens the QR modal for mobile testing.
- **Stop** button.

### Existing Tunnel (Stopped)

If a tunnel exists but is stopped, you see:

- **Status chip** — Shows "Stopped".
- **Start Tunnel** button — Starts the existing tunnel configuration.

This integration makes it easy to share a local dev site without navigating to the Tunnels page first.

---

## Exposing Custom Ports vs DevStack Sites

Tunnels in DevStack can target either a **DevStack-managed site** or an **arbitrary local port**.

### Exposing a DevStack Site (Target Type: Site)

When **Target Type** is set to **Site**:

- A dropdown lists all configured DevStack sites by domain (e.g., `myshop.test`).
- The tunnel forwards traffic to `http://127.0.0.1:<site-php-port>`.
- The site's PHP port (e.g., 9000) is resolved automatically from the site configuration.
- This is the recommended mode when sharing a DevStack site.

### Exposing a Custom Port (Target Type: Port)

When **Target Type** is set to **Port**:

- Enter a port number (1–65535).
- The tunnel forwards traffic to `http://127.0.0.1:<port>`.
- This is useful for sharing:
  - Local development servers (e.g., `3000` for Vite/React, `5173` for Next.js/Vite, `8080` for various servers).
  - Databases or APIs running locally.
  - Any service listening on a localhost port.

### Cloudflare Quick Tunnel Behavior

- **Quick Tunnels** (no token) use `--url http://127.0.0.1:<port>` — the port comes from `targetPort`.
- **Named Tunnels** (with token) establish a persistent reverse tunnel; the target is the local service the tunnel is configured to reach.

### ngrok Behavior

- ngrok always uses `http <port>` to determine which local port to forward.
- For DevStack PHP sites, the target port is the site's `phpPort` (e.g., 9000).
- For custom port targets, you specify the port directly (e.g., 3000).

### Recommendations

| Use Case | Target Type | Provider | Example |
|---|---|---|---|
| Share a DevStack site quickly | Site | Cloudflare (Quick) | `myshop.test` on port 9000 |
| Share localhost:3000 (Vite dev server) | Port | ngrok or Cloudflare | `localhost:3000` |
| Permanent public URL | Site or Port | Cloudflare (Named) or ngrok | `your-app.example.com` |

---

## Troubleshooting

### Binary Download Fails

**Symptom:** Tunnel stays in "Downloading" state or shows an error after a failed download.

**Causes & Fixes:**

- **Network/Firewall blocking GitHub or ngrok bin URLs.**
  - The cloudflared binary is downloaded from `github.com/cloudflare/cloudflared/releases`.
  - The ngrok binary is downloaded from `bin.equinox.io`.
  - Ensure outbound HTTPS traffic (port 443) to these hosts is allowed.

- **Download is interrupted.**
  - Restart the tunnel; the download will retry from the beginning.
  - Check the **Logs** modal for any download error messages.

- **Binary file is missing or corrupt after download.**
  - Manually delete the file at `<base-dir>/bin/tunnels/cloudflared` (or `ngrok`) and restart the tunnel.

- **Antivirus flags the binary.**
  - The cloudflared and ngrok binaries are legitimate open-source tools. Add an exception in your antivirus software if the downloaded binary is quarantined.

### Firewall Blocks Local Access

**Symptom:** The tunnel connects but the local service appears unreachable.

**Cause:** The local service (e.g., Nginx, Apache, PHP-FPM) is only listening on `127.0.0.1` and the tunnel is targeting a different interface.

**Fix:**

- Ensure the target service is listening on `127.0.0.1` (localhost).
- In DevStack, sites bind to `127.0.0.1` by default. If you enable **Lan Access** in settings, sites bind to `0.0.0.0` (reachable from other machines on the network).

### Port Conflicts

**Symptom:** Tunnel fails to start or shows an error like "address already in use."

**Causes & Fixes:**

- The target port is already in use by another process.
  - Run `netstat -an | findstr :<port>` (Windows) or `ss -tulnp | grep :<port>` (Linux) to find the process.
  - Use a different port for the tunnel target.

- Multiple tunnels targeting the same port.
  - Only one tunnel can forward to a given local port at a time. Stop the conflicting tunnel first.

### Mobile QR Code Not Scanning

**Symptom:** The QR code modal appears but the phone's camera cannot scan it.

**Causes & Fixes:**

- **QR code is too small or too dense.**
  - Ensure good lighting and hold the phone steady. The QR code in the modal encodes the full public URL.
  - You can also manually type or copy the URL shown below the QR code.

- **Phone cannot reach the tunnel URL.**
  - Cloudflare Quick Tunnels and ngrok free URLs are accessible from the public internet, so mobile data or Wi-Fi works.
  - If using a **Custom Domain** (Named Tunnel), ensure DNS is properly configured and SSL is active. The tunnel URL must resolve from the phone's network.

- **URL is not yet ready.**
  - After starting, it may take a few seconds for the tunnel to become reachable. Wait for the status to show **Running** before scanning.

- **Local-only services.**
  - If you are targeting a port that is only accessible from your machine (e.g., a service bound to `0.0.0.0` behind a NAT), the tunnel itself makes it public — the mobile device connects to the tunnel's public URL, not your local network.

### ngrok Inspector Not Loading

**Symptom:** Clicking the Web Inspector icon or visiting `http://127.0.0.1:4040` shows a blank page or connection refused.

**Causes & Fixes:**

- The inspector URL is only available once ngrok has fully started. Wait for the **Running** status.
- ngrok may have been configured to use a different inspector port. Check the tunnel **Logs** for lines containing `starting web service`.
- Ensure no firewall rule blocks local connections to port 4040.

### Cloudflare Tunnel Token Errors

**Symptom:** Named Tunnel fails to start with a token-related error.

**Causes & Fixes:**

- **Invalid or expired token.** Double-check the token in the Cloudflare dashboard.
- **Token copied with extra whitespace.** The token field is trimmed automatically, but paste carefully.
- **Insufficient permissions.** The token must be created with Tunnel permissions in the Cloudflare dashboard.
- **Account/zone mismatch.** Ensure the token is for the correct Cloudflare account and zone.

### Cloudflare Quick Tunnel URL Errors

**Symptom:** Quick Tunnel URL is not assigned or appears briefly then disappears.

**Fixes:**

- Quick Tunnel URLs are ephemeral. Restarting the tunnel generates a new URL.
- If the status gets stuck on "Connecting," check the **Logs** modal — the process may need a moment to register with Cloudflare's edge.
- Ensure outbound connections to `trycloudflare.com` are not blocked.

### Tunnel Process Not Stopping

**Symptom:** Clicking **Stop** doesn't terminate the tunnel; status stays Running.

**Fixes:**

- DevStack uses `BackgroundProcess.stopManaged()` which sends a termination signal to the tunnel process. If the process is unresponsive, the next app restart will clean up stale processes.
- On Linux, ensure `kill` command is available. On Windows, `taskkill` must be accessible.
- Manually kill the process if needed: find the PID from the session details in the **Logs** modal, then terminate it.

### Logs

- **Tunnel logs** are accessible via the **Logs** icon on any tunnel card. They show the raw stdout/stderr of the tunnel binary — useful for debugging connection, URL parsing, and error messages.
- **App logs** may contain additional context. Check the DevStack **Logs** tab for `TunnelManagerService` entries.

---

## Binary Storage Location

Tunnel binaries are downloaded and cached locally:

| Provider | Windows Path | Linux Path |
|---|---|---|
| Cloudflare | `<base-dir>\bin\tunnels\cloudflared.exe` | `<base-dir>/bin/tunnels/cloudflared` |
| ngrok | `<base-dir>\bin\tunnels\ngrok.exe` | `<base-dir>/bin/tunnels/ngrok` |

Binaries are downloaded on first use and reused thereafter. Delete the file to force a re-download.

---

## Default Tokens (App Settings)

You can configure default tokens in **Settings > App Settings** that serve as fallbacks if a tunnel is created without a token:

| Field | Description |
|---|---|
| `ngrokDefaultToken` | Default ngrok authtoken used if the tunnel has no token. |
| `cloudflareDefaultToken` | Default Cloudflare Tunnel token used if the tunnel has no token. |

These are stored in the local Isar database alongside other app settings.
