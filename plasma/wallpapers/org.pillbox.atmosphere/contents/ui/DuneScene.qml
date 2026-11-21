/*
 * Dune – a sea of dunes under a wide sky. Each dune has a sharp crest with a lit
 * flank facing the sun and a shadowed flank (the shadow is the dune's own shape,
 * shifted away from the sun). Mesas on the horizon, a low sun in the evening and the
 * Milky Way at night. CPU: sand blows over the crests. GPU: heat shimmer.
 * Unread: a shooting star.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 18.5
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property var sky: P.sky(hour, [205, 150, 105], 0.16)
    readonly property real night: sky.star
    readonly property var sunPos: P.sun(hour, 0.56)
    readonly property real horizon: height * 0.58
    readonly property real vh: Math.min(height, width * 0.6)
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property real golden: Math.max(Math.max(0, 1 - Math.abs(hour - 7) / 1.8), Math.max(0, 1 - Math.abs(hour - 18.6) / 1.8))
    // sand colour by option, warmer in golden hour, blue-grey by moonlight
    readonly property var sandBase: ({ gold: [224, 172, 112], red: [206, 112, 70], white: [232, 220, 196] })[(env && env.cfg && env.cfg.DuneTone) || "gold"] || [224, 172, 112]
    readonly property var sandLit: P.mix(P.mix(sandBase, [255, 170, 100], golden * 0.35), [96, 106, 138], night * 0.8)
    readonly property var sandShade: P.mix(P.mix(sandBase, [120, 70, 60], 0.55 + golden * 0.15), [30, 34, 52], night * 0.75)
    // light from the left before noon, from the right after; the shadow falls the other way
    readonly property real sunSide: sunPos.up ? (sunPos.x < 0.5 ? -1 : 1) : 1
    readonly property var light: sunPos.up ? P.mix([255, 238, 205], [255, 150, 90], golden) : [226, 232, 246]

    // ---------------------------------------------------------------- dune geometry
    function tri(x) { const f = x - Math.floor(x); return 1 - Math.abs(2 * f - 1) }
    // crest height of dune row i at x: sharp asymmetric peaks with gentle troughs
    function crest(i, x) {
        const u = x / Math.max(1, width)
        const base = horizon + vh * [0.02, 0.09, 0.2, 0.36, 0.56][i]
        const amp = vh * [0.06, 0.1, 0.15, 0.22, 0.3][i]
        const f = [1.3, 1.1, 0.9, 0.75, 0.6][i]
        const a = Math.pow(tri(u * f + i * 0.37), 1.8) * 0.85 + Math.pow(tri(u * f * 2.3 + i * 1.3), 3) * 0.15
        return base - a * amp
    }
    function rowPath(i, shift) {
        const pts = [Qt.point(-20, height + 10)]
        if (width < 50 || height < 50) return pts
        for (let x = -20; x <= width + 20; x += 10) pts.push(Qt.point(x, crest(i, x - shift) + Math.abs(shift) * 0.35))
        pts.push(Qt.point(width + 20, height + 10))
        return pts
    }

    // ---------------------------------------------------------------- sky
    Rectangle {
        width: parent.width; height: scene.horizon + scene.vh * 0.05
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.72; color: P.col(P.mix(scene.sky.bot, [255, 176, 120], scene.golden * 0.4 * (1 - scene.night))) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, [255, 196, 140], scene.golden * 0.55 * (1 - scene.night))) }
        }
    }
    // the Milky Way: a soft diagonal band of light and dense stars, only at night
    Item {
        anchors.fill: parent
        visible: scene.night > 0.2
        opacity: (scene.night - 0.2) * 1.25
        Rectangle {
            x: scene.width * 0.15; y: -scene.height * 0.2
            width: scene.width * 0.22; height: scene.height * 1.1
            rotation: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.45; color: Qt.rgba(0.75, 0.78, 0.92, 0.10) }
                GradientStop { position: 0.55; color: Qt.rgba(0.95, 0.88, 0.85, 0.13) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Stars { count: 220; band: 0.58; strength: scene.night }
    Item {
        x: (scene.sunPos.up ? scene.sunPos.x : 0.72) * scene.width
        y: Math.min(scene.horizon + scene.vh * 0.01, (scene.sunPos.up ? scene.sunPos.y : 0.2) * scene.height)
        visible: scene.sunPos.up || scene.night > 0.3
        Glow { r: scene.vh * (0.5 + scene.golden * 0.2); tone: scene.light; strength: 0.22 + scene.golden * 0.22 }
        Rectangle {
            readonly property real r: scene.vh * (scene.sunPos.up ? 0.045 + scene.golden * 0.02 : 0.024)
            x: -r; y: -r; width: r * 2; height: width; radius: width / 2
            color: P.col(scene.light, 0.97)
        }
    }
    // mesas on the horizon
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: P.col(P.mix(P.mix(scene.sandShade, scene.sky.bot, 0.55), [40, 40, 60], scene.night * 0.4))
            PathPolyline {
                path: {
                    const W = scene.width, H = scene.horizon + scene.vh * 0.03, v = scene.vh
                    if (W < 50) return []
                    const m = (x0, w, h) => [Qt.point(x0, H), Qt.point(x0 + w * 0.08, H - h * 0.85), Qt.point(x0 + w * 0.12, H - h), Qt.point(x0 + w * 0.88, H - h),
                                             Qt.point(x0 + w * 0.93, H - h * 0.8), Qt.point(x0 + w, H)]
                    return [Qt.point(-10, H)].concat(m(W * 0.06, W * 0.13, v * 0.07), m(W * 0.22, W * 0.06, v * 0.045), m(W * 0.63, W * 0.17, v * 0.06)).concat([Qt.point(W + 10, H), Qt.point(W + 10, H + 4), Qt.point(-10, H + 4)])
                }
            }
        }
    }
    // heat shimmer (GPU)
    Rectangle {
        visible: scene.gpu > 0.03
        y: scene.horizon - scene.vh * 0.02; width: parent.width; height: scene.vh * 0.06
        opacity: scene.gpu * (0.55 + 0.25 * Math.sin(scene.t * 2.7))
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: P.col([255, 196, 140], 0.45) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ---------------------------------------------------------------- the dunes: lit body, shadow on top
    Repeater {
        model: 5
        Item {
            id: row
            required property int index
            readonly property real depth: index / 4                        // 0 far … 1 near
            readonly property real haze: 1 - depth
            anchors.fill: parent
            Shape {                                                        // the lit flank
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: P.col(P.mix(scene.sandLit, scene.sky.bot, row.haze * 0.45))
                    PathPolyline { path: scene.rowPath(row.index, 0) }
                }
            }
            Shape {                                                        // the shadow: same dune, shifted away from the sun
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: scene.crest(row.index, scene.width / 2) - scene.vh * 0.1; x2: 0; y2: scene.height
                        GradientStop { position: 0; color: P.col(P.mix(scene.sandShade, scene.sky.bot, row.haze * 0.5)) }
                        GradientStop { position: 1; color: P.col(P.mix(scene.sandShade, [20, 14, 18], 0.25 + row.depth * 0.25)) }
                    }
                    PathPolyline { path: scene.rowPath(row.index, -scene.sunSide * scene.vh * (0.09 + row.depth * 0.16)) }
                }
            }
        }
    }
    // sand blowing over the nearest crests (CPU)
    Repeater {
        model: 22
        Rectangle {
            required property int index
            readonly property int rowIdx: 2 + index % 3
            readonly property real span: scene.width + 300
            readonly property real px: ((scene.t * span / (8 + (index % 5) * 2) + P.rnd(index, 1) * span) % span) - 150
            readonly property real py: scene.crest(rowIdx, px + width / 2) - 2 - P.rnd(index, 2) * 8 * scene.k
            readonly property bool hidden: { for (let j = rowIdx + 1; j < 5; ++j) if (scene.crest(j, px + width / 2) < py) return true; return false }
            visible: scene.cpu > 0.04 && !hidden
            x: px; y: py
            width: (50 + P.rnd(index, 3) * 120) * scene.k; height: Math.max(1, 1.6 * scene.k)
            opacity: Math.min(1, scene.cpu * 1.3)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: P.col(P.mix(scene.sandLit, [255, 255, 255], 0.4), 0.8) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Meteor { id: meteor; width: scene.width * 0.09 }
    Connections {
        target: scene.env; ignoreUnknownSignals: true
        function onNewNotification() {
            const x = scene.width * (0.15 + Math.random() * 0.5)
            meteor.fire(x, scene.height * 0.06, x + scene.width * 0.28, scene.height * 0.26)
        }
    }
}
