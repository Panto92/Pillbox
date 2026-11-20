/*
 * Fogline – a misty lake under mountains, mirrored in the water.
 * Static shapes coloured by the clock; only fog banks and glints drift.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property var sky: P.sky(hour, [110, 140, 165], 0.14)
    readonly property var sunPos: P.sun(hour, 0.7)
    readonly property real water: height * 0.7
    readonly property real heat: env ? Math.max(0, (env.gpu - 0.25) / 0.7) : 0
    readonly property real dens: Math.min(1, (env ? env.cpu : 0) + ({ light: 0, normal: 0.22, dense: 0.55 }[((env && env.cfg && env.cfg.FoglineFog) || "normal")] || 0))
    readonly property bool live: env && env.running
    readonly property real t: env ? env.time : 0

    function ridge(base, amp, seed) {
        const pts = [Qt.point(-10, water)]
        for (let x = -10; x <= width + 10; x += 16) {
            const u = x / Math.max(1, width)
            const y = Math.sin(u * 6.1 + seed) * 0.5 + Math.sin(u * 13.7 + seed * 2.3) * 0.25 + Math.sin(u * 29.3 + seed * 4.1) * 0.12
            pts.push(Qt.point(x, base - (y * 0.5 + 0.5) * amp))
        }
        pts.push(Qt.point(width + 10, water))
        return pts
    }
    readonly property var farRidge: ridge(height * 0.6, height * 0.22, 1.3)
    readonly property var nearRidge: ridge(height * 0.69, height * 0.16, 4.2)

    // sky + stars + sun glow
    Rectangle {
        width: parent.width; height: scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 1; color: P.col(scene.sky.bot) }
        }
    }
    Repeater {
        model: 90
        Rectangle {
            required property int index
            x: Math.abs((Math.sin(index * 12.9898) * 43758.5453) % 1) * scene.width
            y: Math.abs((Math.sin(index * 78.233) * 12345.678) % 1) * scene.water * 0.8
            width: 1.5 + (index % 3) * 0.5; height: width; radius: width / 2
            color: "#e9eef2"; opacity: scene.sky.star * (0.35 + (index % 5) * 0.12)
        }
    }
    Shape {
        id: sunGlow
        readonly property real rad: scene.height * 0.5
        readonly property var tone: scene.hour > 16 || scene.hour < 9 ? [255, 168, 120] : [255, 244, 225]
        x: scene.sunPos.x * scene.width - sunGlow.rad; y: scene.sunPos.y * scene.height - sunGlow.rad
        width: rad * 2; height: rad * 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: sunGlow.rad; centerY: sunGlow.rad; centerRadius: sunGlow.rad; focalX: sunGlow.rad; focalY: sunGlow.rad
                GradientStop { position: 0; color: P.col(sunGlow.tone, 0.42 * scene.sky.light) }
                GradientStop { position: 1; color: P.col(sunGlow.tone, 0) }
            }
            PathAngleArc { centerX: sunGlow.rad; centerY: sunGlow.rad; radiusX: sunGlow.rad; radiusY: sunGlow.rad; startAngle: 0; sweepAngle: 360 }
        }
    }

    // mountains (crest glows with GPU load)
    component Ridge: Shape {
        id: rg
        property var points
        property real depth
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: scene.heat > 0.01 ? P.col([255, 160, 90], 0.6 * scene.heat * rg.depth) : "transparent"
            strokeWidth: 1.5
            fillColor: P.col(P.mix(scene.sky.bot, [8, 10, 13], 0.35 + rg.depth * 0.5))
            PathPolyline { path: rg.points }
        }
    }
    Ridge { points: scene.farRidge; depth: 0.3 }
    Ridge { points: scene.nearRidge; depth: 0.62 }

    // the lake: darker sky, mirrored ridge
    Rectangle {
        y: scene.water; width: parent.width; height: parent.height - scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [10, 12, 16], 0.35)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [4, 6, 8], 0.6)) }
        }
    }
    Ridge {
        points: scene.nearRidge; depth: 0.9
        opacity: 0.28
        transform: Scale { origin.y: scene.water; yScale: -1 }
    }
    // glints drifting on the water (render-thread animators)
    Repeater {
        model: 14
        Rectangle {
            required property int index
            y: scene.water + 6 + (index * 37.3) % Math.max(1, scene.height - scene.water - 8)
            width: 40 + (index % 5) * 14; height: 1
            color: P.col(P.mix(scene.sky.bot, [255, 255, 255], 0.5), 0.12 + 0.2 * scene.sky.light)
            readonly property real span: scene.width + 160
            x: ((scene.t * (span / (26 + (index % 4) * 9)) + index * 233) % span) - 80
        }
    }
    // fog banks along the water line, denser under load
    Repeater {
        model: 6
        Shape {
            id: fogBlob
            required property int index
            readonly property real rad: scene.height * (0.18 + (index % 3) * 0.06) * (1 + scene.dens * 0.6)
            y: scene.height * (0.6 + (index % 3) * 0.06) - rad
            width: rad * 2; height: rad * 2
            opacity: (0.06 + 0.3 * scene.dens) * (0.5 + 0.5 * scene.sky.light)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: fogBlob.rad; centerY: fogBlob.rad; centerRadius: fogBlob.rad; focalX: fogBlob.rad; focalY: fogBlob.rad
                    GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [235, 240, 244], 0.45)) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc { centerX: fogBlob.rad; centerY: fogBlob.rad; radiusX: fogBlob.rad; radiusY: fogBlob.rad; startAngle: 0; sweepAngle: 360 }
            }
            readonly property real span: scene.width + fogBlob.rad * 2 + 40
            x: ((scene.t * span / (70 + fogBlob.index * 7) + fogBlob.index * span / 6) % span) - fogBlob.rad * 2
        }
    }
    // a ring on the water for each new notification
    Rectangle {
        id: ring
        x: scene.width * 0.6 - width / 2; y: scene.water + (scene.height - scene.water) * 0.4 - height / 2
        width: 10; height: width * 0.3; radius: height / 2
        color: "transparent"; border.width: 1.2; border.color: Qt.rgba(0.86, 0.91, 0.94, 0.6); opacity: 0
        ParallelAnimation {
            id: ringAnim
            NumberAnimation { target: ring; property: "width"; from: 6; to: 140; duration: 2200; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 2200 }
        }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { ring.x = scene.width * (0.15 + Math.random() * 0.7) - 70; ringAnim.restart() } }
}
