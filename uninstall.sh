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

# The island switched Plasma's own notification popups off for the apps it showed.
# Give them back first, while the list is still in the panel config.
python3 -I - "$CONF" <<'PY' || true
import re, subprocess, sys, os
conf = sys.argv[1]
src = os.path.join(conf, "plasma-org.kde.plasma.desktop-appletsrc")
apps, services = set(), set()
if os.path.exists(src):
    for line in open(src, encoding="utf-8", errors="replace"):
        m = re.match(r"(suppressedApps|suppressedServices)=(.*)", line.strip())
        if m:
            (apps if m.group(1) == "suppressedApps" else services).update(x for x in m.group(2).split(",") if x)
for group, names in (("Applications", apps), ("Services", services)):
    for n in names:
        subprocess.run(["kwriteconfig6", "--file", "plasmanotifyrc", "--group", group, "--group", n, "--key", "ShowPopups", "--delete"], check=False)
if apps or services:
    print(":: Gave Plasma's notification popups back to %d apps" % (len(apps) + len(services)))
PY

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
else
    # keep the panels, but give every desktop that uses the living wallpaper Plasma's image back
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "desktops().forEach(function(d){ if (d.wallpaperPlugin === 'org.pillbox.atmosphere') d.wallpaperPlugin = 'org.kde.image'; });" >/dev/null 2>&1 || true
fi
if (( ! RESTORE )) && [[ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null)" == "org.pillbox.desktop" ]]; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop
    say "Switched global theme back to Breeze Dark (panels kept)"
fi

"$(dirname "$0")/kwin/browser-rule.sh" remove && say "Removed the browser window rule" || true
kpackagetool6 -t Plasma/LookAndFeel -r org.pillbox.desktop >/dev/null 2>&1 && say "Removed global theme" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.orb     >/dev/null 2>&1 && say "Removed the Orb" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.island  >/dev/null 2>&1 && say "Removed the island clock" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.status  >/dev/null 2>&1 && say "Removed the status pill" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.search  >/dev/null 2>&1 && say "Removed the search" || true
kwriteconfig6 --file krunnerrc --group General --key FreeFloating --delete 2>/dev/null || true
rm -f "$DATA/color-schemes/PillboxTinted.colors"
rm -f "$HOME/.local/bin/pillbox" "$DATA/applications/org.pillbox.os.desktop" "$DATA"/icons/hicolor/scalable/apps/pillbox-{os,orb,line,line-symbolic}.svg "$STATE/mode"
kpackagetool6 -t Plasma/Wallpaper   -r org.pillbox.atmosphere >/dev/null 2>&1 && say "Removed the living wallpaper" || true
kpackagetool6 -t Plasma/Applet      -r org.pillbox.stats   >/dev/null 2>&1 && say "Removed widget: Pillbox Stats" || true
if [[ -e /usr/share/sddm/themes/pillbox ]]; then
    say "The Pillbox login screen is still installed. Remove it with:"
    say "    sudo $STATE/login/install-login.sh --remove"
fi
case "$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)" in
    Pillbox|Pillbox-Duo|Pillbox-Lucide) /usr/lib/*/libexec/plasma-changeicons breeze-dark >/dev/null 2>&1 || kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark ;;
esac
rm -rf "$DATA/icons/Pillbox" "$DATA/icons/Pillbox-Duo" "$DATA/icons/Pillbox-Lucide"
if [[ "$(kreadconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin 2>/dev/null)" == "org.pillbox.atmosphere" ]]; then
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin --delete    # back to Plasma's image
fi
rm -rf "$DATA/plasma/desktoptheme/Pillbox"
rm -f  "$DATA/color-schemes/Pillbox.colors"
rm -f  "$DATA/konsole/Pillbox.colorscheme" "$DATA/konsole/Pillbox.profile"
rm -f  "$DATA"/locale/*/LC_MESSAGES/plasma_applet_org.pillbox.*.mo "$DATA"/locale/*/LC_MESSAGES/plasma_wallpaper_org.pillbox.*.mo
say "Removed Plasma style, colour scheme, Konsole profile and translations"

say "Your settings backups are kept in $STATE/ (delete that folder if you don't need them)"
