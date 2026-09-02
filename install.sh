#!/usr/bin/env bash
# Sets up the Victron VE Configure tools under Wine on any Linux distribution.
# Nothing distribution-specific is assumed; everything is detected at runtime.
#
# No personal data is stored in this repository: the Linux user name is read
# from `id -un` and the Wine user name from the prefix, both at install time.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/i18n.sh
. "$HERE/lib/i18n.sh"

WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
VICTRON_COM="com1"
VICTRON_DEV="/dev/victron-mk3"
VE_LANG="$VLANG"          # Victron UI language, follows the script language
DO_UDEV=1
DO_TOOLS=1
ASSUME_YES=0

usage() {
    printf '%s\n\n' "$M_USAGE_HEAD"
    printf '  %s\n' "$M_OPT_PREFIX" "$M_OPT_COM" "$M_OPT_LANG" \
                    "$M_OPT_NOUDEV" "$M_OPT_NOTOOLS" "$M_OPT_YES" "$M_OPT_HELP"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix) WINEPREFIX="$2"; shift 2 ;;
        --com)    VICTRON_COM="$2"; shift 2 ;;
        --lang)   VE_LANG="$2"; shift 2 ;;
        --no-udev) DO_UDEV=0; shift ;;
        --no-tools) DO_TOOLS=0; shift ;;
        -y|--yes) ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf "$M_UNKNOWN_OPT\n" "$1" >&2; usage >&2; exit 2 ;;
    esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m    ! %s\033[0m\n' "$*" >&2; }
die()  { printf "\033[31m==> $M_ABORT\033[0m\n" "$*" >&2; exit 1; }

ask() {
    [ "$ASSUME_YES" = 1 ] && return 0
    printf '    %s %s ' "$1" "$M_YESNO"
    read -r a </dev/tty || return 1
    case "$a" in [$M_YES_CHARS]*) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------ distribution --
DISTRO=unknown
[ -r /etc/os-release ] && . /etc/os-release && DISTRO="${ID:-unknown}"
case "$DISTRO" in
    arch|endeavouros|manjaro|cachyos|omarchy|garuda) PKG_HINT='sudo pacman -S --needed wine' ;;
    debian|ubuntu|linuxmint|pop|raspbian|elementary) PKG_HINT='sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install wine wine32:i386' ;;
    fedora|rhel|centos|nobara)                       PKG_HINT='sudo dnf install wine wine-core.i686' ;;
    opensuse*|sles)                                  PKG_HINT='sudo zypper install wine wine-32bit' ;;
    void)                                            PKG_HINT='sudo xbps-install wine wine-32bit' ;;
    *) PKG_HINT='install Wine from your package manager, including its 32-bit part' ;;
esac

printf "\n\033[1m==> $M_SYSTEM\033[0m\n" "${PRETTY_NAME:-$DISTRO}"

command -v wine >/dev/null 2>&1 || die "$(printf "$M_NO_WINE" "$PKG_HINT")"
info "$(printf "$M_WINE_IS" "$(wine --version 2>/dev/null)")"

if [ -d /run/systemd/system ]; then
    HAVE_SYSTEMD=1
else
    HAVE_SYSTEMD=0
    warn "$M_NO_SYSTEMD1"
    warn "$M_NO_SYSTEMD2"
fi

# ------------------------------------------------------------------- udev ---
if [ "$DO_UDEV" = 1 ]; then
    say "$M_H_UDEV"

    # Arch and Fedora call the group owning serial devices "uucp",
    # Debian, Ubuntu and openSUSE call it "dialout". Use whichever exists.
    TTYGROUP=""
    for g in uucp dialout; do
        if getent group "$g" >/dev/null 2>&1; then TTYGROUP="$g"; break; fi
    done
    [ -n "$TTYGROUP" ] || die "$M_NO_TTYGROUP"
    info "$(printf "$M_TTYGROUP" "$TTYGROUP")"

    RULE=/etc/udev/rules.d/70-victron-mk3.rules
    TMPRULE=$(mktemp)
    sed "s/@TTYGROUP@/$TTYGROUP/" "$HERE/files/udev/70-victron-mk3.rules.in" > "$TMPRULE"

    if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo"; fi
    if [ -n "$SUDO" ] && ! command -v sudo >/dev/null 2>&1; then
        warn "$M_NO_SUDO"
        echo "      install -m 0644 $TMPRULE $RULE"
        echo "      udevadm control --reload && udevadm trigger --subsystem-match=tty"
        echo "      usermod -aG $TTYGROUP $(id -un)"
    else
        info "$(printf "$M_WRITE_RULE" "$RULE")"
        $SUDO install -m 0644 "$TMPRULE" "$RULE"
        $SUDO udevadm control --reload
        $SUDO udevadm trigger --subsystem-match=tty || true
        if id -nG "$(id -un)" | tr ' ' '\n' | grep -qx "$TTYGROUP"; then
            info "$(printf "$M_IN_GROUP" "$TTYGROUP")"
        else
            $SUDO usermod -aG "$TTYGROUP" "$(id -un)"
            warn "$(printf "$M_GROUP_ADDED" "$TTYGROUP")"
            warn "$M_GROUP_UACCESS"
        fi
    fi
    rm -f "$TMPRULE"
else
    say "$M_UDEV_SKIP"
fi

# ------------------------------------------------------------ COM mapping ---
say "$(printf "$M_H_COM" "$VICTRON_COM" "$VICTRON_DEV")"

