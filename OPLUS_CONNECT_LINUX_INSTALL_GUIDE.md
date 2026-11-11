# Hướng Dẫn Tự Động Hóa Cài Đặt O+ Connect (OPPO PC Connect) Trên Linux

> **Dành cho:** Antigravity AI Agent hoặc bất kỳ Coding Agent nào thực hiện cài đặt O+ Connect trên môi trường Linux mới (Arch, Manjaro, Ubuntu, Fedora...).
> **Mục tiêu:** Cài đặt O+ Connect (OPPO/OnePlus PC Connect) vào Proton/Wine Prefix, tự động vá các điểm nghẽn nhị phân (WinRT crash, .NET runtime check, Toast crash, Wayland GPU freeze, offline Wi-Fi detection) để app nhận diện và kết nối điện thoại OPPO mượt mà.

---

## 1. Yêu cầu Tiền đề (Prerequisites)

Agent cần kiểm tra và cài đặt các công cụ sau trên máy mục tiêu:

### Trên Arch / Manjaro:
```bash
sudo pacman -S --needed p7zip python3
# Khuyến nghị sử dụng Proton-GE (thông qua Steam hoặc Heroic Games Launcher) hoặc wine-staging
```

### Trên Ubuntu / Debian:
```bash
sudo apt update && sudo apt install -y p7zip-full python3
```

### File Cài đặt Gốc:
- File cài đặt Windows từ OPPO: ví dụ `OplusConnectSetup_17.100.10_export_261031185834_1b49387.exe` (hoặc phiên bản tương đương).

---

## 2. Các Biến Môi Trường Chuẩn Bị

Agent hãy thiết lập các biến đường dẫn:

```bash
# 1. Đường dẫn file installer
INSTALLER_EXE="/path/to/OplusConnectSetup_17.100.10.exe"

# 2. Thư mục Prefix Wine/Proton độc lập
PREFIX_DIR="$HOME/.local/share/wineprefixes/OplusConnect"

# 3. Trình chạy Wine (Ưu tiên Proton-GE nếu có Steam/Heroic, hoặc dùng wine hệ thống)
# Ví dụ với GE-Proton:
WINE_BIN="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton11-7-x86_64/files/bin/wine"
# Nếu không có Steam Proton, fallback sang wine hệ thống:
which "$WINE_BIN" 2>/dev/null || WINE_BIN="wine"

# 4. Thư mục cài đặt ứng dụng bên trong Prefix
APP_DIR="$PREFIX_DIR/drive_c/Program Files/Oplus/OplusConnect"
```

---

## 3. Quy trình Cài đặt & Vá Lỗi (Step-by-Step)

### Bước 1: Khởi tạo Wine Prefix 64-bit
Không chạy trực tiếp file `.exe` cài đặt vì wrapper kiểm tra .NET Framework 4 sẽ báo lỗi `0x80070490`. Hãy khởi tạo prefix sạch:

```bash
mkdir -p "$PREFIX_DIR"
WINEPREFIX="$PREFIX_DIR" WINEARCH=win64 wineboot -u
```

---

### Bước 2: Giải nén Payload từ Installer
Bỏ qua bộ cài .NET bằng cách trích xuất trực tiếp tài nguyên nén PE Resource `103` (chứa toàn bộ ứng dụng):

```bash
mkdir -p /tmp/oplus_extract
7z x "$INSTALLER_EXE" -o/tmp/oplus_extract -y

# Tìm file resource 103 (thường nằm ở .rsrc/2052/RCDATA/103 hoặc .rsrc/1033/RCDATA/103)
PAYLOAD_103=$(find /tmp/oplus_extract -name "103" -type f | head -n 1)

mkdir -p "$APP_DIR"
7z x "$PAYLOAD_103" -o"$APP_DIR" -y

# Dọn dẹp file tạm
rm -rf /tmp/oplus_extract
```

---

### Bước 3: Chạy Script Python Tự Động Vá Nhị Phân (Universal Patcher)

Tạo và chạy script `patch_oplus.py` bên dưới. Script này sẽ tự động giải quyết 3 lỗi nghiêm trọng:

1. **Vô hiệu hóa `toastNotification.dll`**: Tránh lỗi Mono/WinRT `UniversalApiContract` crash app khi khởi động.
2. **Vá nhị phân `pantaChannelService.exe`**:
   - Thay đổi thư viện import từ `api-ms-win-core-debug-minidump-l1-1-0.dll` sang `dbghelp.dll` (sửa lỗi thiếu DLL `0xC0000135`).
   - Patch `ret` (`0xc3`) vào hàm `RadioManager::enumerateRadios` và coroutine `WindowsWiFiDirect::closeCoroutine` (bỏ qua lệnh gọi WinRT `Windows.Devices.Radios.Radio` vốn không tồn tại trên Wine, loại bỏ triệt để vòng lặp crash & restart khiến ô QR bị trắng).
