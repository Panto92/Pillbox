// Pillbox: rebuild the top panels in another arrangement, keeping every widget's settings.
// Run through plasmashell's evaluateScript with MODE replaced by islands | bar | capsule.
// SPDX-License-Identifier: MIT
var mode = "MODE";
var LEFT = ["org.kde.plasma.kickoff", "org.kde.plasma.kicker", "org.kde.plasma.kickerdash", "org.pillbox.stats"];
var CENTER = ["org.pillbox.island", "org.kde.plasma.digitalclock"];
var SKIP = ["org.kde.plasma.panelspacer", "org.kde.plasma.marginsseparator"];

// 1) remember the widgets of all top panels with all their settings
var top = panels().filter(function (p) { return p.location === "top"; });
if (top.length === 0) throw "no top panel";
var height = top[0].height, floating = top[0].floating;
var items = { left: [], center: [], right: [] };
top.forEach(function (p) {
    p.widgets().forEach(function (w) {
        if (SKIP.indexOf(w.type) >= 0) return;
        var cfg = {};
        w.configGroups.forEach(function (g) {
            w.currentConfigGroup = [g];
            var o = {};
            w.configKeys.forEach(function (k) { o[k] = w.readConfig(k); });
            cfg[g] = o;
        });
        var slot = LEFT.indexOf(w.type) >= 0 ? "left" : CENTER.indexOf(w.type) >= 0 ? "center" : "right";
        items[slot].push({ type: w.type, cfg: cfg });
    });
});

// keep a sensible order: the launcher first, then load; the clock in the middle
function rank(list) { return function (a, b) { var i = list.indexOf(a.type), j = list.indexOf(b.type); return (i < 0 ? 99 : i) - (j < 0 ? 99 : j); }; }
items.left.sort(rank(LEFT));
items.center.sort(rank(CENTER));

// 2) remove the old panels
top.forEach(function (p) { p.remove(); });

// 3) build the new arrangement
function add(panel, it) {
    var w = panel.addWidget(it.type);
    if (!w) return;
    for (var g in it.cfg) {
        w.currentConfigGroup = [g];
        for (var k in it.cfg[g]) w.writeConfig(k, it.cfg[g][k]);
    }
}
function makePanel(align, fill) {
    var p = new Panel;
    p.location = "top";
    p.height = height;
    p.floating = floating;
    p.alignment = align;
    p.lengthMode = fill ? "fill" : "fit";
    p.hiding = "none";
    return p;
}
if (mode === "bar") {
    var p = makePanel("center", true);
    items.left.forEach(function (it) { add(p, it); });
    p.addWidget("org.kde.plasma.panelspacer");
    items.center.forEach(function (it) { add(p, it); });
    p.addWidget("org.kde.plasma.panelspacer");
    items.right.forEach(function (it) { add(p, it); });
} else if (mode === "capsule") {
    var c = makePanel("center", false);
    items.left.concat(items.center, items.right).forEach(function (it) { add(c, it); });
} else {
    var l = makePanel("left", false), m = makePanel("center", false), r = makePanel("right", false);
    items.left.forEach(function (it) { add(l, it); });
    items.center.forEach(function (it) { add(m, it); });
    items.right.forEach(function (it) { add(r, it); });
}
print("arranged: " + mode);
