# Giai đoạn 4: Bảo mật Chuỗi Cung ứng & Mã hóa Dữ liệu Nhạy cảm (Phase 4 Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện bảo mật chuỗi cung ứng tải binary (xác thực SHA256 checksum, bắt buộc HTTPS cho catalog URLs - VULN-12) và mã hóa bảo vệ mật khẩu cơ sở dữ liệu lưu trữ cục bộ trong Isar (VULN-11).

**Architecture:** 
1. Mở rộng `AppModel` và schema catalog để hỗ trợ checksum SHA256 (`versionSha256` / `sha256`); tích hợp pipeline tính toán và so khớp hash stream SHA-256 sau khi tải binary trong `AppInstallerService._downloadPayload` trước khi cho phép giải nén.
2. Siết chặt `AppsRepository.updateAppListFromUrl` chỉ chấp nhận URL có scheme `https://` hợp lệ để ngăn chặn Man-in-the-Middle (MitM) catalog tampering.
3. Xây dựng dịch vụ mã hóa cục bộ `LocalSecretVault` (sử dụng platform-backed AES / PBKDF2 với persistent secure salt & key derive hoặc platform-safe secure store) để mã hóa/giải mã trường mật khẩu trong `DatabaseRecord` trước khi ghi vào Isar và sau khi đọc ra giao diện.

**Tech Stack:** Dart 3.11, Flutter 3.41, `crypto` package (SHA256, HMAC/PBKDF2), Riverpod, Isar.

**Spec:** `docs/superpowers/plans/2026-09-05-system-hardening-master-plan.md`

## Global Constraints

- 100% tương thích ngược với Windows và Linux.
- Toàn bộ 401 test hiện có phải tiếp tục PASS mà không có regression.
- Không phá vỡ dữ liệu đã tồn tại trong database Isar của người dùng (backward compatible cho plaintext passwords cũ nếu có).
- Đường dẫn chuẩn hóa qua `package:path/path.dart`.
- Tuân thủ nghiêm ngặt quy trình TDD: viết test fail trước, triển khai code tối thiểu, kiểm tra PASS và commit.

---

### File Structure & Trách nhiệm

| Tệp nguồn | Trách nhiệm chính |
| :--- | :--- |
| `lib/features/apps/domain/app_model.dart` | Mở rộng trường `versionSha256Json` / getter `versionSha256` lưu trữ mã băm SHA256 tương ứng từng version từ catalog. |
| `lib/features/apps/data/apps_repository.dart` | Parse trường `sha256` từ catalog json trong `mergeAppsCatalog`; bắt buộc scheme `https://` trong `updateAppListFromUrl`. |
| `lib/features/apps/data/app_installer_service.dart` | Tích hợp xác thực checksum SHA256 (`verifyFileChecksum`) sau khi tải file trong `_downloadPayload`; ném ngoại lệ nếu hash không khớp. |
| `lib/core/security/local_secret_vault.dart` | Dịch vụ mã hóa và giải mã chuỗi nhạy cảm (AES-GCM / XOR-HMAC keystore) độc lập cho desktop, tự sinh và bảo vệ master key trong app support directory. |
| `lib/features/databases/data/databases_provider.dart` | Sử dụng `LocalSecretVault` để mã hóa mật khẩu khi lưu vào `DatabaseRecord` và giải mã khi nạp ra danh sách / copy. |
| `test/features/apps/checksum_verification_test.dart` | Kiểm thử tính toán SHA256 và từ chối file có checksum không khớp hoặc sai lệch. |
| `test/features/apps/catalog_https_enforcement_test.dart` | Kiểm thử bắt buộc HTTPS cho `updateAppListFromUrl` và từ chối các URL HTTP / file không an toàn. |
| `test/core/security/local_secret_vault_test.dart` | Kiểm thử mã hóa / giải mã đối xứng, tính toàn vẹn và khả năng xử lý fallback cho plain text cũ. |
| `test/features/databases/database_credential_encryption_test.dart` | Kiểm thử lưu trữ mật khẩu mã hóa trong database Isar và hiển thị / copy mật khẩu an toàn. |

---

### Task 1: Bắt buộc HTTPS cho Remote Catalog URLs (VULN-12 Part 1)

**Files:**
- Modify: `lib/features/apps/data/apps_repository.dart`
- Create: `test/features/apps/catalog_https_enforcement_test.dart`

**Interfaces:**
- Consumes: `AppsRepository.updateAppListFromUrl(String url)`
- Produces: Kiểm tra URL hợp lệ bằng `Uri.tryParse(url)`; từ chối (ném `ArgumentError` hoặc `SecurityException`) mọi URL không có scheme `https`.

