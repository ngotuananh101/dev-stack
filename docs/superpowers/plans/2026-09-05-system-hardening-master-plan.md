# Master Plan: Toàn diện Bảo mật, Vòng đời Tiến trình, Kiến trúc & Kiểm thử dev-stack

> **Tài liệu tham chiếu nghiên cứu:** Kết quả kiểm toán tự động đa tác tử (Multi-agent Dynamic Workflow Audit) ngày 05/09/2026.  
> **Mục tiêu:** Định hình khung chiến lược tổng thể (Master Plan) để nâng cao bảo mật, tối ưu hóa kiến trúc và củng cố độ ổn định đa nền tảng (Windows & Linux) cho `dev-stack`. Các kế hoạch triển khai chi tiết sẽ được bẻ nhỏ thành các sub-plan kỹ thuật theo mô hình TDD.

---

## I. TỔNG QUAN TÌNH TRẠNG & ĐÁNH GIÁ RỦI RO

Dự án `dev-stack` là môi trường quản trị stack phát triển (web server, PHP runtime, database) tương tự Laragon/Herd trên desktop (Flutter Windows & Linux). Điểm mạnh là kiến trúc phân tầng rõ ràng (Clean Architecture), phản hồi nhanh và hỗ trợ đa dạng dịch vụ.

Tuy nhiên, do tính chất tương tác trực tiếp ở tầng OS và quyền hạn cao (`sudo`, `pkexec`, `taskkill`, quản lý `/etc/hosts`, sửa file cấu hình), hệ thống tồn tại 4 nhóm thách thức cốt lõi:
1. **Bảo mật chuỗi cung ứng & Thực thi lệnh:** Thiếu xác thực mã băm binary tải về và bộ lọc lệnh shell ở package manager còn kẽ hở.
2. **Quản lý Vòng đời Tiến trình (Process Lifecycle):** Rủi ro rò rỉ tiến trình con (orphan/zombie worker) trên Linux và bất đồng bộ trạng thái PHP-FPM qua `systemctl`.
3. **Chất lượng Mã nguồn & Độ phức tạp:** Một số service quá lớn (`AppInstallerService.install()` > 250 dòng, cyclomatic complexity ~80; `_configureWebserver()` > 320 dòng).
4. **Khoảng trống Kiểm thử (Test Coverage Gaps):** Thiếu mock integration tests cho chuỗi tải/cài đặt và quản lý tiến trình ngầm; xuất hiện test "rỗng" (tautology test) ở Linux capability.

---

## II. MA TRẬN PHÂN LOẠI VẤN ĐỀ ĐÃ ĐƯỢC XÁC MINH (VERIFIED FINDINGS)

