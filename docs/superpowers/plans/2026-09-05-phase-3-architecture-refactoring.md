# Giai đoạn 3: Tái cấu trúc Kiến trúc & Mở rộng Kiểm thử (Phase 3 Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tái cấu trúc các service nguyên khối (`AppInstallerService.install()`, `_configureWebserver()`), bảo vệ giải nén Tar chống Path Traversal (VULN-08), module hóa cấu hình Nginx và Apache với Config Builders riêng (ARCH-02), loại bỏ race condition khi mở Isar database (ARCH-03) và mở lại bộ test `apps_repository_test.dart` mà không bị phụ thuộc native DLL (TEST-02).

**Architecture:** Áp dụng Strategy Pattern cho extraction payload; tách biệt cấu hình Webserver thành `NginxConfigBuilder` và `ApacheConfigBuilder` theo mô hình của `CaddyConfigBuilder`; dùng `Completer` khóa luồng mở Isar singleton; trích xuất logic parse/merge catalog của `AppsRepository` thành hàm thuần để kiểm thử trọn vẹn không cần Isar native DLL.

**Tech Stack:** Dart, Flutter, Clean Architecture, Strategy Pattern, Riverpod, Isar.

**Spec:** `docs/superpowers/plans/2026-09-05-system-hardening-master-plan.md`

## Global Constraints

- 100% tương thích ngược với Windows và Linux.
- Toàn bộ 358 test hiện có phải tiếp tục PASS.
- Đường dẫn chuẩn hóa qua `package:path/path.dart`.
- Tuân thủ TDD: viết test trước, triển khai tối giản, kiểm tra PASS, commit.

---

### File Structure & Trách nhiệm

| Tệp nguồn | Trách nhiệm chính |
| :--- | :--- |
| `lib/features/apps/data/app_installer_service.dart` | Chia nhỏ `install()` thành extraction strategies (`_extractArchive`) và post-config hooks; tích hợp kiểm tra Path Traversal cho Tar. |
| `lib/core/config/nginx_config_builder.dart` | Tạo builder sinh cấu hình Nginx (`nginx.conf`, vhosts) tương tự `CaddyConfigBuilder`. |
| `lib/core/config/apache_config_builder.dart` | Tạo builder sinh cấu hình Apache (`httpd.conf`, vhosts). |
| `lib/core/database/isar_provider.dart` | Triển khai `Completer` khóa luồng cho `IsarInstance.getInstance()`, giải quyết race condition khi khởi động. |
| `lib/features/apps/data/apps_repository.dart` | Tách logic merge catalog và installed state thành `mergeAppsCatalog` độc lập để test thuần túy. |
| `test/features/apps/tar_traversal_test.dart` | Kiểm thử phát hiện và chặn path traversal (`../`, absolute path) trong tar extraction. |
| `test/core/config/nginx_config_builder_test.dart` | Kiểm thử sinh cấu hình Nginx hợp lệ. |
| `test/core/config/apache_config_builder_test.dart` | Kiểm thử sinh cấu hình Apache hợp lệ. |
| `test/core/database/isar_concurrency_test.dart` | Kiểm thử race condition / concurrency lock của `IsarInstance`. |
| `test/features/apps/apps_repository_test.dart` | Viết lại test suite cho `AppsRepository` và `mergeAppsCatalog`, gỡ bỏ `skip`. |

---

### Task 1: Phòng chống Path Traversal trong Tar Archive & Phân rã `AppInstallerService.install()` (VULN-08 & ARCH-01)

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Create: `test/features/apps/tar_traversal_test.dart`

**Interfaces:**
- Consumes: `AppInstallerService.install`, `buildTarExtractArgs`, `validateTarEntries`
- Produces:
  - Hàm `bool isSafeTarEntry(String entryPath)` kiểm tra và từ chối các entry chứa `../`, `..\`, hoặc bắt đầu bằng root path `/` hay `\`.
  - Tách `_extractPayload(...)` xử lý độc lập từng định dạng: Zip, Tar (có validation), Exe, Zonky Jar, Raw Binary.
  - Tách các hàm cấu hình: `_configureDatabases(...)`, `_configureRuntimes(...)`.

- [ ] **Step 1: Viết failing test cho Tar Traversal validation**
  Tạo `test/features/apps/tar_traversal_test.dart`:
  - Test 1: Entry hợp lệ (`bin/nginx`, `conf/nginx.conf`) -> `isSafeTarEntry` trả về true.
  - Test 2: Entry chứa `../` hoặc `..\` (`../../etc/shadow`, `foo/../../bar`) -> trả về false.
  - Test 3: Entry là absolute path (`/etc/passwd`, `C:\Windows\System32`) -> trả về false.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/features/apps/tar_traversal_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai validation & chia tách các hàm trong `AppInstallerService`**
  - Cung cấp `static bool isSafeTarEntry(String entryPath)`.
  - Kiểm tra danh sách entry hoặc thêm cờ an toàn khi trích xuất tar.
  - Tách `_extractPayload` và các nhóm post-installation riêng biệt để giảm độ dài và độ phức tạp của `install()`.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/apps/tar_traversal_test.dart test/features/apps/installer_linux_tar_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/app_installer_service.dart test/features/apps/tar_traversal_test.dart
  git commit -m "fix(security): prevent tar path traversal and decompose install workflow"
  ```

---

### Task 2: Module hóa Webserver Config Builders cho Nginx & Apache (ARCH-02)

**Files:**
- Create: `lib/core/config/nginx_config_builder.dart`
- Create: `lib/core/config/apache_config_builder.dart`
- Modify: `lib/features/apps/data/app_installer_service.dart` (thay thế chuỗi inline template bằng các builder)
- Create: `test/core/config/nginx_config_builder_test.dart`
- Create: `test/core/config/apache_config_builder_test.dart`

