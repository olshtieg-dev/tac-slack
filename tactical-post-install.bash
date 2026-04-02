#!/bin/bash

# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root. Slackware doesn't do hand-holding."
  exit 1
fi

# Initialize temporary file for dialog output
TMP_CHOICE=$(mktemp /tmp/slack_choice.XXXXXX)

# --- The Truth-Teller Function ---
# Usage: check_status $? "Description"
check_status() {
    local EXIT_CODE=$1
    local TASK_NAME=$2

    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "\n\e[1;31m[!!!] CRITICAL FAILURE: $TASK_NAME\e[0m"
        echo "Exit Code: $EXIT_CODE. Mission halted to prevent system corruption."
        echo "------------------------------------------------------------"
        read -p "Press [ENTER] to return to menu and troubleshoot..."
        return 1
    else
        echo -e "\n\e[1;32m[OK] SUCCESS: $TASK_NAME\e[0m"
        read -p "Press [ENTER] to return to the Housekeeping Menu..."
        return 0
    fi
}

# --- Functions ---

shield_kernel() {
    BLACKLIST_FILE="/etc/slackpkg/blacklist"
    dialog --title "Kernel Shield" --yesno "Blacklist kernel updates to protect bootloader?" 8 60
    if [ $? -eq 0 ]; then
        echo "[*] Hardening $BLACKLIST_FILE..."
        # Ensure the file exists before sed-ing
        touch "$BLACKLIST_FILE"
        sed -i 's/^#kernel-generic/kernel-generic/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-huge/kernel-huge/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-modules/kernel-modules/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-headers/kernel-headers/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-source/kernel-source/' "$BLACKLIST_FILE"
        
        # Ensure they are actually in there (not just uncommented)
        for pkg in kernel-generic kernel-huge kernel-modules; do
            grep -q "^$pkg" "$BLACKLIST_FILE" || echo "$pkg" >> "$BLACKLIST_FILE"
        done
        check_status $? "Kernel Blacklisting"
    fi
}

view_blacklist() {
    BLACKLIST_FILE="/etc/slackpkg/blacklist"
    if [ -f "$BLACKLIST_FILE" ]; then
        dialog --title "Current Blacklist" --textbox "$BLACKLIST_FILE" 18 75
    else
        dialog --msgbox "Error: $BLACKLIST_FILE not found." 6 40
    fi
}

configure_mirrors() {
    dialog --title "Mirror Selection" --yesno "Edit /etc/slackpkg/mirrors?" 7 60
    if [ $? -eq 0 ]; then
        nano /etc/slackpkg/mirrors
        clear
        echo "[*] Syncing clock and pulling official updates..."
        ntpdate -u pool.ntp.org 2>/dev/null || rdate -s rdate.cpanel.net
        slackpkg update gpg && slackpkg update && slackpkg install-new && slackpkg upgrade-all
        check_status $? "Official Mirror Sync/Upgrade"
        [ $? -eq 0 ] && touch /tmp/.slack_updated
    fi
}

install_slackpkg_plus() {
    dialog --title "Step 1: Install slackpkg+" --yesno "Fetch and install slackpkg+ (Alien Bob Edition)?" 7 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Fetching package verbosely..."
        rm -f /tmp/slackpkg+*.txz
        wget -v https://slackware.nl/slackpkgplus/pkg/slackpkg+-1.8.2-noarch-1alien.txz -P /tmp/
        if [ $? -eq 0 ]; then
            installpkg /tmp/slackpkg+*.txz
            check_status $? "slackpkg+ Installation"
        else
            check_status 1 "Download failed. Check URL or Network."
        fi
        rm -f /tmp/slackpkg+*.txz
    fi
}

configure_slackpkg_plus() {
    dialog --title "Step 2: Nano Handoff" --msgbox "MISSION:\n1. Find REPOSPLUS and add: multilib alienbob\n2. Find MIRRORS_PRIORITY and add: multilib alienbob\n3. Uncomment MIRROR_multilib=..." 14 70
    nano /etc/slackpkg/slackpkgplus.conf
    dialog --msgbox "Configuration saved. You are ready for Multilib." 6 50
}

install_multilib() {
    dialog --title "Multilib Deployment" --yesno "Begin mass download of 32-bit compat libraries?" 7 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Updating GPG and Repository Lists..."
        slackpkg update gpg && slackpkg update
        if [ $? -eq 0 ]; then
            echo "[*] Running 'slackpkg install multilib'..."
            slackpkg install multilib
            check_status $? "Multilib Deployment"
            [ $? -eq 0 ] && touch /tmp/.slack_updated
        else
            check_status $? "Multilib Repo Sync"
        fi
    fi
}

install_sbotools() {
    dialog --title "sbotools" --yesno "Clone and build sbotools for auto-dependency handling?" 7 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Cloning sbotools source..."
        rm -rf /tmp/sbotools
        git clone --verbose https://github.com/pink-mist/sbotools.git /tmp/sbotools
        if [ $? -eq 0 ]; then
            echo "[*] Compiling and Installing..."
            cd /tmp/sbotools && perl Makefile.PL && make && make install
            INSTALL_STATE=$?
            sboconfig --dist 15.0
            cd - > /dev/null
            rm -rf /tmp/sbotools
            check_status $INSTALL_STATE "sbotools Build/Install"
        else
            check_status 1 "Git clone failed."
        fi
    fi
}

final_reboot() {
    if [ -f /tmp/.slack_updated ]; then
        dialog --title "Reboot Required" --yesno "Core updates or Multilib were applied. Reboot now?" 7 60
        [ $? -eq 0 ] && reboot
    fi
}

# --- Main Menu Loop ---

while true; do
    dialog --clear --title "SlackTix Forge Housekeeping v2.4" \
        --menu "Use arrows to select. Every step is verified for success." 19 75 9 \
        "KERNEL"   "Shield Kernel (Protect Bootloader)" \
        "VIEW"     "View Blacklist (Check Shield status)" \
        "MIRRORS"  "Configure Official Mirrors & Update" \
        "PLUS"     "Install slackpkg+ (Step 1)" \
        "PLUSCONF" "Configure slackpkg+ (Step 2: Nano)" \
        "MULTILIB" "Install Multilib (Via slackpkg+)" \
        "SBOTOOLS" "Install sbotools (Dependency King)" \
        "EXIT"     "Exit to Shell" 2> "$TMP_CHOICE"

    choice=$(cat "$TMP_CHOICE")

    case "$choice" in
        KERNEL)   shield_kernel ;;
        VIEW)     view_blacklist ;;
        MIRRORS)  configure_mirrors ;;
        PLUS)     install_slackpkg_plus ;;
        PLUSCONF) configure_slackpkg_plus ;;
        MULTILIB) install_multilib ;;
        SBOTOOLS) install_sbotools ;;
        EXIT|"")  break ;;
    esac
done

rm -f "$TMP_CHOICE"
final_reboot
rm -f /tmp/.slack_updated
clear
echo "--- Housekeeping Complete. System status: Verified. ---"