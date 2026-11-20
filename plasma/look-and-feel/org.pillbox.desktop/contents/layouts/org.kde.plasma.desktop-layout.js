/*
 * Pillbox desktop layout
 *   top:    three floating "pills"  – stats (left) · clock (center) · media/tray/power (right)
 *   bottom: floating dock            – launcher + pinned/running apps
 * SPDX-License-Identifier: MIT
 */

var PILL_HEIGHT = 30;
var DOCK_HEIGHT = 56;

function pill(alignment, widgets) {
    var p = new Panel;
    p.location = "top";
    p.height = PILL_HEIGHT;
    p.floating = true;
    p.lengthMode = "fit";
    p.alignment = alignment;
    p.hiding = "none";
    widgets.forEach(function (w) { p.addWidget(w); });
    return p;
}

// Desktop: keep the default folder view, but use the image wallpaper plugin
desktopsForActivity(currentActivity()).forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
});

pill("left",   ["org.pillbox.stats"]);

var center = pill("center", ["org.kde.plasma.digitalclock"]);
var clock = center.widgets("org.kde.plasma.digitalclock")[0];
if (clock) {
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", "true");
    clock.writeConfig("dateFormat", "custom");
    clock.writeConfig("customDateFormat", "ddd dd MMM");
    clock.writeConfig("dateDisplayFormat", "1");
    clock.writeConfig("use24hFormat", "2");
}

pill("right",  ["org.kde.plasma.mediacontroller",
                "org.kde.plasma.systemtray",
                "org.kde.plasma.lock_logout"]);

var dock = new Panel;
dock.location = "bottom";
dock.height = DOCK_HEIGHT;
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "none";
dock.addWidget("org.kde.plasma.kickoff");
dock.addWidget("org.kde.plasma.icontasks");
