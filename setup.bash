#!/bin/bash
# Tac-Slack Setup: Prepping the Garage

if [ "$EUID" -ne 0 ]; then 
  echo "You need root to tune this engine."
  exit 1
fi

echo "[*] Tac-Slack: Starting the Pit Crew..."

# 1. Essential Native Tools (Check & Install via slackpkg)
NATIVE_TOOLS=("rpm2txz" "ar" "zstd" "lftp" "wget" "git" "perl" "python3")
MISSING_NATIVE=()

for tool in "${NATIVE_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_NATIVE+=("$tool")
    fi
done

if [ ${#MISSING_NATIVE[@]} -ne 0 ]; then
    echo "[!] Missing core tools: ${MISSING_NATIVE[*]}"
    slackpkg update && slackpkg install "${MISSING_NATIVE[@]}"
fi

# 2. 3rd Party Ninja Tools (Download & Install)
pushd /tmp > /dev/null

# --- src2pkg (The Heavy Hitter) ---
if ! command -v src2pkg &> /dev/null; then
    echo "[*] Fetching src2pkg..."
    wget https://distro.ibiblio.org/amigolinux/download/src2pkg/src2pkg-3.0-noarch-1.tgz
    installpkg src2pkg-3.0-noarch-1.tgz
fi

# --- deb2tgz (The Debian Specialist) ---
if ! command -v deb2tgz &> /dev/null; then
    echo "[*] Fetching deb2tgz..."
    # Using a reliable community version
    wget https://github.com/01mf02/deb2tgz/raw/master/deb2tgz -O /usr/local/bin/deb2tgz
    chmod +x /usr/local/bin/deb2tgz
fi

# --- arch2pkg (The Arch Raider) ---
if ! command -v arch2pkg &> /dev/null; then
    echo "[*] Fetching arch2pkg..."
    git clone https://github.com/Ponce/arch2pkg.git
    cd arch2pkg
    # arch2pkg is usually a script; we'll move it to path
    cp arch2pkg.sh /usr/local/bin/arch2pkg
    chmod +x /usr/local/bin/arch2pkg
    cd ..
fi

popd > /dev/null

# 3. Deploy the Main Dispatcher
echo "[*] Tuning the main Tac-Slack engine..."
cp tactical-post-install.bash /usr/local/bin/tac-slack
chmod +x /usr/local/bin/tac-slack

echo "[*] Garage prepped. Tac-Slack ninjas are ready for deployment!"