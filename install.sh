#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Mo ta: Tu dong cai dat va patch O+ Connect (OPPO PC Connect) tren Linux
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$1"

echo "========================================================"
echo "    CAI DAT O+ CONNECT (OPPO/ONEPLUS PC CONNECT) LINUX  "
echo "========================================================"

# 1. Kiem tra file cai dat
if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    echo "[?] Khong co tham so duong dan installer. Dang tim file trong he thong..."
    POSSIBLE_FILES=(
        "$HOME/Downloads"/Oplus*.exe
        "$HOME/Tải về"/Oplus*.exe
        "$SCRIPT_DIR"/Oplus*.exe
        "$HOME"/Downloads/*Connect*.exe
    )
    for f in "${POSSIBLE_FILES[@]}"; do
        if [ -f "$f" ]; then
            INSTALLER="$f"
            break
        fi
    done
fi

if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    echo "[-] Loi: Khong tim thay file cai dat OplusConnectSetup*.exe!"
    echo "    Cach su dung: $0 /duong/dan/toi/OplusConnectSetup.exe"
    exit 1
fi

echo "[+] Tim thay installer: $INSTALLER"

# 2. Kiem tra cong cu
command -v 7z >/dev/null 2>&1 || {
    echo "[-] Loi: Chua cai dat 7z. Cai bang: sudo pacman -S p7zip (hoac sudo apt install p7zip-full)"
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo "[-] Loi: Chua cai dat python3."
    exit 1
}

# 3. Chon Wine / Proton
WINE_BIN=""
# Tim Proton-GE neu co
PROTON_CANDIDATES=$(find "$HOME/.local/share/Steam/compatibilitytools.d" "$HOME/.config/heroic/tools/proton" -type f -name "wine" 2>/dev/null | grep -E "GE-Proton" | sort -V | tail -n 1 || true)
if [ -n "$PROTON_CANDIDATES" ] && [ -x "$PROTON_CANDIDATES" ]; then
    WINE_BIN="$PROTON_CANDIDATES"
    echo "[+] Su dung Proton-GE: $WINE_BIN"
elif command -v wine >/dev/null 2>&1; then
    WINE_BIN="wine"
    echo "[+] Su dung Wine he thong: $(which wine)"
else
    echo "[-] Loi: Khong tim thay Wine hoac Proton. Hay cai dat wine-staging hoac Proton-GE."
    exit 1
fi

# 4. Thiet lap Prefix
PREFIX_DIR="${PREFIX_DIR:-$HOME/.local/share/wineprefixes/OplusConnect}"
APP_DIR="$PREFIX_DIR/drive_c/Program Files/Oplus/OplusConnect"

echo "[+] Prefix: $PREFIX_DIR"
echo "[+] Thu muc app: $APP_DIR"

mkdir -p "$PREFIX_DIR"
echo "[*] Khoi tao Wine Prefix 64-bit..."
WINEPREFIX="$PREFIX_DIR" WINEARCH=win64 "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true

# 5. Giai nen Installer
TMP_EXTRACT="/tmp/oplus_extract_$$"
mkdir -p "$TMP_EXTRACT"
echo "[*] Dang trich xuat tai nguyen tu installer..."
7z x "$INSTALLER" -o"$TMP_EXTRACT" -y >/dev/null 2>&1

PAYLOAD_103=$(find "$TMP_EXTRACT" -name "103" -type f | head -n 1)
if [ -z "$PAYLOAD_103" ]; then
    echo "[-] Loi: Khong tim thay payload 103 trong installer!"
    rm -rf "$TMP_EXTRACT"
    exit 1
fi

echo "[+] Tim thay payload: $PAYLOAD_103"
mkdir -p "$APP_DIR"
echo "[*] Dang bung payload vao thu muc ung dung..."
7z x "$PAYLOAD_103" -o"$APP_DIR" -y >/dev/null 2>&1
rm -rf "$TMP_EXTRACT"

# 6. Chay Python Patcher
echo "[*] Dang chay bo va loi nhị phan & ASAR..."
python3 "$SCRIPT_DIR/patch_oplus.py" "$APP_DIR"

# 7. Tao launch.sh
LAUNCH_SCRIPT="$PREFIX_DIR/launch.sh"
cat << EOF > "$LAUNCH_SCRIPT"
#!/usr/bin/env bash
export WINEPREFIX="$PREFIX_DIR"
export WINEDEBUG=-all
cd "$APP_DIR"
exec "$WINE_BIN" "O+Connect.exe" --force-device-scale-factor=2 --disable-gpu "\$@"
EOF
chmod +x "$LAUNCH_SCRIPT"
echo "[+] Da tao script khoi chay tai: $LAUNCH_SCRIPT"

# 8. Tao shortcut .desktop
DESKTOP_FILE="$HOME/.local/share/applications/oplus-connect.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=O+ Connect
Comment=Ket noi dien thoai OPPO voi may tinh Linux
Exec="$LAUNCH_SCRIPT"
Icon=phone
Terminal=false
Type=Application
Categories=Utility;Network;
EOF
chmod +x "$DESKTOP_FILE"
echo "[+] Da tao menu shortcut tai: $DESKTOP_FILE"

echo "========================================================"
echo "[V] HOAN TAT CAI DAT O+ CONNECT THANH CONG!"
echo "    Ban co the khoi dong ung dung bang lenh:"
echo "    $LAUNCH_SCRIPT"
echo "========================================================"
