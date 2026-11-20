/*
 * Pillbox desktop layout
 *   top:     three floating "pills" – menu + stats (left) · island clock (center) · media/tray/power (right)
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
// living wallpaper (Flow) on every monitor; falls back to Plasma's image wallpaper if missing
desktops.forEach(function (d) {
    d.wallpaperPlugin = "org.pillbox.atmosphere";
    d.currentConfigGroup = ["Wallpaper", "org.pillbox.atmosphere", "General"];
    d.writeConfig("Scene", "flow");
});
var primary = desktops.filter(function (d) { return d.screen === 0; })[0] || desktops[0];
if (primary && knownWidgetTypes.indexOf("org.pillbox.orb") >= 0) {
    var orb = primary.addWidget("org.pillbox.orb");
    orb.currentConfigGroup = ["Appearance"];
    orb.writeConfig("wallScene", "flow");          // the settings centre shows the same choice
}

pill("left",   ["org.kde.plasma.kickoff", "org.pillbox.stats"]);

// the centre pill: a clock that grows into an island for notifications
pill("center", ["org.pillbox.island"]);

pill("right",  ["org.kde.plasma.mediacontroller",
                "org.kde.plasma.systemtray",
                "org.kde.plasma.lock_logout"]);