- [ ] **Step 1: Viết failing test cho `updateAppListFromUrl`**
  Tạo `test/features/apps/catalog_https_enforcement_test.dart`:
  - Test 1: URL HTTP (`http://example.com/apps.json`) -> ném `ArgumentError` thông báo catalog URL phải sử dụng HTTPS.
  - Test 2: URL Scheme khác (`ftp://`, `file:///etc/passwd`, `javascript:...`) -> ném `ArgumentError`.
  - Test 3: URL HTTPS (`https://example.com/apps.json`) -> hợp lệ và tiếp tục tiến trình tải.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/features/apps/catalog_https_enforcement_test.dart`
  Expected: FAIL

- [ ] **Step 3: Cập nhật `AppsRepository.updateAppListFromUrl`**
  ```dart
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
    throw ArgumentError('Catalog URL must use secure HTTPS protocol: $url');
  }
  ```

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/apps/catalog_https_enforcement_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/apps_repository.dart test/features/apps/catalog_https_enforcement_test.dart
  git commit -m "fix(security): enforce HTTPS for remote catalog updates (VULN-12)"
  ```

---

### Task 2: Hỗ trợ Metadata Checksum SHA256 trong AppModel & Catalog Parsing (VULN-12 Part 2)

**Files:**
- Modify: `lib/features/apps/domain/app_model.dart`
- Modify: `lib/features/apps/data/apps_repository.dart`
- Create: `test/features/apps/checksum_metadata_test.dart`

**Interfaces:**
- Consumes: `AppModel.versionSha256`, `AppModel.versionSha256Json`, `AppsRepository.mergeAppsCatalog`
- Produces: 
  - `Map<String, String> get versionSha256` trong `AppModel`.
  - `mergeAppsCatalog` tự động đọc thuộc tính `sha256` (Map version -> hash hoặc string hash) từ JSON catalog và đưa vào `versionSha256Json`.

- [ ] **Step 1: Viết failing test cho parse checksum metadata**
  Tạo `test/features/apps/checksum_metadata_test.dart`:
  - Test 1: Catalog JSON có `sha256: {"25.9.0": "abc123..."}` -> `app.versionSha256['25.9.0'] == 'abc123...'`.
  - Test 2: Catalog JSON không có `sha256` -> `app.versionSha256` trả về rỗng `{}` mà không crash.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/features/apps/checksum_metadata_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai thuộc tính `versionSha256Json` trong `AppModel` và parse trong `AppsRepository`**
  - Thêm `String? versionSha256Json` và getter/setter `versionSha256` vào `AppModel`.
  - Trong `AppsRepository.mergeAppsCatalog`: trích xuất trường `sha256` từ `json['sha256']` nếu có.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/apps/checksum_metadata_test.dart test/features/apps/apps_repository_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/domain/app_model.dart lib/features/apps/data/apps_repository.dart test/features/apps/checksum_metadata_test.dart
  git commit -m "feat(apps): add sha256 checksum metadata support to AppModel and catalog parser"
  ```

---

### Task 3: Pipeline Xác thực Checksum Binary Sau khi Tải (VULN-12 Part 3)

**Files:**
- Modify: `lib/features/apps/data/app_installer_service.dart`
- Create: `test/features/apps/checksum_verification_test.dart`

**Interfaces:**
- Consumes: `AppInstallerService.verifyFileChecksum(File file, String expectedSha256)`
- Produces: Hàm stream SHA256 từ `crypto` package và so sánh case-insensitive mã băm. Nếu file không khớp checksum mong đợi, ném ngoại lệ `ChecksumMismatchException` và xóa tệp tải bị hỏng.

- [ ] **Step 1: Viết failing test cho `verifyFileChecksum`**
  Tạo `test/features/apps/checksum_verification_test.dart`:
  - Test 1: File có nội dung khớp với hash sha256 -> `verifyFileChecksum` trả về true.
  - Test 2: File có nội dung bị chỉnh sửa/không khớp hash -> `verifyFileChecksum` ném `ChecksumMismatchException`.
  - Test 3: Hash chuỗi hoa hay thường (lowercase / uppercase) đều được so khớp chính xác.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/features/apps/checksum_verification_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai `verifyFileChecksum` và tích hợp vào `_downloadPayload` trong `AppInstallerService`**
  - Viết `Future<bool> verifyFileChecksum(File file, String expectedSha256)` bằng stream sha256.
  - Trong `install()`: lấy `expectedHash = app.versionSha256[version]`. Nếu có `expectedHash`, gọi `verifyFileChecksum(tempFile, expectedHash)`.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/apps/checksum_verification_test.dart test/features/apps/tar_traversal_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/apps/data/app_installer_service.dart test/features/apps/checksum_verification_test.dart
  git commit -m "feat(security): verify binary SHA256 checksum before extraction (VULN-12)"
  ```

---

### Task 4: Xây dựng Dịch vụ Mã hóa Cục bộ `LocalSecretVault` (VULN-11 Part 1)

**Files:**
- Create: `lib/core/security/local_secret_vault.dart`
- Create: `test/core/security/local_secret_vault_test.dart`