| ID | Nhóm vấn đề | Mức độ | Tệp nguồn liên quan | Tóm tắt sự cố & Tác động |
| :--- | :--- | :--- | :--- | :--- |
| **VULN-01** | Security | 🔴 **Critical** | `app_installer_service.dart:2409` | Lệnh `sh -c` kết hợp cờ `runInShell: true` gây double shell interpretation trên POSIX. |
| **VULN-02** | Security | 🔴 **High** | `package_command_validator.dart:33,44` | Danh sách trắng `_allowedBinaries` chứa `tee`, `sudo`, `pkexec` tạo lỗ hổng leo thang hoặc ghi đè file tùy ý. |
| **VULN-04** | Security | 🔴 **High** | `app_installer_service.dart:865` | `executablePath` truyền trực tiếp vào `sudo setcap` chưa được kiểm tra tính hợp lệ trong `AppConfig.appsDir`. |
| **VULN-08** | Security | 🔴 **High** | `app_installer_service.dart:236,411` | Thao tác giải nén `tar -xf` thiếu kiểm tra path traversal (`../`) khiến archive có thể ghi đè file ngoài thư mục cài đặt. |
| **VULN-12** | Security | 🔴 **High** | `app_installer_service.dart:197` | Không xác minh SHA256 checksum/signature cho file tải từ URL catalog; catalog URL thiếu bắt buộc HTTPS. |
| **VULN-03** | Security | 🟡 **Medium** | `app_installer_service.dart:1907` | Secret Blowfish của phpMyAdmin sinh từ timestamp `microsecondsSinceEpoch` có thể dự đoán được. |
| **VULN-05** | Security | 🟡 **Medium** | `background_process.dart:170`, `hosts_repository.dart:49` | Nâng quyền qua `pkexec` không ghi nhật ký kiểm toán (audit trail) đầy đủ tham số dòng lệnh. |
| **VULN-11** | Security | 🟡 **Medium** | `database_record.dart:13` | Mật khẩu kết nối database lưu dạng plain text trong cơ sở dữ liệu Isar. |
| **VULN-13** | Security | 🟡 **Medium** | `app_installer_service.dart:806` | Cấu hình PostgreSQL gán `listen_addresses = '*'` cố định, expose DB ra LAN ngay cả khi tắt `allowLanAccess`. |
| **VULN-06** | Bug / Quality | 🟢 **Low** | `app_installer_service.dart:2496` | Chuỗi fallback `'/usr/bin/$phpName'` dùng single quotes không nội suy biến, khiến logic fallback luôn sai. |
| **VULN-07** | Security | 🟢 **Low** | `hosts_repository.dart:44` | File tạm `/tmp/ponta_hosts_*` không thiết lập phân quyền chặt chẽ (0600). |
| **VULN-14** | Security | 🟢 **Low** | `app_installer_service.dart:116` | Thực thi `chmod -R 755` trên toàn bộ thư mục cài đặt, làm lộ quyền đọc/thực thi file dữ liệu và config nhạy cảm. |
| **VULN-15** | Security | 🟢 **Low** | `app_config.dart:52` | Cập nhật `DEVSTACK_BASE_DIR` trên Windows qua PowerShell thiếu kiểm tra whitelist thư mục hợp lệ. |
| **ARCH-01** | Architecture | 🟡 **Medium** | `app_installer_service.dart:131-389` | Phương thức `install()` nguyên khối xử lý 7 định dạng nén và 6 nhánh cấu hình dịch vụ. |
| **ARCH-02** | Architecture | 🟡 **Medium** | `app_installer_service.dart:897-1220` | `_configureWebserver()` gộp Nginx, Caddy, Apache dài hơn 320 dòng, lặp mẫu vhost. |
| **ARCH-03** | Architecture | 🟡 **Medium** | `isar_provider.dart:12` | `IsarInstance.getInstance()` có nguy cơ race condition khi mở đồng thời nhiều luồng lúc khởi động. |
| **ARCH-04** | Architecture | 🟡 **Medium** | `log_service.dart:11` | `AppLogger` dùng mô hình global singleton tĩnh thay vì Riverpod Provider, cản trở mock testing. |
| **LIFE-01** | Lifecycle | 🔴 **High** | `app_service_manager.dart:636-663` | `forceKillPid` trên Linux chỉ dùng `kill -9 <pid>` đơn lẻ thay vì Process Group, gây rò rỉ worker Nginx/Caddy. |
| **LIFE-02** | Lifecycle | 🟡 **Medium** | `app_service_manager.dart:701-818` | Khởi động PHP-FPM qua `systemctl` không bắt lỗi non-zero exit code và không probe `is-active`, gây lệch trạng thái UI. |
| **LIFE-03** | Lifecycle / UX | 🟡 **Medium** | `php_settings_provider.dart:13` | Cài đặt PHP từ package manager gán `location='system_package'`, dẫn đến màn hình sửa `php.ini` bị trắng tinh. |
| **TEST-01** | Test Gap | 🔴 **High** | `installer_linux_capability_test.dart` | Cảnh báo `unused_import` và toàn bộ 9 test là tautology (`expect(true, isTrue)`), chưa kiểm tra hàm thật. |
| **TEST-02** | Test Gap | 🟡 **Medium** | `apps_repository_test.dart` | Test bị skip toàn bộ do phụ thuộc thư viện native `isar.dll`. |
| **CLEAN-01** | Hygiene | 🟢 **Low** | `assets/data/new-apps-linux.json` | Tệp catalog nháp bị bỏ quên không được sử dụng. |

---

## III. CHIẾN LƯỢC PHÂN KỲ & LỘ TRÌNH THỰC HIỆN

Kế hoạch tổng thể được chia thành **4 giai đoạn (Sub-plans)** độc lập, có thể giao việc tuần tự hoặc song song:

```
┌─────────────────────────────────────────────────────────────┐
│ MASTER PLAN: DEV-STACK HARDENING & REFACTORING              │
└──────────────────────────────┬──────────────────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  SUB-PLAN 1  │       │  SUB-PLAN 2  │       │  SUB-PLAN 3  │
│  Quick Wins  │──────▶│   Platform   │──────▶│ Architecture │
│  & Security  │       │  Lifecycle   │       │ & Testing    │
│  Fixes       │       │  Hardening   │       │ Refactoring  │
└──────────────┘       └──────────────┘       └──────────────┘
                               │
                               ▼
                       ┌──────────────┐
                       │  SUB-PLAN 4  │
                       │ Supply Chain │
                       │ & Encryption │
                       └──────────────┘
```

