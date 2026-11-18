# Thiết kế: hỏi quyền cài thư viện build trước khi cài Python bằng pyenv

Ngày: 2026-11-18
Trạng thái: đã duyệt

## Ý định (vì sao)

Cài Python 3.15.2 bằng pyenv thất bại vì máy thiếu openssl-devel: CPython build
ra không có module ssl, pyenv kiểm tra sau khi cài thì tính là fail rồi tự xoá
bản build. Phần hiện log lỗi đã sửa xong (`installVersion` giữ lại đoạn cuối
stdout/stderr trong dialog và trang Logs). Tính năng này ngăn lỗi từ đầu: kiểm
tra thư viện build trước khi build Python, thiếu thì hỏi quyền cài rồi mới build.

## Mục tiêu

- Bấm Install một version Python mà thiếu lib thì app hỏi và tự cài lib rồi mới build.
- Chỉ cài những gói đang thiếu.
- Dùng đúng mẫu phần SSL đã có: nhận diện distro, cài bằng pkexec, hỏi một lần,
  hiện đúng lệnh sẽ chạy.

## Không làm (non-goals)

- Không tự cài lib mà không hỏi.
- Không quản lý lib sau khi cài (không gỡ, không cập nhật).
- Không áp cho Windows (pyenv-win không build từ source nên không cần lib).
- Không đụng vào flow cài app pyenv — chỉ hook vào lúc cài version Python.

## Không được phép (anti-goals)

- Hỏi lặp lại mỗi lần dù đã từ chối.
- Chạy lệnh quyền admin mà không cho xem trước.
- Đoán sai distro/gói rồi cài nhầm.

## Ràng buộc

- Chỉ Linux.
- Cài bằng `BackgroundProcess.runElevated` (pkexec) như SSL.
- Lệnh package manager phải non-interactive (`-y` / `--noconfirm`) vì pkexec
  không có terminal để trả lời.
- Dialog xin quyền là `AppDialogs.showPermissionRequest` đã có (hiện đúng lệnh,
  nút ALLOW/CANCEL, bấm ra ngoài tính là không).
- Ghi nhớ từ chối trong file JSON riêng, không đụng Isar schema (mẫu
  `SslInstallDeclines`).
- Distro không nhận diện được thì chỉ hiện lệnh để chạy tay, không tự chạy.

## Cách làm (đã chọn: cách 1 — hỏi ngay lúc bấm Install)

- Hook vào `_install` trong
  `lib/features/apps/presentation/widgets/pyenv_manage_modal.dart`, trước khi gọi
  `installVersion`.
- Kiểm tra bằng file header trong `/usr/include` (và `which` cho gcc/make).
- Gói theo danh sách khuyến nghị của pyenv wiki, chỉ cài gói thiếu. Ví dụ
  Fedora 22+: `make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite
  sqlite-devel openssl-devel tk-devel libffi-devel xz-devel libuuid-devel
  gdbm-devel libnsl2-devel`; Ubuntu/Debian: `make build-essential libssl-dev
  zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev
  liblzma-dev`.
- Chạy refresh index rồi install (2 lệnh elevated, giống SSL).
- Cài xong kiểm tra lại header rồi mới build Python.
- Từ chối thì ghi lại theo đúng danh sách gói đang thiếu — lần sau thiếu đúng
  danh sách đó thì không hỏi nữa, thiếu khác đi thì hỏi lại — và vẫn cài Python
  như thường.
- Cài lib mà lỗi thì báo rõ lý do (mẫu `SslService.describeInstallFailure`) và
  dừng, không build mù.

## Các cách đã cân nhắc

- Cách 1 — hỏi ngay lúc bấm Install Python: đã chọn. Chỉ hỏi đúng lúc cần.
- Cách 2 — hỏi ngay lúc mở bảng pyenv: hỏi cả khi chỉ mở ra xem hoặc gỡ
  version, hơi phiền.
- Cách 3 — chỉ báo lệnh, không tự cài: vẫn làm tay như trước, không đúng ý
  "hỏi quyền để cài luôn".

## Để lại cho lúc làm (builder)

- Bảng map chi tiết distro → gói + cách kiểm tra từng gói (apt/dnf/zypper/
  pacman/apk).
- Tên file declines + key.
- Có tách helper dùng chung với `SslService`
  (packageRefreshArgs/packageInstallArgs/describeInstallFailure) hay viết riêng.
- Xử lý khi máy không có pkexec.
- Test những gì.