**Interfaces:**
- Consumes: `LocalSecretVault.encrypt(String plaintext)`, `LocalSecretVault.decrypt(String ciphertext)`
- Produces:
  - Khởi tạo key mã hóa bảo mật từ file master key cục bộ được lưu an toàn (chỉ user hiện tại có quyền đọc).
  - Sử dụng HMAC-SHA256 authenticated encryption hoặc AES-equivalent stream cipher với IV ngẫu nhiên cho mỗi bản mã (`ENC:<iv>:<ciphertext>:<mac>`).
  - Hỗ trợ giải mã fallback trong suốt: nếu chuỗi không bắt đầu bằng prefix mã hóa (`ENC:`), trả về nguyên bản plaintext (đảm bảo 100% tương thích ngược với mật khẩu cũ chưa mã hóa).

- [ ] **Step 1: Viết failing test cho `LocalSecretVault`**
  Tạo `test/core/security/local_secret_vault_test.dart`:
  - Test 1: Chuỗi rỗng `encrypt('')` -> trả về `''`.
  - Test 2: Mã hóa chuỗi plaintext -> kết quả có prefix `ENC:` và không chứa plaintext gốc.
  - Test 3: Giải mã chuỗi đã mã hóa -> trả về đúng chuỗi plaintext ban đầu.
  - Test 4: Giải mã chuỗi chưa mã hóa (legacy password) -> trả về nguyên chuỗi ban đầu.
  - Test 5: Hai lần mã hóa cùng một nội dung sinh ra 2 ciphertext khác nhau (nhờ IV ngẫu nhiên).

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/core/security/local_secret_vault_test.dart`
  Expected: FAIL

- [ ] **Step 3: Triển khai `LocalSecretVault`**
  Tạo `lib/core/security/local_secret_vault.dart` với thuật toán mã hóa đối xứng xác thực (HMAC-SHA256 authenticated keystore), quản lý master key file an toàn.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/core/security/local_secret_vault_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/security/local_secret_vault.dart test/core/security/local_secret_vault_test.dart
  git commit -m "feat(security): implement LocalSecretVault for local sensitive data encryption (VULN-11)"
  ```

---

### Task 5: Tích hợp Mã hóa Mật khẩu Cơ sở Dữ liệu trong `DatabasesNotifier` (VULN-11 Part 2)

**Files:**
- Modify: `lib/features/databases/data/databases_provider.dart`
- Create: `test/features/databases/database_credential_encryption_test.dart`

**Interfaces:**
- Consumes: `LocalSecretVault.encrypt`, `LocalSecretVault.decrypt`
- Produces:
  - Khi lưu `DatabaseRecord` trong `addDatabase` hoặc `updateDatabase`: mật khẩu được mã hóa qua `LocalSecretVault.encrypt` trước khi ghi vào Isar.
  - Khi nạp `DatabaseRecord` trong `fetchByEngine` hoặc khi lấy mật khẩu hiển thị / sao chép: giải mã bằng `LocalSecretVault.decrypt`.
  - Mật khẩu truyền vào CLI (`CREATE USER ... IDENTIFIED BY ...`) vẫn sử dụng bản rõ an toàn đã giải mã.

- [ ] **Step 1: Viết failing test cho lưu trữ mật khẩu mã hóa**
  Tạo `test/features/databases/database_credential_encryption_test.dart`:
  - Test 1: Khi lưu record, giá trị `password` trong Isar có tiền tố `ENC:` (không lưu plaintext).
  - Test 2: Khi truy xuất ra UI / state, mật khẩu được giải mã chính xác.
  - Test 3: Record cũ có plaintext password vẫn được giải mã ra giá trị chính xác không lỗi.

- [ ] **Step 2: Chạy test xác nhận fail**
  Run: `flutter test test/features/databases/database_credential_encryption_test.dart`
  Expected: FAIL

- [ ] **Step 3: Cập nhật `DatabasesNotifier` trong `databases_provider.dart`**
  - Tích hợp `LocalSecretVault` để mã hóa mật khẩu trước khi put vào Isar.
  - Giải mã mật khẩu khi load records trong `fetchByEngine`.

- [ ] **Step 4: Chạy test xác nhận PASS**
  Run: `flutter test test/features/databases/database_credential_encryption_test.dart`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/databases/data/databases_provider.dart test/features/databases/database_credential_encryption_test.dart
  git commit -m "feat(databases): encrypt database credentials in local Isar storage (VULN-11)"
  ```

---

### Task 6: Kiểm tra Toàn diện & Xác thực Linter (Verification & Static Analysis)

- [ ] **Step 1: Chạy toàn bộ test suite**
  Run: `flutter test`
  Expected: 100% tests PASS (tất cả các bài test từ Phase 1, 2, 3 và Phase 4 mới đều PASS).

- [ ] **Step 2: Chạy static analysis**
  Run: `flutter analyze`
  Expected: No issues found!

- [ ] **Step 3: Cập nhật checklist tài liệu kế hoạch Phase 4**
  Đánh dấu hoàn thành các checkbox trong `docs/superpowers/plans/2026-09-05-phase-4-supply-chain-encryption.md`.
