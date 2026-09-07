# Architecture Design: Tunnel Service Integration (Cloudflare Tunnel & ngrok)

- **Date:** 2026-09-07
- **Status:** Approved
- **Target Systems:** Windows (x64) & Linux (x64)
- **Author:** DevStack Architecture Team

---

## 1. Overview & Context

DevStack provides local developer environment management on Windows and Linux, orchestrating web servers (Nginx, Apache, Caddy), runtimes (PHP, Node.js, Bun, Deno, Python), and databases.

Developers frequently need to expose local web sites or services to the public internet for:
- Testing external webhooks (Stripe, GitHub, PayPal, Facebook).
- Demonstrating progress to clients or teammates on mobile devices or remote networks.
- Testing integrations requiring public HTTPS endpoints.

Currently, DevStack lacks a built-in tunneling subsystem. Developers must manually install CLI tools, open terminals, and manage command-line arguments.

### Objectives
1. Provide a unified, driver-based **Tunnel Subsystem** in DevStack supporting **Cloudflare Tunnel (`cloudflared`)** and **ngrok**, extensible to future providers (such as frp and zrok).
2. Deliver a **Zero-Configuration 1-click experience** via Cloudflare Quick Tunnels (no account or credit card required), alongside full authenticated support for ngrok and Cloudflare Named Tunnels.
3. Automatically download, verify, unpack, and manage tunnel client binaries on-demand without bloating the initial installer.
4. Integrate deeply into DevStack:
   - A dedicated **Tunnels** navigation tab for central management, port forwarding, logs, and QR code inspection.
   - A 1-click **Share / Tunnel** action in the **Sites** table to instantaneously expose any configured site.
5. Ensure process isolation, hidden window execution via `BackgroundProcess`, clean process termination, and persistence across app restarts via Isar Database.

---

## 2. Architecture & Components

```
+-------------------------------------------------------------------------+
|                              DevStack UI                                |
|  - Sidebar: NavigationTab.tunnels                                      |
|  - TunnelsPage (List, Status, Public URL, Copy, QR Modal, Web Inspector)|
|  - CreateTunnelModal & TunnelSettingsModal                              |
|  - SitesPage (Quick 1-Click "Share / Tunnel" Action)                    |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                        Tunnel Notifiers & State                         |
|  - tunnelsProvider (Isar Watcher: List<TunnelModel>)                    |
|  - tunnelSessionsProvider (StateNotifier: Map<int, TunnelSession>)      |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                          TunnelManagerService                           |
|  - Orchestrates lifecycle (start, stop, auto-start, restart)            |
|  - Coordinates binary readiness via TunnelDownloaderService             |
|  - Delegates provider operations to TunnelDriver instances              |
|  - Aggregates logs and connection status streams                        |
+-------------------+---------------------------------+-------------------+
                    |                                 |
                    v                                 v
+------------------------------------+  +---------------------------------+
|      TunnelDownloaderService       |  |          TunnelDriver           |
|  - Fetches binaries per OS         |  |   (CloudflareDriver,            |
|  - Unzips / sets chmod +x          |  |    NgrokDriver)                 |
|  - Reports download progress (0-1) |  |   - Builds CLI arguments        |
+------------------------------------+  |   - Spawns BackgroundProcess    |
                                        |   - Parses public URL & status  |
                                        |   - Connects to Web Inspector   |
                                        +---------------------------------+
                                                      |
                                                      v
                                        +---------------------------------+
                                        |      OS BackgroundProcess       |
                                        |   - Windows: wscript launcher   |
                                        |   - Linux: Process.start        |
                                        +---------------------------------+
```

---

## 3. Detailed Design

### 3.1 Data Model (`TunnelModel`) - Isar Collection

Defined in `lib/features/tunnels/domain/tunnel_model.dart`:

