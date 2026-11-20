#!/usr/bin/env bash
# Pillbox login screen (SDDM) – needs root, because SDDM themes live system-wide.
#   sudo ./sddm/install-login.sh            install and switch to it
#   sudo ./sddm/install-login.sh --remove   remove it; SDDM falls back to your previous theme
# It only adds /usr/share/sddm/themes/pillbox and /etc/sddm.conf.d/zz-pillbox.conf –
# no existing file is changed, so removing those two brings the old login screen back.
# SPDX-License-Identifier: MIT
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$HERE")"
THEME=/usr/share/sddm/themes/pillbox
CONF=/etc/sddm.conf.d/zz-pillbox.conf

if [[ $EUID -ne 0 ]]; then echo "Please run as root (sudo or pkexec)." >&2; exit 1; fi

if [[ "${1:-}" == "--remove" ]]; then
    rm -rf "$THEME" "$CONF"
    echo ":: Pillbox login screen removed – SDDM uses your previous theme again."
    exit 0
fi

rm -rf "$THEME"
install -d "$THEME/scenes"
install -m 644 "$HERE"/pillbox/{Main.qml,metadata.desktop,theme.conf} "$THEME/"
W="$SRC/plasma/wallpapers/org.pillbox.atmosphere/contents/ui"
install -m 644 "$W"/*Scene.qml "$W"/{palette.js,Stars.qml,Glow.qml,Meteor.qml,Precip.qml} "$THEME/scenes/"
# zz- sorts after kde_settings.conf, so this choice wins without touching it
printf '[Theme]\nCurrent=pillbox\n' > "$CONF"
chmod 644 "$CONF"
echo ":: Pillbox login screen installed. You'll see it the next time you log out or restart."
