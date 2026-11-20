#!/usr/bin/env bash
# Pillbox uninstaller – removes only files Pillbox installed.
# SPDX-License-Identifier: MIT
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
say() { printf '\033[38;2;127;151;166m::\033[0m %s\n' "$*"; }

# Leave the desktop in a working state before removing anything
if [[ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null)" == "org.pillbox.desktop" ]]; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
    say "Switched global theme back to Breeze Dark (panels kept)"
fi

kpackagetool6 -t Plasma/LookAndFeel -r org.pillbox.desktop >/dev/null 2>&1 && say "Removed global theme" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.stats   >/dev/null 2>&1 && say "Removed widget: Pillbox Stats" || true
rm -rf "$DATA/plasma/desktoptheme/Pillbox" && say "Removed Plasma style"
rm -f  "$DATA/color-schemes/Pillbox.colors" && say "Removed color scheme"
rm -f  "$DATA/konsole/Pillbox.colorscheme" "$DATA/konsole/Pillbox.profile" && say "Removed Konsole profile"

say "Settings backups were kept in $DATA/pillbox/backups/"
say "To restore your old panels:  tar -xzf <backup> -C $CONF  and log out/in."