if [ "$VICTRON_COM" = com1 ] && [ -c /dev/ttyS0 ]; then
    # Wine normally maps com1 onto /dev/ttyS0. If that is a real port here,
    # pointing com1 at the MK3 would hide it.
    if [ "$(cat /sys/class/tty/ttyS0/type 2>/dev/null || echo 0)" != 0 ]; then
        warn "$M_TTYS0_REAL1"
        warn "$M_TTYS0_REAL2"
        ask "$M_TTYS0_ASK" || die "$M_TTYS0_ABORT"
    fi
fi

CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/victron-wine"
mkdir -p "$HOME/.local/bin" "$CONFDIR"
install -m 0755 "$HERE/files/bin/victron-com1-fix" "$HOME/.local/bin/victron-com1-fix"
cat > "$CONFDIR/config" <<EOF
# Written by install.sh, read by victron-com1-fix.
WINEPREFIX="$WINEPREFIX"
VICTRON_COM="$VICTRON_COM"
VICTRON_DEV="$VICTRON_DEV"
EOF
info "$M_SCRIPT_AT"
info "$(printf "$M_CONFIG_AT" "$CONFDIR/config")"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "$M_PATH_HINT" ;;
esac

# ----------------------------------------------------------------- prefix ---
say "$(printf "$M_H_PREFIX" "$WINEPREFIX")"
if [ ! -d "$WINEPREFIX" ]; then
    info "$M_PREFIX_NEW"
    WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all wineboot -u >/dev/null 2>&1 || true
fi
[ -d "$WINEPREFIX/dosdevices" ] || die "$(printf "$M_PREFIX_FAIL" "$WINEPREFIX")"

# Wine names the profile directory after the Linux user; fall back to whatever
# single user directory the prefix happens to contain.
WINEUSER=$(id -un)
[ -d "$WINEPREFIX/drive_c/users/$WINEUSER" ] || {
    cand=$(ls "$WINEPREFIX/drive_c/users" 2>/dev/null | grep -vx -e Public -e crossover | head -1 || true)
    [ -n "$cand" ] && WINEUSER="$cand"
}
info "$(printf "$M_WINEUSER" "$WINEUSER")"

# ---------------------------------------------------------------- systemd ---
if [ "$HAVE_SYSTEMD" = 1 ]; then
    say "$M_H_SYSTEMD"
    UNITDIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$UNITDIR"
    install -m 0644 "$HERE/files/systemd/victron-com1.service" "$UNITDIR/victron-com1.service"
    sed "s|@WINEPREFIX@|$WINEPREFIX|" "$HERE/files/systemd/victron-com1.path.in" > "$UNITDIR/victron-com1.path"
    systemctl --user daemon-reload
    systemctl --user enable --now victron-com1.path
    systemctl --user start victron-com1.service
    info "$M_UNITS_OK"
else
    "$HOME/.local/bin/victron-com1-fix"
    info "$M_MAPPED_ONCE"
fi

# -------------------------------------------------------- Victron software --
if [ "$DO_TOOLS" = 1 ]; then
    say "$M_H_TOOLS"
    TOOLDIR="$WINEPREFIX/drive_c/Program Files (x86)/VE Configure tools"
    SETUP=$(ls "$HERE"/installers/*.exe 2>/dev/null | head -1 || true)
    TARBALL="$HERE/installers/ve-configure-tools.tar.gz"

    if [ -f "$TOOLDIR/VEConfig.exe" ]; then
        info "$(printf "$M_TOOLS_THERE" "$TOOLDIR")"
    elif [ -n "$SETUP" ]; then
        info "$(printf "$M_TOOLS_SETUP" "$(basename "$SETUP")")"
        WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all wine "$SETUP" || warn "$M_TOOLS_SETUP_ERR"
    elif [ -f "$TARBALL" ]; then
        info "$(printf "$M_TOOLS_TAR" "$TOOLDIR")"
        mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)"
        tar -xzf "$TARBALL" -C "$WINEPREFIX/drive_c/Program Files (x86)"
    else
        warn "$M_TOOLS_NONE1"
        warn "$M_TOOLS_NONE2"
        warn "$M_TOOLS_NONE3"
        warn "$M_TOOLS_NONE4"
    fi
fi

# --------------------------------------------------------------- registry ---
say "$M_H_REG"
mkdir -p "$WINEPREFIX/drive_c/users/$WINEUSER/Documents"
touch "$WINEPREFIX/drive_c/users/$WINEUSER/Documents/Multinames.dat"

TMPREG=$(mktemp --suffix=.reg)
sed -e "s/@WINEUSER@/$WINEUSER/" -e "s/@LANG@/$VE_LANG/" \
    "$HERE/files/registry/victron-settings.reg.in" > "$TMPREG"
if WINEPREFIX="$WINEPREFIX" WINEDEBUG=-all wine regedit "$TMPREG" >/dev/null 2>&1; then
    info "$(printf "$M_REG_OK" "$VE_LANG")"
else
    warn "$M_REG_FAIL"
fi
rm -f "$TMPREG"

# ------------------------------------------------------------------- done ---
say "$M_H_CHECK"
"$HERE/doctor.sh" || true

COM_UPPER=$(echo "$VICTRON_COM" | tr '[:lower:]' '[:upper:]')
echo
echo "$M_DONE_HEAD"
printf "  $M_DONE_1\n" "$COM_UPPER"
printf '  %s\n' "$M_DONE_2" "$M_DONE_3" "$M_DONE_3B" "$M_DONE_4" "$M_DONE_4B"
