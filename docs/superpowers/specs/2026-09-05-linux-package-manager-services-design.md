# Design Document: Linux Package Manager Support for Apache, PostgreSQL, Redis, and PHP-FPM

**Date:** 2026-09-05  
**Topic:** Package Manager Installation & Process Isolation on Linux for Apache, PostgreSQL, Redis, and PHP-FPM  
**Status:** Approved  

---

## 1. Overview & Objectives

In DevStack, services on Linux were either distributed as portable binaries (Zonky Postgres, Valkey tarballs) or tied to systemd (`php8.x-fpm` via `systemctl`). Meanwhile, Apache was missing due to lack of portable builds.

### Core Goals
- **Package Manager Integration**: Use native Linux system package managers (`apt-get` for Debian/Ubuntu, `dnf` for CentOS/RHEL/Fedora) to install system-tested binaries for **Apache**, **PostgreSQL**, **Redis**, and **PHP-FPM** (`php82`, `php83`, `php84`, `php85`).
- **Full Service Isolation (Model 2)**: 
  - Immediately disable and stop the default systemd background services (`sudo systemctl disable --now <service>`) upon package installation so host ports (80, 5432, 6379, 9000/908x) are never hijacked by background daemons.
  - DevStack manages all processes directly in user space using `BackgroundProcess`, isolating configuration, data directories, and logs completely inside `~/.ponta` (`AppConfig.dataDir`, `AppConfig.vhostsDir`, `AppConfig.logsDir`).
- **Unified Management**: DevStack retains 100% full control over process lifecycle (start, stop, restart, PID tracking, real-time log streaming, port conflict probing via `ss -tulpn`) without needing `systemctl` runtime wrappers.

---

## 2. Architecture & Components

