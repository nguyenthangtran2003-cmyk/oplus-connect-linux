#!/usr/bin/env python3
"""
patch_oplus.py - Universal Binary & ASAR Patcher for O+ Connect on Linux/Wine
Author: Google Deepmind Antigravity Pair Programmer
"""

import os
import sys

def patch_app(app_dir):
    print(f"[*] Bat dau qua trinh va O+ Connect tai: {app_dir}")
    if not os.path.isdir(app_dir):
        print(f"[-] Loi: Thu muc khong ton tai: {app_dir}")
        sys.exit(1)

    # --- 1. Xu ly toastNotification.dll ---
    toast_dll = os.path.join(app_dir, "toastNotification.dll")
    if os.path.exists(toast_dll):
        bak_file = toast_dll + ".bak"
        if os.path.exists(bak_file):
            os.remove(bak_file)
        os.rename(toast_dll, bak_file)
        print("[+] Da doi ten toastNotification.dll -> .bak (Tranh crash WinRT toast)")
    else:
        print("[i] toastNotification.dll da duoc xu ly hoac khong ton tai")

    # --- 2. Va pantaChannelService.exe ---
    panta_exe = os.path.join(app_dir, "daemon", "pantaChannelService.exe")
    if os.path.exists(panta_exe):
        with open(panta_exe, "rb") as f:
            data = bytearray(f.read())

        # 2.1 Patch Minidump DLL import
        target_dll = b"api-ms-win-core-debug-minidump-l1-1-0.dll"
        repl_dll = b"dbghelp.dll\x00" + b"\x00" * (len(target_dll) - len(b"dbghelp.dll\x00"))
        if target_dll in data:
            data = data.replace(target_dll, repl_dll)
            print("[+] Da patch minidump DLL import sang dbghelp.dll")

        # 2.2 Patch RadioManager::enumerateRadios (Pattern: 48 89 5c 24 08 55 56 57 41 54 41 55 41 56 41 57 48 8d 6c 24 d9 48 81 ec a0 00 00 00)
        pat1 = bytes.fromhex("48 89 5c 24 08 55 56 57 41 54 41 55 41 56 41 57 48 8d 6c 24 d9 48 81 ec a0 00 00 00")
        pos1 = data.find(pat1)
        if pos1 != -1:
            data[pos1] = 0xc3  # ret
            print(f"[+] Da patch RadioManager tai offset 0x{pos1:x} -> ret (0xc3)")
        else:
            print("[i] Khong tim thay pattern RadioManager (co the da duoc patch)")

        # 2.3 Patch WindowsWiFiDirect::closeCoroutine (Pattern: 48 89 54 24 10 48 83 ec 38 41 ba 58 00 00 00 4e 89 4c 12 01)
        pat2 = bytes.fromhex("48 89 54 24 10 48 83 ec 38 41 ba 58 00 00 00 4e 89 4c 12 01")
        pos2 = data.find(pat2)
        if pos2 != -1:
            data[pos2] = 0xc3  # ret
            print(f"[+] Da patch closeCoroutine tai offset 0x{pos2:x} -> ret (0xc3)")
        else:
            print("[i] Khong tim thay pattern closeCoroutine (co the da duoc patch)")

        with open(panta_exe, "wb") as f:
            f.write(data)
        print("[+] Da luu ban va daemon/pantaChannelService.exe thanh cong")

    # --- 3. Va resources/app.asar (SSID check) ---
    asar_file = os.path.join(app_dir, "resources", "app.asar")
    if os.path.exists(asar_file):
        with open(asar_file, "rb") as f:
            asar_data = f.read()

        target_chunk = b'try{T();let t=(await s.wifiConnections())[0].ssid;0===t.trim().length&&(l.info(E,"ssid get fail, use cmd!"),t=await this.getCurrentWiFiSSID(),console.error("ssid===1: "+t),l.info(E,"ssid is: "+t)),e(t)}catch(e){t(e)}}'
        repl_base    = b'try{let n=await s.wifiConnections();let a=(n&&n[0]&&n[0].ssid)?n[0].ssid:"WLAN";e(a)}catch(n){e("WLAN")}'

        pad_len = len(target_chunk) - len(repl_base) - 4
        repl_chunk = repl_base + b"/*" + b"A" * pad_len + b"*/"

        if target_chunk in asar_data:
            asar_data = asar_data.replace(target_chunk, repl_chunk)
            with open(asar_file, "wb") as f:
                f.write(asar_data)
            print("[+] Da patch getWifiSSID trong resources/app.asar thanh cong (Giu nguyen do dai file)")
        else:
            print("[i] Target getWifiSSID khong tim thay trong app.asar (co the da duoc patch)")

    print("[*] Hoan tat toan bo cac buoc va loi cho O+ Connect!")

if __name__ == "__main__":
    app_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    patch_app(app_dir)