**Interfaces:**
- Consumes: `NginxConfigBuilder.buildMainConfig(...)`, `ApacheConfigBuilder.buildMainConfig(...)`
- Produces: Chuỗi cấu hình webserver chuẩn, tách biệt hoàn toàn khỏi logic cài đặt của `AppInstallerService`.

- [ ] **Step 1: Viết failing test cho `NginxConfigBuilder` & `ApacheConfigBuilder`**
  Tạo `test/core/config/nginx_config_builder_test.dart` và `test/core/config/apache_config_builder_test.dart`.
  Kiểm tra các directive cốt lõi (listen port, root, server_name, include vhosts, fastcgi pass).

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/core/config/nginx_config_builder_test.dart test/core/config/apache_config_builder_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai các Builder và refactor `AppInstallerService._configureWebserver`**
  - Tạo `NginxConfigBuilder` trong `lib/core/config/nginx_config_builder.dart`.
  - Tạo `ApacheConfigBuilder` trong `lib/core/config/apache_config_builder.dart`.
  - Refactor `_configureWebserver` trong `app_installer_service.dart` gọi các builder này.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/core/config/nginx_config_builder_test.dart test/core/config/apache_config_builder_test.dart test/features/apps/installer_apache_pma_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/config/nginx_config_builder.dart lib/core/config/apache_config_builder.dart lib/features/apps/data/app_installer_service.dart test/core/config/
  git commit -m "refactor(config): modularize Nginx and Apache configuration builders"
  ```

---

### Task 3: Chống Race Condition trong `IsarInstance.getInstance()` (ARCH-03)

**Files:**
- Modify: `lib/core/database/isar_provider.dart`
- Create: `test/core/database/isar_concurrency_test.dart`

**Interfaces:**
- Consumes: `IsarInstance.getInstance()`
- Produces: `Completer<Isar>? _openCompleter` để serialize các lời gọi đồng thời, đảm bảo `Isar.open` chỉ chạy đúng 1 lần duy nhất ngay cả khi nhiều async callers cùng lúc.

- [ ] **Step 1: Viết failing test kiểm tra cơ chế concurrency lock**
  Tạo `test/core/database/isar_concurrency_test.dart` mô phỏng nhiều lời gọi đồng thời qua một mock/synchronizer.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/core/database/isar_concurrency_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai Completer serialization trong `IsarInstance`**
  ```dart
  static Completer<Isar>? _openCompleter;

  static Future<Isar> getInstance({Future<Isar> Function()? opener}) async {
    if (_instance != null && _instance!.isOpen) {
      return _instance!;
    }
    if (_openCompleter != null) {
      return await _openCompleter!.future;
    }
    _openCompleter = Completer<Isar>();
    try {
      final isar = opener != null ? await opener() : await _openInternal();
      _instance = isar;
      _openCompleter!.complete(isar);
      return isar;
    } catch (e, st) {
      _openCompleter!.completeError(e, st);
      rethrow;
    } finally {
      _openCompleter = null;
    }
  }
  ```

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/core/database/isar_concurrency_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/database/isar_provider.dart test/core/database/isar_concurrency_test.dart
  git commit -m "fix(database): serialize IsarInstance.getInstance with Completer to prevent race conditions"
  ```

---

### Task 4: Mở lại Bộ Kiểm thử `AppsRepository` không phụ thuộc Native DLL (TEST-02)

**Files:**
- Modify: `lib/features/apps/data/apps_repository.dart`
- Modify: `test/features/apps/apps_repository_test.dart`

**Interfaces:**
- Consumes: `AppsRepository.mergeAppsCatalog(List<dynamic> appsJson, Map<String, InstalledApp> installedMap)`
- Produces: Tách biệt logic xử lý catalog + installed app thành hàm thuần có thể test độc lập 100% trong môi trường `flutter test` mà không cần `isar.dll`.

- [ ] **Step 1: Viết các test case thực tế trong `test/features/apps/apps_repository_test.dart`**
  - Xóa bỏ cờ `skip: 'Requires Isar native library (isar.dll)'`.
  - Test 1: Merge catalog rỗng -> trả về rỗng.
  - Test 2: Merge catalog với app chưa cài -> `isInstalled == false`.
  - Test 3: Merge catalog với app đã cài trong `installedMap` -> map đúng version, status, paths.
  - Test 4: Catalog chứa LTS labels / extra info -> parse đúng `extraInfoJson`.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/features/apps/apps_repository_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai `mergeAppsCatalog` trong `AppsRepository`**
  Trích xuất logic từ `getAll()` thành `static List<AppModel> mergeAppsCatalog(List<dynamic> appsJson, Map<String, InstalledApp> installedMap)` và gọi nó từ `getAll()`.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/apps/apps_repository_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/apps_repository.dart test/features/apps/apps_repository_test.dart
  git commit -m "test(apps): unskip and implement unit tests for AppsRepository catalog merging"
  ```

---

### Task 5: Kiểm tra Toàn diện & Xác thực Linter (Verification & Static Analysis)

- [ ] **Step 1: Chạy toàn bộ test suite**
  Run: `flutter test`
  Expected: Toàn bộ tests PASS (0 failures, 0 skipped không mong muốn).

- [ ] **Step 2: Chạy static analysis**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 3: Cập nhật tài liệu kế hoạch Phase 3**
  Đánh dấu hoàn thành các checkbox trong `docs/superpowers/plans/2026-09-05-phase-3-architecture-refactoring.md`.
