#!/bin/sh
# App actions from an application's .desktop file ("jump list"): the extra entries apps
# offer, like "New private window" or "New tab".
#   actions.sh list <launcher-url>        -> ACT<TAB>id<TAB>name<TAB>icon per action
#   actions.sh run  <launcher-url> <id>   -> starts that action
# SPDX-License-Identifier: MIT
set -u
url="${2:-}"
file=""
case "$url" in
    applications:*)
        id="${url#applications:}"
        for d in "${XDG_DATA_HOME:-$HOME/.local/share}" $(printf '%s' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' ') /var/lib/flatpak/exports/share "$HOME/.local/share/flatpak/exports/share"; do
            if [ -f "$d/applications/$id" ]; then file="$d/applications/$id"; break; fi
        done ;;
    file://*) file="$(printf '%b' "$(printf '%s' "${url#file://}" | sed 's/%/\\x/g')")" ;;
    /*) file="$url" ;;
esac
[ -n "$file" ] && [ -f "$file" ] || exit 0
lang="${LANG%%.*}"; short="${lang%%_*}"

case "${1:-}" in
list)
    awk -v lang="$lang" -v short="$short" -F= '
        /^\[/ { sec = $0; next }
        sec == "[Desktop Entry]" && $1 == "Actions" { n = split($2, ids, ";") }
        sec ~ /^\[Desktop Action / {
            id = sec; sub(/^\[Desktop Action /, "", id); sub(/\]$/, "", id)
            v = substr($0, index($0, "=") + 1)
            if ($1 == "Name") name[id] = v
            else if ($1 == "Name[" lang "]") lname[id] = v
            else if ($1 == "Name[" short "]" && !(id in lname)) lname[id] = v
            else if ($1 == "Icon") icon[id] = v
        }
        END { for (i = 1; i <= n; i++) { id = ids[i]; if (id == "" || !(id in name)) continue
              printf "ACT\t%s\t%s\t%s\n", id, (id in lname ? lname[id] : name[id]), icon[id] } }' "$file" ;;
run)
    act="$(printf '%s' "${3:-}" | tr -cd 'A-Za-z0-9_.-')"
    [ -n "$act" ] || exit 0
    cmd="$(awk -v want="[Desktop Action $act]" '/^\[/ { sec = $0; next } sec == want && /^Exec=/ { print substr($0, 6); exit }' "$file")"
    [ -n "$cmd" ] || exit 0
    cmd="$(printf '%s' "$cmd" | sed -e 's/%[fFuUdDnNickvm]//g' -e 's/%%/%/g')"
    setsid -f sh -c "$cmd" >/dev/null 2>&1 ;;
esac
