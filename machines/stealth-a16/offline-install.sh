#!/bin/bash
# Installs macOS 26.7.1 (25G241) from the full installer on the MACINSTALL partition, with no network.
# In macOS Recovery: Utilities > Terminal, then
#     bash /Volumes/1401/StealthA16/offline-install.sh            (installs onto the volume named "macOS")
#     bash /Volumes/1401/StealthA16/offline-install.sh "Other"    (another volume name)
set -euo pipefail

PKG=/Volumes/MACINSTALL/InstallAssistant.pkg
TARGET=/Volumes/${1:-macOS}

[ -f "$PKG" ] || { echo "No $PKG: is the MACINSTALL partition mounted? (diskutil list; diskutil mount MACINSTALL)"; exit 1; }
[ -d "$TARGET" ] || { echo "No volume $TARGET: create the APFS volume in Disk Utility first, or pass its name."; exit 1; }

echo "== Unpacking the installer onto $TARGET (about 10 minutes, 17 GB)"
installer -pkg "$PKG" -target "$TARGET"

APP=$(ls -d "$TARGET"/Applications/Install\ macOS*.app | head -1)
[ -d "$APP" ] || { echo "The installer app did not appear in $TARGET/Applications"; exit 1; }
echo "== $APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" || true

echo "== Starting the install onto $TARGET; the Mac restarts by itself several times"
echo "   (each time: F11 > the USB stick > in OpenCore pick 'macOS Installer', later '${1:-macOS}')"
if ! "$APP/Contents/Resources/startosinstall" --agreetolicense --nointeraction --volume "$TARGET"; then
    echo "== startosinstall declined here; opening the installer window instead (pick $TARGET in it)"
    for b in InstallAssistant_springboard InstallAssistant; do
        [ -x "$APP/Contents/MacOS/$b" ] && exec "$APP/Contents/MacOS/$b"
    done
    echo "No installer binary found in $APP/Contents/MacOS"; exit 1
fi
