# Bộ Cài Đặt Tự Động O+ Connect (OPPO PC Connect) Cho Linux

Dành cho Antigravity AI Agent hoặc người dùng muốn cài đặt O+ Connect trên máy Linux mới.

## Cấu trúc thư mục

- `install.sh`: Script bash thực thi toàn bộ quy trình: kiểm tra dependencies, tạo Prefix, giải nén không cần qua .NET wrapper, vá nhị phân và tạo launcher.
- `patch_oplus.py`: Script Python thực hiện vá byte nhị phân PE (`pantaChannelService.exe`), sửa thư viện liên kết và vá SSID check trong `app.asar`.

## Hướng dẫn sử dụng nhanh

Chỉ cần chạy lệnh:

```bash
chmod +x install.sh
./install.sh /duong/dan/toi/OplusConnectSetup.exe
```

*(Nếu không truyền đường dẫn, script sẽ tự động tìm kiếm file trong thư mục Downloads)*

Sau khi cài đặt xong, ứng dụng có thể được mở từ Menu ứng dụng hệ thống hoặc chạy trực tiếp bằng:
```bash
~/.local/share/wineprefixes/OplusConnect/launch.sh
```
