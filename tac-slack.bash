#!/bin/bash
# Tac-Slack: The Universal Package Ninja Dispatcher

# upgradepkg --install-new ## do this later!!

# --- Functions ---

usage() {
    echo "Usage: tac-slack [package-file]"
    echo "Supported: .tar.gz (SBo/Source), .rpm, .deb, .pkg.tar.zst (Arch)"
    exit 1
}

check_tool() {
    command -v "$1" >/dev/null 2>&1 || { echo "Error: $1 is missing. Run setup.bash."; exit 1; }
}

scan_dependencies() {
    local pkg_path="$1"
    local scan_dir="/tmp/tac-scan-$(date +%s)"
    mkdir -p "$scan_dir"
    explodepkg "$pkg_path" "$scan_dir" > /dev/null
    MISSING=$(find "$scan_dir" -type f \( -perm -111 -o -name "*.so*" \) -exec ldd {} + 2>/dev/null | grep "not found" | sort -u)
    rm -rf "$scan_dir"
    [ -z "$MISSING" ] && echo "[*] Scan: Clear." || echo -e "[!] MISSING:\n$MISSING"
}

prompt_final_action() {
    local pkg_path="$1"
    [ ! -f "$pkg_path" ] && { echo "Error: Forge failed."; return 1; }

    # Show the user the goods
    clear
    echo "--- Forge Report: $(basename "$pkg_path") ---"
    scan_dependencies "$pkg_path"
    echo "------------------------------------------------"

    # Step 1: Install?
    dialog --title "Install?" --yesno "Forge successful. Do you want to install this package now?" 7 60
    if [ $? -eq 0 ]; then
        clear
        installpkg "$pkg_path"
        # After install, do we keep the file?
        dialog --title "Keep Package?" --yesno "Installation complete. Keep the .txz in your current directory?" 7 60
        [ $? -eq 0 ] && mv "$pkg_path" . || rm "$pkg_path"
    else
        # Step 2: Hold?
        dialog --title "Hold?" --yesno "Installation skipped. Would you like to 'Hold' (keep) the package in your current directory?" 7 60
        if [ $? -eq 0 ]; then
            mv "$pkg_path" .
            echo "[*] Package saved to $(pwd)/$(basename "$pkg_path")"
        else
            rm "$pkg_path"
            echo "[*] Workspace cleared. No files kept."
        fi
    fi
}

# --- Main Dispatcher ---

if [ -z "$1" ] || [ ! -f "$1" ]; then usage; fi
FILE="$1"
FILENAME=$(basename "$FILE")
TMP_BASE="/tmp/tac-forge-$(date +%s)"

clear
echo "[*] Tac-Slack: Processing $FILENAME..."

case "$FILE" in
    *.tar.gz|*.tgz|*.tar.xz|*.tar.bz2)
        mkdir -p "$TMP_BASE"
        tar -xf "$FILE" -C "$TMP_BASE"
        DIR_NAME=$(ls "$TMP_BASE" | head -n 1)
        BUILD_SCRIPT=$(ls "$TMP_BASE/$DIR_NAME"/*.SlackBuild 2>/dev/null)

        if [ -n "$BUILD_SCRIPT" ]; then
            pushd "$TMP_BASE/$DIR_NAME" > /dev/null
            chmod +x "$(basename "$BUILD_SCRIPT")"
            ./$(basename "$BUILD_SCRIPT")
            NEW_PKG=$(ls -t /tmp/${DIR_NAME}*.t?z 2>/dev/null | head -n 1)
            popd > /dev/null
        else
            check_tool src2pkg
            src2pkg -N "$FILE"
            NEW_PKG=$(ls -t /tmp/*.t?z | head -n 1)
        fi
        prompt_final_action "$NEW_PKG"
        ;;

    *.deb)
        check_tool deb2tgz
        deb2tgz "$FILE"
        prompt_final_action "${FILE%.deb}.tgz"
        ;;

    *.pkg.tar.zst|*.pkg.tar.xz)
        check_tool arch2pkg
        arch2pkg "$FILE"
        NEW_PKG=$(ls -t *.t?z | head -n 1)
        prompt_final_action "$NEW_PKG"
        ;;

    *.rpm)
        check_tool rpm2txz
        rpm2txz -p "$FILE"
        prompt_final_action "${FILE%.rpm}.txz"
        ;;

    *) echo "Error: Unsupported format."; usage ;;
esac

rm -rf "$TMP_BASE"