```dart
import 'package:isar/isar.dart';

part 'tunnel_model.g.dart';

@collection
class TunnelModel {
  Id id = Isar.autoIncrement;

  late String name;           // Friendly name (e.g., "Shop Webhook", "API Port 3000")
  
  @Index()
  late String provider;       // 'cloudflare' | 'ngrok'
  
  late String targetType;     // 'site' | 'port'
  
  String? targetSiteDomain;   // Domain of DevStack site if targetType == 'site'
  int targetPort = 80;        // Local port to expose (e.g. 80, 443, 3000, 8080)
  
  String? authToken;          // Custom authtoken for this specific tunnel
  String? customDomain;       // Custom reserved domain (if configured)
  
  bool autoStart = false;     // Connect automatically when DevStack launches
  
  DateTime? createdAt;
  DateTime? lastActiveAt;

  TunnelModel({
    this.id = Isar.autoIncrement,
    required this.name,
    this.provider = 'cloudflare',
    this.targetType = 'site',
    this.targetSiteDomain,
    this.targetPort = 80,
    this.authToken,
    this.customDomain,
    this.autoStart = false,
    this.createdAt,
    this.lastActiveAt,
  });
}
```

### 3.2 Runtime State (`TunnelSession`)

In-memory runtime state tracked in `Map<int, TunnelSession>`:

```dart
enum TunnelStatus {
  stopped,
  downloadingBinary,
  connecting,
  running,
  error,
}

class TunnelSession {
  final int tunnelId;
  final TunnelStatus status;
  final String? publicUrl;
  final String? webInspectorUrl; // e.g. http://127.0.0.1:4040 for ngrok
  final double downloadProgress; // 0.0 to 1.0 when downloadingBinary
  final String? errorMessage;
  final int? pid;
  final DateTime? connectedAt;
  final List<String> logs;

  const TunnelSession({
    required this.tunnelId,
    this.status = TunnelStatus.stopped,
    this.publicUrl,
    this.webInspectorUrl,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.pid,
    this.connectedAt,
    this.logs = const [],
  });

  TunnelSession copyWith({
    TunnelStatus? status,
    String? publicUrl,
    String? webInspectorUrl,
    double? downloadProgress,
    String? errorMessage,
    int? pid,
    DateTime? connectedAt,
    List<String>? logs,
  }) {
    return TunnelSession(
      tunnelId: tunnelId,
      status: status ?? this.status,
      publicUrl: publicUrl ?? this.publicUrl,
      webInspectorUrl: webInspectorUrl ?? this.webInspectorUrl,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      pid: pid ?? this.pid,
      connectedAt: connectedAt ?? this.connectedAt,
      logs: logs ?? this.logs,
    );
  }
}
```

### 3.3 Binary Management (`TunnelDownloaderService`)

Binaries are stored inside DevStack's user directory:
- **Windows**: `<baseDir>\bin\tunnels\` (e.g. `C:\Users\<User>\AppData\Roaming\dev-stack\bin\tunnels\`)
- **Linux**: `<baseDir>/bin/tunnels/` (e.g. `~/.local/share/dev-stack/bin/tunnels/`)

#### Download Matrix
1. **Cloudflare (`cloudflared`)**:
   - Windows: `https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe`
   - Linux: `https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64`
   - Format: Direct executable file. On Linux, execute `chmod +x cloudflared`.
2. **ngrok (`ngrok`)**:
   - Windows: `https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip`
   - Linux: `https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz`
   - Format: Archive. Decompressed via `archive` package into the tunnels directory. On Linux, ensure `chmod +x ngrok`.

#### Download Workflow
- The service streams chunks using `Dio` or `HttpClient` with progress reporting (`onProgress(double ratio)`).
- Temporary files use `.download` extension until verification/extraction is complete to prevent corruption.
- If already downloaded, verification checks file presence and executability before skipping.

### 3.4 Driver Pattern & Execution Logic

#### Interface `TunnelDriver`
```dart
abstract class TunnelDriver {
  String get providerId;
  
  Future<bool> isBinaryReady();
  Future<String> getExecutablePath();
  
  Future<void> downloadBinary({void Function(double progress)? onProgress});

  Future<ManagedBackgroundProcess> startProcess({
    required TunnelModel tunnel,
    required String? defaultToken,
    required void Function(String logLine) onLog,
    required void Function(String publicUrl) onPublicUrlDetected,
    required void Function(String inspectorUrl) onInspectorUrlDetected,
    required void Function(String error) onError,
  });
}
```

#### Provider Implementation Specifics

##### 1. Cloudflare Driver (`cloudflared`)
- **Execution Arguments**:
  - Quick Tunnel:
    `cloudflared tunnel --url http://127.0.0.1:<port> --no-tls-verify`
  - Named Tunnel (Token provided):
    `cloudflared tunnel run --token <token>`
