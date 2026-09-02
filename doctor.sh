#!/usr/bin/env bash
# Checks the whole chain from the USB adapter to the COM port inside Wine and
# prints OK / FAIL per step, with a hint on what to do about it.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/i18n.sh
. "$HERE/lib/i18n.sh"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/victron-wine/config"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
VICTRON_COM="${VICTRON_COM:-com1}"
VICTRON_DEV="${VICTRON_DEV:-/dev/victron-mk3}"

fail=0
ok()   { printf '  \033[32m%s\033[0m %s\n' "$M_D_OK" "$*"; }
bad()  { printf '  \033[31m%s\033[0m %s\n' "$M_D_BAD" "$*"; fail=1; }
note() { printf '        %s\n' "$*"; }

echo "$M_D_HEAD"
echo

if command -v wine >/dev/null 2>&1; then
    ok "$(printf "$M_D_WINE_OK" "$(wine --version 2>/dev/null)")"
else
    bad "$M_D_WINE_BAD"
fi

if ! command -v lsusb >/dev/null 2>&1; then
    note "$M_D_USB_SKIP"
elif lsusb 2>/dev/null | grep -qi '0403:6015'; then
    ok "$M_D_USB_OK"
else
    bad "$M_D_USB_BAD"
fi

if [ -e /etc/udev/rules.d/70-victron-mk3.rules ]; then
    ok "$M_D_RULE_OK"
else
    bad "$M_D_RULE_BAD"
fi

if [ -e "$VICTRON_DEV" ]; then
    ok "$(printf "$M_D_DEV_OK" "$VICTRON_DEV" "$(readlink -f "$VICTRON_DEV")")"
    if [ -r "$VICTRON_DEV" ] && [ -w "$VICTRON_DEV" ]; then
        ok "$(printf "$M_D_ACL_OK" "$VICTRON_DEV")"
    else
        bad "$(printf "$M_D_ACL_BAD" "$VICTRON_DEV")"
        note "$(printf "$M_D_ACL_N1" "$(readlink -f "$VICTRON_DEV")" "$(id -un)")"
        note "$M_D_ACL_N2"
    fi
else
    bad "$(printf "$M_D_DEV_BAD" "$VICTRON_DEV")"
fi

if [ -x "$HOME/.local/bin/victron-com1-fix" ]; then
    ok "$M_D_FIX_OK"
else
    bad "$M_D_FIX_BAD"
fi

link=$(readlink "$WINEPREFIX/dosdevices/$VICTRON_COM" 2>/dev/null)
if [ "$link" = "$VICTRON_DEV" ]; then
    ok "$(printf "$M_D_COM_OK" "$VICTRON_COM" "$VICTRON_DEV")"
else
    bad "$(printf "$M_D_COM_BAD" "$VICTRON_COM" "${link:--}" "$VICTRON_DEV")"
    note "$M_D_COM_N"
fi

stray=$(find "$WINEPREFIX/dosdevices" -maxdepth 1 -name 'com*' 2>/dev/null | grep -cv "/$VICTRON_COM\$")
if [ "${stray:-0}" -eq 0 ]; then
    ok "$M_D_STRAY_OK"
else
    bad "$(printf "$M_D_STRAY_BAD" "$stray")"
    note "$M_D_STRAY_N"
fi

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    if [ "$(systemctl --user is-enabled victron-com1.path 2>/dev/null)" = enabled ]; then
        ok "$M_D_PATH_OK"
    else
        bad "$M_D_PATH_BAD"
        note "$M_D_PATH_N"
    fi
fi

if [ -f "$WINEPREFIX/drive_c/Program Files (x86)/VE Configure tools/VEConfig.exe" ]; then
    ok "$M_D_TOOLS_OK"
else
    bad "$M_D_TOOLS_BAD"
fi

if [ -f "$WINEPREFIX/user.reg" ]; then
    n=$(grep -c '"Scan COM ports"="0"' "$WINEPREFIX/user.reg" 2>/dev/null || echo 0)
    if [ "$n" -ge 1 ]; then
        ok "$(printf "$M_D_SCAN_OK" "$n")"
    else
        bad "$M_D_SCAN_BAD"
    fi
fi

COM_UPPER=$(echo "$VICTRON_COM" | tr '[:lower:]' '[:upper:]')
echo
if [ "$fail" = 0 ]; then
    printf "$M_D_ALL_OK\n" "$COM_UPPER"
else
    echo "$M_D_SOME_BAD"
fi
exit "$fail"