3. **Vá `resources/app.asar`**:
   - Bổ sung fallback SSID cho hàm `getWifiSSID()` khi `wifiConnections()` trả về rỗng trong Wine (tránh lỗi `Cannot read properties of undefined (reading 'ssid')` làm app chuyển sang chế độ ngoại tuyến/offline).

```python
cat << 'EOF' > /tmp/patch_oplus.py
import os
import sys

def patch_app(app_dir):
    print(f"[*] Bat dau va ung dung tai: {app_dir}")
    
    # --- 1. Xu ly toastNotification.dll ---
    toast_dll = os.path.join(app_dir, "toastNotification.dll")
    if os.path.exists(toast_dll):
        os.rename(toast_dll, toast_dll + ".bak")
        print("[+] Da doi ten toastNotification.dll -> .bak (Tranh crash WinRT toast)")
        
    # --- 2. Va pantaChannelService.exe ---
    panta_exe = os.path.join(app_dir, "daemon", "pantaChannelService.exe")
    if os.path.exists(panta_exe):
        with open(panta_exe, "rb") as f:
            data = bytearray(f.read())
            
        # 2.1 Patch Minidump DLL
        target_dll = b"api-ms-win-core-debug-minidump-l1-1-0.dll"
        repl_dll = b"dbghelp.dll\x00" + b"\x00" * (len(target_dll) - len(b"dbghelp.dll\x00"))
        if target_dll in data:
            data = data.replace(target_dll, repl_dll)
            print("[+] Da patch minidump DLL import sang dbghelp.dll")
            
        # 2.2 Patch RadioManager::enumerateRadios (Pattern: 48 89 5c 24 08 55 56 57 41 54 41 55 41 56 41 57 48 8d 6c 24 d9 48 81 ec a0 00 00 00)
        pat1 = bytes.fromhex("48 89 5c 24 08 55 56 57 41 54 41 55 41 56 41 57 48 8d 6c 24 d9 48 81 ec a0 00 00 00")
        pos1 = data.find(pat1)
        if pos1 != -1:
            data[pos1] = 0xc3 # ret
            print(f"[+] Da patch RadioManager tai offset 0x{pos1:x} -> ret (0xc3)")
        else:
            print("[!] Canh bao: Khong tim thay pattern RadioManager")
            
        # 2.3 Patch WindowsWiFiDirect::closeCoroutine (Pattern: 48 89 54 24 10 48 83 ec 38 41 ba 58 00 00 00 4e 89 4c 12 01)
        pat2 = bytes.fromhex("48 89 54 24 10 48 83 ec 38 41 ba 58 00 00 00 4e 89 4c 12 01")
        pos2 = data.find(pat2)
        if pos2 != -1:
            data[pos2] = 0xc3 # ret
            print(f"[+] Da patch closeCoroutine tai offset 0x{pos2:x} -> ret (0xc3)")
        else:
            print("[!] Canh bao: Khong tim thay pattern closeCoroutine")
            
        with open(panta_exe, "wb") as f:
            f.write(data)
        print("[+] Da luu ban va pantaChannelService.exe")

    # --- 3. Va resources/app.asar (SSID check) ---
    asar_file = os.path.join(app_dir, "resources", "app.asar")
    if os.path.exists(asar_file):
        with open(asar_file, "rb") as f:
            asar_data = f.read()
            
        # Tìm đoạn code lấy SSID gây lỗi khi không có Wi-Fi card (trên Wine):
        target_chunk = b'try{T();let t=(await s.wifiConnections())[0].ssid;0===t.trim().length&&(l.info(E,"ssid get fail, use cmd!"),t=await this.getCurrentWiFiSSID(),console.error("ssid===1: "+t),l.info(E,"ssid is: "+t)),e(t)}catch(e){t(e)}}'
        repl_base    = b'try{let n=await s.wifiConnections();let a=(n&&n[0]&&n[0].ssid)?n[0].ssid:"WLAN";e(a)}catch(n){e("WLAN")}'
        
        # Cân bằng chiều dài bằng comment JS để giữ nguyên 100% header và offset của ASAR archive
        pad_len = len(target_chunk) - len(repl_base) - 4
        repl_chunk = repl_base + b"/*" + b"A" * pad_len + b"*/"
        
        if target_chunk in asar_data:
            asar_data = asar_data.replace(target_chunk, repl_chunk)
            with open(asar_file, "wb") as f:
                f.write(asar_data)
            print("[+] Da patch getWifiSSID trong app.asar thanh cong (Giu nguyen do dai file)")
        else:
            print("[!] Canh bao: Khong tim thay target_chunk trong app.asar (co the file da duoc patch)")
    
    print("[*] Hoan tat toan bo cac buoc va loi!")

if __name__ == "__main__":
    app_dir = sys.argv[1] if len(sys.argv) > 1 else "/home/thang/Games/Heroic/Prefixes/OplusConnect/pfx/drive_c/Program Files/Oplus/OplusConnect"
    patch_app(app_dir)
EOF

python3 /tmp/patch_oplus.py "$APP_DIR"
rm /tmp/patch_oplus.py
```

