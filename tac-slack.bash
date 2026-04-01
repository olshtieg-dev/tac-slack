#!/bin/bash
# Tac-Slack: The Universal Package Ninja Dispatcher

# --- Help / Usage ---
usage() {
    echo "Usage: tac-slack [package-file]"
    echo "Supported: .tar.gz (SBo/Source), .rpm, .deb, .pkg.tar.zst (Arch)"
    exit 1
}

if [ -z "$1" ] || [ ! -f "$1" ]; then usage; fi

FILE="$1"
FILENAME=$(basename "$FILE")
TMP_BASE="/tmp/tac-forge-$(date +%s)"

# --- Dependency Check ---
check_tool() {
    command -v "$1" >/dev/null 2>&1 || { echo "Error: $1 is not installed. Run setup.bash first."; exit 1; }
}

# --- The Installation Prompt ---
prompt_install() {
    local pkg_path="$1"
    if [ -z "$pkg_path" ] || [ ! -f "$pkg_path" ]; then
        echo "Error: Forge failed to produce a package."
        return 1
    fi
    
    dialog --title "Forge Complete" --yesno "Successfully forged: $(basename "$pkg_path")\n\nWould you like to install it now?" 8 60
    if [ $? -eq 0 ]; then
        clear
        installpkg "$pkg_path"
    else
        echo "Package saved to: $pkg_path"
    fi
}

# --- Main Dispatcher ---
clear
echo "[*] Tac-Slack: Identifying $FILENAME..."

case "$FILE" in
    *.tar.gz|*.tgz|*.tar.xz|*.tar.bz2)
        echo "[*] Detected: Tarball (Source or SlackBuild)"
        mkdir -p "$TMP_BASE"
        tar -xf "$FILE" -C "$TMP_BASE"
        
        DIR_NAME=$(ls "$TMP_BASE" | head -n 1)
        BUILD_SCRIPT=$(ls "$TMP_BASE/$DIR_NAME"/*.SlackBuild 2>/dev/null)

        if [ -n "$BUILD_SCRIPT" ]; then
            echo "[*] Found a SlackBuild. Executing..."
            pushd "$TMP_BASE/$DIR_NAME" > /dev/null
            chmod +x "$(basename "$BUILD_SCRIPT")"
            ./"$(basename "$BUILD_SCRIPT")"
            # Packages created by SBo usually land in /tmp
            NEW_PKG=$(ls -t /tmp/${DIR_NAME}*.t?z 2>/dev/null | head -n 1)
            popd > /dev/null
        else
            echo "[*] No SlackBuild. Calling src2pkg (The Heavy Hitter)..."
            check_tool src2pkg
            src2pkg -N "$FILE" # -N is non-interactive
            NEW_PKG=$(ls -t /tmp/*.t?z | head -n 1)
        fi
        prompt_install "$NEW_PKG"
        ;;

    *.deb)
        echo "[*] Detected: Debian Package"
        check_tool deb2tgz
        deb2tgz "$FILE"
        # deb2tgz creates a .tgz in the current directory
        prompt_install "${FILE%.deb}.tgz"
        ;;

    *.pkg.tar.zst|*.pkg.tar.xz)
        echo "[*] Detected: Arch Linux Package"
        check_tool arch2pkg
        arch2pkg "$FILE"
        # Find the most recent t?z in current directory
        NEW_PKG=$(ls -t *.t?z | head -n 1)
        prompt_install "$NEW_PKG"
        ;;

    *.rpm)
        echo "[*] Detected: Red Hat Package"
        check_tool rpm2txz
        rpm2txz -p "$FILE"
        prompt_install "${FILE%.rpm}.txz"
        ;;

    *)
        echo "Error: Unsupported file format."
        usage
        ;;
esac

# Cleanup
rm -rf "$TMP_BASE"