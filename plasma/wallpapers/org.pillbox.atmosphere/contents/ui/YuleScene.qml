/*
 * Yule – a snowed-in village at the edge of the forest on a winter night. Snowy hills and
 * fir woods behind, small houses with warm windows and smoking chimneys, a tall decorated
 * fir with a string of lights, the moon, stars and a quiet snowfall. Always night: the time
 * of day only shifts it between a deep-blue dusk (afternoon, early evening) and deep night.
 * CPU: it snows harder. GPU: the lights glow brighter. Unread: a sleigh crosses the moon.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 20
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property string lightsMode: (env && env.cfg && env.cfg.YuleLights) || "warm"
    // the scene's own clock: 21:00 (blue dusk) in the afternoon, deep night around midnight
    readonly property real dusk: hour >= 12 && hour < 21 ? Math.max(0, 1 - Math.abs(hour - 17) / 4) : 0
    readonly property var sky: P.sky(23.5 - dusk * 2.2, [70, 92, 150], 0.18)
    readonly property real night: Math.max(0.75, sky.star)
    readonly property real dark: 1
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property real vh: Math.min(height, width * 0.6)
    readonly property real ground: height * 0.72
    readonly property var snowLit: P.mix([236, 242, 250], [118, 136, 176], 0.82)        // moonlit, never bright white
    readonly property var snowShade: P.mix([196, 208, 228], [52, 62, 96], 0.88)
    readonly property real glow: Math.min(1, 0.25 + dark * 0.6 + gpu * 0.5)
    readonly property var lightTones: lightsMode === "colorful" ? [[255, 90, 90], [255, 200, 80], [90, 200, 255], [130, 230, 140], [230, 120, 255]]
                                    : lightsMode === "cold" ? [[200, 230, 255], [160, 205, 255], [230, 240, 255]]
                                    : [[255, 214, 140], [255, 190, 110], [255, 230, 180]]

    // ---------------------------------------------------------------- sky
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.7; color: P.col(P.mix(scene.sky.bot, [120, 140, 190], 0.25)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, [190, 200, 230], 0.3)) }
        }
    }
    Stars { count: 160; band: 0.6; strength: scene.night }
    // the moon (or a pale winter sun by day)
    Item {
        id: moon
        x: scene.width * 0.74; y: scene.height * 0.16
        Glow { r: scene.vh * 0.32; tone: [210, 222, 255]; strength: 0.18 + scene.night * 0.12 }
        Rectangle {
            readonly property real r: scene.vh * 0.045
            x: -r; y: -r; width: r * 2; height: width; radius: r
            color: "#eef2fb"
            opacity: 0.95
        }
    }

    // ---------------------------------------------------------------- hills and forest behind the village
    function hillY(i, x) {
        const u = x / Math.max(1, width)
        return ground - vh * ([0.2, 0.11][i]) - Math.sin(u * (2.1 + i * 1.3) + i * 2) * vh * 0.04 - Math.sin(u * 5.3 + i) * vh * 0.015
    }
    Repeater {
        model: 2
        Shape {
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: scene.ground - scene.vh * 0.28; x2: 0; y2: scene.ground
                    GradientStop { position: 0; color: P.col(P.mix(scene.snowShade, scene.sky.bot, 0.45 - index * 0.2)) }
                    GradientStop { position: 1; color: P.col(P.mix(scene.snowShade, scene.sky.bot, 0.25 - index * 0.15)) }
                }
                PathPolyline { path: { const p = [Qt.point(-10, scene.height)]; if (scene.width < 50) return p
                    for (let x = -10; x <= scene.width + 10; x += 14) p.push(Qt.point(x, scene.hillY(index, x)))
                    p.push(Qt.point(scene.width + 10, scene.height)); return p } }
            }
        }
    }
    // a fir wood along the near hill (many small spiky tips: the plain renderer is much faster)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: P.col(P.mix([24, 40, 46], [12, 18, 30], scene.night))
            PathPolyline { path: {
                const p = [Qt.point(-10, scene.ground + 4)]
                if (scene.width < 50 || scene.height < 50) return p
                let x = -10, n = 0
                while (x < scene.width + 10) {
                    const base = scene.hillY(1, x) + scene.vh * 0.035
                    const h = (14 + P.rnd(n, 7) * 26) * scene.k, w = (8 + P.rnd(n, 8) * 7) * scene.k
                    p.push(Qt.point(x, base)); p.push(Qt.point(x + w / 2, base - h))
                    x += w; n++
                }
                p.push(Qt.point(scene.width + 10, scene.ground + 4)); return p } }
        }
    }
    // snow on the wood's tips: a soft white haze along the tree line
    Rectangle {
        y: scene.hillY(1, scene.width / 2) - scene.vh * 0.02; width: parent.width; height: scene.vh * 0.06
        opacity: 0.35
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: P.col(scene.snowLit, 0.6) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ---------------------------------------------------------------- the snowfield the village stands on
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: scene.ground - scene.vh * 0.04; x2: 0; y2: scene.height
                GradientStop { position: 0; color: P.col(scene.snowLit) }
                GradientStop { position: 1; color: P.col(scene.snowShade) }
            }
            PathPolyline { path: { const p = [Qt.point(-10, scene.height)]; if (scene.width < 50) return p
                for (let x = -10; x <= scene.width + 10; x += 16) p.push(Qt.point(x, scene.ground - Math.sin(x / scene.width * 3.1 + 0.4) * scene.vh * 0.02))
                p.push(Qt.point(scene.width + 10, scene.height)); return p } }
        }
    }

    // ---------------------------------------------------------------- the village
    readonly property var houses: {
        const out = []
        if (width < 50) return out
        const xs = [0.12, 0.2, 0.3, 0.41, 0.5, 0.86]
        for (let i = 0; i < xs.length; ++i) {
            const w = (110 + P.rnd(i, 1) * 90) * k, h = (70 + P.rnd(i, 2) * 50) * k
            out.push({ i: i, x: width * xs[i] - w / 2, w: w, h: h, roof: h * (0.55 + P.rnd(i, 3) * 0.25),
                       baseY: ground + (6 + P.rnd(i, 4) * 26) * k, chimney: P.rnd(i, 5) < 0.75, wall: P.rnd(i, 6) })
        }
        return out.sort((a, b) => a.baseY - b.baseY)
    }
    Repeater {
        model: scene.houses
        Item {
            id: house
            required property var modelData
            readonly property var d: modelData
            x: d.x; y: d.baseY - d.h
            width: d.w; height: d.h
            // walls
            Rectangle {
                anchors.fill: parent
                color: P.col(P.mix(house.d.wall < 0.33 ? [96, 52, 44] : house.d.wall < 0.66 ? [72, 60, 54] : [58, 66, 82], [22, 24, 36], scene.night * 0.6))
            }
            // windows: warm light that comes on in the evening
            Repeater {
                model: 2 + Math.floor(house.d.w / (60 * scene.k))
                Rectangle {
                    required property int index
                    readonly property int cols: 2 + Math.floor(house.d.w / (60 * scene.k))
                    readonly property bool lit: P.rnd(house.d.i * 10 + index, 9) < 0.75
                    x: (index + 0.5) * house.width / cols - width / 2
                    y: house.height * 0.32
                    width: 16 * scene.k; height: 20 * scene.k; radius: 2
                    color: lit ? P.col(P.mix([70, 70, 80], [255, 206, 120], scene.dark)) : P.col([40, 42, 52])
                    Rectangle { anchors.centerIn: parent; width: 1.5; height: parent.height; color: Qt.rgba(0, 0, 0, 0.35) }
                    Rectangle { anchors.centerIn: parent; width: parent.width; height: 1.5; color: Qt.rgba(0, 0, 0, 0.35) }
                    Glow { visible: parent.lit && scene.dark > 0.2; x: parent.width / 2; y: parent.height / 2; r: 46 * scene.k; tone: [255, 190, 110]; strength: 0.28 * scene.dark }
                }
            }
            // door
            Rectangle { x: house.width * 0.08; y: house.height * 0.48; width: 20 * scene.k; height: house.height * 0.52; radius: 2
                color: P.col(P.mix([60, 36, 30], [20, 16, 20], scene.night * 0.5)) }
            // chimney with smoke
            Rectangle {
                visible: house.d.chimney
                x: house.width * 0.7; y: -house.d.roof * 0.75; width: 16 * scene.k; height: house.d.roof * 0.6
                color: P.col(P.mix([84, 62, 56], [30, 28, 38], scene.night * 0.6))
                Rectangle { y: -4 * scene.k; x: -2 * scene.k; width: parent.width + 4 * scene.k; height: 7 * scene.k; radius: 3; color: P.col(scene.snowLit) }
                Repeater {
                    model: house.d.chimney ? 5 : 0
                    Rectangle {
                        required property int index
                        readonly property real f: ((scene.t * 0.06 + index / 5 + house.d.i * 0.13) % 1)
                        x: parent.width / 2 - width / 2 + Math.sin(f * 6 + house.d.i) * 10 * scene.k + f * 34 * scene.k
                        y: -f * 120 * scene.k
                        width: (10 + f * 34) * scene.k; height: width; radius: width / 2
                        color: P.col(P.mix([200, 205, 215], [120, 130, 155], scene.night))
                        opacity: 0.32 * (1 - f)
                    }
                }
            }
            // roof, thick with snow
            Shape {
                x: -12 * scene.k; y: -house.d.roof
                width: house.width + 24 * scene.k; height: house.d.roof + 6 * scene.k
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: P.col(P.mix([70, 44, 40], [26, 24, 34], scene.night * 0.6))
                    startX: 0; startY: house.d.roof
                    PathLine { x: (house.width + 24 * scene.k) / 2; y: 0 }
                    PathLine { x: house.width + 24 * scene.k; y: house.d.roof }
                    PathLine { x: 0; y: house.d.roof }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: P.col(scene.snowLit)
                    startX: -2 * scene.k; startY: house.d.roof + 2 * scene.k
                    PathLine { x: (house.width + 24 * scene.k) / 2; y: -4 * scene.k }
                    PathLine { x: house.width + 26 * scene.k; y: house.d.roof + 2 * scene.k }
                    PathQuad { x: house.width * 0.6; y: house.d.roof * 0.62; controlX: house.width * 0.95; controlY: house.d.roof * 0.66 }
                    PathQuad { x: -2 * scene.k; y: house.d.roof + 2 * scene.k; controlX: house.width * 0.2; controlY: house.d.roof * 0.5 }
                }
            }
            // snow at the foot of the walls
            Rectangle { x: -8 * scene.k; y: house.height - 6 * scene.k; width: house.width + 16 * scene.k; height: 12 * scene.k; radius: height / 2; color: P.col(scene.snowLit) }
        }
    }

    // ---------------------------------------------------------------- the decorated fir
    Item {
        id: tree
        readonly property real h: scene.vh * 0.5
        readonly property real w: h * 0.62
        x: scene.width * 0.68 - w / 2
        y: scene.ground + scene.vh * 0.06 - h
        width: w; height: h
        Glow { x: tree.w / 2; y: tree.h * 0.55; r: tree.h * 0.75; tone: [255, 200, 130]; strength: 0.12 * scene.glow * scene.dark }
        Rectangle { x: tree.w / 2 - width / 2; y: tree.h * 0.9; width: tree.w * 0.09; height: tree.h * 0.1; color: P.col([60, 40, 32]) }
        Repeater {
            model: 4
            Shape {
                id: layer
                required property int index
                readonly property real topY: tree.h * (index * 0.2)
                readonly property real botY: tree.h * (0.36 + index * 0.19)
                readonly property real half: tree.w / 2 * (0.42 + index * 0.19)
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: P.col(P.mix([30, 72, 54], [14, 32, 34], scene.night * 0.7))
                    startX: tree.w / 2; startY: layer.topY
                    PathLine { x: tree.w / 2 + layer.half; y: layer.botY }
                    PathQuad { x: tree.w / 2 - layer.half; y: layer.botY; controlX: tree.w / 2; controlY: layer.botY + tree.h * 0.05 }
                    PathLine { x: tree.w / 2; y: layer.topY }
                }
                ShapePath {                                     // snow on each layer's edge
                    strokeColor: P.col(scene.snowLit, 0.85); strokeWidth: Math.max(2, 4 * scene.k); fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: tree.w / 2 + layer.half * 0.92; startY: layer.botY - tree.h * 0.01
                    PathQuad { x: tree.w / 2 - layer.half * 0.92; y: layer.botY - tree.h * 0.01; controlX: tree.w / 2; controlY: layer.botY + tree.h * 0.04 }
                }
            }
        }
        // the string of lights: three garlands across the tree
        Repeater {
            model: 34
            Item {
                required property int index
                readonly property int row: index % 3
                readonly property real u: Math.floor(index / 3) / 11
                readonly property real yy: tree.h * (0.3 + row * 0.22) + Math.sin(u * Math.PI) * tree.h * 0.05 - u * tree.h * 0.06
                readonly property real half: tree.w / 2 * (0.4 + row * 0.22) * (yy / (tree.h * (0.36 + row * 0.19)))
                readonly property var tone: scene.lightTones[(index * 7) % scene.lightTones.length]
                readonly property real tw: 0.65 + 0.35 * Math.sin(scene.t * (1.3 + P.rnd(index, 4)) + index * 1.7)
                x: tree.w / 2 - half + u * half * 2
                y: yy
                Glow { r: 12 * scene.k; tone: parent.tone; strength: 0.5 * scene.glow * parent.tw }
                Rectangle { x: -2.5 * scene.k; y: -2.5 * scene.k; width: 5 * scene.k; height: width; radius: width / 2; color: P.col(parent.tone); opacity: 0.4 + 0.6 * scene.glow * parent.tw }
            }
        }
        // the star on top
        Item {
            x: tree.w / 2; y: tree.h * 0.01
            Glow { r: 40 * scene.k; tone: [255, 220, 140]; strength: 0.55 * scene.glow }
            Text { anchors.centerIn: parent; text: "★"; color: "#ffe4a0"; font.pixelSize: 30 * scene.k; opacity: 0.6 + 0.4 * scene.glow }
        }
    }

    // ---------------------------------------------------------------- foreground drift and small firs
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: P.col(P.mix(scene.snowLit, [255, 255, 255], 0.2))
            PathPolyline { path: { const p = [Qt.point(-10, scene.height)]; if (scene.width < 50) return p
                for (let x = -10; x <= scene.width + 10; x += 16) p.push(Qt.point(x, scene.height * 0.9 - Math.max(0, Math.sin(x / scene.width * 4.2 + 1)) * scene.vh * 0.05))
                p.push(Qt.point(scene.width + 10, scene.height)); return p } }
        }
    }
    Repeater {
        model: 4
        Shape {
            id: fir
            required property int index
            readonly property real ph: scene.vh * (0.16 + P.rnd(index, 3) * 0.1)
            x: scene.width * [0.03, 0.07, 0.95, 0.98][index] - width / 2
            y: scene.height - ph * 0.98
            width: ph * 0.5; height: ph
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: P.col(P.mix([22, 46, 42], [10, 18, 26], scene.night))
                PathPolyline { path: { const w = fir.width, h = fir.height, pts = [Qt.point(w / 2, 0)]
                    for (let j = 1; j <= 5; ++j) { const y = h * j / 5.6, half = w / 2 * (0.25 + j * 0.15); pts.push(Qt.point(w / 2 + half, y)); pts.push(Qt.point(w / 2 + half * 0.5, y)) }
                    pts.push(Qt.point(w / 2, h))
                    for (let j = 5; j >= 1; --j) { const y = h * j / 5.6, half = w / 2 * (0.25 + j * 0.15); pts.push(Qt.point(w / 2 - half * 0.5, y)); pts.push(Qt.point(w / 2 - half, y)) }
                    return pts } }
            }
        }
    }

    // ---------------------------------------------------------------- snowfall: a gentle drift, denser under load
    // far flakes are small and slow, near ones larger, a little faster and swaying more
    Repeater {
        model: 110 + Math.round(scene.cpu * 120)
        Rectangle {
            required property int index
            readonly property real depth: P.rnd(index, 4)                         // 0 far … 1 near
            readonly property real sp: 0.012 + depth * 0.022 + P.rnd(index, 2) * 0.006
            readonly property real fy: (scene.t * sp + P.rnd(index, 3)) % 1
            x: P.rnd(index, 1) * scene.width + Math.sin(scene.t * (0.35 + depth * 0.4) + index * 1.7) * (8 + depth * 22) * scene.k
            y: fy * (scene.height + 40) - 20
            width: (1.2 + depth * 3.4) * scene.k; height: width; radius: width / 2
            color: "#eef3ff"
            opacity: (0.35 + depth * 0.5) * Math.min(1, (1 - fy) * 6)                // melts away near the bottom
        }
    }

    // ---------------------------------------------------------------- a sleigh across the moon for each notification
    Item {
        id: sleigh
        visible: false
        y: scene.height * 0.15
        Repeater {                                             // reindeer: small leaping silhouettes in a row
            model: 4
            Shape {
                required property int index
                x: 40 * scene.k + index * 26 * scene.k
                y: Math.sin(scene.t * 8 + index) * 2 * scene.k
                width: 22 * scene.k; height: 18 * scene.k
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"; fillColor: "#151a26"
                    PathPolyline { path: { const s = scene.k; return [Qt.point(0, 8 * s), Qt.point(14 * s, 6 * s), Qt.point(17 * s, 1 * s), Qt.point(20 * s, 0), Qt.point(19 * s, 4 * s), Qt.point(16 * s, 7 * s),
                        Qt.point(16 * s, 10 * s), Qt.point(19 * s, 16 * s), Qt.point(15 * s, 11 * s), Qt.point(6 * s, 11 * s), Qt.point(2 * s, 16 * s), Qt.point(3 * s, 10 * s), Qt.point(0, 8 * s)] } }
                }
            }
        }
        Shape {                                                // the sleigh
            width: 36 * scene.k; height: 18 * scene.k; y: 2 * scene.k
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: "#151a26"
                PathPolyline { path: { const s = scene.k; return [Qt.point(2 * s, 2 * s), Qt.point(30 * s, 6 * s), Qt.point(30 * s, 12 * s), Qt.point(34 * s, 15 * s), Qt.point(4 * s, 15 * s), Qt.point(0, 12 * s), Qt.point(2 * s, 2 * s)] } }
            }
        }
        NumberAnimation on x { id: ride; running: false; from: scene.width * 0.45; to: scene.width + 80; duration: 9000; onFinished: sleigh.visible = false }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { if (!ride.running) { sleigh.visible = true; ride.restart() } } }
}
