/*
 * Horizon – flat layered hills, one clear sun or moon. Almost entirely static:
 * it changes once a minute with the clock; only thin haze drifts.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property var sky: P.sky(hour, [150, 130, 150], 0.12)
    readonly property var sunPos: P.sun(hour, 0.62)
    readonly property real heat: env ? env.gpu : 0
    readonly property real haze: env ? env.cpu : 0

    // sky
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.75; color: P.col(scene.sky.bot) }
        }
    }
    // a few stars (static)
    Repeater {
        model: 70
        Rectangle {
            required property int index
            readonly property real u: (Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real v: (Math.sin(index * 78.233) * 12345.678) % 1
            x: Math.abs(u) * scene.width; y: Math.abs(v) * scene.height * 0.5
            width: 1.5 + (index % 3) * 0.5; height: width; radius: width / 2
            color: "#e9eef2"
            opacity: scene.sky.star * (0.4 + (index % 5) * 0.12)
        }
    }
    // sun or moon: a crisp disc with a soft halo
    Item {
        id: sunItem
        readonly property real r: scene.height * (scene.sunPos.up ? 0.07 + scene.heat * 0.05 : 0.04)
        readonly property var tone: scene.sunPos.up ? P.mix([255, 236, 210], [255, 140, 80], scene.heat * 0.7 + (scene.hour > 17 ? 0.3 : 0)) : [235, 240, 248]
        visible: scene.sunPos.up || scene.sky.star > 0.3
        x: (scene.sunPos.up ? scene.sunPos.x : 0.72) * scene.width
        y: (scene.sunPos.up ? scene.sunPos.y : 0.22) * scene.height
        Shape {
            id: halo
            readonly property real rad: sunItem.r * 4
            x: -rad; y: -rad; width: rad * 2; height: rad * 2
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: halo.rad; centerY: halo.rad; centerRadius: halo.rad; focalX: halo.rad; focalY: halo.rad
                    GradientStop { position: 0; color: P.col(sunItem.tone, 0.16 + scene.heat * 0.12) }
                    GradientStop { position: 1; color: P.col(sunItem.tone, 0) }
                }
                PathAngleArc { centerX: halo.rad; centerY: halo.rad; radiusX: halo.rad; radiusY: halo.rad; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle { x: -sunItem.r; y: -sunItem.r; width: sunItem.r * 2; height: width; radius: width / 2; color: P.col(sunItem.tone, 0.95) }
    }
    // five flat hill layers, each a step darker; haze between them
    Repeater {
        model: 5
        Item {
            id: layer
            required property int index
            readonly property real d: index / 4
            readonly property real base: scene.height * (0.55 + d * 0.33)
            readonly property real amp: scene.height * (0.08 + d * 0.05)
            anchors.fill: parent
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: P.col(P.mix(P.mix(scene.sky.bot, scene.sky.top, 0.4), [12, 14, 20], 0.25 + layer.d * 0.65))
                    PathPolyline {
                        path: {
                            const pts = [Qt.point(-10, scene.height)]
                            for (let x = -10; x <= scene.width + 10; x += 24) {
                                const u = x / scene.width
                                pts.push(Qt.point(x, layer.base - (Math.sin(u * (2 + layer.index * 0.7) + layer.index * 1.7) * 0.5 + 0.5) * layer.amp))
                            }
                            pts.push(Qt.point(scene.width + 10, scene.height))
                            return pts
                        }
                    }
                }
            }
            Rectangle {                          // drifting haze, stronger under load
                visible: layer.index < 4 && scene.haze > 0.03
                y: layer.base - layer.amp * 0.2
                width: scene.width * 1.6; height: layer.amp
                opacity: scene.haze * 0.5
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: P.col(P.mix(scene.sky.bot, [255, 255, 255], 0.35), 0.3) }
                    GradientStop { position: 1; color: "transparent" }
                }
                x: -scene.width * 0.6 + ((scene.env ? scene.env.time : 0) * scene.width * 0.6 / (90 + layer.index * 9)) % (scene.width * 0.6)
            }
        }
    }
    // a small flock for new notifications
    Item {
        id: flock
        y: scene.height * 0.28
        visible: false
        Repeater {
            model: 7
            Text { required property int index; x: -index * 18; y: (index % 2 ? 1 : -1) * index * 4; text: "︶"; color: Qt.rgba(0.1, 0.1, 0.14, 0.75); font.pixelSize: 14 }
        }
        NumberAnimation on x { id: fly; running: false; from: -40; to: scene.width + 160; duration: 14000; onFinished: flock.visible = false }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { if (!fly.running) { flock.visible = true; fly.restart() } } }
}
