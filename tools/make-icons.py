#!/usr/bin/env python3
"""Generate the Pillbox icon themes (line and duotone) from one table of shapes.

All icons share a 24-unit grid, a 1.7 stroke and round ends. Plasma recolours
them: ColorScheme-Text follows the text colour, ColorScheme-Highlight the accent
colour – the duotone theme puts an accent-coloured surface under each icon.
Only icons listed here are replaced; everything else comes from Breeze.

Usage: make-icons.py OUTPUT_DIR      SPDX-License-Identifier: MIT"""
import math, os, sys

def arc(cx, cy, r, a0, a1):
    """SVG arc from angle a0 to a1 (degrees, 0 = right, clockwise like screen coords)."""
    p = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x0, y0), (x1, y1) = p(a0), p(a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{x0:.2f} {y0:.2f}A{r} {r} 0 {large} 1 {x1:.2f} {y1:.2f}"

def sector(cx, cy, r, a0, a1):
    return arc(cx, cy, r, a0, a1).replace("M", f"M{cx} {cy}L", 1) + "Z"

DIM = ' opacity=".3"'
I = {}   # name -> (line elements, duo surfaces)

# ---- wifi: three arcs and a dot; brighter arcs = stronger signal
def wifi(level, extra=""):
    arcs = [arc(12, 19, r, 225, 315) for r in (4.2, 8.2, 12.2)]
    lit = {0: 0, 20: 1, 40: 2, 60: 2, 80: 3, 100: 4}[level]
    els = [f'<circle cx="12" cy="19" r="1.1" fill="currentColor" stroke="none"{"" if lit >= 1 else DIM}/>']
    for i, a in enumerate(arcs):
        els.append(f'<path d="{a}"{"" if lit >= i + 2 else DIM}/>')
    radius = {0: 0, 1: 2.5, 2: 4.2, 3: 8.2, 4: 12.2}[lit]
    duo = [f'<path d="{sector(12, 19, radius, 225, 315)}"/>'] if radius else []
    return els + ([extra] if extra else []), duo
for lv in (0, 20, 40, 60, 80, 100):
    I[f"network-wireless-{lv}"] = wifi(lv)
    I[f"network-wireless-signal-{ {0:'none',20:'weak',40:'ok',60:'good',80:'good',100:'excellent'}[lv] }"] = wifi(lv)
I["network-wireless-connected"] = wifi(100)
I["network-wireless-disconnected"] = wifi(0, '<path d="M16.5 15.5l4 4M20.5 15.5l-4 4"/>')
I["network-wireless-acquiring"] = wifi(40, '<path d="M18 16.5h.01M20.5 16.5h.01" stroke-width="2.2"/>')
I["network-wireless-offline"] = I["network-wireless-disconnected"]

# ---- wired / network state
I["network-wired"] = ([ '<rect x="4" y="15.5" width="6" height="5" rx="1.5"/>', '<rect x="14" y="15.5" width="6" height="5" rx="1.5"/>',
                        '<rect x="9" y="3.5" width="6" height="5" rx="1.5"/>', '<path d="M12 8.5v3.5M7 15.5v-3.5h10v3.5"/>' ],
                      [ '<rect x="9" y="3.5" width="6" height="5" rx="1.5"/>' ])
I["network-wired-activated"] = I["network-wired"]
I["network-wired-disconnected"] = (I["network-wired"][0] + ['<path d="M3 3l18 18"/>'], [])
I["network-offline"] = ([ '<circle cx="12" cy="12" r="8.5"/>', '<path d="M6 6l12 12"/>' ], [])
I["network-limited"] = (wifi(60)[0] + ['<path d="M19.5 3.5v4M19.5 10.5h.01" stroke-width="2"/>'], wifi(60)[1])
plane = '<path d="M12 3.5c.8 0 1.4.7 1.4 1.6V9.5l6.6 4v1.8l-6.6-2v4.4l2 1.6v1.4L12 19.8l-3.4.9v-1.4l2-1.6v-4.4l-6.6 2v-1.8l6.6-4V5.1c0-.9.6-1.6 1.4-1.6Z"/>'
I["network-flightmode-on"] = ([plane], [plane.replace('<path', '<path opacity="1"')])
I["network-flightmode-off"] = ([plane.replace('/>', DIM + '/>'), '<path d="M4 4l16 16"/>'], [])

# ---- sound
spk = '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4Z"/>'
spk_fill = '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4Z"/>'
waves = ['<path d="M15.5 9.5a3.5 3.5 0 0 1 0 5"/>', '<path d="M17.8 7.2a6.8 6.8 0 0 1 0 9.6"/>', '<path d="M20.1 4.9a10 10 0 0 1 0 14.2"/>']
for name, n in (("high", 3), ("medium", 2), ("low", 1)):
    I[f"audio-volume-{name}"] = ([spk] + [w if i < n else w.replace('/>', DIM + '/>') for i, w in enumerate(waves)], [spk_fill])
I["audio-volume-muted"] = ([spk, '<path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>'], [])
I["audio-volume-zero"] = ([spk] + [w.replace('/>', DIM + '/>') for w in waves], [spk_fill])

# ---- microphone
mic = ['<rect x="9" y="3.5" width="6" height="11" rx="3"/>', '<path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v2.5M9 20.5h6"/>']
for name in ("high", "medium", "low"):
    I[f"microphone-sensitivity-{name}"] = (mic, ['<rect x="9" y="3.5" width="6" height="11" rx="3"/>'])
I["microphone-sensitivity-muted"] = (mic + ['<path d="M4 4l16 16"/>'], [])

# ---- bluetooth
rune = '<path d="M7 7.5L17 16.5 12 21V3l5 4.5L7 16.5"/>'
I["network-bluetooth"] = ([rune.replace('/>', ' opacity=".55"/>')], [])
I["network-bluetooth-activated"] = ([rune, '<path d="M3.5 12h.01M20.5 12h.01" stroke-width="2.4"/>'], ['<path d="M12 3v18l5-4.5L12 12l5-4.5Z"/>'])
I["bluetooth-active"] = I["network-bluetooth-activated"]
I["bluetooth-disabled"] = ([rune.replace('/>', ' opacity=".55"/>'), '<path d="M4 4l16 16"/>'], [])

# ---- notifications
bell = '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.5h-15Z"/>'
clapper = '<path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>'
bell_fill = '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5Z"/>'
I["notification-inactive"] = ([bell, clapper], [bell_fill])
I["notifications"] = I["notification-inactive"]
I["notification-active"] = ([bell, clapper, '<circle class="ColorScheme-Highlight" cx="18.5" cy="5.5" r="3" fill="currentColor" stroke="none"/>'], [bell_fill])
I["notification-new"] = I["notification-active"]
I["notification-disabled"] = ([bell, clapper, '<path d="M4 4l16 16"/>'], [])

# ---- session
I["system-shutdown"] = (['<path d="M12 3.5v8"/>', '<path d="M7 6.8a7.5 7.5 0 1 0 10 0"/>'], ['<circle cx="12" cy="13.3" r="6"/>'])
I["system-reboot"] = (['<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/>', '<path d="M19.5 3.5v4h-4"/>'], ['<circle cx="12" cy="12" r="5.5"/>'])
I["system-lock-screen"] = (['<rect x="5" y="10.5" width="14" height="10" rx="3"/>', '<path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>', '<path d="M12 14.5v2"/>'], ['<rect x="5" y="10.5" width="14" height="10" rx="3"/>'])
I["system-log-out"] = (['<path d="M13 4.5H7a2.5 2.5 0 0 0-2.5 2.5v10A2.5 2.5 0 0 0 7 19.5h6"/>', '<path d="M10.5 12h10M17 8.5l3.5 3.5-3.5 3.5"/>'], ['<path d="M7 4.5h6v15H7a2.5 2.5 0 0 1-2.5-2.5V7A2.5 2.5 0 0 1 7 4.5Z"/>'])
moon = '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10Z"/>'
I["system-suspend"] = ([moon], [moon])
I["system-hibernate"] = ([moon, '<path d="M15.5 4h3.5l-3.5 4h3.5"/>'], [moon])
I["system-switch-user"] = (['<circle cx="9" cy="8" r="3.2"/>', '<path d="M3.5 19.5a5.5 5.5 0 0 1 11 0"/>', '<circle cx="17" cy="9.5" r="2.5"/>', '<path d="M16.5 14.5a4.5 4.5 0 0 1 4.5 4.5"/>'], ['<circle cx="9" cy="8" r="3.2"/>'])

# ---- media
play = '<path d="M8 5.8v12.4a1 1 0 0 0 1.5.9l10-6.2a1 1 0 0 0 0-1.8l-10-6.2A1 1 0 0 0 8 5.8Z"/>'
I["media-playback-start"] = ([play], [play])
I["media-playback-pause"] = (['<rect x="6.5" y="5" width="4" height="14" rx="1.5"/>', '<rect x="13.5" y="5" width="4" height="14" rx="1.5"/>'], ['<rect x="6.5" y="5" width="4" height="14" rx="1.5"/>', '<rect x="13.5" y="5" width="4" height="14" rx="1.5"/>'])
I["media-playback-playing"] = (['<path d="M9 17.5V5.5l10-2v12"/>', '<circle cx="6.5" cy="17.5" r="2.5"/>', '<circle cx="16.5" cy="15.5" r="2.5"/>'], ['<circle cx="6.5" cy="17.5" r="2.5"/>', '<circle cx="16.5" cy="15.5" r="2.5"/>'])
I["media-playback-stopped"] = (['<rect x="6" y="6" width="12" height="12" rx="2.5"/>'], ['<rect x="6" y="6" width="12" height="12" rx="2.5"/>'])

# ---- tray helpers
I["klipper"] = (['<rect x="5" y="5" width="14" height="16" rx="3"/>', '<path d="M9 5V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1"/>', '<path d="M8.5 11h7M8.5 15h4.5"/>'], ['<rect x="5" y="5" width="14" height="16" rx="3"/>'])
I["kdeconnect-tray"] = (['<rect x="7" y="3" width="10" height="18" rx="2.5"/>', '<path d="M11 17.5h2"/>'], ['<rect x="7" y="3" width="10" height="18" rx="2.5"/>'])
I["input-keyboard"] = (['<rect x="2.5" y="6.5" width="19" height="11" rx="3"/>', '<path d="M6 10h.01M9 10h.01M12 10h.01M15 10h.01M18 10h.01M7.5 14h9"/>'], ['<rect x="2.5" y="6.5" width="19" height="11" rx="3"/>'])
I["drive-removable-media"] = (['<rect x="7" y="9" width="10" height="12" rx="2.5"/>', '<path d="M9 9V4.5h6V9M10.5 6.5h.01M13.5 6.5h.01"/>'], ['<rect x="7" y="9" width="10" height="12" rx="2.5"/>'])
sun = ['<circle cx="12" cy="12" r="4"/>', '<path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>']
I["redshift-status-day"] = (sun, ['<circle cx="12" cy="12" r="4"/>'])
I["redshift-status-on"] = ([moon], [moon])
I["redshift-status-off"] = ([moon.replace('/>', DIM + '/>'), '<path d="M4 4l16 16"/>'], [])
I["view-calendar"] = (['<rect x="3.5" y="5" width="17" height="15.5" rx="3"/>', '<path d="M3.5 10h17M8 3v4M16 3v4"/>', '<path d="M8 14h.01M12 14h.01M16 14h.01M8 17h.01M12 17h.01" stroke-width="2"/>'], ['<path d="M6.5 5h11a3 3 0 0 1 3 3v2h-17V8a3 3 0 0 1 3-3Z"/>'])
grid = ['<rect x="4" y="4" width="7" height="7" rx="2"/>', '<rect x="13" y="4" width="7" height="7" rx="2"/>', '<rect x="4" y="13" width="7" height="7" rx="2"/>', '<rect x="13" y="13" width="7" height="7" rx="3.5"/>']
I["view-app-grid"] = (grid, ['<rect x="4" y="4" width="7" height="7" rx="2"/>'])
I["application-menu"] = (['<path d="M5 7h14M5 12h14M5 17h14"/>'], [])

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#fcfcfc}.ColorScheme-Highlight{color:#3daee9}</style>')

def svg(line, duo, with_duo):
    s = HEAD
    if with_duo and duo:
        s += '<g class="ColorScheme-Highlight" fill="currentColor" stroke="none" opacity=".6">' + "".join(duo) + "</g>"
    s += ('<g class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="1.7" '
          'stroke-linecap="round" stroke-linejoin="round">' + "".join(line) + "</g></svg>\n")
    return s

THEMES = {
    "Pillbox": ("Pillbox", "Calm line icons for the panel and system tray; everything else comes from Breeze.", False),
    "Pillbox-Duo": ("Pillbox Duotone", "Line icons on an accent-coloured surface for the panel and system tray; everything else comes from Breeze.", True),
}

def main(out):
    for folder, (name, comment, duo) in THEMES.items():
        d = os.path.join(out, folder, "symbolic")
        os.makedirs(d, exist_ok=True)
        for icon, (line, surf) in I.items():
            body = svg(line, surf, duo)
            for n in (icon, icon + "-symbolic"):
                with open(os.path.join(d, n + ".svg"), "w") as f:
                    f.write(body)
        with open(os.path.join(out, folder, "index.theme"), "w") as f:
            f.write(f"[Icon Theme]\nName={name}\nComment={comment}\nInherits=breeze-dark,breeze,hicolor\n"
                    "Directories=symbolic\n\n[symbolic]\nSize=24\nMinSize=8\nMaxSize=512\nType=Scalable\nContext=Status\n")
    print(f"{len(I)} icons × 2 names × {len(THEMES)} themes written to {out}")

if __name__ == "__main__":
    main(sys.argv[1])
