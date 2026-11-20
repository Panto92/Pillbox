/*
 * Pillbox desktop layout
 *   top:     three floating "pills" – menu + stats (left) · clock (center) · media/tray/power (right)
 *   desktop: the Pillbox Orb replaces the dock (floating, draggable, on the primary screen)
 * SPDX-License-Identifier: MIT
 */

var PILL_HEIGHT = 30;

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

// Desktop: keep the default folder view, use the image wallpaper plugin,
// and put the Orb on the primary screen's desktop
var desktops = desktopsForActivity(currentActivity());
desktops.forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
});
var primary = desktops.filter(function (d) { return d.screen === 0; })[0] || desktops[0];
if (primary && knownWidgetTypes.indexOf("org.pillbox.orb") >= 0) {
    primary.addWidget("org.pillbox.orb");
}

pill("left",   ["org.kde.plasma.kickoff", "org.pillbox.stats"]);

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