```
┌─────────────────────────────────────────────────────────────┐
│                 DevStack Marketplace UI                     │
└──────────────────────────────┬──────────────────────────────┘
                               │ click "Install"
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    AppInstallerService                      │
│                                                             │
│ 1. PackageCommandValidator.validateAll()                    │
│ 2. Execute distro commands:                                 │
│    - sudo apt-get install -y <package>                      │
│    - sudo systemctl disable --now <service>                 │
│ 3. Resolve binary paths via _findInstalledBinary()          │
│ 4. Post-install configuration in ~/.ponta:                  │
│    - Apache: Generate httpd.conf & setcap bind service      │
│    - Postgres: Run initdb to initialize ~/.ponta/data/...   │
│    - Redis: Generate local redis.conf in ~/.ponta/data/redis│
│    - PHP-FPM: Generate local php-fpm.conf (ports 9082..9085)│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     AppServiceManager                       │
│                                                             │
│ Direct user-space execution (Foreground mode):              │
│ - Apache:   apache2 -DFOREGROUND -f <conf>                  │
│ - Postgres: postgres -D <data_dir>                          │
│ - Redis:    redis-server <conf>                             │
│ - PHP-FPM:  php-fpm8.x -F -y <conf>                         │
│                                                             │
│ Lifecycle & Logging:                                        │
│ - Real-time stream stdout/stderr into AppModel.serviceLogs  │
│ - Track PID directly, stop via POSIX SIGTERM / SIGKILL      │
│ - Zero dependency on systemctl during runtime               │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Specifications

### 3.1 Catalog Definitions (`assets/data/apps-linux.json` & `update.js`)

Each service definition will have `install_method: "package_manager"` and distro-specific commands for Ubuntu, Debian, and CentOS/Fedora/RHEL:

#### 1. Apache (`apache`)
- **App ID:** `apache`
- **Category:** `webserver`
- **Group:** `webserver`
- **Exec File:** `apache2` (fallback to `httpd`)
- **CLI File:** `apache2` (or `httpd`)
- **Commands:**
  - `ubuntu` / `debian`:
    ```bash
    sudo apt-get update
    sudo apt-get install -y apache2
    sudo systemctl disable --now apache2
    ```
  - `centos`:
    ```bash
    sudo dnf install -y httpd
    sudo systemctl disable --now httpd
    ```

#### 2. PostgreSQL (`postgresql`)
- **App ID:** `postgresql`
- **Category:** `database`
- **Group:** `database`
- **Exec File:** `postgres`
- **CLI File:** `psql`
- **Commands:**
  - `ubuntu` / `debian`:
    ```bash
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl disable --now postgresql
    ```
  - `centos`:
    ```bash
    sudo dnf install -y postgresql-server postgresql-contrib
    sudo systemctl disable --now postgresql
    ```

#### 3. Redis (`redis`)
- **App ID:** `redis`
- **Category:** `database`
- **Group:** `redis`
- **Exec File:** `redis-server`
- **CLI File:** `redis-cli`
- **Commands:**
  - `ubuntu` / `debian`:
    ```bash
    sudo apt-get update
    sudo apt-get install -y redis-server
    sudo systemctl disable --now redis-server
    ```
  - `centos`:
    ```bash
    sudo dnf install -y redis
    sudo systemctl disable --now redis
    ```

#### 4. PHP-FPM (`php82`, `php83`, `php84`, `php85`)
- **App ID:** `php82`, `php83`, `php84`, `php85`
- **Category:** `runtime`
- **Group:** `php`
- **Exec File:** `php-fpm8.x` (fallback to `php-fpm`)
- **CLI File:** `php8.x` (fallback to `php`)
- **Commands:** Add `sudo systemctl disable --now php8.x-fpm` (or `php-fpm`) right after package installation to ensure the default system daemon is turned off.

---

### 3.2 Installer Service Refactoring (`AppInstallerService`)

1. **Generalize `_findInstalledBinary`**:
   - Multi-path binary resolver:
     - Uses `which <binaryName>` first.
     - Scans `/usr/bin`, `/usr/sbin`, `/usr/local/bin`, `/usr/local/sbin`.
     - For PostgreSQL on Debian/Ubuntu: `/usr/lib/postgresql/*/bin/postgres` and `/usr/lib/postgresql/*/bin/initdb`.
     - For PHP-FPM: `/usr/sbin/php-fpm8.*`, `/usr/sbin/php-fpm`, `/usr/bin/php-fpm`.
     - For Apache: `/usr/sbin/apache2` and `/usr/sbin/httpd`.

2. **Isolated Configuration Generation**:
   - **Apache**:
     - Generate isolated config in `${AppConfig.vhostsDir}/apache/httpd.conf`.
     - Apply Linux capability `cap_net_bind_service=+ep` so user space process binds 80/443.
   - **PostgreSQL**:
     - Run `initdb` to create isolated cluster at `${AppConfig.dataDir}/postgresql-<version>`.
     - Set secure local authentication and random password in `postgres-password.txt`.
   - **Redis**:
     - Generate `${AppConfig.dataDir}/redis/redis.conf` with `daemonize no`, `dir "${AppConfig.dataDir}/redis"`.
   - **PHP-FPM**:
     - Generate `${AppConfig.baseDir}/php/<appId>/php-fpm.conf`:
       ```ini
       [global]
       error_log = ${AppConfig.logsDir}/<appId>-fpm.error.log
       daemonize = no

       [www]
       listen = 127.0.0.1:<port>
       pm = ondemand
       pm.max_children = 10
       pm.process_idle_timeout = 10s
       ```
     - Port allocated dynamically (e.g. 9082 for php82, 9083 for php83, etc.).

---

### 3.3 Process Lifecycle & Execution (`AppServiceManager`)

All services run directly via `BackgroundProcess` in **Foreground Mode**:
1. **Apache (`apache2` / `httpd`)**:
   `apache2 -DFOREGROUND -f ~/.ponta/vhosts/apache/httpd.conf`
2. **PostgreSQL (`postgres`)**:
   `postgres -D ~/.ponta/data/postgresql-<version>`
3. **Redis (`redis-server`)**:
   `redis-server ~/.ponta/data/redis/redis.conf`
4. **PHP-FPM (`php-fpm8.x`)**:
   `php-fpm8.x -F -y ~/.ponta/php/<appId>/php-fpm.conf`
5. **No Systemctl Runtime Dependency**:
   - Remove `_startPhpFpmViaSystemctl` and `_stopPhpFpmViaSystemctl` from `AppServiceManager`.
   - All services uniformly benefit from stream subscriptions on stdout/stderr, PID tracking, and graceful termination (`SIGTERM` / `SIGKILL`).

---

### 3.4 Security & Validation

- `PackageCommandValidator`: All package manager commands (`apt-get`, `dnf`, `systemctl`) pass allowlist validation.
- Commands remain immutable, audited, and strictly non-chained.
