<div align="center">

<img src="assets/images/icon.png" alt="dev-stack Logo" width="128" height="128" />

# dev-stack

**A modern, blazing-fast, and hardened local web development environment for Windows & Linux.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue?style=for-the-badge&logo=linux&logoColor=white)](#-supported-platforms)
[![Tests](https://img.shields.io/badge/Tests-424%20Passing-success?style=for-the-badge&logo=githubactions&logoColor=white)](#-code-quality--testing)
[![License](https://img.shields.io/badge/License-Proprietary-orange?style=for-the-badge)](#-license)

<p align="center">
  Similar to <b>Laragon</b> or <b>Laravel Herd</b>, but engineered natively with <b>Flutter Desktop</b> using Clean Architecture. Features multi-webserver switching (Nginx, Caddy, Apache), multi-version PHP isolation with Composer, diverse database engines (MySQL, PostgreSQL, Redis, MongoDB), automated local SSL certificates, and enterprise-grade security hardening.
</p>

---

</div>

## 📑 Table of Contents

- [✨ Key Features](#-key-features)
- [🛡️ Enterprise Security Hardening](#️-enterprise-security-hardening)
- [📦 Supported Applications & Services](#-supported-applications--services)
- [🖥️ Supported Platforms](#️-supported-platforms)
- [🚀 Quick Start Guide](#-quick-start-guide)
  - [Prerequisites](#prerequisites)
  - [Building & Running from Source](#building--running-from-source)
  - [Packaging Installer for Windows](#packaging-installer-for-windows)
- [🏛️ Architecture & Design Patterns](#️-architecture--design-patterns)
- [🧪 Code Quality & Testing](#-code-quality--testing)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Key Features

- **Multi-Webserver Management**: Seamlessly switch between **Nginx**, **Caddy**, and **Apache** with a single click. Automatically generates virtual host configurations and reverse proxies with FastCGI integration.
- **Isolated Multi-version PHP**: Effortlessly toggle between PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, and 8.5. Includes automated Composer installation, PHP-FPM lifecycle management, and extension management.
- **Robust Database Engine Support**:
  - Run and manage **MySQL**, **MariaDB**, **PostgreSQL**, **MongoDB**, **Redis (Valkey)**, **Elasticsearch**, and **Meilisearch**.
  - Built-in GUI tool integrations (**phpMyAdmin**, **HeidiSQL**, **MongoDB Compass**) with single-click access.
- **Automated Virtual Hosts & Local SSL**:
  - Automatic `.test` and `.local` domain routing with secure `/etc/hosts` and Windows hosts file management.
  - Automatically provisions trusted local **SSL (HTTPS)** certificates using an internal Root Certificate Authority.
- **Modern Runtimes Management**: Easily install and manage **Node.js** versions and **Python** via **pyenv**.
- **Integrated Configuration Editor**: Edit configuration files (`php.ini`, `nginx.conf`, `httpd.conf`, `Caddyfile`, `my.ini`) directly within the application with syntax highlighting and instant validation.
- **System Tray & Auto-Start Integration**: Minimizes unobtrusively to the system tray and provides optional automatic background service startup upon system boot.

---

## 🛡️ Enterprise Security Hardening

`dev-stack` has been thoroughly audited and hardened across 4 multi-phase security benchmarks to ensure maximum defense-in-depth:

| Security Domain | Protection Mechanism & Implementation |
| :--- | :--- |
| **Supply Chain Security (VULN-12)** | Streaming **SHA-256 Checksum** verification for all remote binary downloads before extraction; strict **HTTPS** protocol enforcement for remote catalog updates to prevent MitM attacks. |
| **Encrypted Local Storage (VULN-11)** | Database passwords and sensitive credentials are encrypted using `LocalSecretVault` with authenticated encryption (HMAC-SHA256 authenticated keystore, random per-ciphertext IVs). Transparent backward-compatible fallback for legacy plaintext entries. |
| **Path Traversal Defense (VULN-08)** | Pre-inspection of Tar & Zip archives via `isSafeTarEntry` rejecting any entries with relative traversal sequences (`../`, `..\`), root paths, or drive letters. |
| **Command Injection Mitigation (VULN-01 & VULN-02)** | Eliminated double-shell interpretation by removing redundant `runInShell: true` on POSIX systems; strictly restricted `PackageCommandValidator` allowlist by removing high-risk binaries (`sudo`, `pkexec`, `tee`). |
| **Process Lifecycle Reliability (LIFE-01 & LIFE-02)** | POSIX **Process Group Kill** (`kill -9 -- -$pid`) on Linux to prevent orphan/zombie worker leaks; real-time systemd liveness detection via `systemctl is-active`. |
| **Least-Privilege File Permissions (VULN-04, 05, 07, 14)** | Sensitive temporary files restricted to `0600` permissions; binary directories granted execution privileges without granting blanket `755` permissions across data directories; comprehensive audit logging for all elevated commands (`pkexec`). |

---

## 📦 Supported Applications & Services

<div align="center">

| Web Servers | Language Runtimes | Databases & Caching | GUI Tools & Management |
| :---: | :---: | :---: | :---: |
| <img src="assets/images/nginx.png" width="40"/><br/>**Nginx** | <img src="assets/images/php.png" width="40"/><br/>**PHP 7.4 – 8.5** | <img src="assets/images/mysql.png" width="40"/><br/>**MySQL** | <img src="assets/images/phpmyadmin.png" width="40"/><br/>**phpMyAdmin** |
| <img src="assets/images/caddy.png" width="40"/><br/>**Caddy** | <img src="assets/images/nodejs.png" width="40"/><br/>**Node.js** | <img src="assets/images/mariadb.png" width="40"/><br/>**MariaDB** | <img src="assets/images/heidisql.png" width="40"/><br/>**HeidiSQL** |
| <img src="assets/images/apache.png" width="40"/><br/>**Apache** | <img src="assets/images/python.png" width="40"/><br/>**Python (pyenv)** | <img src="assets/images/postgre.png" width="40"/><br/>**PostgreSQL** | <img src="assets/images/mongodb.png" width="40"/><br/>**MongoDB Compass** |
| | | <img src="assets/images/redis.png" width="40"/><br/>**Redis / Valkey** | |
| | | <img src="assets/images/mongodb.png" width="40"/><br/>**MongoDB** | |
| | | <img src="assets/images/elasticsearch.png" width="40"/><br/>**Elasticsearch** | |
| | | <img src="assets/images/meilisearch.png" width="40"/><br/>**Meilisearch** | |

</div>

---

## 🖥️ Supported Platforms

- **Windows**: Windows 10 & Windows 11 (64-bit architecture). Supports portable standalone software installations under `C:\dev-stack`.
- **Linux**: Ubuntu, Debian, Fedora, Arch Linux, openSUSE, and Alpine Linux.
  - Automatic distribution detection via `LinuxDistroResolver`.
  - Seamless support for both portable standalone binaries (Jirutka static Linux binaries, Valkey tarballs, Zonky PostgreSQL) and native system package managers (`apt`, `dnf`, `pacman`).

---

## 🚀 Quick Start Guide

### Prerequisites

- **Flutter SDK**: `>= 3.10.4` (Flutter 3.41+ recommended).
- **Dart SDK**: `^3.10.4` (Dart 3.11+ recommended).
- **Windows**: Visual Studio 2022 with the "Desktop development with C++" workload.
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.

### Building & Running from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ngotuananh101/dev-stack.git
   cd dev-stack
   ```

2. **Install project dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate code bindings (Isar & Riverpod Generators)** *(required when modifying models)*:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the application**:
   - On **Windows**:
     ```bash
     flutter run -d windows
     ```
   - On **Linux**:
     ```bash
     flutter run -d linux
     ```

### Packaging Installer for Windows

To compile a standalone Windows `.exe` installer using **Inno Setup**:

1. Download and install **Inno Setup 6** from [jrsoftware.org](https://jrsoftware.org/isdl.php).
2. Execute the automated packaging script in PowerShell:
   ```powershell
   .\scripts\package.ps1
   ```
3. The compiled installer executable will be generated in `innosetup\Output\`.

---

## 🏛️ Architecture & Design Patterns

The codebase follows **Clean Architecture** principles and leverages **Riverpod** for reactive state management:

```
lib/
├── core/
│   ├── config/             # Config Builders (Nginx, Caddy, Apache) & AppConfig
│   ├── database/           # Isar Singleton Provider & Concurrency Mutex Lock
│   ├── security/           # LocalSecretVault (HMAC-SHA256 Authenticated Encryption)
│   ├── services/           # SSL, Path, Process, Logging, Distro Resolver
│   └── theme/              # Typography, Colors, Themes
├── features/
│   ├── apps/               # Application & Service Lifecycle, Installation Pipeline
│   ├── databases/          # Database Records, Credential Encryption, User Grants
│   ├── hosts/              # Virtual Hosts, Local Domain Resolution, System Hosts
│   ├── sites/              # Projects, Virtual Hosts, SSL Certificates
│   └── settings/           # App Preferences, Port Bindings, Distro Configuration
└── shared/                 # Reusable UI Widgets, Inline Code Editor, Dialogs
```

### Key Design Patterns
- **Builder Pattern**: Static configuration generators (`NginxConfigBuilder`, `ApacheConfigBuilder`, `CaddyConfigBuilder`) producing clean, normalized configuration files across Windows and POSIX systems.
- **Strategy & Pipeline Pattern**: Decomposed `AppInstallerService.install()` into modular phases: download ➔ checksum verification ➔ archive extraction ➔ database configuration ➔ runtime configuration ➔ webserver integration.
- **Single-Flight / Async Mutex Pattern**: Concurrency lock using `Completer<Isar>` in `IsarInstance.getInstance()` to eliminate race conditions and file lock contentions during application boot.

---

## 🧪 Code Quality & Testing

`dev-stack` enforces strict Test-Driven Development (TDD) standards:

- **100% Automated Test Pass Rate**: **424 / 424 tests PASS** (0 failures, 0 skipped).
- **Clean Static Analysis**: `flutter analyze` reports **0 issues**.
- **Comprehensive Test Coverage**:
  - Unit tests for all Webserver Config Builders (Nginx, Apache, Caddy).
  - Security regression test suites for Tar Path Traversal, Command Injection, Allowlist Validation, SHA256 Checksums, and Authenticated Keystore Tampering.
  - Mock integration tests for POSIX signals, Process Group termination, and systemd service lifecycles.

Run all tests:
```bash
flutter test
```

Perform static analysis:
```bash
flutter analyze
```

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'feat: add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This software is developed and distributed under the terms specified in the [LICENSE](LICENSE) file.

<div align="center">
  <sub>Built with ❤️ for the global developer community.</sub>
</div>
