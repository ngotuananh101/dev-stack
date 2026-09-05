# Design Document: Linux Package Manager Support for Apache, PostgreSQL, and Redis

**Date:** 2026-09-05  
**Topic:** Package Manager Installation & Process Isolation on Linux for Apache, PostgreSQL, and Redis  
**Status:** Approved  

---

## 1. Overview & Objectives

In DevStack, application distribution on Linux previously relied on portable prebuilt tarballs and binaries (or static binaries like Zonky Embedded Postgres and Valkey tarballs). However:
- **Apache (`httpd`)**: Lacks official standalone portable prebuilt binaries for Linux and was omitted from `apps-linux.json`.
- **PostgreSQL**: Relied on heavy Maven Central embedded JAR extraction (`io.zonky.test.postgres`).
- **Redis**: Relied on external Valkey prebuilt tarball URLs requiring runtime distro substitution.

### Core Goals
- **Package Manager Integration**: Use native Linux system package managers (`apt-get` for Debian/Ubuntu, `dnf` for CentOS/RHEL/Fedora) to install system-tested binaries for Apache, PostgreSQL, and Redis.
- **Service Isolation (Model 2)**: 
  - Immediately disable and stop the default systemd background services (`sudo systemctl disable --now <service>`) upon installation to avoid port conflicts with host services.
  - DevStack manages the processes directly in user space, isolating data, logs, and configuration inside `~/.ponta` (`AppConfig.dataDir`, `AppConfig.vhostsDir`, `AppConfig.logsDir`).
- **Unified Management**: DevStack retains full control over starting, stopping, status monitoring, log streaming, and port conflict checks identically to Windows and standalone binaries.

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
│ 4. Post-install initialization:                             │
│    - Apache: Generate httpd.conf & setcap bind service      │
│    - Postgres: Run initdb to initialize ~/.ponta/data/...   │
│    - Redis: Generate local redis.conf in ~/.ponta/data/redis│
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     AppServiceManager                       │
│                                                             │
│ - Apache: BackgroundProcess('apache2', ['-DFOREGROUND',...])│
│ - Postgres: BackgroundProcess('postgres', ['-D', dataDir])  │
│ - Redis: BackgroundProcess('redis-server', [confFile])      │
│ - Captures stdout/stderr into AppModel.serviceLogs          │
│ - Monitors process lifecycle via PID & POSIX signals        │
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
- **Exec File:** `apache2` (with fallback to `httpd`)
- **CLI File:** `apache2` (or `httpd`)
- **Package Manager Commands:**
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
- **Package Manager Commands:**
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
- **Package Manager Commands:**
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

---

### 3.2 Installer Service Refactoring (`AppInstallerService`)

1. **Generalize `_findInstalledBinary`**:
   - Replace `_findInstalledPhp` with a robust multi-path binary resolver:
     - Uses `which <binaryName>` first.
     - Scans common directories: `/usr/bin`, `/usr/sbin`, `/usr/local/bin`, `/usr/local/sbin`.
     - For PostgreSQL on Debian/Ubuntu: scans `/usr/lib/postgresql/*/bin/postgres` and `/usr/lib/postgresql/*/bin/initdb`.
     - For Apache: checks `/usr/sbin/apache2` and `/usr/sbin/httpd`.

2. **Decouple Post-Install Configuration**:
   - For `php`: retain composer installation.
   - For `apache`:
     - Generate isolated Apache config in `${AppConfig.vhostsDir}/apache/httpd.conf`.
     - Apply Linux capability `cap_net_bind_service=+ep` so the user process can bind port 80/443.
   - For `postgresql`:
     - Locate `initdb` (using resolved path from `/usr/lib/postgresql/*/bin/initdb` or `/usr/bin/initdb`).
     - Run `_initializePostgresql` to create the cluster at `${AppConfig.dataDir}/postgresql-<version>`.
   - For `redis`:
     - Ensure `${AppConfig.dataDir}/redis/redis.conf` exists with:
       ```conf
       port 6379
       bind 127.0.0.1
       daemonize no
       dir "${AppConfig.dataDir}/redis"
       ```

---

### 3.3 Process Lifecycle & Execution (`AppServiceManager`)

When running under DevStack:
1. **Apache (`apache2` / `httpd`)**:
   - Runs in foreground mode:
     ```bash
     apache2 -DFOREGROUND -f <ponta_httpd_conf>
     ```
   - DevStack monitors standard output and error directly, without requiring systemctl.
2. **PostgreSQL (`postgres`)**:
   - Runs directly with data directory:
     ```bash
     postgres -D <ponta_data_dir>/postgresql-<version>
     ```
3. **Redis (`redis-server`)**:
   - Runs directly pointing to local config:
     ```bash
     redis-server <ponta_data_dir>/redis/redis.conf
     ```
4. **Stopping & Killing**:
   - Managed via standard POSIX signals (`SIGTERM`, followed by `SIGKILL` after timeout) using existing `BackgroundProcess` routines.

---

### 3.4 Security & Validation

1. **Command Allowlist**:
   - All catalog commands pass through `PackageCommandValidator`.
   - `apt-get`, `dnf`, and `systemctl` are already in `_allowedBinaries`.
   - Chaining and dangerous subshells remain strictly rejected.
2. **Path Traversal & Capability Restraints**:
   - `setLinuxCapabilityForWebserver` ensures only binaries within approved directories or system binary paths are granted capabilities.

---

## 4. Testing Strategy

1. **Catalog Integrity Unit Tests**:
   - Validate that `assets/data/apps-linux.json` contains `apache`, `postgresql`, and `redis` with valid `package_manager_commands`.
   - Validate that all commands pass `PackageCommandValidator.validateAll`.
2. **Binary Resolution Tests**:
   - Test `_findInstalledBinary` with various mock path structures (including Debian's `/usr/lib/postgresql/*/bin/`).
3. **Configuration & Service Startup Arguments**:
   - Test argument generation in `AppServiceManager.argumentsForExecutable` for `apache2`, `httpd`, `postgres`, and `redis-server` on Linux.