---

### GIAI ĐOẠN 1: QUICK WINS & CÁC LỖ HỔNG BẢO MẬT KHẨN CẤP
*Dự kiến thời gian: 1–2 ngày | Mục tiêu: Loại bỏ hoàn toàn các rủi ro bảo mật mức Critical & High và sửa linter.*

1. **Sub-plan 1.1: Khắc phục Command Injection & Validator Bypass**
   - Loại bỏ `runInShell: true` tại `app_installer_service.dart:2409` (VULN-01).
   - Tinh chỉnh `package_command_validator.dart`: loại bỏ `tee`, `sudo`, `pkexec` khỏi `_allowedBinaries` và siết chặt regex đường dẫn tuyệt đối (VULN-02).
   - Sửa lỗi nội suy chuỗi `$phpName` trong `_findInstalledPhp` (VULN-06).

2. **Sub-plan 1.2: Bảo mật Cấp quyền & Khởi tạo Secret**
   - Thay thế việc sinh Blowfish secret bằng hàm `_generateSecret()` sử dụng `Random.secure()` (VULN-03).
   - Bổ sung xác thực `p.isWithin(AppConfig.appsDir, executablePath)` trước khi chạy `sudo setcap` (VULN-04).
   - Ràng buộc cấu hình PostgreSQL `listen_addresses`: chỉ gán `'*'` khi `allowLanAccess == true`, mặc định `'127.0.0.1'` (VULN-13).

3. **Sub-plan 1.3: Dọn dẹp & Chuẩn hóa Kiểm thử ban đầu**
   - Xóa cảnh báo `unused_import` và viết lại ca kiểm thử có ý nghĩa cho `installer_linux_capability_test.dart` (TEST-01).
   - Xóa tệp dư thừa `assets/data/new-apps-linux.json` (CLEAN-01).

---

### GIAI ĐOẠN 2: CỦNG CỐ VÒNG ĐỜI TIẾN TRÌNH & NỀN TẢNG LINUX
*Dự kiến thời gian: 1–2 tuần | Mục tiêu: Triệt tiêu rò rỉ tiến trình mồ côi và đồng bộ hóa trạng thái dịch vụ.*

1. **Sub-plan 2.1: Đồng bộ hóa cơ chế Process Termination**
   - Nâng cấp `forceKillPid` trên Linux: sử dụng Process Group Kill (`kill -9 -- -$pid` hoặc gửi tín hiệu theo nhóm) tương thích với logic trong `stopManaged`, đảm bảo giải phóng toàn bộ worker tiến trình con (LIFE-01).
   - Xử lý cơ chế timeout và escalation: gửi `SIGTERM`, chờ tối đa 3 giây, nếu không thoát thì leo thang sang `SIGKILL`.

2. **Sub-plan 2.2: Ổn định Dịch vụ Systemctl & PHP-FPM**
   - Bổ sung kiểm tra exit code cho `systemctl [--user] start`, tự động fallback về system instance nếu user session bus không sẵn sàng (LIFE-02).
   - Thêm bước liveness probe định kỳ (`systemctl is-active`) để cập nhật trạng thái UI chính xác, tránh hiển thị "Running" ảo.
   - Xử lý màn hình chỉnh sửa `php.ini` khi cài qua `system_package`: định vị đúng đường dẫn cấu hình mặc định của distro (`/etc/php/X.Y/fpm/php.ini`) hoặc hiển thị hướng dẫn trực quan thay vì để trống (LIFE-03).

3. **Sub-plan 2.3: An toàn Tệp tin Tạm & Phân quyền File**
   - Thiết lập quyền `0600` cho file tạm `/tmp/ponta_hosts_*` trước khi copy sang `/etc/hosts` (VULN-07).
   - Ghi audit log rõ ràng trước khi gọi `pkexec` (VULN-05).
   - Tinh chỉnh lệnh cấp quyền Linux sau cài đặt: chỉ cấp quyền thực thi `755` cho các thư mục nhị phân `bin/` thay vì `chmod -R 755` trên toàn bộ folder cài đặt (VULN-14).

---

