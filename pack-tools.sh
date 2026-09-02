#!/usr/bin/env bash
# Packs the already installed VE Configure tools from the Wine prefix into
# installers/ve-configure-tools.tar.gz, so the bundle can be carried to a
# machine without internet access. install.sh unpacks it when no setup program
# is present.
#
# The archive is NOT part of this repository: it contains Victron's software,
# which is theirs to distribute, so .gitignore keeps it out. Download it from
# https://www.victronenergy.com/support-and-downloads/software instead.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/i18n.sh
. "$HERE/lib/i18n.sh"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/victron-wine/config"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

SRC="$WINEPREFIX/drive_c/Program Files (x86)"
if [ ! -d "$SRC/VE Configure tools" ]; then
    printf "$M_P_MISSING\n" "$SRC/VE Configure tools" >&2
    exit 1
fi

OUT="$HERE/installers/ve-configure-tools.tar.gz"
mkdir -p "$HERE/installers"

# Pack reproducibly: fixed order, no owners, no timestamps -- neither in the
# tar nor in the gzip header (gzip -n). Otherwise every run produces a
# byte-different file for identical content.
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 1970-01-01' \
    -cf - -C "$SRC" "VE Configure tools" | gzip -n -9 > "$OUT"

printf "$M_P_WROTE\n" "$OUT" "$(du -h "$OUT" | cut -f1)"
echo "$M_P_CONTAINS"
tar -tzf "$OUT" | sed 's/^/  /'
echo
echo "$M_P_WARN"
echo "$M_P_WARN2"