- **Output Parsing (Stderr/Stdout)**:
  - Cloudflare prints progress and assigned public hostname to stderr.
  - Regex pattern: `https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com`
  - When matched, emit `onPublicUrlDetected(url)`.

##### 2. ngrok Driver (`ngrok`)
- **Execution Arguments**:
  - If token provided (tunnel-level or default settings):
    Run `ngrok config add-authtoken <token>` or supply `--authtoken <token>`.
  - Start tunnel:
    `ngrok http <port> --log stdout --log-format json` (plus `--domain <customDomain>` if set).
- **Output & Inspector Parsing**:
  - With `--log-format json`, parse stdout lines as JSON. Event `started tunnel` contains field `"url": "https://..."`.
  - Alternatively, query `http://127.0.0.1:4040/api/tunnels` after spawn to retrieve public URLs.
  - Web Inspector URL is fixed at `http://127.0.0.1:4040` (or the configured inspection port).

### 3.5 UI & Navigation Integration

#### 1. Navigation & Sidebar
- Add `NavigationTab.tunnels` to `lib/shared/providers/navigation_provider.dart`.
- Add navigation item in `lib/shared/layouts/sidebar.dart` with `LucideIcons.radio`.

#### 2. Tunnels Page (`TunnelsPage`)
- **Header**: Title, Subtitle, "New Tunnel" button, "Tunnel Settings" button.
- **Table / Card List**:
  - Columns: Name & Provider Icon, Target (Site domain or port), Status Chip (Stopped, Connecting, Running, Error, Downloading), Public URL with 1-click Copy button, Browser button, and QR Code modal button.
  - Web Inspector badge for ngrok tunnels.
  - Action buttons: Start/Stop toggle switch, Live Logs viewer modal, Edit, Delete.

#### 3. Quick Action in Sites Page (`SitesPage`)
- Add a "Share / Tunnel" action icon (`LucideIcons.share2` / `LucideIcons.radio`) to each site in `SiteTable`.
- Clicking checks if a tunnel already exists for this site:
  - If yes: Starts/stops the tunnel or shows a floating dialog with the active public URL & QR code.
  - If no: Opens a quick "Create Tunnel for [site.domain]" dialog pre-filled with the site's local port and domain.

#### 4. QR Code Modal
- Display generated QR code using `qr_flutter` package.
- Displays the public URL in clear text with a copy button for quick mobile device testing.

---

## 4. Error Handling & Edge Cases

1. **Target Port Not Responding / Site Stopped**:
   - The tunnel will start and acquire a public URL, but requests will return 502/Bad Gateway.
   - The UI will display a warning banner if the target site's web server (Nginx/Apache/Caddy) is not currently running.
2. **Download Failure / Network Interruption**:
   - Clean up partial `.download` files.
   - Set session status to `TunnelStatus.error` with a descriptive error message and a "Retry" button.
3. **Port Conflict on ngrok Inspector (4040)**:
   - If port 4040 is occupied by another instance, ngrok chooses 4041. The driver reads the actual inspection address from stdout JSON logs.
4. **App Shutdown Teardown**:
   - `TunnelManagerService` registers a disposal hook on `ref.onDispose`.
   - All active managed PIDs are terminated via `BackgroundProcess.stopManaged(pid)` to avoid dangling background processes.

---

## 5. Testing Strategy

1. **Unit Tests**:
   - `CloudflareDriverTest`: Test regex extraction of public URLs against sample `cloudflared` stdout/stderr outputs.
   - `NgrokDriverTest`: Test JSON log parser and authtoken argument construction.
   - `TunnelManagerServiceTest`: Test state transitions (`stopped` -> `downloading` -> `connecting` -> `running` -> `stopped`) using mocked processes and fake downloaders.
2. **Widget Tests**:
   - Test `TunnelsPage` rendering empty state and populated state.
   - Test Start/Stop toggle button interactions.
   - Test QR code dialog display and copy-to-clipboard action.
3. **Static Analysis**:
   - Ensure `flutter analyze` passes with 0 warnings or errors.
