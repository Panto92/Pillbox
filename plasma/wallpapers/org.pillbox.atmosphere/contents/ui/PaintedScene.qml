/*
 * Painted – your own pictures, brought to life. Put a day and a night picture into
 * ~/.local/share/pillbox/painted/ (day.jpg / night.jpg, also .png or .webp); the scene
 * crossfades between them with the time of day and lays snow, rain or twinkling stars over them.
 * With only one picture it darkens that one gently at night.
 * CPU: the snow or rain gets denser. GPU: a soft glow rises from below. Unread: a shooting star.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtCore
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 21
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property string effect: (env && env.cfg && env.cfg.PaintedEffect) || "snow"
    readonly property real night: P.sky(hour, [0, 0, 0], 0).star
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property string folder: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/pillbox/painted/"

    // the first of day.jpg / day.png / day.webp that exists
    component Picture: Image {
        property string base
        property var exts: ["jpg", "png", "webp", "jpeg"]
        property int tryIx: 0
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: Math.min(3840, scene.width)
        source: scene.folder + base + "." + exts[tryIx]
        onStatusChanged: if (status === Image.Error && tryIx < exts.length - 1) tryIx++
        readonly property bool ok: status === Image.Ready
    }

    Rectangle { anchors.fill: parent; color: "#0d1117" }
    Picture { id: day; base: "day"; opacity: ok ? 1 : 0 }
    Picture { id: nightPic; base: "night"; opacity: ok ? scene.night : 0 }
    // only one picture: darken it towards night instead
    Rectangle {
        anchors.fill: parent
        color: "#0a0e1a"
        opacity: nightPic.ok ? 0 : scene.night * 0.55
    }
    // nothing there yet: say where the pictures go
    Column {
        visible: !day.ok && !nightPic.ok
        anchors.centerIn: parent
        spacing: 8
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Painted"; color: "#cdd5db"; font.pixelSize: 34 * scene.k; font.weight: Font.DemiBold }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "~/.local/share/pillbox/painted/  ·  day.jpg  ·  night.jpg"; color: "#7d8a94"; font.pixelSize: 18 * scene.k }
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
            opacity: scene.night * (0.3 + 0.7 * (0.5 + 0.5 * Math.sin(scene.t * (0.8 + P.rnd(index, 4)) + index)))
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
