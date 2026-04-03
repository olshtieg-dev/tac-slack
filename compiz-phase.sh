#!/bin/bash
#remember to make executable with chmod +x compiz-phase.sh
# --- Safety Check ---
if [ "$EUID" -ne 0 ]; then 
  echo "Run as root."
  exit 1
fi

TMP_CHOICE=$(mktemp)

log_phase() {
    echo "[*] $1"
}

pause() {
    read -p "Press ENTER to continue..."
}

run_phase() {
    clear
    echo "[*] Running: $1"
    eval "$1"
    if [ $? -ne 0 ]; then
        echo "[!] Error occurred."
    else
        echo "[OK] Completed."
    fi
    pause
}

install_compiz_stack() {
    run_phase "sbosnap update"

    run_phase "sboinstall compiz"
    run_phase "sboinstall compiz-plugins-main"
    run_phase "sboinstall compiz-plugins-extra"
    run_phase "sboinstall compizconfig-backend-kconfig"
    run_phase "sboinstall compizconfig-settings-manager"
    run_phase "sboinstall fusion-icon"
    run_phase "sboinstall emerald"
    run_phase "sboinstall emerald-themes"
}

disable_xfce_compositor() {
    run_phase "xfconf-query -c xfwm4 -p /general/use_compositing -s false"
}

test_gl() {
    clear
    echo "[*] Checking OpenGL..."
    glxinfo | grep "direct rendering"
    pause
}

start_compiz_stack() {
    clear
    echo "[*] Starting Compiz + Emerald..."
    compiz --replace &
    sleep 2
    emerald --replace &
    sleep 1
    gtk-window-decorator --replace &
    pause
}

create_fallback_script() {
    cat <<EOF > /usr/local/bin/fix-desktop.sh
#!/bin/bash
xfwm4 --replace &
EOF
    chmod +x /usr/local/bin/fix-desktop.sh
    echo "[OK] Created fallback: fix-desktop.sh"
    pause
}

setup_autostart() {
    mkdir -p ~/.config/autostart

    cat <<EOF > ~/.config/autostart/emerald.desktop
[Desktop Entry]
Type=Application
Exec=emerald --replace
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Emerald
EOF

    echo "[OK] Emerald autostart configured."
    pause
}

launch_theme_manager() {
    emerald-theme-manager
}

# --- Main Menu ---
while true; do
    dialog --clear --title "SlackTix Compiz Phase" \
    --menu "Choose Phase" 20 70 10 \
    1 "Install Compiz Stack (SBo)" \
    2 "Disable Xfce Compositor" \
    3 "Check OpenGL (glxinfo)" \
    4 "Start Compiz + Emerald" \
    5 "Create Fallback Script" \
    6 "Setup Emerald Autostart" \
    7 "Launch Emerald Theme Manager" \
    8 "Exit" 2> "$TMP_CHOICE"

    CHOICE=$(cat "$TMP_CHOICE")

    case $CHOICE in
        1) install_compiz_stack ;;
        2) disable_xfce_compositor ;;
        3) test_gl ;;
        4) start_compiz_stack ;;
        5) create_fallback_script ;;
        6) setup_autostart ;;
        7) launch_theme_manager ;;
        8|*) break ;;
    esac
done

rm -f "$TMP_CHOICE"
clear
echo "[*] Compiz Phase Complete."