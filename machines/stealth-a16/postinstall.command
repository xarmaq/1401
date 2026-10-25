#!/bin/bash
# One-time setup after macOS is installed on the MSI Stealth A16 AI+. Double-click it (or: sudo bash postinstall.command).
# --undo removes everything it installed.
set -euo pipefail
cd "$(dirname "$0")"
if [ "$(id -u)" != 0 ]; then exec sudo /bin/bash "$0" "$@"; fi

LABEL=com.stealtha16.tune
BIN=/Library/PrivilegedHelperTools/$LABEL
PLIST=/Library/LaunchDaemons/$LABEL.plist

if [ "${1:-}" = --undo ]; then
    launchctl bootout "system/$LABEL" 2>/dev/null || true
    rm -f "$PLIST" "$BIN"
    defaults delete /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || true
    echo "Removed. Reboot to return CPU and display settings to their defaults."
    exit 0
fi

echo "== Performance daemon (CPU boost + 240 Hz frame pacing)"
launchctl bootout "system/$LABEL" 2>/dev/null || true
mkdir -p /Library/PrivilegedHelperTools
install -o root -g wheel -m 755 stealth-tune.sh "$BIN"
/usr/bin/plutil -create xml1 "$PLIST"
/usr/bin/plutil -insert Label -string "$LABEL" "$PLIST"
/usr/bin/plutil -insert ProgramArguments -array "$PLIST"
/usr/bin/plutil -insert ProgramArguments.0 -string "$BIN" "$PLIST"
/usr/bin/plutil -insert RunAtLoad -bool true "$PLIST"
/usr/bin/plutil -insert KeepAlive -bool true "$PLIST"
/usr/bin/plutil -insert StandardOutPath -string /var/log/stealth-tune.log "$PLIST"
/usr/bin/plutil -insert StandardErrorPath -string /var/log/stealth-tune.log "$PLIST"
chown root:wheel "$PLIST"; chmod 644 "$PLIST"
launchctl bootstrap system "$PLIST"

echo "== Power settings"
# no hibernation image (a hackintosh cannot resume from one), no Power Nap / dark wakes that wake the dGPU
pmset -a hibernatemode 0 standby 0 powernap 0 tcpkeepalive 0 proximitywake 0 womp 0
rm -f /var/vm/sleepimage
pmset -c lowpowermode 0
pmset -c displaysleep 15 sleep 30
pmset -b displaysleep 5 sleep 15

echo "== Keep macOS on 26.7.1 (25G241): the Wi-Fi menu and Bluetooth fix only work on this build"
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true

echo "== Smoother animations"
# window resize animation is a fixed 0.2 s timer, independent of refresh rate
sudo -u "$(stat -f %Su /dev/console)" defaults write -g NSWindowResizeTime -float 0.1 || true

echo
echo "Done. Log: /var/log/stealth-tune.log"
echo "In System Settings > Displays pick 240 Hz and the size you like (HiDPI sizes are there)."
