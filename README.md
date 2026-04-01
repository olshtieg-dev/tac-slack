
# Tac-Slack: The Universal Forge for Slackware

Welcome to the Tactical-Slack ecosystem. Slackware is the most stable and security-conscious Linux distribution, but it doesn't believe in "hand-holding." That's where **Tac-Slack** comes in.

Tac-Slack is a universal package management abstraction layer. It doesn't matter if the software you found is an `.rpm` (Fedora), a `.deb` (Debian), an Arch Linux `zst` package, or a raw source `tarball`—Tac-Slack identifies the format, forges it into a Slackware package (`.txz`), scans it for missing parts, and installs it for you.

### Why Tac-Slack?
* **One Command:** `tac-slack [file]` handles everything.
* **Ninja Forge:** Automates `deb2tgz`, `arch2pkg`, `rpm2txz`, and `src2pkg`.
* **Safety First:** Includes a pre-install `ldd` dependency scanner to warn you about missing libraries before they break your system.
* **User Sovereignty:** You decide whether to Install, Hold, or Burn the forged package.

### Installation
1. Ensure you have `slackpkg` configured.
2. Run the `setup.bash` script as **root**:
   ```bash
   sudo ./setup.bash