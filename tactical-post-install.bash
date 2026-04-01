#!/bin/bash

# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root. Slackware doesn't do hand-holding."
  exit 1
fi

# Initialize temporary file for dialog output
TMP_CHOICE=$(mktemp /tmp/slack_choice.XXXXXX)

# --- Functions for specific tasks ---

shield_kernel() {
    BLACKLIST_FILE="/etc/slackpkg/blacklist"
    
    dialog --title "Kernel Shield" \
           --yesno "Would you like to blacklist kernel updates?\n\nThis prevents 'slackpkg upgrade-all' from touching your kernel/modules, protecting your bootloader from accidental crashes." 9 60
    
    if [ $? -ne 0 ]; then
        return
    fi

    if [ -f "$BLACKLIST_FILE" ]; then
        sed -i 's/^#kernel-generic/kernel-generic/' "$BLACKLIST_FILE"
        sed -i 's/^#kernel-huge/kernel-huge/' "$BLACKLIST_FILE"
        sed -i 's/^#kernel-modules/kernel-modules/' "$BLACKLIST_FILE"
        sed -i 's/^#kernel-headers/kernel-headers/' "$BLACKLIST_FILE"
        sed -i 's/^#kernel-source/kernel-source/' "$BLACKLIST_FILE"
        
        for pkg in kernel-generic kernel-huge kernel-modules; do
            grep -q "^$pkg" "$BLACKLIST_FILE" || echo "$pkg" >> "$BLACKLIST_FILE"
        done
        
        dialog --title "Shield Active" --msgbox "Kernel packages are now blacklisted.\nYour bootloader is safe." 7 50
    else
        dialog --title "Error" --msgbox "Could not find $BLACKLIST_FILE" 6 40
    fi
}

view_blacklist() {
    BLACKLIST_FILE="/etc/slackpkg/blacklist"
    if [ -f "$BLACKLIST_FILE" ]; then
        dialog --title "Educational: /etc/slackpkg/blacklist" \
               --exit-label "Return to Menu" \
               --textbox "$BLACKLIST_FILE" 18 75
    else
        dialog --title "Error" --msgbox "Blacklist file not found!" 6 40
    fi
}

configure_mirrors() {
    dialog --title "Mirror Selection" --yesno "Would you like to open /etc/slackpkg/mirrors to select a download source?" 7 60
    if [ $? -eq 0 ]; then
        nano /etc/slackpkg/mirrors
        
        dialog --infobox "Syncing system clock..." 5 50
        ntpdate -u pool.ntp.org 2>/dev/null || rdate -s rdate.cpanel.net
        
        dialog --infobox "Updating GPG keys and package lists..." 5 50
        slackpkg update gpg && slackpkg update
        
        clear
        echo "--- Upgrading Core System (Ignoring Blacklisted Kernels) ---"
        slackpkg install-new
        slackpkg upgrade-all
        
        # Touch a flag so we know an update occurred
        touch /tmp/.slack_updated
        
        dialog --title "Core Update Complete" --msgbox "System is now current with official mirrors." 8 60
    fi
}

