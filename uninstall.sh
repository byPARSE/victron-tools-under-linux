#!/usr/bin/env bash
# Removes what install.sh created. The Wine prefix and the Victron software are
# deliberately left alone -- remove those by hand if you want them gone.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/i18n.sh
. "$HERE/lib/i18n.sh"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/victron-wine/config"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

echo "==> $M_U_UNITS"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl --user disable --now victron-com1.path 2>/dev/null
    systemctl --user stop victron-com1.service 2>/dev/null
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/victron-com1.path" \
          "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/victron-com1.service"
    systemctl --user daemon-reload
    echo "    $M_U_REMOVED"
fi

echo "==> $M_U_SCRIPT"
rm -f "$HOME/.local/bin/victron-com1-fix"
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/victron-wine"
echo "    $M_U_REMOVED"

echo "==> $M_U_RULE"
if [ -e /etc/udev/rules.d/70-victron-mk3.rules ]; then
    if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo"; fi
    if $SUDO rm -f /etc/udev/rules.d/70-victron-mk3.rules && $SUDO udevadm control --reload; then
        echo "    $M_U_REMOVED"
    else
        echo "    $M_U_RULE_FAIL"
    fi
else
    echo "    $M_U_RULE_ABSENT"
fi

echo
echo "$M_U_KEPT"
printf "$M_U_KEPT_1\n" "$WINEPREFIX"
echo "$M_U_KEPT_2"
printf "$M_U_KEPT_2B\n" "$(id -un)"
printf "$M_U_KEPT_3\n"
