/*
 * Aurora – a Norwegian fjord in polar night. Curtains of light with fine rays dance
 * over layered mountains and are mirrored in the still water; a narrow dark shore,
 * a few pines, a hut. CPU: the aurora grows brighter and faster. GPU: the hut's
 * window lights up. Unread: a light snowfall.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 23
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    // polar light: even noon stays a deep blue dusk
    readonly property var sky: P.sky(hour, [10, 22, 46], 0.55)
    readonly property real night: Math.max(0.45, sky.star)
    readonly property real show: night * (0.55 + 0.45 * Math.min(1, cpu * 1.3 + 0.15))
    readonly property real water: height * 0.7
    readonly property real s: height / 1440
    // landscape heights are measured against a landscape-shaped view, so a portrait
    // monitor doesn't get mountains twice as tall as the screen is wide
    readonly property real vh: Math.min(height, width * 0.6)

    // ---- shared geometry
    function tri(x) { const f = x - Math.floor(x); return 1 - Math.abs(2 * f - 1) }
    function ridge(base, amp, seed, f1, f2) {
        const pts = [Qt.point(-10, water + 2)]
        for (let x = -10; x <= width + 10; x += 14) {
            const u = x / Math.max(1, width)
            const v = Math.pow(tri(u * f1 + seed), 1.6) * 0.6 + tri(u * f2 + seed * 1.9) * 0.28 + Math.sin(u * 47 + seed * 5) * 0.03
            pts.push(Qt.point(x, base - v * amp))
        }
        pts.push(Qt.point(width + 10, water + 2))
        return pts
    }
    readonly property var farRidge: ridge(water - vh * 0.03, vh * 0.27, 0.37, 2.3, 5.1)
    readonly property var nearRidge: ridge(water + 1, vh * 0.17, 1.71, 3.1, 7.7)

    // aurora curtain i: vertical position, thickness, horizontal drift, wavy edges
    function bandTop(i) { return height * [0.2, 0.12, 0.06][i] }
    function bandThick(i) { return height * [0.2, 0.16, 0.1][i] }
    function bandShift(i) { return -((t * width / [55, 80, 70][i]) % width) }
    function wave(u, ph) { return Math.sin(2 * Math.PI * 2 * u + ph) * 0.6 + Math.sin(2 * Math.PI * 5 * u + ph * 2.1) * 0.3 }
    function bandBottom(i, sx) { return bandTop(i) + bandThick(i) + wave((sx - bandShift(i)) / Math.max(1, width), i * 1.7 + 0.8) * height * 0.075 }
    readonly property var tones: ({ green: [[80, 255, 160], [140, 255, 190], [60, 220, 150]],
                                    violet: [[190, 110, 255], [235, 120, 220], [140, 110, 255]] })[((env && env.cfg && env.cfg.AuroraColor) || "mixed")]
                                 || [[80, 255, 160], [110, 225, 255], [190, 110, 255]]
    readonly property bool hutOn: !env || !env.cfg || env.cfg.AuroraHut !== "off"

    // ---- the aurora as one reusable layer (drawn in the sky and mirrored in the water)
    component AuroraLayer: Item {
        width: scene.width; height: scene.water
        Repeater {
            model: 3
            Shape {
                id: band
                required property int index
                readonly property var tone: scene.tones[index]
                readonly property real topY: scene.bandTop(index)
                readonly property real thick: scene.bandThick(index)
                width: scene.width * 2; height: scene.water
                x: scene.bandShift(index)
                opacity: scene.show * [0.95, 0.5, 0.35][index]
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: band.topY - scene.height * 0.14; x2: 0; y2: band.topY + band.thick + scene.height * 0.07
                        GradientStop { position: 0; color: P.col(band.tone, 0) }
                        GradientStop { position: 0.45; color: P.col(band.tone, 0.06) }
                        GradientStop { position: 0.8; color: P.col(band.tone, 0.32) }
                        GradientStop { position: 0.92; color: P.col(band.tone, 0.7) }
                        GradientStop { position: 1; color: P.col(band.tone, 0) }
                    }
                    PathPolyline {
                        path: {
                            const W = scene.width, H = scene.height, pts = []
                            for (let x = 0; x <= 2 * W; x += 20) pts.push(Qt.point(x, band.topY - H * 0.12 + scene.wave(x / W, band.index * 1.7) * H * 0.02))
                            for (let x = 2 * W; x >= 0; x -= 20) pts.push(Qt.point(x, band.topY + band.thick + scene.wave(x / W, band.index * 1.7 + 0.8) * H * 0.075))
                            return pts
                        }
                    }
                }
            }
        }
        // fine vertical rays hanging from the lower edge of the main curtain
        Repeater {
            model: 44
            Rectangle {
                required property int index
                readonly property int b: index % 3 === 2 ? 1 : 0
                readonly property real span: scene.width + 40
                readonly property real px: ((P.rnd(index, 1) * span + scene.t * span / (70 + P.rnd(index, 2) * 50)) % span) - 20
                readonly property real baseY: scene.bandBottom(b, px)
                width: (2 + P.rnd(index, 3) * 6) * scene.s
                height: scene.height * (0.06 + P.rnd(index, 4) * 0.14)
                x: px; y: baseY - height + scene.height * 0.015
                opacity: scene.show * (0.25 + 0.35 * (0.5 + 0.5 * Math.sin(scene.t * (0.6 + P.rnd(index, 5)) + index * 2.3)))
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.75; color: P.col(scene.tones[b], 0.45) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
    component Mountains: Item {
        width: scene.width; height: scene.water
        Shape {                                                   // far range, moonlit snowy peaks
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: scene.water - scene.vh * 0.3; x2: 0; y2: scene.water
                    GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [150, 165, 190], 0.45)) }
                    GradientStop { position: 0.35; color: P.col(P.mix(scene.sky.top, [40, 50, 70], 0.5)) }
                    GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [14, 18, 28], 0.7)) }
                }
                PathPolyline { path: scene.farRidge }
            }
        }
        Shape {                                                   // near range, almost black
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: P.col(P.mix(scene.sky.top, [6, 9, 14], 0.82))
                PathPolyline { path: scene.nearRidge }
            }
        }
    }

    // ---- sky
    Rectangle {
        width: parent.width; height: scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.top, [4, 6, 12], 0.5)) }
            GradientStop { position: 1; color: P.col(scene.sky.bot) }
        }
    }
    Stars { count: 170; band: 0.62; strength: scene.night }
    AuroraLayer {}
    Mountains {}

    // ---- the fjord: dark water mirroring sky, aurora and mountains
    Rectangle {
        y: scene.water; width: parent.width; height: parent.height - scene.water
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [6, 10, 18], 0.45)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [2, 4, 8], 0.75)) }
        }
    }
    Item {
        y: scene.water; width: parent.width; height: parent.height - scene.water
        clip: true
        opacity: 0.42
        Item {
            y: scene.water; width: scene.width; height: scene.water
            transform: Scale { yScale: -1 }
            AuroraLayer {}
            Mountains {}
        }
    }
    // faint ripples
    Repeater {
        model: 12
        Rectangle {
            required property int index
            y: scene.water + 4 + Math.pow(index / 11, 1.5) * (scene.height - scene.water) * 0.92
            x: P.rnd(index, 1) * scene.width * 0.6
            width: scene.width * (0.15 + P.rnd(index, 2) * 0.35); height: 1
            color: Qt.rgba(0.7, 0.9, 0.85, 0.02 + 0.03 * (0.5 + 0.5 * Math.sin(scene.t * 0.7 + index)))
        }
    }

    // ---- narrow shore in front, pines, the hut
    function shoreRaw(x) { const u = x / Math.max(1, width); return height * 0.93 - Math.pow(tri(u * 1.3 + 0.62), 2) * vh * 0.08 }
    // the shore, levelled into a small flat terrace where the hut stands
    readonly property real hutW: 70 * s
    readonly property real hutX: width * 0.74
    readonly property real hutGround: shoreRaw(hutX + hutW / 2)
    function shoreY(x) {
        const d = Math.abs(x - (hutX + hutW / 2)), a = hutW * 0.75, b = hutW * 2.2
        const k = d <= a ? 0 : d >= b ? 1 : (function (f) { return f * f * (3 - 2 * f) })((d - a) / (b - a))
        return hutGround * (1 - k) + shoreRaw(x) * k
    }
    // the window's warm light, behind the shore so it only falls on air and water
    Item {
        visible: scene.hutOn
        x: scene.hutX + scene.hutW * 0.32; y: scene.hutGround - scene.hutW * 0.25
        Glow { r: scene.hutW * 1.4; tone: [255, 180, 100]; strength: 0.3 * Math.min(1, 0.35 + scene.gpu * 0.65) }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#05070b"
            PathPolyline {
                path: { const pts = [Qt.point(-10, scene.height + 10)]
                    for (let x = -10; x <= scene.width + 10; x += 8) pts.push(Qt.point(x, scene.shoreY(x)))
                    pts.push(Qt.point(scene.width + 10, scene.height + 10)); return pts }
            }
        }
    }
    Repeater {
        model: 9
        Shape {
            id: pine
            required property int index
            readonly property real px: scene.width * [0.03, 0.06, 0.1, 0.14, 0.62, 0.66, 0.88, 0.92, 0.95][index]
            readonly property real ph: (60 + P.rnd(index, 2) * 80) * scene.s
            x: px; y: scene.shoreY(px + width / 2) - ph + 4
            width: ph * 0.42; height: ph
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#05070b"
                PathPolyline {
                    path: { const w = pine.width, h = pine.height
                        return [Qt.point(w / 2, 0), Qt.point(w * 0.78, h * 0.35), Qt.point(w * 0.64, h * 0.35), Qt.point(w * 0.92, h * 0.68), Qt.point(w * 0.72, h * 0.68),
                                Qt.point(w, h), Qt.point(0, h), Qt.point(w * 0.28, h * 0.68), Qt.point(w * 0.08, h * 0.68), Qt.point(w * 0.36, h * 0.35), Qt.point(w * 0.22, h * 0.35)] }
                }
            }
        }
    }
    Item {
        id: hut
        visible: scene.hutOn
        readonly property real w: scene.hutW
        readonly property real lit: Math.min(1, 0.35 + scene.gpu * 0.65)
        x: scene.hutX; y: scene.hutGround + 2 * scene.s
        Rectangle { y: -hut.w * 0.45; width: hut.w; height: hut.w * 0.45 + 8 * scene.s; color: "#05070b" }   // sunk into the ground
        Shape {
            y: -hut.w * 0.8; x: -hut.w * 0.08; width: hut.w * 1.16; height: hut.w * 0.36
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: "#05070b"
                PathPolyline { path: [Qt.point(0, hut.w * 0.36), Qt.point(hut.w * 0.58, 0), Qt.point(hut.w * 1.16, hut.w * 0.36)] } }
        }
        Rectangle { x: hut.w * 0.22; y: -hut.w * 0.32; width: hut.w * 0.2; height: hut.w * 0.15; radius: 1; color: Qt.rgba(1, 0.76, 0.45, hut.lit) }
    }
    Precip { id: snowfall; snow: true }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { snowfall.start(25) } }
}
