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
        
        # 1. Sync the clock (Essential for GPG)
        dialog --infobox "Syncing system clock..." 5 50
        ntpdate -u pool.ntp.org 2>/dev/null || rdate -s rdate.cpanel.net
        
        # 2. Refresh the package lists
        dialog --infobox "Updating GPG keys and package lists..." 5 50
        slackpkg update gpg && slackpkg update
        
        # 3. Bring the core system up to date (Ignoring blacklisted items)
        # We use 'clear' because slackpkg's output is too long for a dialog box
        clear
        echo "--- Upgrading Core System (Ignoring Blacklisted Kernels) ---"
        slackpkg install-new
        slackpkg upgrade-all
        
        dialog --title "Core Update Complete" --msgbox "System is now current with official mirrors.\n\nYou can now proceed to Multilib or 3rd Party tools." 8 60
    fi
}

install_multilib() {
    dialog --title "Multilib" --yesno "Install Multilib (Alien Bob)? Required for 32-bit apps like Steam/Wine." 7 60
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Fetching multilib... this uses lftp to mirror the repo."
        lftp -c "open http://www.slackware.com/~alien/multilib/ ; mirror 15.0"
        upgradepkg --reinstall --install-new 15.0/*.t?z
        upgradepkg --install-new 15.0/slackware64-compat32/*-compat32/*.t?z
        rm -rf 15.0/ 
        dialog --msgbox "Multilib installation complete." 6 40
    fi
}

install_slackpkg_plus() {
    dialog --title "slackpkg+" --yesno "Install slackpkg+ for 3rd party repo support (Alien/Ponce)?" 7 60
    if [ $? -eq 0 ]; then
        wget https://downloads.sourceforge.net/project/slackpkgplus/slackpkg%2B-1.7.0-noarch-1pkgplus.txz -O /tmp/slackpkgplus.txz
        installpkg /tmp/slackpkgplus.txz
        dialog --msgbox "Installed. REMEMBER: Edit /etc/slackpkg/slackpkgplus.conf to enable repos." 8 60
    fi
}

install_sbotools() {
    dialog --title "sbotools (Dependency King)" --yesno "Install sbotools? This handles SlackBuild dependencies automatically, keeping the system clean." 8 65
    if [ $? -eq 0 ]; then
        clear
        echo "[*] Cloning sbotools from GitHub..."
        git clone https://github.com/pink-mist/sbotools.git /tmp/sbotools
        cd /tmp/sbotools
        
        echo "[*] Building and installing sbotools..."
        perl Makefile.PL && make && make install
        
        echo "[*] Initializing sbotools config..."
        # Set to 15.0 by default, feel free to change to 'current'
        sboconfig --dist 15.0
        
        cd - > /dev/null
        rm -rf /tmp/sbotools
        
        dialog --title "Success" --msgbox "sbotools installed!\n\nQuick Commands:\n- sboinstall <pkg>\n- sbocheck\n- sboupgrade --all" 10 50
    fi
}

# --- Main Menu Loop ---

while true; do
    dialog --clear --title "Slackware64 Post-Install Housekeeping" \
        --menu "Select a task. sbotools is recommended for dependency handling." 17 75 8 \
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

# Cleanup
rm -f "$TMP_CHOICE"
clear
echo "--- Housekeeping Complete. Enjoy the Slack! ---"