#!/usr/bin/env bash
# Pillbox uninstaller – brings back your desktop as it was before Pillbox
# and removes only files Pillbox installed.
# SPDX-License-Identifier: MIT
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/pillbox"
RESTORE=1
for a in "$@"; do
    case "$a" in
        --keep-layout) RESTORE=0 ;;
        -h|--help) echo "Usage: ./uninstall.sh [--keep-layout]"
                   echo "  default        restore panels, theme and colours from before Pillbox"
                   echo "  --keep-layout  keep your current panels, only switch the theme back to Breeze Dark"
                   exit 0 ;;
        *) echo "Unknown option: $a" >&2; exit 1 ;;
    esac
done
say() { printf '\033[38;2;127;151;166m::\033[0m %s\n' "$*"; }

ORIG="$STATE/original-settings.tar.gz"
[[ -e "$ORIG" ]] || ORIG="$(ls -1 "$STATE"/backups/settings-*.tar.gz 2>/dev/null | head -1 || true)"

if (( RESTORE )) && [[ -n "$ORIG" && -e "$ORIG" ]]; then
    say "Restoring your desktop from $(basename "$ORIG") …"
    # plasmashell writes its config on exit, so stop it before restoring
    if systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
        systemctl --user stop plasma-plasmashell
        tar -xzf "$ORIG" -C "$CONF"
        systemctl --user start plasma-plasmashell
    else
        kquitapp6 plasmashell >/dev/null 2>&1 || true
        tar -xzf "$ORIG" -C "$CONF"
        (kstart plasmashell >/dev/null 2>&1 &)
    fi
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    say "Panels, theme and colours are back to how they were before Pillbox"
elif [[ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null)" == "org.pillbox.desktop" ]]; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
    say "Switched global theme back to Breeze Dark (panels kept)"
fi

kpackagetool6 -t Plasma/LookAndFeel -r org.pillbox.desktop >/dev/null 2>&1 && say "Removed global theme" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.orb     >/dev/null 2>&1 && say "Removed the Orb" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.stats   >/dev/null 2>&1 && say "Removed widget: Pillbox Stats" || true
rm -rf "$DATA/plasma/desktoptheme/Pillbox"
rm -f  "$DATA/color-schemes/Pillbox.colors"
rm -f  "$DATA/konsole/Pillbox.colorscheme" "$DATA/konsole/Pillbox.profile"
rm -f  "$DATA"/locale/*/LC_MESSAGES/plasma_applet_org.pillbox.*.mo
say "Removed Plasma style, colour scheme, Konsole profile and translations"

say "Your settings backups are kept in $STATE/ (delete that folder if you don't need them)"
