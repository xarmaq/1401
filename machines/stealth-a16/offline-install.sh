#!/bin/bash
# Installs macOS from the full installer (InstallAssistant.pkg) on the MACINSTALL partition, with no network.
# In macOS Recovery: Utilities > Terminal, then
#     bash /V*/14*/go                                             (the short form: /Volumes/1401/go runs this)
#     bash /Volumes/1401/StealthA16/offline-install.sh "Other"    (another target volume name)
set -uo pipefail

PKG=/Volumes/MACINSTALL/InstallAssistant.pkg
TARGET=/Volumes/${1:-macOS}

pmset -a sleep 0 displaysleep 0 disksleep 0 >/dev/null 2>&1 || true

[ -f "$PKG" ] || { echo "No $PKG: is the MACINSTALL partition mounted? (diskutil mount MACINSTALL)"; exit 1; }
[ -d "$TARGET" ] || { echo "No volume $TARGET: create the APFS volume in Disk Utility first, or pass its name."; exit 1; }

app() { ls -d "$TARGET"/Applications/Install\ macOS*.app 2>/dev/null | head -1; }
APP=$(app)
if [ -z "$APP" ] || [ ! -x "$APP/Contents/Resources/startosinstall" ]; then
    echo "== Unpacking the installer app onto $TARGET"
    # The package's postinstall (link_shared_support.bash) fails in Recovery; the app itself is laid down before it
    # runs, and its only job, putting SharedSupport.dmg in place, is done below.
    installer -pkg "$PKG" -target "$TARGET" || echo "   (the package's own postinstall failed, as expected in Recovery)"
fi
APP=$(app); SS="$APP/Contents/SharedSupport/SharedSupport.dmg"
[ -n "$APP" ] && [ -x "$APP/Contents/Resources/startosinstall" ] || { echo "The installer app is not in $TARGET/Applications"; exit 1; }

# InstallAssistant.pkg is also the SharedSupport disk image (it ends in a DMG trailer); Apple's script copies it as-is
want=$(stat -f %z "$PKG")
if [ "$(stat -f %z "$SS" 2>/dev/null || echo 0)" != "$want" ]; then
    echo "== Copying the macOS image into the installer (17 GB, about 5-10 minutes)"
    mkdir -p "$(dirname "$SS")"
    cp "$PKG" "$SS.part" && mv -f "$SS.part" "$SS" || { echo "Copy failed"; exit 1; }
    chmod 0644 "$SS"
fi

echo "== Starting the install onto $TARGET; the Mac restarts by itself several times"
echo "   (each time: F11 > the USB stick > in OpenCore pick 'macOS Installer', later '${1:-macOS}')"
"$APP/Contents/Resources/startosinstall" --agreetolicense --nointeraction --volume "$TARGET" && exit 0
echo "== startosinstall declined here; opening the installer window instead (pick ${1:-macOS} in it)"
for b in InstallAssistant_springboard InstallAssistant; do
    [ -x "$APP/Contents/MacOS/$b" ] && exec "$APP/Contents/MacOS/$b"
done
echo "No installer binary found in $APP/Contents/MacOS"; exit 1
