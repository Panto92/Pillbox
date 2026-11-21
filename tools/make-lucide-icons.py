#!/usr/bin/env python3
"""Build the "Pillbox Lucide" icon theme from Lucide (https://lucide.dev, ISC licence).

Maps the freedesktop / Plasma icon names used by the top bar, the system tray and the
Pillbox panels to Lucide symbols. The Lucide sources this needs are kept in
tools/lucide/ (with Lucide's licence); refresh them from a lucide-static package with
--vendor PATH_TO_PACKAGE.

Plasma recolours the result: strokes use ColorScheme-Text, so the icons follow the
panel's text colour on light and dark themes. Everything not listed comes from Breeze.

Usage: make-lucide-icons.py OUTPUT_DIR [--vendor PATH_TO_lucide-static/package]
SPDX-License-Identifier: MIT"""
import os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "lucide")
STROKE = "1.8"

M = {}
def to(lucide, *names):
    for n in names:
        M[n] = lucide

# sound
to("volume-2", "audio-volume-high", "audio-volume-high-danger")
to("volume-1", "audio-volume-medium")
to("volume", "audio-volume-low")
to("volume-x", "audio-volume-muted")
to("mic", "audio-input-microphone", "microphone-sensitivity-high", "microphone-sensitivity-medium")
to("mic-off", "microphone-sensitivity-muted", "audio-input-microphone-muted")
to("headphones", "audio-headphones", "audio-headset")
to("speaker", "audio-speakers", "audio-card")
# network
for lv in (80, 100): to("wifi", f"network-wireless-{lv}")
for lv in (40, 60): to("wifi-high", f"network-wireless-{lv}")
to("wifi-low", "network-wireless-20")
to("wifi-zero", "network-wireless-0")
to("wifi", "network-wireless", "network-wireless-connected", "network-wireless-signal-excellent", "network-wireless-signal-good",
   "network-wireless-on")
to("wifi-high", "network-wireless-signal-ok")
to("wifi-low", "network-wireless-signal-weak", "network-wireless-acquiring", "network-wireless-signal-low")
to("wifi-zero", "network-wireless-signal-none")
to("wifi-off", "network-wireless-disconnected", "network-wireless-offline", "network-offline", "network-wireless-off")
to("network", "network-wired", "network-wired-activated", "network-connect")
to("unplug", "network-wired-disconnected", "network-disconnect")
to("globe", "network-limited", "globe", "internet-web-browser")
to("plane", "network-flightmode-on")
to("plane-landing", "network-flightmode-off")
to("shield-check", "network-vpn")
# bluetooth
to("bluetooth", "network-bluetooth", "preferences-system-bluetooth", "bluetooth")
to("bluetooth-connected", "network-bluetooth-activated", "preferences-system-bluetooth-activated")
to("bluetooth-off", "network-bluetooth-inactive", "preferences-system-bluetooth-inactive")
# battery and power
for lv in range(0, 101, 10):
    name = "battery-warning" if lv <= 10 else "battery-low" if lv <= 30 else "battery-medium" if lv <= 60 else "battery-full"
    to(name, f"battery-{lv:03d}")
    to("battery-charging", f"battery-{lv:03d}-charging")
