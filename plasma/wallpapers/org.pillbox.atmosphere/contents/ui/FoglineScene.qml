/*
 * Fogline – an alpine lake in morning fog. Four mountain ranges fade into the
 * distance, snow caps catch the first and last light, fog banks drift between the
 * ranges and over the water, a forest lines the shore and everything is mirrored
 * in the still lake. CPU: the fog thickens and drifts. GPU: alpenglow on the peaks.
 * Unread: rings on the water.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 7.5
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property var sky: P.sky(hour, [118, 138, 162], 0.12)
    readonly property real night: sky.star
    readonly property var sunPos: P.sun(hour, 0.6)
    readonly property real water: height * 0.66
    readonly property real s: height / 1440
    readonly property real vh: Math.min(height, width * 0.6)
    // golden hour: warm light on the snow in the morning and evening, or from the GPU
    readonly property real golden: Math.max(Math.max(0, 1 - Math.abs(hour - 7) / 1.6), Math.max(0, 1 - Math.abs(hour - 18.6) / 1.6))
    readonly property real glow: Math.min(1, golden * (1 - night) + gpu * 0.7)
    readonly property real dens: Math.min(1, cpu + ({ light: 0, normal: 0.25, dense: 0.6 }[(env && env.cfg && env.cfg.FoglineFog) || "normal"] || 0.25))
    readonly property var light: sunPos.up ? P.mix([255, 238, 210], [255, 170, 120], golden) : [222, 230, 245]
    readonly property real lightX: (sunPos.up ? sunPos.x : 0.7) * width

    // ---------------------------------------------------------------- geometry
    function tri(x) { const f = x - Math.floor(x); return 1 - Math.abs(2 * f - 1) }
    function ridge(base, amp, seed, f1, f2, sharp) {
        const pts = [Qt.point(-10, water + 2)]
        for (let x = -10; x <= width + 10; x += 10) {
            const u = x / Math.max(1, width)
            const v = Math.pow(tri(u * f1 + seed), sharp) * 0.62 + tri(u * f2 + seed * 1.9) * 0.26 + Math.sin(u * 61 + seed * 5) * 0.025
            pts.push(Qt.point(x, base - v * amp))
        }
        pts.push(Qt.point(width + 10, water + 2))
        return pts
    }
    // the forest: a gentle hill line with many small fir tips on top
    function forest(base, amp, seed) {
        const pts = [Qt.point(-10, water + 2)]
        if (width < 50 || height < 50) return pts          // not laid out yet (avoids an endless loop)
        const k = Math.max(0.5, height / 1440)              // own scale, never tiny
        let x = -10, i = 0
        while (x <= width + 10) {
            const u = x / Math.max(1, width)
            const hill = base - (Math.sin(u * 5.3 + seed) * 0.5 + 0.5) * amp
            const h = (16 + P.rnd(i, seed) * 34) * k
            const w = (5 + P.rnd(i, seed + 1) * 4) * k
            pts.push(Qt.point(x, hill))
            pts.push(Qt.point(x + w * 0.5, hill - h))
            x += w; i++
        }
        pts.push(Qt.point(width + 10, water + 2))
        return pts
    }
    readonly property var ranges: [
        ridge(water - vh * 0.06, vh * 0.32, 0.21, 1.7, 5.3, 2.6),     // farthest, tallest, craggy
        ridge(water - vh * 0.03, vh * 0.2, 0.93, 2.6, 7.1, 2.0),
        ridge(water - vh * 0.01, vh * 0.12, 1.57, 3.4, 8.3, 1.3)
    ]
    readonly property var forestLine: forest(water + 1, vh * 0.05, 3)

    function rangeColor(i) { return P.col(P.mix(P.mix(sky.bot, [70, 86, 110], 0.25), [10, 14, 22], 0.2 + i * 0.24)) }
    function snowColor(i) { return P.col(P.mix(P.mix(P.mix(sky.bot, [246, 248, 252], 0.85 - i * 0.25), [255, 170, 140], glow * (0.7 - i * 0.2)), [40, 48, 64], night * 0.6)) }

    // ---------------------------------------------------------------- reusable landscape (also mirrored)
    component Range: Shape {
        property int idx
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: scene.water - scene.vh * [0.36, 0.23, 0.13][idx]; x2: 0; y2: scene.water
                GradientStop { position: 0; color: scene.snowColor(idx) }
                GradientStop { position: [0.14, 0.18, 0.3][idx]; color: scene.snowColor(idx) }
                GradientStop { position: [0.3, 0.36, 0.5][idx]; color: scene.rangeColor(idx) }
                GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, [12, 16, 24], 0.35 + idx * 0.2)) }
            }
            PathPolyline { path: scene.ranges[idx] }
        }
    }
    component FogBand: Rectangle {
        property real yPos
        property real thick
        property real speed: 120
        property real strength: 1
        readonly property real span: scene.width
        x: -((scene.t * span / speed) % span)
        y: yPos - thick / 2
        width: scene.width * 2; height: thick
        opacity: (0.25 + scene.dens * 0.6) * strength * (0.6 + 0.4 * (1 - scene.night))
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: P.col(P.mix(scene.sky.bot, [236, 240, 245], 0.45), 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    component Landscape: Item {
        width: scene.width; height: scene.water
        Range { idx: 0 }
        FogBand { yPos: scene.water - scene.vh * 0.08; thick: scene.vh * 0.09; speed: 160; strength: 0.8 }
        Range { idx: 1 }
        FogBand { yPos: scene.water - scene.vh * 0.035; thick: scene.vh * 0.06; speed: 110; strength: 0.9 }
        Range { idx: 2 }
        Shape {                                                   // the forest: many straight tips → plain geometry renderer
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            ShapePath { strokeColor: "transparent"; fillColor: P.col(P.mix(scene.sky.top, [8, 14, 16], 0.85)); PathPolyline { path: scene.forestLine } }
        }
    }

    // ---------------------------------------------------------------- sky
    Rectangle {
        width: parent.width; height: scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.75; color: P.col(P.mix(scene.sky.bot, [255, 190, 150], scene.golden * 0.25 * (1 - scene.night))) }
            GradientStop { position: 1; color: P.col(scene.sky.bot) }
        }
    }
    Stars { count: 140; band: 0.5; strength: scene.night }
    Item {
        x: scene.lightX
        y: Math.min(scene.water - scene.vh * 0.05, (scene.sunPos.up ? scene.sunPos.y : 0.18) * scene.height)
        visible: scene.sunPos.up || scene.night > 0.3
        Glow { r: scene.vh * 0.42; tone: scene.light; strength: 0.22 + scene.golden * 0.18 }
        Rectangle {
            readonly property real r: scene.vh * (scene.sunPos.up ? 0.035 : 0.022)
            x: -r; y: -r; width: r * 2; height: width; radius: width / 2
            color: P.col(scene.light, 0.95)
        }
    }
    Landscape {}

    // ---------------------------------------------------------------- the lake
    Rectangle {
        y: scene.water; width: parent.width; height: parent.height - scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [14, 20, 28], 0.4)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [4, 7, 10], 0.75)) }
        }
    }
    Item {                                                      // mirror image
        y: scene.water; width: parent.width; height: parent.height - scene.water
        clip: true
        opacity: 0.55
        Item {
            y: scene.water; width: scene.width; height: scene.water
            transform: Scale { yScale: -1 }
            Landscape {}
        }
    }
    // a path of light on the water
    Repeater {
        model: (scene.sunPos.up || scene.night > 0.3) ? 22 : 0
        Rectangle {
            required property int index
            readonly property real base: (18 + index * 9) * scene.s
            width: base * (0.6 + 0.4 * Math.sin(scene.t * 1.3 + index * 1.7))
            height: Math.max(1, 2 * scene.s)
            radius: height / 2
            x: scene.lightX - width / 2 + Math.sin(scene.t * 0.7 + index) * 5 * scene.s
            y: scene.water + 6 + Math.pow(index / 21, 1.5) * (scene.height - scene.water) * 0.85
            color: P.col(scene.light, (0.45 - index * 0.013) * (0.6 + scene.golden * 0.4))
        }
    }
    // low fog over the water
    FogBand { yPos: scene.water + scene.vh * 0.03; thick: scene.vh * 0.08; speed: 90; strength: 1 }
    FogBand { yPos: scene.water + scene.vh * 0.12; thick: scene.vh * 0.1; speed: 140; strength: 0.6 }
    // faint ripples
    Repeater {
        model: 10
        Rectangle {
            required property int index
            y: scene.water + 10 + Math.pow(index / 9, 1.4) * (scene.height - scene.water) * 0.9
            x: P.rnd(index, 4) * scene.width * 0.7
            width: scene.width * (0.1 + P.rnd(index, 5) * 0.25); height: 1
            color: Qt.rgba(1, 1, 1, 0.025 + 0.025 * (0.5 + 0.5 * Math.sin(scene.t * 0.6 + index)))
        }
    }

    // ---------------------------------------------------------------- foreground shore
    function shoreY(x) {
        const u = x / Math.max(1, width)
        const left = Math.max(0, 1 - u / 0.28), right = Math.max(0, (u - 0.8) / 0.2)
        return height - (Math.pow(left, 1.6) * 0.17 + Math.pow(right, 1.8) * 0.12) * vh - 4 * s
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"; fillColor: "#05080a"
            PathPolyline {
                path: { const pts = [Qt.point(-10, scene.height + 10)]
                    for (let x = -10; x <= scene.width + 10; x += 12) pts.push(Qt.point(x, scene.shoreY(x)))
                    pts.push(Qt.point(scene.width + 10, scene.height + 10)); return pts }
            }
        }
    }
    Repeater {
        model: 7
        Shape {
            id: pine
            required property int index
            readonly property real px: scene.width * [0.015, 0.05, 0.09, 0.13, 0.86, 0.91, 0.95][index]
            readonly property real ph: (index === 1 || index === 5 ? 260 : 150 + P.rnd(index, 7) * 80) * scene.s
            x: px - width / 2; y: scene.shoreY(px) - ph + 6
            width: ph * 0.36; height: ph
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: "#05080a"
                PathPolyline {
                    path: { const w = pine.width, h = pine.height, pts = [Qt.point(w / 2, 0)]
                        for (let k = 1; k <= 5; ++k) { const y = h * k / 5.6, half = w / 2 * (0.25 + k * 0.15)
                            pts.push(Qt.point(w / 2 + half, y)); pts.push(Qt.point(w / 2 + half * 0.45, y)) }
                        pts.push(Qt.point(w / 2 + w * 0.06, h)); pts.push(Qt.point(w / 2 - w * 0.06, h))
                        for (let k = 5; k >= 1; --k) { const y = h * k / 5.6, half = w / 2 * (0.25 + k * 0.15)
                            pts.push(Qt.point(w / 2 - half * 0.45, y)); pts.push(Qt.point(w / 2 - half, y)) }
                        return pts }
                }
            }
        }
    }

    // ---------------------------------------------------------------- a ring on the water for each notification
    Rectangle {
        id: ring
        x: scene.width * 0.5 - width / 2; y: scene.water + (scene.height - scene.water) * 0.35 - height / 2
        width: 10; height: width * 0.28; radius: height / 2
        color: "transparent"; border.width: 1.2; border.color: Qt.rgba(0.88, 0.92, 0.96, 0.6); opacity: 0
        ParallelAnimation {
            id: ringAnim
            NumberAnimation { target: ring; property: "width"; from: 6; to: 180 * scene.s; duration: 2400; easing.type: Easing.OutCubic }
            NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 2400 }
        }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { ring.x = scene.width * (0.25 + Math.random() * 0.5) - 90 * scene.s; ringAnim.restart() } }
}
