#!/bin/bash

# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root. Slackware doesn't do hand-holding."
  exit 1
fi

# Initialize temporary file for dialog output
TMP_CHOICE=$(mktemp /tmp/slack_choice.XXXXXX)

# --- The Truth-Teller Function ---
check_status() {
    local EXIT_CODE=$1
    local TASK_NAME=$2

    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "\n\e[1;31m[!!!] CRITICAL FAILURE: $TASK_NAME\e[0m"
        echo "Exit Code: $EXIT_CODE. Mission halted."
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
        touch "$BLACKLIST_FILE"
        sed -i 's/^#kernel-generic/kernel-generic/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-huge/kernel-huge/' "$BLACKLIST_FILE" && \
        sed -i 's/^#kernel-modules/kernel-modules/' "$BLACKLIST_FILE"
        
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
        rm -f /tmp/slackpkg+*.txz
        wget -v https://slackware.nl/slackpkgplus/pkg/slackpkg+-1.8.2-noarch-1alien.txz -P /tmp/
        if [ $? -eq 0 ]; then
            installpkg /tmp/slackpkg+*.txz
            check_status $? "slackpkg+ Installation"
        else
            check_status 1 "Download failed."
        fi
        rm -f /tmp/slackpkg+*.txz
    fi
}

auto_prep_multilib() {
    # Dynamically find the setup script in the documentation directory
    local SETUP_SCRIPT=$(find /usr/doc/slackpkg+-* -name setupmultilib.sh | head -n 1)
    local CONFIG_FILE="/etc/slackpkg/slackpkgplus.conf"

    if [ -z "$SETUP_SCRIPT" ]; then
        dialog --title "Error" --msgbox "Could not find setupmultilib.sh.\n\nEnsure slackpkg+ is installed first." 8 60
        return 1
    fi

    dialog --title "Auto-Config Multilib" --yesno "Found script at: $SETUP_SCRIPT\n\nRun this to automate slackpkgplus.conf settings? (I will back up your config first)." 10 70
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Backing up $CONFIG_FILE to ${CONFIG_FILE}.bak..."
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        
        echo "[*] Launching official setupmultilib.sh..."
        sh "$SETUP_SCRIPT"
        check_status $? "Automated Multilib Configuration"
    fi
}

install_multilib() {
    dialog --title "Multilib Deployment" --yesno "Begin mass download of 32-bit compat libraries?" 7 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Syncing Repository Lists..."
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
    dialog --title "sbotools" --yesno "Clone and build sbotools?" 7 65
    if [ $? -eq 0 ]; then
        clear
        rm -rf /tmp/sbotools
        git clone --verbose https://github.com/pink-mist/sbotools.git /tmp/sbotools
        if [ $? -eq 0 ]; then
            cd /tmp/sbotools && perl Makefile.PL && make && make install
            STATE=$?
            sboconfig --dist 15.0
            cd - > /dev/null
            rm -rf /tmp/sbotools
            check_status $STATE "sbotools Build/Install"
        else
            check_status 1 "Git clone failed."
        fi
    fi
}

final_reboot() {
    if [ -f /tmp/.slack_updated ]; then
        dialog --title "Reboot Required" --yesno "System changes detected. Reboot now?" 7 60
        [ $? -eq 0 ] && reboot
    fi
}

# --- Main Menu Loop ---

while true; do
    dialog --clear --title "SlackTix Forge Housekeeping v2.5" \
        --menu "Select a task. 'AUTOPREP' is the recommended way to set up Multilib." 20 75 10 \
        "KERNEL"   "Shield Kernel (Protect Bootloader)" \
        "VIEW"     "View Blacklist (Check Shield status)" \
        "MIRRORS"  "Configure Official Mirrors & Update" \
        "PLUS"     "Install slackpkg+ (Required First)" \
        "AUTOPREP" "AUTO-CONFIG Multilib (The Pro Way)" \
        "EDIT"     "Manual Edit slackpkgplus.conf (Nano)" \
        "MULTILIB" "Install Multilib (Via slackpkg+)" \
        "SBOTOOLS" "Install sbotools (Dependency King)" \
        "EXIT"     "Exit to Shell" 2> "$TMP_CHOICE"

    choice=$(cat "$TMP_CHOICE")

    case "$choice" in
        KERNEL)   shield_kernel ;;
        VIEW)     view_blacklist ;;
        MIRRORS)  configure_mirrors ;;
        PLUS)     install_slackpkg_plus ;;
        AUTOPREP) auto_prep_multilib ;;
        EDIT)     nano /etc/slackpkg/slackpkgplus.conf ;;
        MULTILIB) install_multilib ;;
        SBOTOOLS) install_sbotools ;;
        EXIT|"")  break ;;
    esac
done

rm -f "$TMP_CHOICE"
final_reboot
rm -f /tmp/.slack_updated
clear
echo "--- Housekeeping Complete. Multilib is prepped surgically. ---"