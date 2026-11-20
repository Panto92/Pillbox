/*
 * Dune – a desert of soft layered dunes. CPU: sand blows over the crests.
 * GPU: heat shimmer on the horizon. Unread: a shooting star. Night: moonlit dunes.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property var sky: P.sky(hour, [205, 150, 105], 0.16)
    readonly property var sunPos: P.sun(hour, 0.6)
    readonly property real night: sky.star
    readonly property var sandDay: ({ gold: [212, 168, 118], red: [200, 112, 72], white: [226, 216, 196] })[((env && env.cfg && env.cfg.DuneTone) || "gold")] || [212, 168, 118]
    readonly property var sand: P.mix(sandDay, [64, 76, 108], night)

    function crest(i, x) {
        const u = x / Math.max(1, width)
        const base = height * [0.6, 0.7, 0.82, 0.95][i]
        const amp = height * [0.07, 0.09, 0.11, 0.13][i]
        const v = Math.sin(u * (3 + i) + i * 1.9) * 0.6 + Math.sin(u * (7.3 + i * 2) + i * 4.1) * 0.25
        return base - (v * 0.5 + 0.5) * amp
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.62; color: P.col(scene.sky.bot) }
        }
    }
    Stars { count: 110; band: 0.55; strength: scene.night }
    Item {
        id: orbItem
        readonly property real r: scene.height * (scene.sunPos.up ? 0.055 : 0.032)
        readonly property var tone: scene.sunPos.up ? P.mix([255, 238, 205], [255, 150, 90], scene.hour > 16 ? 0.6 : 0.1) : [232, 238, 248]
        visible: scene.sunPos.up || scene.night > 0.3
        x: (scene.sunPos.up ? scene.sunPos.x : 0.24) * scene.width
        y: (scene.sunPos.up ? scene.sunPos.y : 0.2) * scene.height
        Glow { r: orbItem.r * 4.5; tone: orbItem.tone; strength: 0.2 }
        Rectangle { x: -orbItem.r; y: -orbItem.r; width: orbItem.r * 2; height: width; radius: width / 2; color: P.col(orbItem.tone, 0.95) }
    }
    // heat shimmer (GPU)
    Rectangle {
        visible: scene.gpu > 0.03
        y: scene.height * 0.585 - height / 2; width: parent.width; height: scene.height * 0.05
        opacity: scene.gpu * (0.55 + 0.25 * Math.sin(scene.t * 2.7))
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: P.col([255, 190, 130], 0.45) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Repeater {
        model: 4
        Shape {
            id: dl
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: P.col(P.mix(P.mix(scene.sand, [22, 16, 14], dl.index * 0.17), scene.sky.bot, (3 - dl.index) * 0.12))
                PathPolyline {
                    path: {
                        const pts = [Qt.point(-10, scene.height + 10)]
                        for (let x = -10; x <= scene.width + 10; x += 18) pts.push(Qt.point(x, scene.crest(dl.index, x)))
                        pts.push(Qt.point(scene.width + 10, scene.height + 10))
                        return pts
                    }
                }
            }
        }
    }
    // sand blowing over the crests (CPU)
    Repeater {
        model: 18
        Rectangle {
            required property int index
            readonly property int layerIdx: index % 4
            readonly property real span: scene.width + 200
            readonly property real px: ((scene.t * span / (9 + (index % 5) * 2) + P.rnd(index, 1) * span) % span) - 100
            readonly property real py: scene.crest(layerIdx, px + width / 2) - 2 - P.rnd(index, 2) * 6
            readonly property bool hidden: { for (let j = layerIdx + 1; j < 4; ++j) if (scene.crest(j, px + width / 2) < py) return true; return false }
            visible: scene.cpu > 0.04 && !hidden
            x: px; y: py
            width: 40 + P.rnd(index, 3) * 70; height: 1.5
            opacity: Math.min(1, scene.cpu * 1.3)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: P.col(P.mix(scene.sand, [255, 255, 255], 0.45), 0.75) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Meteor { id: meteor; width: scene.width * 0.08 }
    Connections {
        target: scene.env; ignoreUnknownSignals: true
        function onNewNotification() {
            const x = scene.width * (0.15 + Math.random() * 0.5)
            meteor.fire(x, scene.height * 0.06, x + scene.width * 0.28, scene.height * 0.24)
        }
    }
}
