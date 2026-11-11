# O+ Connect for Linux (OPPO & OnePlus PC Connect)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://kernel.org)
[![Compatibility: Wine / Proton](https://img.shields.io/badge/Compatibility-Wine%20%2F%20Proton-purple.svg)](https://www.winehq.org)
[![Target: OPPO / OnePlus](https://img.shields.io/badge/Devices-OPPO%20%7C%20OnePlus-green.svg)](https://www.oppo.com)

Dự án cài đặt và tương thích hóa ứng dụng **O+ Connect (OPPO / OnePlus PC Connect)** trên hệ điều hành **Linux** (thông qua Wine / Proton-GE), kèm bộ công cụ tự động vá các lỗi nhị phân (Reverse Engineering & Binary Patching).

Dự án mở ra nhằm kêu gọi cộng đồng **Fork, đóng góp và cùng nhau phát triển** một giải pháp kết nối điện thoại OPPO/OnePlus với máy tính Linux toàn diện và mượt mà nhất.

---

## 🌟 Tại sao dùng O+ Connect thay vì scrcpy?

| Tiêu chí | `scrcpy` | **O+ Connect (Dự án này)** |
| :--- | :--- | :--- |
| **Yêu cầu Developer Mode / USB Debugging** | ⚠️ **Bắt buộc** |  **KHÔNG CẦN** |
| **Khả năng dùng App Ngân hàng & VNeID** | ❌ Bị khóa/chặn do bật ADB |  **Hoạt động 100% bình thường** |
| **Chiếu màn hình (Screen Mirroring)** |  Có |  Có (Độ trễ thấp, mượt mà) |
| **Chia sẻ Clipboard 2 chiều** |  Có |  Có (Tự động đồng bộ thời gian thực) |
| **Kéo thả truyền file (File Transfer)** |  Có |  Có (Tích hợp trực tiếp) |
| **Ghép đôi không dây (Wireless Pairing)** | ⚠️ Cần cắm cáp pair trước |  Quét mã QR trực tiếp qua Wi-Fi |

---

## 📂 Cấu trúc Thư mục Dự Án

```text
oplus-connect-linux/
├── install.sh      # Script Bash cài đặt tự động 1-click
├── patch_oplus.py  # Script Python vá nhị phân PE & ASAR
├── GUIDE.md        # Cẩm nang kỹ thuật kiến trúc, Reverse Engineering & Hướng dẫn phát triển
└── README.md       # Tài liệu tổng quan dự án & Bắt đầu nhanh
```

- **[`install.sh`](install.sh)**: Tự động phát hiện bộ cài đặt Windows, tạo Wine Prefix 64-bit sạch, giải nén trực tiếp PE Resource `103` (bỏ qua bẫy kiểm tra .NET Framework 4), gọi bộ vá lỗi nhị phân và tạo launcher cùng biểu tượng Menu ứng dụng (`.desktop`).
- **[`patch_oplus.py`](patch_oplus.py)**: Thực hiện vá byte nhị phân chính xác trên file thực thi `pantaChannelService.exe`, chỉnh sửa bảng Import DLL và vá logic kiểm tra Wi-Fi trong `resources/app.asar`.
- **[`GUIDE.md`](GUIDE.md)**: **Tài liệu cốt lõi dành cho Contributor & AI Agent**: Phân tích kiến trúc toàn hệ thống (Multi-process, OAF, Shared Memory EventBus), giao thức mạng (Senseless SDP, TCP socket), từng byte nhị phân đã vá (offset PE, opcode `ret 0xc3`), quy trình debug chuyên sâu và lộ trình các bài toán mở để cộng đồng cùng Fork và phát triển.

---

## 🔬 Phân tích Kỹ thuật & Các Bản Vá (Reverse Engineering)

O+ Connect nguyên bản dành cho Windows 10/11 sử dụng nhiều API đặc thù của Microsoft (WinRT, C++/WinRT Coroutines, UniversalApiContract). Khi chạy trên Wine thuần, ứng dụng sẽ gặp phải 5 điểm nghẽn nghiêm trọng đã được dự án bẻ khóa và vá thành công:

### 1. Bỏ qua Bộ kiểm tra .NET Framework 4 (`0x80070490`)
- **Vấn đề:** File `OplusConnectSetup.exe` là wrapper kiểm tra registry .NET Framework 4 của Windows; trên Wine nó sẽ báo lỗi và dừng cài đặt.
- **Giải pháp:** Sử dụng `7z` trích xuất trực tiếp tài nguyên PE Resource `103` (`.rsrc/2052/RCDATA/103`). Đây là file nén chứa toàn bộ ứng dụng sạch mà không cần chạy file cài đặt gốc.

### 2. Vô hiệu hóa `toastNotification.dll`
- **Vấn đề:** DLL này cố gắng gọi các contract notification của WinRT qua Mono, gây assertion crash ngay khi vừa khởi chạy.
- **Giải pháp:** Tự động đổi tên sang `toastNotification.dll.bak`. Ứng dụng sẽ bỏ qua notification hệ thống mà không ảnh hưởng luồng chính.

### 3. Khắc phục Vòng lặp Crash `pantaChannelService.exe` & Ô Mã QR Trắng
- **Vấn đề:** `pantaChannelService.exe` (Open Accessory Framework daemon) gọi `Windows.Devices.Radios.Radio::GetRadiosAsync` thông qua coroutine C++/WinRT. Wine chưa hỗ trợ class này (`REGDB_E_CLASSNOTREG`), ném ngoại lệ C++ chưa bắt khiến tiến trình crash với mã thoát `-4`. Tiến trình `devicespace.exe` liên tục restart daemon, giữ cờ `OAF_INIT_FLAG = false`, dẫn đến API trả về HTTP 500 và **ô mã QR bị trắng trơn**.
- **Giải pháp trong [`patch_oplus.py`](patch_oplus.py):**
  - Vá bảng import DLL từ `api-ms-win-core-debug-minidump-l1-1-0.dll` sang `dbghelp.dll`.
  - Ghi đè mã máy `0xc3` (`ret`) ngay tại entry point của `RadioManager::enumerateRadios` (offset `0x88010`) và `WindowsWiFiDirect::closeCoroutine` (offset `0x26ece0`).
  - *Kết quả:* Vô hiệu hóa hoàn toàn lệnh thăm dò phần cứng vô nghĩa trên Wine, giữ cho daemon sống vĩnh viễn, UDP EventBus trên cổng 46915 khởi tạo trơn tru và mã QR hiển thị tức thì.

### 4. Vá Kiểm tra Mạng Ngoại Tuyến trong `resources/app.asar`
- **Vấn đề:** Trên Wine, thư viện `systeminformation` (`s.wifiConnections()`) trả về danh sách rỗng, khiến code JS truy cập `n[0].ssid` bị lỗi `TypeError`, đẩy giao diện vào chế độ Offline.
- **Giải pháp:** Vá chuỗi nhị phân trong file ASAR, bổ sung fallback SSID mặc định (`"WLAN"`) với độ dài chuỗi (byte padding) được giữ nguyên tuyệt đối để không làm hỏng ASAR archive header.

### 5. Khắc phục Đơ Giao Diện trên Wayland & Màn Hình HiDPI
- Tự động thêm cờ `--disable-gpu` để Electron GUI không bị xung đột bộ đệm OpenGL/Vulkan với XWayland.
- Thêm `--force-device-scale-factor=2` (hoặc tùy biến) giúp giao diện hiển thị sắc nét trên màn hình 2K/4K.

---

## 🚀 Hướng Dẫn Cài Đặt Nhanh

### 1. Cài đặt các công cụ phụ trợ (Prerequisites)

- **Arch Linux / Manjaro:**
  ```bash
  sudo pacman -S --needed p7zip python3 wine-staging
  # Hoặc tốt nhất là Proton-GE (thông qua Steam hoặc Heroic Games Launcher)
  ```
- **Ubuntu / Debian:**
  ```bash
  sudo apt update && sudo apt install -y p7zip-full python3 wine
  ```
- **Fedora:**
  ```bash
  sudo dnf install -y p7zip p7zip-plugins python3 wine
  ```

### 2. Tải bộ cài O+ Connect Windows
Tải file cài đặt chính thức từ trang chủ OPPO hoặc nguồn tin cậy:
- File mẫu: `OplusConnectSetup_17.100.10_export_261031185834_1b49387.exe`

### 3. Chạy kịch bản cài đặt tự động
Clone repository và thực thi script:

```bash
git clone https://github.com/nguyenthangtran2003-cmyk/oplus-connect-linux.git
cd oplus-connect-linux

chmod +x install.sh
./install.sh /duong/dan/toi/OplusConnectSetup.exe
```

*(Nếu bạn đặt file `OplusConnectSetup*.exe` trong thư mục `Downloads` hoặc ngay cạnh `install.sh`, chỉ cần chạy `./install.sh` mà không cần truyền tham số).*

Sau khi hoàn tất, bạn có thể mở **O+ Connect** từ Menu ứng dụng (Application Launcher) của hệ thống hoặc chạy:
```bash
~/.local/share/wineprefixes/OplusConnect/launch.sh
```

---

## 📡 Lưu Ý Vận Hành Mạng: Wi-Fi Thường vs Điểm Phát Sóng (Hotspot)

> [!IMPORTANT]
> **Quy tắc vàng khi Ghép đôi lần đầu (First-time Pairing):**
> Hãy đảm bảo máy tính và điện thoại cùng kết nối vào **một mạng Wi-Fi thông thường** (router gia đình, văn phòng).

- **Tại sao?** Khi ghép đôi lần đầu, ứng dụng sử dụng giao thức **Senseless SDP** phát gói tin UDP Multicast (`239.255.255.250:29915`). Kernel của Android khi bật Hotspot (SoftAP) sẽ chủ động chặn (drop) các gói tin multicast này giữa client và host để tiết kiệm năng lượng.
- **Sau khi đã ghép đôi thành công 1 lần:** Khóa mật mã trao đổi AES và định danh thiết bị đã được lưu vĩnh viễn vào cơ sở dữ liệu `ptc.db`. Lúc này, bạn có thể **bật 4G Hotspot trên điện thoại cho máy tính kết nối**; ứng dụng sẽ thiết lập kết nối Unicast TCP trực tiếp tới IP Gateway (`10152`/`10153`) và hoạt động trơn tru.

---

## 🛠 Định Hướng Phát Triển & Kêu Gọi Đóng Góp (Call for Contributions)

Dự án này là bước khởi đầu chứng minh **OPPO PC Connect hoàn toàn có thể chạy mượt mà trên Linux**. Chúng tôi rất mong cộng đồng mã nguồn mở cùng **Fork** và tham gia phát triển:

- [ ] **Đóng gói phân phối:**
  - Viết `PKGBUILD` đưa lên **AUR** cho người dùng Arch Linux / Manjaro.
  - Xây dựng gói **Flatpak** hoặc **AppImage** độc lập không phụ thuộc prefix bên ngoài.
- [ ] **Hotspot Auto-Fix (Cải tiến ASAR UI):**
  - Can thiệp vào file Vue.js renderer trong `app.asar` để khi kết nối mạng Hotspot, app tự lấy địa chỉ Default Gateway thay vì sử dụng IP cũ bị lưu trong cache danh sách thiết bị.
- [ ] **Linux System Tray & Khởi động cùng hệ thống:**
  - Viết một daemon nhỏ bằng Python/Qt để hiển thị System Tray icon trên GNOME/KDE, tự động thu nhỏ app xuống khay hệ thống.
- [ ] **Giao thức kết nối qua USB (AOA / RNDIS):**
  - Nghiên cứu khả năng bắt tay trực tiếp qua giao thức Android Open Accessory (AOA) qua cổng USB mà không cần mở USB Debugging.

### Cách đóng góp:
1. **Fork** repository này về tài khoản GitHub của bạn.
2. Tạo nhánh tính năng (`git checkout -b feature/tinh-nang-moi`).
3. Commit các thay đổi (`git commit -m 'Them tinh nang...'`).
4. Push lên nhánh của bạn (`git push origin feature/tinh-nang-moi`).
5. Tạo một **Pull Request** để cùng thảo luận và hợp nhất mã nguồn!

---

## 📄 Bản quyền & Tuyên bố Miễn trừ Trách nhiệm (Disclaimer)

- Dự án này không liên kết chính thức với tập đoàn OPPO hay OnePlus.
- Mọi thương hiệu và bản quyền nhị phân gốc thuộc về OPPO / OnePlus Electronics Corp.
- Bộ mã kịch bản trong kho lưu trữ này được phân phối dưới giấy phép **MIT License** nhằm mục đích nghiên cứu, tương thích hóa và cải thiện trải nghiệm người dùng Linux.
