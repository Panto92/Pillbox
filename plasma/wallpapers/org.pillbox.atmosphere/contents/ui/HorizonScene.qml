/*
 * Horizon – rolling hills to the horizon, layer behind layer, each a step deeper in
 * colour; the nearer ridges are covered in fir forest, a dark tree line closes the
 * view. A large sun with a soft halo, haze between the ridges.
 * CPU: the haze thickens and drifts. GPU: the sun grows warmer. Unread: a flock of birds.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 17.8
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property string tone: (env && env.cfg && env.cfg.HorizonTone) || "natural"
    readonly property var tint: tone === "teal" ? [60, 150, 150] : tone === "rose" ? [230, 120, 140] : [240, 150, 110]
    readonly property var sky: P.sky(hour, tint, tone === "natural" ? 0.14 : 0.26)
    readonly property real night: sky.star
    readonly property var sunPos: P.sun(hour, 0.5)
    readonly property real horizon: height * 0.5
    readonly property real vh: Math.min(height, width * 0.6)
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property real golden: Math.max(Math.max(0, 1 - Math.abs(hour - 7) / 1.8), Math.max(0, 1 - Math.abs(hour - 18.6) / 1.8))
    readonly property var light: sunPos.up ? P.mix(P.mix([255, 236, 205], [255, 150, 90], golden), [255, 120, 60], gpu * 0.5) : [222, 230, 245]
    readonly property real haze: Math.min(1, 0.25 + cpu * 0.75)
    // the deepest colour the nearest ridge reaches
    readonly property var deepest: P.mix(P.mix(sky.top, [14, 12, 22], 0.75), [4, 6, 10], night * 0.5)

    // ---------------------------------------------------------------- geometry
    readonly property int layers: 7
    function ridgeY(i, x) {
        const u = x / Math.max(1, width), d = i / (layers - 1)
        const base = horizon + vh * (0.05 + d * 0.5)
        const amp = vh * (0.1 + d * 0.16)
        const v = Math.sin(u * (1.6 + i * 0.45) + i * 1.9) * 0.6 + Math.sin(u * (3.7 + i * 0.6) + i * 0.7) * 0.32 + Math.sin(u * 11 + i * 3) * 0.04
        return base - (v * 0.5 + 0.5) * amp
    }
    // a ridge outline; from layer 3 on it carries a fir forest (many small tips)
    function ridgePath(i) {
        const pts = [Qt.point(-20, height + 10)]
        if (width < 50 || height < 50) return pts
        const forest = i >= 3
        if (!forest) {
            for (let x = -20; x <= width + 20; x += 12) pts.push(Qt.point(x, ridgeY(i, x)))
        } else {
            const d = i / (layers - 1), sz = (6 + d * 22) * k
            let x = -20, n = 0
            while (x <= width + 20) {
                const y = ridgeY(i, x), h = sz * (1.4 + P.rnd(n, i) * 1.6), w = sz * (0.8 + P.rnd(n, i + 9) * 0.5)
                pts.push(Qt.point(x, y)); pts.push(Qt.point(x + w * 0.5, y - h))
                x += w; n++
            }
        }
        pts.push(Qt.point(width + 20, height + 10))
        return pts
    }
    function layerColor(i) {
        const d = i / (layers - 1)
        return P.col(P.mix(P.mix(sky.bot, light, golden * 0.15 * (1 - d)), deepest, Math.pow(d, 0.85) * 0.92))
    }

    // ---------------------------------------------------------------- sky, sun, birds
    Rectangle {
        width: parent.width; height: scene.horizon + scene.vh * 0.1
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.75; color: P.col(P.mix(scene.sky.bot, scene.light, scene.golden * 0.25 * (1 - scene.night))) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, scene.light, scene.golden * 0.35 * (1 - scene.night))) }
        }
    }
    Stars { count: 140; band: 0.45; strength: scene.night }
    Item {
        x: (scene.sunPos.up ? scene.sunPos.x : 0.7) * scene.width
        y: Math.min(scene.horizon + scene.vh * 0.04, (scene.sunPos.up ? scene.sunPos.y : 0.2) * scene.height)
        visible: scene.sunPos.up || scene.night > 0.3
        Glow { r: scene.vh * (0.55 + scene.golden * 0.15); tone: scene.light; strength: 0.25 + scene.golden * 0.2 + scene.gpu * 0.15 }
        Rectangle {
            readonly property real r: scene.vh * (scene.sunPos.up ? 0.05 + scene.gpu * 0.015 : 0.025)
            x: -r; y: -r; width: r * 2; height: width; radius: width / 2
            color: P.col(scene.light, 0.97)
        }
    }

    // ---------------------------------------------------------------- the hills, back to front, haze in between
    Repeater {
        model: scene.layers
        Item {
            id: lay
            required property int index
            anchors.fill: parent
            Shape {
                anchors.fill: parent
                // forest ridges have many straight tips: the plain renderer is much faster there
                preferredRendererType: lay.index >= 3 ? Shape.GeometryRenderer : Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: scene.layerColor(lay.index)
                    PathPolyline { path: scene.ridgePath(lay.index) }
                }
            }
            Rectangle {                                            // haze resting in the valley in front of this ridge
                visible: lay.index < scene.layers - 1
                readonly property real span: scene.width
                width: scene.width * 2; height: scene.vh * (0.035 + lay.index * 0.012)
                x: -((scene.t * span / (140 + lay.index * 25) + lay.index * 211) % span)
                y: scene.ridgeY(lay.index + 1, scene.width / 2) - height * 0.65
                opacity: scene.haze * (0.55 - lay.index * 0.05) * (1 - scene.night * 0.4)
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.55; color: P.col(P.mix(scene.sky.bot, scene.light, 0.2 + scene.golden * 0.2), 0.7) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
    // a few tall firs in the very front
    Repeater {
        model: 6
        Shape {
            id: fir
            required property int index
            readonly property real px: scene.width * [0.02, 0.06, 0.11, 0.88, 0.93, 0.97][index]
            readonly property real ph: scene.vh * (0.2 + P.rnd(index, 3) * 0.14)
            x: px - width / 2; y: scene.height - ph + scene.vh * 0.02
            width: ph * 0.34; height: ph
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: P.col(P.mix(scene.deepest, [0, 0, 0], 0.3))
                PathPolyline {
                    path: { const w = fir.width, h = fir.height, pts = [Qt.point(w / 2, 0)]
                        for (let j = 1; j <= 6; ++j) { const y = h * j / 6.6, half = w / 2 * (0.2 + j * 0.13)
                            pts.push(Qt.point(w / 2 + half, y)); pts.push(Qt.point(w / 2 + half * 0.45, y)) }
                        pts.push(Qt.point(w * 0.56, h)); pts.push(Qt.point(w * 0.44, h))
                        for (let j = 6; j >= 1; --j) { const y = h * j / 6.6, half = w / 2 * (0.2 + j * 0.13)
                            pts.push(Qt.point(w / 2 - half * 0.45, y)); pts.push(Qt.point(w / 2 - half, y)) }
                        return pts }
                }
            }
        }
    }

    // ---------------------------------------------------------------- a flock for each notification
    Item {
        id: flock
        y: scene.height * 0.26
        visible: false
        Repeater {
            model: 9
            Text { required property int index; x: -index * 22 * scene.k; y: (index % 2 ? 1 : -1) * index * 5 * scene.k; text: "︶"; color: Qt.rgba(0.08, 0.08, 0.12, 0.7); font.pixelSize: 16 * scene.k }
        }
        NumberAnimation on x { id: fly; running: false; from: -60; to: scene.width + 240; duration: 15000; onFinished: flock.visible = false }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { if (!fly.running) { flock.visible = true; fly.restart() } } }
}
