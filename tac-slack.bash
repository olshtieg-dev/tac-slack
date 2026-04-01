#!/bin/bash
# Tac-Slack: The Universal Package Ninja Dispatcher

## place this in /usr/local/bin/ and make it executable with chmod +x or chmod 755


# --- Help / Usage ---
usage() {
    echo "Usage: tac-slack [package-file]"
    echo "Supported formats: .tar.gz (SBo), .rpm, .deb, .pkg.tar.zst (Arch)"
    exit 1
}

if [ -z "$1" ] || [ ! -f "$1" ]; then usage; fi

FILE="$1"
EXT="${FILE##*.}"
FILENAME=$(basename "$FILE")
TMP_BASE="/tmp/tac-forge-$(date +%s)"

# --- Dependency Check ---
check_tool() {
    command -v "$1" >/dev/null 2>&1 || { echo "Error: $1 is not installed."; exit 1; }
}

# --- The Installation Prompt ---
prompt_install() {
    local pkg_path="$1"
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
    *.tar.gz|*.tgz)
        echo "[*] Detected: SlackBuild / Source Tarball"
        # Logic: Extract, find .SlackBuild, run it
        mkdir -p "$TMP_BASE"
        tar -xf "$FILE" -C "$TMP_BASE"
        DIR_NAME=$(ls "$TMP_BASE")
        pushd "$TMP_BASE/$DIR_NAME" > /dev/null
        BUILD_SCRIPT=$(ls *.SlackBuild 2>/dev/null)
        if [ -z "$BUILD_SCRIPT" ]; then
            echo "Error: No .SlackBuild found in archive."; exit 1
        fi
        chmod +x "$BUILD_SCRIPT"
        ./"$BUILD_SCRIPT"
        NEW_PKG=$(ls -t /tmp/${DIR_NAME}*.t?z | head -n 1)
        popd > /dev/null
        prompt_install "$NEW_PKG"
        ;;

    *.rpm)
        echo "[*] Detected: Red Hat Package"
        check_tool rpm2txz
        rpm2txz -p "$FILE" # -p keeps it in current dir
        TXZ_NAME="${FILE%.rpm}.txz"
        prompt_install "$TXZ_NAME"
        ;;

    *.deb)
        echo "[*] Detected: Debian Package"
        check_tool ar
        mkdir -p "$TMP_BASE/pkg"
        cp "$FILE" "$TMP_BASE/"
        pushd "$TMP_BASE" > /dev/null
        ar x "$FILENAME"
        DATA_FILE=$(ls data.tar.*)
        tar -xf "$DATA_FILE" -C pkg/
        cd pkg
        makepkg -l y -c n "/tmp/${FILENAME%.deb}-tac.txz"
        popd > /dev/null
        prompt_install "/tmp/${FILENAME%.deb}-tac.txz"
        ;;

    *.zst)
        echo "[*] Detected: Arch Linux Package"
        check_tool zstd
        mkdir -p "$TMP_BASE"
        tar --zstd -xf "$FILE" -C "$TMP_BASE"
        rm -f "$TMP_BASE"/{.PKGINFO,.BUILDINFO,.MTREE,.INSTALL}
        makepkg -l y -c n "/tmp/${FILENAME%.pkg.tar.zst}-tac-arch.txz"
        prompt_install "/tmp/${FILENAME%.pkg.tar.zst}-tac-arch.txz"
        ;;

    *)
        echo "Error: Unsupported file format."
        usage
        ;;
esac

# Cleanup
rm -rf "$TMP_BASE"