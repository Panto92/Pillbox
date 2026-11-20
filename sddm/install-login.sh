#!/usr/bin/env bash
# Pillbox login screen (SDDM) – needs root once, because SDDM themes live system-wide.
#   sudo ./sddm/install-login.sh            install and switch to it
#   sudo ./sddm/install-login.sh --remove   remove it; SDDM falls back to your previous theme
#
# It only adds three things, no existing file is changed:
#   /usr/share/sddm/themes/pillbox          the theme
#   /etc/sddm.conf.d/zz-pillbox.conf        selects it (sorts after kde_settings.conf)
#   /var/lib/pillbox-login/theme.conf.user  your choices, owned by you, so the Pillbox
#                                           settings centre can change them without a password
# SPDX-License-Identifier: MIT
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
THEME=/usr/share/sddm/themes/pillbox
CONF=/etc/sddm.conf.d/zz-pillbox.conf
USERDIR=/var/lib/pillbox-login

if [[ $EUID -ne 0 ]]; then echo "Please run as root (sudo or pkexec)." >&2; exit 1; fi

if [[ "${1:-}" == "--remove" ]]; then
    rm -rf "$THEME" "$CONF" "$USERDIR"
    echo ":: Pillbox login screen removed – SDDM uses your previous theme again."
    exit 0
fi

# who asked for it (sudo or pkexec) – they get to change the login screen later
OWNER="${SUDO_USER:-}"
if [[ -z "$OWNER" && -n "${PKEXEC_UID:-}" ]]; then OWNER="$(getent passwd "$PKEXEC_UID" | cut -d: -f1)"; fi

rm -rf "$THEME"
install -d "$THEME/scenes"
install -m 644 "$HERE"/pillbox/{Main.qml,metadata.desktop,theme.conf} "$THEME/"
if [[ -d "$HERE/pillbox/scenes" ]]; then
    install -m 644 "$HERE"/pillbox/scenes/* "$THEME/scenes/"             # assembled copy (~/.local/share/pillbox/login)
else
    W="$(dirname "$HERE")/plasma/wallpapers/org.pillbox.atmosphere/contents/ui"   # source checkout
    install -m 644 "$W"/*Scene.qml "$W"/{palette.js,Stars.qml,Glow.qml,Meteor.qml,Precip.qml} "$THEME/scenes/"
fi

install -d -m 755 "$USERDIR"
[[ -e "$USERDIR/theme.conf.user" ]] || printf '[General]\nscene=auto\n' > "$USERDIR/theme.conf.user"
chmod 644 "$USERDIR/theme.conf.user"
if [[ -n "$OWNER" ]]; then chown "$OWNER" "$USERDIR" "$USERDIR/theme.conf.user"; fi
ln -sf "$USERDIR/theme.conf.user" "$THEME/theme.conf.user"

printf '[Theme]\nCurrent=pillbox\n' > "$CONF"
chmod 644 "$CONF"
echo ":: Pillbox login screen installed. You'll see it the next time you log out or restart."