to("battery-charging", "battery-charging", "battery-full-charging", "battery-good-charging")
to("battery-full", "battery-full", "battery-good", "battery")
to("battery-low", "battery-low", "battery-caution")
to("battery-warning", "battery-empty", "battery-missing")
to("power", "system-shutdown")
to("rotate-ccw", "system-reboot")
to("log-out", "system-log-out")
to("lock", "system-lock-screen")
to("moon", "system-suspend")
to("snowflake", "system-suspend-hibernate")
to("users", "system-switch-user")
to("coffee", "system-suspend-uninhibited")
to("leaf", "power-profile-power-saver")
to("scale", "power-profile-balanced")
to("gauge", "power-profile-performance")
# media
to("music-2", "media-playback-playing", "media-playback-paused", "audio-x-generic", "multimedia-player")
to("play", "media-playback-start")
to("pause", "media-playback-pause")
to("square", "media-playback-stop", "media-playback-stopped")
to("skip-forward", "media-skip-forward")
to("skip-back", "media-skip-backward")
to("shuffle", "media-playlist-shuffle")
to("repeat", "media-playlist-repeat")
to("disc-3", "media-optical-audio")
# notifications, tray helpers
to("bell", "notifications", "preferences-desktop-notification-bell")
to("bell-off", "notifications-disabled")
to("clipboard", "klipper", "edit-paste")
to("smartphone", "kdeconnect-tray", "kdeconnect", "smartphone")
to("keyboard", "input-keyboard")
to("usb", "drive-removable-media", "device-notifier")
to("sun", "video-display-brightness", "redshift-status-day", "brightness-high")
to("moon-star", "redshift-status-on")
to("sun-moon", "redshift-status-off")
to("printer", "printer")
to("camera", "camera-web", "camera-on")
to("vault", "plasmavault")
to("calendar", "view-calendar")
to("layout-grid", "view-app-grid")
to("menu", "application-menu", "open-menu")
to("chevron-up", "arrow-up", "go-up")
to("chevron-down", "arrow-down", "go-down")
# panel and window controls used by Pillbox
to("monitor", "computer", "video-display", "preferences-desktop-display-randr", "preferences-desktop-display")
to("map-pin", "mark-location")
to("app-window", "window")
to("plus", "list-add")
to("settings", "configure")
to("check", "checkmark")
to("trash-2", "edit-clear-history", "user-trash", "user-trash-full", "edit-delete")
to("image", "image-x-generic")
to("info", "dialog-information")
to("x", "window-close")
to("minus", "window-minimize")
to("maximize-2", "window-maximize")
to("minimize-2", "window-restore")
# weather (the clock dashboard)
to("sun", "weather-clear")
to("moon", "weather-clear-night")
to("cloud-sun", "weather-few-clouds")
to("cloud-moon", "weather-few-clouds-night")
to("cloud", "weather-overcast", "weather-clouds")
to("cloud-fog", "weather-fog")
to("cloud-drizzle", "weather-showers-scattered", "weather-showers-scattered-night")
to("cloud-rain", "weather-showers", "weather-showers-night")
to("cloud-snow", "weather-snow", "weather-snow-night")
to("cloud-lightning", "weather-storm", "weather-storm-night")
to("cloud-off", "weather-none-available")

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<style id="current-color-scheme" type="text/css">.ColorScheme-Text{color:#fcfcfc}</style>'
        f'<g class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="{STROKE}" '
        'stroke-linecap="round" stroke-linejoin="round">')

def body(name):
    t = open(os.path.join(SRC, name + ".svg"), encoding="utf-8").read()
    t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
    inner = re.search(r"<svg[^>]*>(.*)</svg>", t, re.S).group(1)
    return " ".join(inner.split())

def vendor(pkg):
    os.makedirs(SRC, exist_ok=True)
    for n in sorted(set(M.values())):
        shutil.copy(os.path.join(pkg, "icons", n + ".svg"), SRC)
    shutil.copy(os.path.join(pkg, "LICENSE"), os.path.join(SRC, "LICENSE"))
    print(f"copied {len(set(M.values()))} Lucide sources to {SRC}")

def main(out):
    d = os.path.join(out, "Pillbox-Lucide", "symbolic")
    if os.path.isdir(d): shutil.rmtree(d)
    os.makedirs(d)
    for icon, src in M.items():
        svg = HEAD + body(src) + "</g></svg>\n"
        for n in (icon, icon + "-symbolic"):
            with open(os.path.join(d, n + ".svg"), "w", encoding="utf-8") as f:
                f.write(svg)
    shutil.copy(os.path.join(SRC, "LICENSE"), os.path.join(out, "Pillbox-Lucide", "LICENSE-lucide"))
    with open(os.path.join(out, "Pillbox-Lucide", "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=Pillbox Lucide\nComment=Lucide line icons for the panel, the system tray and the Pillbox panels; everything else comes from Breeze.\n"
                "Inherits=breeze-dark,breeze,hicolor\nDirectories=symbolic\n\n"
                "[symbolic]\nSize=24\nMinSize=8\nMaxSize=512\nType=Scalable\nContext=Status\n")
    print(f"{len(M)} icons × 2 names written to {out}/Pillbox-Lucide")

if __name__ == "__main__":
    args = sys.argv[1:]
    if "--vendor" in args:
        vendor(args[args.index("--vendor") + 1])
        args = args[:args.index("--vendor")]
    if args:
        main(args[0])
