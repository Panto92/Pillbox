/*
 * Tide – open sea under a wide sky. CPU: waves grow and roll faster.
 * GPU: the sea starts to glow. Unread: rain moves over the water. Night: a path of moonlight.
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
    readonly property var sky: P.sky(hour, [60, 110, 140], 0.15)
    readonly property var sunPos: P.sun(hour, 0.56)
    readonly property real night: sky.star
    readonly property real horizon: height * 0.56
    readonly property real sea: ({ calm: 0.45, normal: 1, rough: 2.2 })[((env && env.cfg && env.cfg.TideWaves) || "normal")] || 1
    readonly property real s: height / 1440
    readonly property bool lightUp: sunPos.up || night > 0.3
    readonly property real lightX: (sunPos.up ? sunPos.x : 0.66) * width
    readonly property var lightTone: sunPos.up ? P.mix([255, 236, 205], [255, 160, 100], hour > 16 ? 0.6 : 0.1) : [225, 232, 245]

    Rectangle {
        width: parent.width; height: scene.horizon
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 1; color: P.col(scene.sky.bot) }
        }
    }
    Stars { count: 120; band: 0.5; strength: scene.night }
    Item {
        id: orbItem
        readonly property real r: scene.height * (scene.sunPos.up ? 0.05 : 0.03)
        visible: scene.lightUp
        x: scene.lightX
        y: Math.min(scene.horizon - r * 0.4, (scene.sunPos.up ? scene.sunPos.y : 0.2) * scene.height)
        Glow { r: orbItem.r * 4.5; tone: scene.lightTone; strength: 0.2 }
        Rectangle { x: -orbItem.r; y: -orbItem.r; width: orbItem.r * 2; height: width; radius: width / 2; color: P.col(scene.lightTone, 0.95) }
    }
    Rectangle {
        y: scene.horizon; width: parent.width; height: parent.height - scene.horizon
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [30, 60, 80], 0.45)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [4, 10, 18], 0.6)) }
        }
    }
    Rectangle {                                       // the sea glows with the graphics card
        visible: scene.gpu > 0.03
        y: scene.horizon; width: parent.width; height: parent.height - scene.horizon
        opacity: scene.gpu
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: P.col([40, 210, 200], 0.4) }
        }
    }
    // path of light on the water
    Repeater {
        model: scene.lightUp ? 20 : 0
        Rectangle {
            required property int index
            readonly property real base: (26 + index * 10) * scene.s
            width: base * (0.65 + 0.35 * Math.sin(scene.t * 1.6 + index * 1.3))
            height: Math.max(1, 2 * scene.s)
            x: scene.lightX - width / 2 + Math.sin(scene.t * 0.9 + index) * 6 * scene.s
            y: scene.horizon + 4 + Math.pow(index / 19, 1.6) * (scene.height - scene.horizon) * 0.9
            radius: height / 2
            color: P.col(scene.lightTone, 0.5 - index * 0.015)
        }
    }
    // swell lines: static paths slid sideways, taller with load
    Repeater {
        model: 7
        Shape {
            id: wv
            required property int index
            readonly property real wl: scene.width / (14 - index)
            readonly property real amp: (1.5 + index * 1.4) * scene.s * scene.sea
            width: scene.width + wl; height: amp * 2 + 4
            x: -((scene.t * wl / (6 + index)) % wl)
            y: scene.horizon + (scene.height - scene.horizon) * Math.pow((index + 1) / 8, 1.5) - amp
            transform: Scale { origin.y: wv.amp; yScale: 1 + scene.cpu * 1.6 }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: P.col(P.mix(scene.sky.bot, [255, 255, 255], 0.4), 0.1 + wv.index * 0.035)
                strokeWidth: 1 + wv.index * 0.25
                PathPolyline {
                    path: { const pts = []
                        for (let x = 0; x <= wv.width; x += 8) pts.push(Qt.point(x, wv.amp + Math.sin(x / wv.wl * 2 * Math.PI) * wv.amp))
                        return pts }
                }
            }
        }
    }
    Precip { id: rain }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { rain.start(20) } }
}
