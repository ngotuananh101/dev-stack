# Giai đoạn 2: Củng cố Vòng đời Tiến trình & Nền tảng Linux (Phase 2 Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Củng cố vòng đời tiến trình dịch vụ trên Linux (Process Group kill, timeout escalation, ổn định systemctl cho PHP-FPM), định vị đường dẫn cấu hình PHP cho gói package manager, và siết chặt an toàn tệp tin tạm và phân quyền tệp trên hệ điều hành.

**Architecture:** Mở rộng `AppServiceManager` để sử dụng Process Group kill trên Linux (`kill -9 -- -$pid`), hỗ trợ ProcessRunner injectable cho unit test; nâng cấp `_startPhpFpmViaSystemctl` và `_stopPhpFpmViaSystemctl` với error handling, systemctl fallback và liveness check; mở rộng `PhpSettings` để phân giải đúng vị trí `php.ini` cho cả Windows standalone và Linux system packages; siết chặt quyền `0600`/`0700` cho hosts file tạm và audit log cho `pkexec`.

**Tech Stack:** Dart, Flutter, Riverpod, POSIX process management (signals, process groups, systemd/systemctl).

**Spec:** `docs/superpowers/plans/2026-09-05-system-hardening-master-plan.md`

## Global Constraints

- Duy trì 100% tương thích ngược với Windows (`taskkill /F /T /PID`).
- Toàn bộ test hiện có phải tiếp tục PASS mà không bị regression.
- Chuẩn hóa đường dẫn bằng `package:path/path.dart`.
- Tuân thủ nghiêm ngặt quy trình TDD: viết test fail trước, sau đó triển khai code tối thiểu, kiểm tra pass và commit.

---

### File Structure & Trách nhiệm

| Tệp nguồn | Trách nhiệm chính |
| :--- | :--- |
| `lib/features/apps/data/app_service_manager.dart` | Cải tiến `forceKillPid` (Process Group & fallback), tối ưu `_startPhpFpmViaSystemctl` & `_stopPhpFpmViaSystemctl`. |
| `lib/features/apps/data/php_settings_provider.dart` | Mở rộng `_getPhpIni` / `resolvePhpIniPath` nhận diện đường dẫn `php.ini` hệ thống trên Linux khi `location == 'system_package'`. |
| `lib/features/hosts/data/hosts_repository.dart` | Siết chặt phân quyền thư mục/file tạm (`0600`) trên Linux trước khi copy sang `/etc/hosts`. |
| `lib/core/services/background_process.dart` | Bổ sung audit log trước khi thực thi `pkexec` trên Linux. |
| `lib/features/apps/data/app_installer_service.dart` | Tinh chỉnh `ensureLinuxPermissions` chỉ gán quyền thực thi cho binary thay vì toàn bộ cây thư mục. |
| `test/features/apps/force_kill_pid_linux_test.dart` | Kiểm thử logic `forceKillPid` trên Linux với Process Group và fallback đơn lẻ. |
| `test/features/apps/systemctl_service_test.dart` | Kiểm thử khởi động, dừng và kiểm tra trạng thái PHP-FPM qua `systemctl`. |
| `test/features/apps/php_ini_resolver_test.dart` | Kiểm thử tìm đường dẫn `php.ini` cho Linux package manager và Windows. |
| `test/features/hosts/hosts_repository_security_test.dart` | Kiểm thử phân quyền file tạm và audit log khi ghi file hosts. |

---

