#!/bin/bash
# stealth-tune: keeps the MSI Stealth A16 AI+ at full speed in macOS. Runs as a root LaunchDaemon.
#
# - CPU: AmdCppc (Strix Point) exposes CPPC through debug.amdcppc.*. Without a policy the cores stay near their 2 GHz
#   P0. On AC the energy-performance preference is 0 (highest performance), on battery EPP_BATTERY. The kext reads the
#   request back on all 24 CPUs and fails the write on a mismatch, so a failed sysctl means "not applied".
#   AmdCppcPolicy from the G14 project takes its AC/profile state from ASUS WMI, which an MSI does not have (it would
#   sit at EPP 191 forever), hence this script.
# - GPU: debug.nvrmfb_flip_latch=2 lets NVRMFB verify a flip at the next present instead of waiting for it, which gives
#   back about half a refresh period per frame on a 240 Hz panel (NullMoth CHANGELOG, opt-in).
# Firmware can reset CPPC requests across sleep, so everything is re-checked every INTERVAL seconds.

EPP_AC=${EPP_AC:-0}
EPP_BATTERY=${EPP_BATTERY:-128}
FLIP_LATCH=${FLIP_LATCH:-2}
INTERVAL=${INTERVAL:-15}

get() { /usr/sbin/sysctl -n "$1" 2>/dev/null; }
set_if() {   # set_if <oid> <value>: write only when the OID exists and differs
    local cur
    cur=$(get "$1") || return 1
    [ -n "$cur" ] || return 1
    [ "$cur" = "$2" ] && return 0
    /usr/sbin/sysctl -w "$1=$2" >/dev/null 2>&1 && echo "$(date '+%F %T') $1=$2" || { echo "$(date '+%F %T') $1=$2 FAILED"; return 1; }
}

last_epp=""
while :; do
    if /usr/bin/pmset -g batt | /usr/bin/grep -q "AC Power"; then epp=$EPP_AC; else epp=$EPP_BATTERY; fi
    if [ -n "$(get debug.amdcppc.report)" ]; then
        set_if debug.amdcppc.cppc 1
        # the kext keeps the request after a write; re-send when the source changed or the report lost it
        if [ "$epp" != "$last_epp" ] || ! get debug.amdcppc.report | /usr/bin/grep -q "epp $epp"; then
            /usr/sbin/sysctl -w "debug.amdcppc.epp=$epp" >/dev/null 2>&1 && { echo "$(date '+%F %T') EPP=$epp"; last_epp=$epp; }
        fi
    fi
    set_if debug.nvrmfb_flip_latch "$FLIP_LATCH"
    sleep "$INTERVAL"
done
