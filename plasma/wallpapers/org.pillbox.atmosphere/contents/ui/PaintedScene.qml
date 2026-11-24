/*
 * Painted – your own pictures, brought to life. Put a day and a night picture into
 * ~/.local/share/pillbox/painted/ (day.jpg / night.jpg, also .png or .webp); the scene
 * crossfades between them with the time of day and lays snow, rain or twinkling stars over them.
 * With only one picture it darkens that one gently at night.
 * More pictures through the day: name them by the hour they belong to, optionally with the
 * effect for that picture – 08-none.jpg, 17-snow.jpg, 21-stars.png, 01-aurora.png. Each one
 * holds until shortly before the next and then fades into it (effects: snow, rain, stars,
 * aurora, none; without one the effect from the settings is used).
 * All pictures drift very slowly (a gentle pan and zoom), so the scene never looks frozen.
 * CPU: the snow or rain gets denser. GPU: a soft glow rises from below. Unread: a shooting star.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 21
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property string cfgEffect: (env && env.cfg && env.cfg.PaintedEffect) || "snow"
    readonly property string effect: keys.length > 0 && keyEffect !== "" ? keyEffect : bundled ? "none" : cfgEffect
    readonly property real night: P.sky(hour, [0, 0, 0], 0).star
    readonly property real k: Math.max(0.5, height / 1440)
    // frost, market, alpine, polar: the same scene with one picture that comes with Pillbox
    readonly property var builtIn: ({ frost: ["08-none", "none"], market: ["16-snow", "snow"], alpine: ["20-stars", "stars"], polar: ["00-aurora", "aurora"] })
    readonly property var own: env && env.cfg ? builtIn[env.cfg.Scene] : undefined
    readonly property bool bundled: own !== undefined
    readonly property string folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/pillbox/painted/"

    // the first of day.jpg / day.png / day.webp that exists
    component Picture: Image {
        property string base
        property var exts: ["jpg", "png", "webp", "jpeg"]
        property int tryIx: 0
        readonly property string stamp: (scene.env && scene.env.cfg && scene.env.cfg.PaintedStamp) || ""
        onStampChanged: tryIx = 0          // a new photo was chosen: look again from the start
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: Math.min(3840, scene.width)
        source: scene.bundled ? "" : scene.folder + base + "." + exts[tryIx] + "?" + stamp
        onStatusChanged: if (status === Image.Error && tryIx < exts.length - 1) tryIx++
        readonly property bool ok: status === Image.Ready
    }

    // ---------------------------------------------------------------- pictures by the hour
    FolderListModel {
        id: files
        folder: "file://" + scene.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        onStatusChanged: scene.readKeys()
        Component.onCompleted: scene.readKeys()
        onCountChanged: scene.readKeys()
    }
    property var keys: []                       // [{ hour, effect, url }] sorted by hour
    function readKeys() {
        if (bundled) { keys = [{ hour: 0, effect: own[1], url: Qt.resolvedUrl("../images/winter/" + own[0] + ".jpg") }]; return }
        const out = []
        for (let i = 0; i < files.count; i++) {
            const name = files.get(i, "fileName")
            const m = /^(\d{1,2})(?:[-_ ]([a-z]+))?/i.exec(name)
            if (!m || Number(m[1]) > 23) continue
            const fx = (m[2] || "").toLowerCase()
            out.push({ hour: Number(m[1]), effect: ["snow", "rain", "stars", "aurora", "none"].indexOf(fx) >= 0 ? fx : "",
                       url: files.get(i, "fileUrl") })
        }
        out.sort((a, b) => a.hour - b.hour)
        keys = out
    }
    onOwnChanged: readKeys()
    readonly property real fadeHours: 1.5
    // which picture holds now, which comes next, and how far the fade into it has got
    readonly property var slot: {
        const n = keys.length
        if (n === 0) return { cur: -1, next: -1, p: 0 }
        let cur = n - 1
        for (let i = 0; i < n; i++) if (keys[i].hour <= hour) cur = i
        const next = (cur + 1) % n
        const until = ((keys[next].hour - hour) % 24 + 24) % 24 || 24
        return { cur: cur, next: next, p: n > 1 ? Math.max(0, Math.min(1, 1 - until / fadeHours)) : 0 }
    }
    readonly property string keyEffect: slot.cur < 0 ? "" : keys[slot.p < 0.5 ? slot.cur : slot.next].effect

    Rectangle { anchors.fill: parent; color: "#0d1117" }
    // everything picture-like drifts together: a slow pan and a breath of zoom
    Item {
        id: stage
        anchors.fill: parent
        scale: 1.045 + 0.015 * Math.sin(scene.t * 0.011)
        transform: Translate {
            x: Math.sin(scene.t * 0.007) * scene.width * 0.012
            y: Math.cos(scene.t * 0.005) * scene.height * 0.008
        }
        Picture { id: day; base: "day"; visible: scene.keys.length === 0; opacity: ok ? 1 : 0 }
        Picture { id: nightPic; base: "night"; visible: scene.keys.length === 0; opacity: ok ? scene.night : 0 }
        Image {
            id: curPic
            anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize.width: Math.min(3840, scene.width)
            source: scene.slot.cur >= 0 ? scene.keys[scene.slot.cur].url : ""
        }
        Image {
            id: nextPic
            anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize.width: Math.min(3840, scene.width)
            source: scene.slot.next >= 0 && scene.slot.next !== scene.slot.cur ? scene.keys[scene.slot.next].url : ""
            opacity: scene.slot.p
        }
    }
    // only one picture: darken it towards night instead
    Rectangle {
        anchors.fill: parent
        color: "#0a0e1a"
        opacity: scene.keys.length > 0 || nightPic.ok ? 0 : scene.night * 0.55
    }
    // nothing there yet: say where the pictures go
    Column {
        visible: !day.ok && !nightPic.ok && scene.keys.length === 0
        anchors.centerIn: parent
        spacing: 8
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Painted"; color: "#cdd5db"; font.pixelSize: 34 * scene.k; font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Pillbox → Hintergrund → Lebendes Foto → Foto auswählen"; color: "#7d8a94"; font.pixelSize: 18 * scene.k }
    }

    // ---------------------------------------------------------------- what moves over the picture
    // stars: only at night, twinkling, in the upper half
    Repeater {
        model: scene.effect === "stars" ? 90 : 0
        Rectangle {
            required property int index
            x: P.rnd(index, 1) * scene.width; y: P.rnd(index, 2) * scene.height * 0.5
            width: (1 + P.rnd(index, 3) * 2) * scene.k; height: width; radius: width / 2
            color: "#f4f6ff"
            opacity: (scene.keyEffect === "stars" ? 1 : scene.night) * (0.3 + 0.7 * (0.5 + 0.5 * Math.sin(scene.t * (0.8 + P.rnd(index, 4)) + index)))
        }
    }
    // snow: layered, far flakes small and slow
    Repeater {
        model: scene.effect === "snow" ? 100 + Math.round(scene.cpu * 120) : 0
        Rectangle {
            required property int index
            readonly property real depth: P.rnd(index, 4)
            readonly property real fy: (scene.t * (0.012 + depth * 0.022 + P.rnd(index, 2) * 0.006) + P.rnd(index, 3)) % 1
            x: P.rnd(index, 1) * scene.width + Math.sin(scene.t * (0.35 + depth * 0.4) + index * 1.7) * (8 + depth * 22) * scene.k
            y: fy * (scene.height + 40) - 20
            width: (1.2 + depth * 3.4) * scene.k; height: width; radius: width / 2
            color: "#eef3ff"
            opacity: (0.35 + depth * 0.5) * Math.min(1, (1 - fy) * 6)
        }
    }
    // rain: thin slanted streaks
    Repeater {
        model: scene.effect === "rain" ? 90 + Math.round(scene.cpu * 110) : 0
        Rectangle {
            required property int index
            readonly property real fy: (scene.t * (0.5 + P.rnd(index, 2) * 0.3) + P.rnd(index, 3)) % 1
            x: P.rnd(index, 1) * scene.width - fy * scene.height * 0.1
            y: fy * (scene.height + 60) - 30
            width: Math.max(1, scene.k); height: (16 + P.rnd(index, 4) * 14) * scene.k
            rotation: 8
            color: "#c8d6e8"
            opacity: 0.18 + P.rnd(index, 5) * 0.2
        }
    }
    // aurora: soft green curtains breathing and wandering along the sky
    Repeater {
        model: scene.effect === "aurora" ? 3 : 0
        Rectangle {
            required property int index
            readonly property real ph: scene.t * (0.05 + index * 0.02) + index * 2.1
            x: scene.width * (0.1 + index * 0.25) + Math.sin(ph) * scene.width * 0.06
            y: scene.height * (0.42 + index * 0.04)
            width: scene.width * 0.45; height: scene.height * 0.28
            rotation: -4 + index * 3
            opacity: 0.10 + 0.08 * Math.sin(ph * 1.7)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.55; color: index === 1 ? "#7cf0b0" : "#4fe08a" }
                GradientStop { position: 1; color: "transparent" }
            }
            radius: height / 2
        }
    }
    // the aurora's stars twinkle too
    Repeater {
        model: scene.effect === "aurora" ? 40 : 0
        Rectangle {
            required property int index
            x: P.rnd(index, 1) * scene.width; y: P.rnd(index, 2) * scene.height * 0.4
            width: (1 + P.rnd(index, 3) * 1.5) * scene.k; height: width; radius: width / 2
            color: "#f4f6ff"
            opacity: 0.2 + 0.6 * (0.5 + 0.5 * Math.sin(scene.t * (0.8 + P.rnd(index, 4)) + index))
        }
    }
    // GPU: a soft warm glow rising from below
    Rectangle {
        visible: scene.gpu > 0.03
        anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.35
        opacity: scene.gpu * 0.35
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(1, 0.62, 0.36, 0.5) }
        }
    }
    Meteor { id: meteor; width: scene.width * 0.09 }
    Connections {
        target: scene.env; ignoreUnknownSignals: true
        function onNewNotification() { const x = scene.width * (0.15 + Math.random() * 0.5); meteor.fire(x, scene.height * 0.06, x + scene.width * 0.25, scene.height * 0.24) }
    }
}
