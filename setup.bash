#!/bin/bash
# Tac-Slack Setup: Prepping the Garage

if [ "$EUID" -ne 0 ]; then 
  echo "You need root to tune this engine."
  exit 1
fi

echo "[*] Tac-Slack: Starting the Pit Crew..."

# 1. Essential Native & Support Tools
NATIVE_TOOLS=("rpm2txz" "ar" "zstd" "lftp" "wget" "git" "perl" "python3")
MISSING_NATIVE=()

for tool in "${NATIVE_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_NATIVE+=("$tool")
    fi
done

if [ ${#MISSING_NATIVE[@]} -ne 0 ]; then
    echo "[!] Missing core tools: ${MISSING_NATIVE[*]}"
    # Sync and install missing native components
    slackpkg update && slackpkg install "${MISSING_NATIVE[@]}"
fi

# 2. 3rd Party Ninja Tools (Community Specialists)
pushd /tmp > /dev/null

# --- src2pkg (The Heavy Hitter) ---
if ! command -v src2pkg &> /dev/null; then
    echo "[*] Installing src2pkg (The Legend)..."
    wget https://distro.ibiblio.org/amigolinux/download/src2pkg/src2pkg-3.0-noarch-1.tgz
    installpkg src2pkg-3.0-noarch-1.tgz
fi

# --- deb2tgz (The Debian Specialist) ---
if ! command -v deb2tgz &> /dev/null; then
    echo "[*] Installing deb2tgz..."
    wget https://github.com/01mf02/deb2tgz/raw/master/deb2tgz -O /usr/local/bin/deb2tgz
    chmod +x /usr/local/bin/deb2tgz
fi

# --- arch2pkg (The Arch Raider) ---
if ! command -v arch2pkg &> /dev/null; then
    echo "[*] Installing arch2pkg (Ponce Edition)..."
    git clone https://github.com/Ponce/arch2pkg.git
    cp arch2pkg/arch2pkg.sh /usr/local/bin/arch2pkg
    chmod +x /usr/local/bin/arch2pkg
fi

popd > /dev/null

# 3. Deployment
echo "[*] Moving tac-slack to /usr/local/bin..."
# Assumes your script file is named tac-slack.bash in current dir
cp tac-slack.bash /usr/local/bin/tac-slack
chmod 755 /usr/local/bin/tac-slack

echo "[*] Setup complete. The hotrod is ready to race."