#!/usr/bin/env bash
# Pillbox installer – installs into your home directory only (no sudo).
# SPDX-License-Identifier: MIT
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/pillbox"
STAMP="$(date +%Y%m%d-%H%M%S)"

APPLY=0; LAYOUT=0; FASTFETCH=0
usage() {
    cat <<EOF
Usage: ./install.sh [options]

Without options Pillbox is only installed – your current desktop is not changed.

  --apply       apply the Pillbox global theme (colors, Plasma style, icons, cursor)
  --layout      also replace your panels with the Pillbox layout (implies --apply)
  --fastfetch   install the fastfetch config (an existing one is backed up first)
  -h, --help    show this help

Before --apply/--layout/--fastfetch change anything, your current settings are
backed up to $STATE/backups/.
EOF
}
for a in "$@"; do
    case "$a" in
        --apply) APPLY=1 ;;
        --layout) APPLY=1; LAYOUT=1 ;;
        --fastfetch) FASTFETCH=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $a" >&2; usage; exit 1 ;;
    esac
done

say() { printf '\033[38;2;127;151;166m::\033[0m %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1 (is this KDE Plasma 6?)" >&2; exit 1; }; }
need kpackagetool6
need plasma-apply-lookandfeel

mkdir -p "$STATE/backups"

backup() {
    local out="$STATE/backups/settings-$STAMP.tar.gz" files=()
    for f in kdeglobals kwinrc plasmarc kcminputrc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc plasmanotifyrc kscreenlockerrc konsolerc fastfetch/config.jsonc; do
        [[ -e "$CONF/$f" ]] && files+=("$f")
    done
    tar -czf "$out" -C "$CONF" "${files[@]}"
    say "Backup of current settings: $out"
    # the very first backup is the state before Pillbox: uninstall.sh restores it.
    # (installs from before this existed: take the oldest backup, not the current one)
    if [[ ! -e "$STATE/original-settings.tar.gz" ]]; then
        cp "$(ls -1 "$STATE"/backups/settings-*.tar.gz | head -1)" "$STATE/original-settings.tar.gz"
        say "Saved your pre-Pillbox desktop – ./uninstall.sh brings it back"
    fi
}

install_pkg() {   # type, source dir
    local type="$1" dir="$2" id
    id="$(basename "$dir")"
    # note: "kpackagetool6 -s" falls back to Breeze for unknown ids, so it can't
    # be used to detect an installed package – just try upgrade, then install
    kpackagetool6 -t "$type" -u "$dir" >/dev/null 2>&1 \
        || kpackagetool6 -t "$type" -i "$dir" >/dev/null
    say "Installed $type: $id"
}

# 1. Color scheme
mkdir -p "$DATA/color-schemes"
cp "$SRC/color-schemes/Pillbox.colors" "$DATA/color-schemes/"
say "Installed color scheme: Pillbox"

# 2. Plasma style (colors are shared with the color scheme)
mkdir -p "$DATA/plasma/desktoptheme"
rm -rf "$DATA/plasma/desktoptheme/Pillbox"
cp -r "$SRC/plasma/desktoptheme/Pillbox" "$DATA/plasma/desktoptheme/"
cp "$SRC/color-schemes/Pillbox.colors" "$DATA/plasma/desktoptheme/Pillbox/colors"
say "Installed Plasma style: Pillbox"

# 3. Widgets and global theme
install_pkg Plasma/Applet      "$SRC/plasma/plasmoids/org.pillbox.stats"
install_pkg Plasma/Applet      "$SRC/plasma/plasmoids/org.pillbox.orb"
install_pkg Plasma/Applet      "$SRC/plasma/plasmoids/org.pillbox.island"
install_pkg Plasma/Wallpaper   "$SRC/plasma/wallpapers/org.pillbox.atmosphere"
# translations (also shipped inside the package; this copy is what KDE's i18n looks up first)
for mo in "$SRC"/plasma/{plasmoids,wallpapers}/*/contents/locale/*/LC_MESSAGES/*.mo; do
    [[ -e "$mo" ]] || continue
    lang="$(basename "$(dirname "$(dirname "$mo")")")"
    mkdir -p "$DATA/locale/$lang/LC_MESSAGES"
    cp "$mo" "$DATA/locale/$lang/LC_MESSAGES/"
done
install_pkg Plasma/LookAndFeel "$SRC/plasma/look-and-feel/org.pillbox.desktop"

# Pillbox icon themes (line and duotone); chosen in the settings centre
mkdir -p "$DATA/icons"
rm -rf "$DATA/icons/Pillbox" "$DATA/icons/Pillbox-Duo"
cp -r "$SRC/icons/Pillbox" "$SRC/icons/Pillbox-Duo" "$DATA/icons/"

# login screen files, ready for the settings centre's "Set up" button (that step needs root)
LOGIN="$STATE/login"
rm -rf "$LOGIN"; mkdir -p "$LOGIN/pillbox/scenes"
cp "$SRC/sddm/install-login.sh" "$LOGIN/"
cp "$SRC"/sddm/pillbox/{Main.qml,metadata.desktop,theme.conf} "$LOGIN/pillbox/"
W="$SRC/plasma/wallpapers/org.pillbox.atmosphere/contents/ui"
cp "$W"/*Scene.qml "$W"/{palette.js,Stars.qml,Glow.qml,Meteor.qml,Precip.qml} "$LOGIN/pillbox/scenes/"

# 4. Konsole (own file names, never overwrites your profiles)
mkdir -p "$DATA/konsole"
cp "$SRC/konsole/Pillbox.colorscheme" "$SRC/konsole/Pillbox.profile" "$DATA/konsole/"
say "Installed Konsole profile: Pillbox (select it in Konsole → Settings → Manage Profiles)"

# 5. Optional changes to the running desktop
if (( APPLY || FASTFETCH )); then backup; fi

if (( FASTFETCH )); then
    mkdir -p "$CONF/fastfetch"
    cp "$SRC/fastfetch/config.jsonc" "$CONF/fastfetch/config.jsonc"
    say "Installed fastfetch config"
fi

if (( APPLY )); then
    "$SRC/kwin/browser-rule.sh" add
    say "Browsers now come to the front when they receive a link"
fi

if (( LAYOUT )); then
    plasma-apply-lookandfeel -a org.pillbox.desktop --resetLayout
    # Plasma ignores panel alignment set inside a look-and-feel layout script, and
    # live panel views don't move when it is changed later. So: store the
    # alignment via the scripting API, then restart plasmashell so the views are
    # rebuilt from the stored config.
    QDBUS="$(command -v qdbus6 || command -v qdbus || true)"
    [[ -n "$QDBUS" ]] || { echo "qdbus6 not found – pills may overlap" >&2; }
    for _ in $(seq 1 15); do
        "$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
        sleep 1
    done
    sleep 2
    "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        panels().forEach(function (p) {
            if (p.location != "top") return;
            var t = p.widgets().map(function (w) { return w.type; }).join();
            p.alignment = t.indexOf("org.pillbox.stats") >= 0 ? "left"
                        : t.indexOf("org.kde.plasma.systemtray") >= 0 ? "right" : "center";
        });' >/dev/null
    # the lock screen gets the same living wallpaper
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.pillbox.atmosphere
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.pillbox.atmosphere --group General --key Scene aurora
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.pillbox.atmosphere --group General --key PauseWhenCovered false
    say "Restarting Plasma to place the pills (panels disappear for a few seconds)…"
    sleep 1
    if systemctl --user is-active --quiet plasma-plasmashell 2>/dev/null; then
        systemctl --user restart plasma-plasmashell
    else
        kquitapp6 plasmashell >/dev/null 2>&1 || true
        (kstart plasmashell >/dev/null 2>&1 &)
    fi
    say "Applied Pillbox theme and layout"
elif (( APPLY )); then
    plasma-apply-lookandfeel -a org.pillbox.desktop
    say "Applied Pillbox theme (your panels were kept)"
fi

say "Done. Remove everything again with ./uninstall.sh"
