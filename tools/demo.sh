#!/usr/bin/env bash
# Pillbox demo: plays a ~60 s tour of the desktop for a screen recording – no clicks needed.
# Start your recording, then run:  ./tools/demo.sh
# Your windows are moved aside (Show Desktop) and every setting is restored at the end.
# SPDX-License-Identifier: MIT
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ARRANGE="$HERE/../plasma/plasmoids/org.pillbox.orb/contents/code/arrange.js"
ev() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" >/dev/null; }
orb() {   # orb <group> <key> <value-as-js>
    ev "desktops().forEach(function(d){ d.widgets().forEach(function(w){ if (w.type == 'org.pillbox.orb') { w.currentConfigGroup = ['$1']; w.writeConfig('$2', $3); } }); });"
}
orbget() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
      "desktops().forEach(function(d){ d.widgets().forEach(function(w){ if (w.type == 'org.pillbox.orb') { w.currentConfigGroup = ['$1']; print(w.readConfig('$2')); } }); });"
}
wall() {  # wall <key> <value-as-js>
    ev "desktops().forEach(function(d){ d.currentConfigGroup = ['Wallpaper','org.pillbox.atmosphere','General']; d.writeConfig('$1', $2); });"
}
wallget() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var d = desktops()[0]; d.currentConfigGroup = ['Wallpaper','org.pillbox.atmosphere','General']; print(d.readConfig('$1'));"; }
arrange() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(sed "s/MODE/$1/" "$ARRANGE")" >/dev/null; }
say() { printf '\033[38;2;127;151;166m::\033[0m %s\n' "$*"; }

# ---- remember
F=$(orbget Appearance form); H=$(orbget Appearance dockHide); X=$(orbget General orbX); Y=$(orbget General orbY)
A=$(orbget Appearance arrangement); CM=$(orbget Appearance colorMode); CC=$(orbget Appearance customColor); S=$(wallget Scene); FT=$(wallget FollowTime); FH=$(wallget FixedHour)
restore() {
    say "Restoring your settings …"
    orb Appearance demo "''"
    orb Appearance form "'${F:-orb}'"; orb Appearance dockHide "'${H:-never}'"
    orb General orbX "${X:--1}"; orb General orbY "${Y:--1}"
    orb Appearance colorMode "'${CM:-custom}'"; [[ -n "$CC" ]] && orb Appearance customColor "'$CC'"
    wall Scene "'${S:-aurora}'"; wall FollowTime "${FT:-true}"; wall FixedHour "${FH:-17.5}"
    [[ "${A:-islands}" != "islands" ]] || true
    qdbus6 org.kde.KWin /KWin org.kde.KWin.showDesktop false >/dev/null 2>&1
}
trap restore EXIT

say "Demo starts in 3 s – start your recording now."
sleep 3
qdbus6 org.kde.KWin /KWin org.kde.KWin.showDesktop true >/dev/null 2>&1
wall Scene "'aurora'"; wall FollowTime false; wall FixedHour 23
orb Appearance form "'orb'"; orb General orbX 1560; orb General orbY 760
sleep 3

say "Orb: the ring"
orb Appearance demo "'ring'"; sleep 4.5; orb Appearance demo "''"; sleep 1.5

say "Orb at the edge: the arc"
orb General orbX -1; orb General orbY -1; sleep 2
orb Appearance demo "'ring'"; sleep 4.5; orb Appearance demo "''"; sleep 1.5

say "Colours"
orb Appearance colorMode "'custom'"; orb General orbX 1560; orb General orbY 760; sleep 1.5
orb Appearance demo "'ring'"; sleep 1
for c in '#8fb0c2' '#e0bd6e' '#ff8a4c' '#e88fa6' '#b49cf0' '#7fd3f0' '#7fdcb0'; do orb Appearance customColor "'$c'"; sleep 1.1; done
orb Appearance demo "''"; [[ -n "$CC" ]] && orb Appearance customColor "'$CC'"; sleep 1.5

say "A notification grows out of the clock"
notify-send -a "Konsole" -h string:desktop-entry:org.kde.konsole "Build finished" "pillbox – all tests passed"; sleep 5

say "Docks: Ember, Shelf, Liquid"
orb Appearance dockHide "'never'"
for f in ember shelf liquid; do orb Appearance form "'$f'"; sleep 4; done
orb Appearance form "'orb'"; sleep 2

say "Wallpaper: a day at the lake"
wall Scene "'fogline'"; wall FixedHour 5.5; sleep 2
for h in $(LC_ALL=C seq 5.5 0.25 22.5); do wall FixedHour "$h"; sleep 0.12; done
sleep 2
wall Scene "'aurora'"; wall FixedHour 23; sleep 3

say "Top bar: full bar, capsule, islands"
arrange bar; sleep 3.5; arrange capsule; sleep 3.5; arrange islands; sleep 3

say "Done – stop your recording."