### Task 1: Nâng cấp Process Group Kill cho `forceKillPid` trên Linux (LIFE-01)

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart:636-664`
- Create: `test/features/apps/force_kill_pid_linux_test.dart`

**Interfaces:**
- Consumes: `AppServiceManager.forceKillPid(String appId, int pid, {Future<ProcessResult> Function(String, List<String>)? runProcess})`
- Produces: Process Group Kill lệnh `kill -9 -- -$pid` trên Linux, fallback về `kill -9 $pid` nếu kill process group thất bại (ví dụ process không phải leader).

- [ ] **Step 1: Viết failing test cho `forceKillPid` trên Linux**
  Tạo `test/features/apps/force_kill_pid_linux_test.dart`:
  - Test case 1: Trên Linux gọi `kill -9 -- -$pid` để kill toàn bộ process group.
  - Test case 2: Nếu lệnh kill process group trả về lỗi (exitCode != 0), fallback gọi `kill -9 $pid`.
  - Test case 3: Trên Windows vẫn gọi `taskkill /F /T /PID $pid`.

- [ ] **Step 2: Chạy test để xác nhận test fail**
  Run: `flutter test test/features/apps/force_kill_pid_linux_test.dart`
  Expected: FAIL (tham số hoặc behavior chưa khớp).

- [ ] **Step 3: Cập nhật triển khai trong `AppServiceManager`**
  Thêm tham số tuỳ chọn `runProcess` vào `forceKillPid`:
  ```dart
  Future<void> forceKillPid(
    String appId,
    int pid, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
    bool? isWindows,
  }) async {
    if (pid <= 0) {
      _logger.warning('No PID recorded for $appId; skipping force kill.');
      return;
    }
    _logger.info('Force killing PID $pid for $appId');
    final onWindows = isWindows ?? Platform.isWindows;
    final runner = runProcess ?? _run;
    if (!onWindows) {
      try {
        // First try killing the entire process group
        final groupRes = await runner('kill', ['-9', '--', '-$pid']);
        if (groupRes.exitCode != 0) {
          // Fallback to killing single PID if not group leader
          await runner('kill', ['-9', '$pid']);
        }
      } catch (e) {
        _logger.warning('Failed to kill PID $pid: $e');
      }
      return;
    }
    ...
  ```

- [ ] **Step 4: Chạy lại test suite để xác nhận PASS**
  Run: `flutter test test/features/apps/force_kill_pid_linux_test.dart test/features/apps/force_kill_pid_tree_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/app_service_manager.dart test/features/apps/force_kill_pid_linux_test.dart
  git commit -m "fix(lifecycle): use process group kill on Linux in forceKillPid"
  ```

---

### Task 2: Củng cố Ổn định Dịch vụ Systemctl & PHP-FPM (LIFE-02)

**Files:**
- Modify: `lib/features/apps/data/app_service_manager.dart:701-818`
- Create: `test/features/apps/systemctl_service_test.dart`

**Interfaces:**
- Consumes: `AppServiceManager._startPhpFpmViaSystemctl`, `AppServiceManager._stopPhpFpmViaSystemctl`, `isPhpFpmRunningViaSystemctl`
- Produces: Quản lý start/stop/status với dependency injection cho `Process.run`, fallback user->system service mượt mà, kiểm tra exitCode và liveness qua `systemctl is-active`.

- [ ] **Step 1: Viết failing test cho `systemctl` flow**
  Tạo `test/features/apps/systemctl_service_test.dart`:
  - Test case 1: Start thử `systemctl --user start`, nếu fail fallback sang `systemctl start`.
  - Test case 2: Start thành công thì kiểm tra liveness bằng `systemctl is-active` và lấy PID qua `systemctl show --property=MainPID`.
  - Test case 3: Nếu cả 2 lệnh start đều fail, ném ngoại lệ rõ ràng và chuyển status về `stopped`.
  - Test case 4: Stop gọi `systemctl stop` và cập nhật status sang `stopped`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/features/apps/systemctl_service_test.dart`
  Expected: FAIL

- [ ] **Step 3: Cập nhật `_startPhpFpmViaSystemctl` và `_stopPhpFpmViaSystemctl`**
  - Bổ sung `Future<ProcessResult> Function(String, List<String>)? runProcess` cho test injection.
  - Sau khi start, gọi `systemctl is-active <serviceName>` để xác nhận service đang chạy thật sự.
  - Xử lý chi tiết mã lỗi và ghi log rõ ràng.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  Run: `flutter test test/features/apps/systemctl_service_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/app_service_manager.dart test/features/apps/systemctl_service_test.dart
  git commit -m "fix(lifecycle): improve PHP-FPM systemctl management and liveness detection"
  ```

---

### Task 3: Định vị Đường dẫn `php.ini` cho Linux Package Manager (LIFE-03)

**Files:**
- Modify: `lib/features/apps/data/php_settings_provider.dart`
- Create: `test/features/apps/php_ini_resolver_test.dart`

**Interfaces:**
- Consumes: `PhpSettings._getPhpIni(AppModel app)`
- Produces: `File? resolvePhpIniFile(AppModel app, {bool? isLinux, List<String>? customSearchPaths})` hỗ trợ tự động tìm kiếm đường dẫn:
  - Windows standalone: `${app.location}\php.ini`
  - Linux `system_package`:
    1. `/etc/php/<version>/fpm/php.ini` (ví dụ `/etc/php/8.2/fpm/php.ini` hoặc `8.3`, `8.4`, ...)
    2. `/etc/php/<version>/cli/php.ini`
    3. `/etc/php.ini` (RHEL/CentOS)
    4. Fallback: trả về file theo quy ước `/etc/php/<version>/fpm/php.ini` để UI hiển thị đường dẫn mục tiêu rõ ràng thay vì `system_package/php.ini`.

- [ ] **Step 1: Viết failing test cho `resolvePhpIniFile`**
  Tạo `test/features/apps/php_ini_resolver_test.dart`:
  - Test case 1: App Windows trả về `<location>/php.ini`.
  - Test case 2: App Linux với `location == 'system_package'` và `appId == 'php82'` phân giải đúng `/etc/php/8.2/fpm/php.ini` (hoặc file tồn tại đầu tiên trong danh sách search).
  - Test case 3: App Linux với `location == 'system_package'` và `appId == 'php84'` phân giải đúng `/etc/php/8.4/fpm/php.ini`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/features/apps/php_ini_resolver_test.dart`
  Expected: FAIL

- [ ] **Step 3: Cập nhật `php_settings_provider.dart`**
  Triển khai hàm tách rời `resolvePhpIniFile` có thể kiểm thử độc lập và sử dụng trong `_getPhpIni`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  Run: `flutter test test/features/apps/php_ini_resolver_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/php_settings_provider.dart test/features/apps/php_ini_resolver_test.dart
  git commit -m "feat(php): resolve system php.ini paths on Linux for package_manager apps"
  ```

---

### Task 4: Siết chặt Quyền Tệp Tạm Hosts & Ghi Audit Log Pkexec (VULN-05, VULN-07 & VULN-14)

**Files:**
- Modify: `lib/features/hosts/data/hosts_repository.dart`
- Modify: `lib/core/services/background_process.dart`
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Create: `test/features/hosts/hosts_repository_security_test.dart`

**Interfaces:**
- Consumes: `HostsRepository.saveHostsRaw`, `BackgroundProcess.runElevated`, `AppInstallerService.ensureLinuxPermissions`
- Produces:
  - File tạm hosts trên Linux được gán quyền `0600` qua `chmod 600 <tempFile>`.
  - `BackgroundProcess.runElevated` ghi nhật ký audit: `AppLogger.info('Auditing elevated command execution: pkexec $executable $arguments')`.
  - `ensureLinuxPermissions` chỉ gán quyền thực thi cho binary (`chmod +x`), không gán tràn lan `chmod -R 755` lên toàn bộ folder cài đặt.

- [ ] **Step 1: Viết failing test cho bảo mật file hosts và permission binary**
  Tạo `test/features/hosts/hosts_repository_security_test.dart` kiểm tra gọi chmod 600 trên file tạm trước khi copy và audit logging.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/features/hosts/hosts_repository_security_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai cập nhật**
  - Trong `hosts_repository.dart`: gọi `chmod 600` trên Linux cho tempFile trước khi copy.
  - Trong `background_process.dart`: thêm audit logging rõ ràng trước khi gọi `pkexec`.
  - Trong `app_installer_service.dart`: cập nhật `ensureLinuxPermissions` chỉ gán `chmod +x` cho các tệp nhị phân thực thi.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/hosts/hosts_repository_security_test.dart test/features/apps/installer_linux_tar_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/hosts/data/hosts_repository.dart lib/core/services/background_process.dart lib/features/apps/data/app_installer_service.dart test/features/hosts/hosts_repository_security_test.dart
  git commit -m "security: tighten temporary file permissions and add pkexec audit logging"
  ```

---

### Task 5: Kiểm tra Toàn diện & Xác thực Linter (Verification & Static Analysis)

- [ ] **Step 1: Chạy toàn bộ test suite**
  Run: `flutter test`
  Expected: 100% tests PASS (không có regression).

- [ ] **Step 2: Chạy static analysis**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 3: Cập nhật tài liệu kế hoạch**
  Đánh dấu hoàn thành các checkbox trong `docs/superpowers/plans/2026-09-05-phase-2-lifecycle-hardening.md`.
