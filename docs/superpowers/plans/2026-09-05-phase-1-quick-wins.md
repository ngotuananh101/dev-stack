# Giai đoạn 1: Quick Wins & Bảo mật Khẩn cấp (Phase 1 Sub-Plan)

> **Thuộc Master Plan:** `docs/superpowers/plans/2026-09-05-system-hardening-master-plan.md`  
> **Mục tiêu:** Khắc phục ngay các lỗ hổng bảo mật cấp bách (Critical / High / Medium), loại bỏ cảnh báo linter và hoàn thiện kiểm thử thực tế cho tính năng cấp quyền Linux capability.

---

## Danh sách công việc (Tasks & Checklist)

### Task 1: Loại bỏ `runInShell: true` redundant tránh Double Shell Interpretation (VULN-01)
- **Tệp chỉnh sửa:** `lib/features/apps/data/app_installer_service.dart:2409`
- **Mô tả:** Lệnh `Process.run('sh', ['-c', cmd], runInShell: true)` khiến Dart bọc thêm một lớp `/bin/sh -c` bên ngoài lệnh đã có `sh -c`, tạo kẽ hở double-interpretation vượt qua kiểm duyệt.
- [x] **Step 1:** Viết/cập nhật unit test kiểm tra tham số gọi `Process.run` hoặc cấu trúc thực thi lệnh gói package.
- [x] **Step 2:** Xóa `runInShell: true` tại dòng 2409 trong `app_installer_service.dart`.
- [x] **Step 3:** Chạy `flutter test` đảm bảo các test liên quan không bị ảnh hưởng.

---

### Task 2: Siết chặt Allowlist & Ngăn chặn Bypass trong PackageCommandValidator (VULN-02)
- **Tệp chỉnh sửa:** `lib/features/apps/data/package_command_validator.dart`
- **Tệp kiểm thử:** `test/features/apps/package_command_validator_test.dart`
- **Mô tả:** 
  1. Loại bỏ `tee`, `sudo`, `pkexec` khỏi danh sách `_allowedBinaries`.
  2. Bổ sung regex kiểm tra an toàn cho lệnh `tee` (nếu bắt buộc phải ghi nguồn APT thì chỉ cho phép ghi vào các path cụ thể như `/etc/apt/sources.list.d/php.list`, không cho phép ghi tùy ý).
  3. Cập nhật `_leadingBinary` regex để không cho phép đường dẫn tùy ý bypass.
- [x] **Step 1:** Viết các test case từ chối các lệnh độc hại (`tee /etc/shadow`, `sudo tee`, `/tmp/evil`).
- [x] **Step 2:** Cập nhật `package_command_validator.dart` để chặn các trường hợp trên trong khi vẫn cho phép các lệnh hợp lệ của catalog hiện tại.
- [x] **Step 3:** Chạy `flutter test test/features/apps/package_command_validator_test.dart` xác nhận toàn bộ test PASS.

---

### Task 3: Sinh Secret An toàn & Sửa Lỗi Fallback PHP (VULN-03 & VULN-06)
- **Tệp chỉnh sửa:** `lib/features/apps/data/app_installer_service.dart`
- **Tệp kiểm thử:** `test/features/apps/installer_php_secret_test.dart`
- **Mô tả:**
  1. Thay thế secret phpMyAdmin dựa trên `DateTime.now().microsecondsSinceEpoch` bằng hàm `_generateSecret(length: 32)` sử dụng `Random.secure()`.
  2. Sửa mảng `commonPaths` trong `_findInstalledPhp` từ `'/usr/bin/$phpName'` (nháy đơn không nội suy) sang nội suy biến đúng hoặc dùng `p.join`.
- [x] **Step 1:** Viết test kiểm tra độ ngẫu nhiên và chiều dài của blowfish secret sinh ra.
- [x] **Step 2:** Cập nhật code tại `app_installer_service.dart:1907` và `app_installer_service.dart:2496`.
- [x] **Step 3:** Chạy kiểm thử xác nhận pass.

---

### Task 4: Xác thực Path cho `sudo setcap` & Ràng buộc PostgreSQL LAN Access (VULN-04 & VULN-13)
- **Tệp chỉnh sửa:** `lib/features/apps/data/app_installer_service.dart`
- **Tệp kiểm thử:** `test/features/apps/installer_security_hardening_test.dart`
- **Mô tả:**
  1. Trong `_setLinuxCapabilityForWebserver`: kiểm tra `p.isWithin(AppConfig.appsDir, executablePath)` để từ chối cấp quyền cho các binary nằm ngoài thư mục ứng dụng hợp lệ.
  2. Trong `_initializePostgresql`: chỉ gán `listen_addresses = '*'` khi có cấu hình cho phép LAN access, mặc định giữ an toàn ở `127.0.0.1`.
- [x] **Step 1:** Viết test case từ chối path bất hợp pháp cho capability setup.
- [x] **Step 2:** Cập nhật logic kiểm tra path và cấu hình PostgreSQL trong `app_installer_service.dart`.
- [x] **Step 3:** Chạy kiểm thử xác nhận.

---

### Task 5: Giải quyết Linter & Viết lại Test Thực tế cho Linux Capability (TEST-01 & CLEAN-01)
- **Tệp chỉnh sửa:** 
  - `test/features/apps/installer_linux_capability_test.dart`
  - Xóa `assets/data/new-apps-linux.json`
- **Mô tả:**
  1. Xóa bỏ unused import.
  2. Tái cấu trúc `_setLinuxCapabilityForWebserver` cho phép nhận dependency injection runner (`ProcessRunner`) để viết test thực tế thay vì tautology (`expect(true, isTrue)`).
  3. Xóa tệp json nháp không sử dụng `assets/data/new-apps-linux.json`.
- [x] **Step 1:** Xóa tệp `new-apps-linux.json`.
- [x] **Step 2:** Tái cấu trúc `_setLinuxCapabilityForWebserver` hỗ trợ mock process runner.
- [x] **Step 3:** Viết lại `test/features/apps/installer_linux_capability_test.dart` thực thi kiểm tra mock sudo và pkexec.
- [x] **Step 4:** Chạy `flutter analyze` và `flutter test` đảm bảo 0 warning, 0 error.