### GIAI ĐOẠN 3: TÁI CẤU TRÚC KIẾN TRÚC & MỞ RỘNG ĐỘ PHỦ TEST
*Dự kiến thời gian: 2–3 tuần | Mục tiêu: Giảm nợ kỹ thuật (Technical Debt) và củng cố độ bền vững hệ thống.*

1. **Sub-plan 3.1: Chia tách Phương thức `AppInstallerService.install()`**
   - Áp dụng mẫu Strategy Pattern hoặc tách thành các hàm riêng biệt:
     - `_installFromZip(file, targetDir)`
     - `_installFromTar(file, targetDir)` (tích hợp phòng chống Traversal - VULN-08)
     - `_installFromExe(file, targetDir)`
   - Tách các hàm cấu hình hậu cài đặt theo phân nhóm: `_configureDatabaseService()`, `_configureRuntimeService()`.

2. **Sub-plan 3.2: Module hóa Webserver Config Builders**
   - Tách cấu hình Apache và Nginx ra khỏi `_configureWebserver()` thành các class độc lập: `NginxConfigBuilder` và `ApacheConfigBuilder` tương tự như `CaddyConfigBuilder` hiện có (ARCH-02).
   - Giảm thiểu việc sao chép chuỗi template thủ công và tập trung hóa logic xử lý vhost.

3. **Sub-plan 3.3: Tối ưu Quản lý State & Database Transaction**
   - Thêm cơ chế khóa `Completer` cho `IsarInstance.getInstance()` để ngăn ngừa race condition khi khởi động ứng dụng (ARCH-03).
   - Tránh việc sửa đổi object Isar in-place trong `settings_provider.dart` (`updateField`), chuyển sang cơ chế immutable copy trước khi ghi DB.
   - Triển khai Mock Isar để mở lại bộ test `apps_repository_test.dart` (TEST-02).

---

### GIAI ĐOẠN 4: BẢO MẬT NÂNG CAO & CHUỖI CUNG ỨNG (ADVANCED SECURITY)
*Dự kiến thời gian: 2–3 tuần | Mục tiêu: Hoàn thiện phòng thủ chiều sâu và bảo vệ dữ liệu nhạy cảm.*

1. **Sub-plan 4.1: Xác thực Checksum Binary & Kiểm tra HTTPS**
   - Bổ sung trường `sha256` hoặc link `.sha256` vào schema `apps.json` và `apps-linux.json`.
   - Viết pipeline tự động xác minh mã băm SHA256 sau khi tải file qua `_dio.download()` trước khi giải nén (VULN-12).
   - Bắt buộc kiểm tra giao thức `https://` khi người dùng nhập URL catalog ngoài.

2. **Sub-plan 4.2: Mã hóa Dữ liệu Nhạy cảm Lưu trữ Cục bộ**
   - Tích hợp `flutter_secure_storage` hoặc cơ chế mã hóa nền tảng (DPAPI trên Windows / Libsecret trên Linux) để mã hóa mật khẩu database trong `DatabaseRecord` (VULN-11).

---

## IV. NGUYÊN TẮC THI CÔNG CHI TIẾT KHI LẬP SUB-PLAN

Mỗi sub-plan cụ thể khi được tạo trong thư mục `docs/superpowers/plans/` cần tuân thủ cấu trúc sau:
1. **Tiêu đề rõ ràng:** Kèm ngày tháng theo định dạng `YYYY-MM-DD-<slug>.md`.
2. **Global Constraints:** Đảm bảo 100% tương thích ngược với Windows; duy trì toàn bộ test hiện có ở trạng thái PASS; chuẩn hóa path bằng `package:path/path.dart`.
3. **Mô hình TDD từng bước:**
   - **Step 1:** Viết test fail trước (Unit test hoặc mock runner).
   - **Step 2:** Chạy kiểm tra test fail đúng như kỳ vọng.
   - **Step 3:** Thực hiện chỉnh sửa mã nguồn tối giản nhất để pass test.
   - **Step 4:** Chạy kiểm tra lại test suite và kiểm tra tĩnh bằng `flutter analyze`.
   - **Step 5:** Commit rõ ràng theo conventional commits (`fix:`, `refactor:`, `test:`).
4. **Cập nhật Checklist:** Sau khi hoàn thành code và commit, phải cập nhật đánh dấu tích (`- [x]`) ngay vào tệp plan để theo dõi tiến độ chính xác.

---
*Tài liệu này đóng vai trò là kim chỉ nam chiến lược duy nhất cho toàn bộ các công việc nâng cấp và dọn dẹp hệ thống trong tương lai.*