---

### Bước 4: Tạo Script Khởi Động Chuẩn (`launch.sh`)

Tạo script thực thi có gắn cờ scale HiDPI x2 và cờ vô hiệu hóa phần cứng GPU (tránh hiện tượng đóng băng cửa sổ Wayland trên Electron):

```bash
cat << EOF > "$PREFIX_DIR/launch.sh"
#!/bin/bash
set -e

PREFIX_DIR="$PREFIX_DIR"
WINE_BIN="$WINE_BIN"
APP_DIR="$APP_DIR"

export WINEPREFIX="\$PREFIX_DIR"
export WINEDEBUG="-all"

cd "\$APP_DIR"
exec "\$WINE_BIN" "O+Connect.exe" --force-device-scale-factor=2 --disable-gpu "\$@"
EOF

chmod +x "$PREFIX_DIR/launch.sh"
```

---

### Bước 5: Tạo Shortcut Ứng Dụng (`.desktop`)

Tạo entry trên menu ứng dụng máy tính:

```bash
mkdir -p "$HOME/.local/share/applications"
cat << EOF > "$HOME/.local/share/applications/oplus-connect.desktop"
[Desktop Entry]
Name=O+ Connect
Comment=Ket noi dien thoai OPPO voi may tinh Linux
Exec="$PREFIX_DIR/launch.sh"
Icon=phone
Terminal=false
Type=Application
Categories=Utility;Network;
EOF

chmod +x "$HOME/.local/share/applications/oplus-connect.desktop"
```

---

## 4. Kiểm Thử & Chạy Ứng Dụng

Agent chạy lệnh sau để kiểm tra trạng thái khởi động:

```bash
"$PREFIX_DIR/launch.sh" &
sleep 5
ps aux | grep -iE "oplus|devicespace|panta" | grep -v grep
```

**Kỳ vọng khi thành công:**
- Xuất hiện đồng thời 4 tiến trình Windows:
  1. `O+Connect.exe` (Giao diện Electron)
  2. `devicespace.exe` (Backend Core daemon quản lý mạng/kết nối)
  3. `pantaChannelService.exe` (Dịch vụ OAF/Bluetooth/WiFi Direct đã vá)
  4. `oplus_remote_service.exe` / `SLDesktopAgent.exe`
- Trên cửa sổ **O+ Connect**, mã QR xuất hiện đầy đủ, không bị ô màu trắng rỗng.

---

## 5. Lưu Ý Vận Hành Thực Tế (Quan Trọng)

1. **Lần ghép đôi (Match) đầu tiên:**
   - **Bắt buộc** để máy tính và điện thoại OPPO kết nối vào **cùng một mạng Wi-Fi thông thường** (router nhà, công ty).
   - *Lý do:* Android Hotspot có cơ chế drop Multicast UDP khiến giao thức khám phá thiết bị (Senseless SDP) bị chặn ở lần đầu.
2. **Sau khi đã ghép đôi thành công:**
   - Khóa mật mã đã lưu vào `ptc.db`.
   - Lúc này bạn có thể bật **4G/Hotspot trên điện thoại** cho máy tính kết nối và sử dụng tính năng truyền file, chiếu màn hình hoàn toàn bình thường thông qua kết nối TCP trực tiếp tới Gateway.
3. **Bảo mật Ngân hàng & VNeID:**
   - Giải pháp này **không yêu cầu Developer Mode**, **không yêu cầu USB Debugging**, và **không cần Accessibility Service**, do đó an toàn 100% với VNeID và tất cả app ngân hàng.