install_multilib() {
    dialog --title "Multilib" --yesno "Install Multilib (Alien Bob)? Required for 32-bit apps like Steam/Wine." 7 60
    if [ $? -eq 0 ]; then
        pushd /tmp > /dev/null
        clear
        echo "[*] Fetching multilib via lftp..."
        
        # We only proceed to install IF lftp succeeds
        if lftp -c "open http://www.slackware.com/~alien/multilib/ ; mirror 15.0"; then
            echo "[*] Download complete. Installing..."
            upgradepkg --reinstall --install-new 15.0/*.t?z
            upgradepkg --install-new 15.0/slackware64-compat32/*-compat32/*.t?z
            dialog --msgbox "Multilib installation complete." 6 40
        else
            dialog --title "Error" --msgbox "Failed to fetch Multilib. Check your network or the mirror status." 6 50
        fi
        
        # Cleanup happens regardless of success or failure
        rm -rf 15.0/ 
        popd > /dev/null
    fi
}

install_slackpkg_plus() {
    dialog --title "slackpkg+ (Alien Bob Edition)" --yesno "Install slackpkg+? \n\nNow maintained by Alien Bob, this is the standard for 3rd-party repo support (Alien/Ponce/Multilib)." 8 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Ensuring /tmp is clean..."
        rm -f /tmp/slackpkg+*.t?z
        
        echo "[*] Fetching the latest slackpkg+ from Alien Bob's mirror..."
        # Note: If this 404s in the future, check Alien's repo and bump the 1.8.2 version!
        wget https://slackware.nl/slackpkgplus15/pkg/slackpkg+-1.8.2-noarch-1pkgplus.txz -P /tmp/
        
        # Check if wget actually got the file (exit code 0)
        if [ $? -eq 0 ]; then
            echo "[*] Installing slackpkg+..."
            installpkg /tmp/slackpkg+*.txz
            
            dialog --title "Success" --msgbox "slackpkg+ installed!\n\nACTION REQUIRED:\nEdit /etc/slackpkg/slackpkgplus.conf to enable your repos.\n\nThen run:\nslackpkg update gpg\nslackpkg update" 12 60
        else
            dialog --title "Download Failed" --msgbox "Failed to download slackpkg+. \n\nEither your internet is down, or Alien Bob updated to a new version (e.g., 1.8.3). Check the URL in the script!" 10 60
        fi
        
        rm -f /tmp/slackpkg+*.txz
    fi
}

install_sbotools() {
    dialog --title "sbotools" --yesno "Install sbotools? This handles SlackBuild dependencies automatically." 8 65
    if [ $? -eq 0 ]; then
        clear
        git clone https://github.com/pink-mist/sbotools.git /tmp/sbotools
        cd /tmp/sbotools && perl Makefile.PL && make && make install
        sboconfig --dist 15.0
        cd - > /dev/null
        rm -rf /tmp/sbotools
        dialog --msgbox "sbotools installed!" 6 40
    fi
}

final_reboot() {
    if [ -f /tmp/.slack_updated ]; then
        dialog --title "Reboot Suggestion" \
               --menu "You've just applied a monstrous influx of updates. While not strictly mandatory, a reboot is highly recommended to ensure all new binaries and libraries are loaded correctly." 12 70 2 \
               "NOW" "Reboot the system" \
               "LATER" "I'm a Slacker, I'll do it later" 2> "$TMP_CHOICE"
        
        choice=$(cat "$TMP_CHOICE")
        
        case "$choice" in
            NOW)
                clear
                echo "Rebooting... See you on the other side of the Slack."
                sleep 2
                reboot
                ;;
            LATER|*)
                clear
                echo "Fair enough. Just remember: if something acts weird, a reboot usually fixes it."
                sleep 2
                ;;
        esac
    fi
}

# --- Main Menu Loop ---

while true; do
    dialog --clear --title "Slackware64 Post-Install Housekeeping" \
        --menu "Select a task. Use Up/Down to cycle." 17 75 8 \
        "KERNEL"   "Shield Kernel (Anti-Crash Security)" \
        "VIEW"     "View Blacklist (Educational / Verify Shield)" \
        "MIRRORS"  "Configure Mirrors & Update GPG" \
        "MULTILIB" "Install Multilib (Alien Bob's Repo)" \
        "PLUS"     "Install slackpkg+ (3rd Party Support)" \
        "SBOTOOLS" "Install sbotools (Auto-Dependency Logic)" \
        "EXIT"     "Finish and Exit to Shell" 2> "$TMP_CHOICE"

    choice=$(cat "$TMP_CHOICE")

    case "$choice" in
        KERNEL)   shield_kernel ;;
        VIEW)     view_blacklist ;;
        MIRRORS)  configure_mirrors ;;
        MULTILIB) install_multilib ;;
        PLUS)     install_slackpkg_plus ;;
        SBOTOOLS) install_sbotools ;;
        EXIT|"")  break ;;
    esac
done

# Cleanup and Final Check
rm -f "$TMP_CHOICE"
final_reboot
rm -f /tmp/.slack_updated

clear
echo "--- Housekeeping Complete. Enjoy the Slack! ---"