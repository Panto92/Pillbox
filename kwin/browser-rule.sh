#!/usr/bin/env bash
# Pillbox: let web browsers come to the front when they receive a link
# (Wayland's focus-stealing prevention otherwise keeps a minimised browser hidden).
# Works for every common browser, packaged natively, as snap or flatpak.
# Usage: browser-rule.sh add | remove        SPDX-License-Identifier: MIT
set -euo pipefail
ID="pillbox-browser-front"
REGEX='^.*(firefox|zen|librewolf|floorp|waterfox|chrom|brave|vivaldi|opera|microsoft-edge|epiphany|falkon).*$'
F=kwinrulesrc
rules="$(kreadconfig6 --file $F --group General --key rules)"

case "${1:-}" in
  add)
    kwriteconfig6 --file $F --group "$ID" --key Description "Pillbox: browsers come to the front for new links"
    kwriteconfig6 --file $F --group "$ID" --key wmclass "$REGEX"
    kwriteconfig6 --file $F --group "$ID" --key wmclassmatch 3        # regular expression
    kwriteconfig6 --file $F --group "$ID" --key wmclasscomplete false
    kwriteconfig6 --file $F --group "$ID" --key types 1               # normal windows only
    kwriteconfig6 --file $F --group "$ID" --key fsplevel 0            # focus stealing prevention: none
    kwriteconfig6 --file $F --group "$ID" --key fsplevelrule 2        # force
    if [[ ",$rules," != *",$ID,"* ]]; then
        rules="${rules:+$rules,}$ID"
        kwriteconfig6 --file $F --group General --key rules "$rules"
    fi
    ;;
  remove)
    kwriteconfig6 --file $F --group "$ID" --key Description --delete >/dev/null 2>&1 || true
    python3 - "$HOME/.config/$F" "$ID" <<'PY'
import sys, re
path, gid = sys.argv[1], sys.argv[2]
try: s = open(path).read()
except FileNotFoundError: sys.exit(0)
s = re.sub(r'\n?\[%s\]\n(?:[^\[\n][^\n]*\n?)*' % re.escape(gid), '\n', s)   # drop the group
open(path, 'w').write(s.strip() + '\n')
PY
    rules="$(echo ",$rules," | sed "s/,$ID,/,/; s/^,//; s/,$//")"
    kwriteconfig6 --file $F --group General --key rules "$rules"
    ;;
  *) echo "usage: $0 add|remove" >&2; exit 1 ;;
esac
n=$(echo "$rules" | tr ',' '\n' | grep -c . || true)
kwriteconfig6 --file $F --group General --key count "$n"
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
