/*
 * Tide – a rocky coast at the open sea. Long clouds drift over a wide sky, a
 * headland with a lighthouse sits on the horizon (its beam sweeps the sea at
 * night), the sea rolls in from fine distant lines to large swells, and the sun or
 * moon lays a glittering path on the water.
 * CPU: higher waves. GPU: the sea glows (bioluminescence at night). Unread: rain.
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
    readonly property var sky: P.sky(hour, [70, 110, 140], 0.14)
    readonly property real night: sky.star
    readonly property var sunPos: P.sun(hour, 0.56)
    readonly property real horizon: height * 0.56
    readonly property real vh: Math.min(height, width * 0.6)
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property real golden: Math.max(Math.max(0, 1 - Math.abs(hour - 7) / 1.6), Math.max(0, 1 - Math.abs(hour - 18.8) / 1.6))
    readonly property real sea: ({ calm: 0.5, normal: 1, rough: 1.9 })[(env && env.cfg && env.cfg.TideWaves) || "normal"] || 1
    readonly property real swell: sea * (1 + cpu * 0.9)
    readonly property bool lightUp: sunPos.up || night > 0.3
    readonly property var light: sunPos.up ? P.mix([255, 240, 214], [255, 168, 112], golden) : [222, 230, 245]
    readonly property real lightX: (sunPos.up ? sunPos.x : 0.38) * width
    readonly property var deep: P.mix(P.mix(sky.top, [8, 26, 38], 0.55), [3, 8, 14], night * 0.6)
    readonly property var shallow: P.mix(P.mix(sky.bot, [40, 92, 110], 0.45), [10, 22, 32], night * 0.55)

    // ---------------------------------------------------------------- sky
    Rectangle {
        width: parent.width; height: scene.horizon
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.7; color: P.col(P.mix(scene.sky.bot, [255, 180, 140], scene.golden * 0.3 * (1 - scene.night))) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, [255, 200, 160], scene.golden * 0.4 * (1 - scene.night))) }
        }
    }
    Stars { count: 150; band: 0.5; strength: scene.night }
    Item {
        x: scene.lightX
        y: Math.min(scene.horizon - scene.vh * 0.04, (scene.sunPos.up ? scene.sunPos.y : 0.2) * scene.height)
        visible: scene.lightUp
        Glow { r: scene.vh * 0.45; tone: scene.light; strength: 0.2 + scene.golden * 0.2 }
        Rectangle {
            readonly property real r: scene.vh * (scene.sunPos.up ? 0.04 : 0.024)
            x: -r; y: -r; width: r * 2; height: width; radius: width / 2
            color: P.col(scene.light, 0.96)
        }
    }
    // long, soft cloud streaks drifting slowly
    Repeater {
        model: 7
        Rectangle {
            required property int index
            readonly property real span: scene.width * 1.6
            readonly property real w: scene.width * (0.35 + P.rnd(index, 1) * 0.4)
            x: ((P.rnd(index, 2) * span + scene.t * span / (260 + index * 40)) % span) - w * 0.6
            y: scene.horizon * (0.12 + P.rnd(index, 3) * 0.62)
            width: w; height: scene.vh * (0.012 + P.rnd(index, 4) * 0.03)
            radius: height / 2
            opacity: (0.18 + P.rnd(index, 5) * 0.25) * (1 - scene.night * 0.5)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: P.col(P.mix(scene.sky.bot, [255, 236, 220], 0.45 + scene.golden * 0.2)) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // ---------------------------------------------------------------- headland with a lighthouse
    function tri(x) { const f = x - Math.floor(x); return 1 - Math.abs(2 * f - 1) }
    readonly property real capeX: width * 0.74
    function capeY(x) {
        const u = (x - width * 0.52) / (width * 0.48)
        const rise = Math.min(1, Math.max(0, u * 3.2))
        return horizon - rise * (0.75 + 0.15 * Math.sin(u * 23) + 0.1 * tri(u * 7.3)) * vh * 0.075
    }
    readonly property var cape: {
        const pts = [Qt.point(width * 0.52, horizon + 2)]
        if (width < 50) return pts
        for (let x = width * 0.52; x <= width + 10; x += 8) {
            pts.push(Qt.point(x, capeY(x)))
        }
        pts.push(Qt.point(width + 10, horizon + 2))
        return pts
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: scene.horizon - scene.vh * 0.08; x2: 0; y2: scene.horizon
                GradientStop { position: 0; color: P.col(P.mix(scene.sky.bot, [30, 34, 44], 0.55)) }
                GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [12, 14, 20], 0.7)) }
            }
            PathPolyline { path: scene.cape }
        }
    }
    Item {                                                       // the lighthouse
        id: tower
        readonly property real hgt: scene.vh * 0.06
        x: scene.capeX; y: scene.capeY(scene.capeX) + 2
        Rectangle {                                              // body, slightly tapered by two layers
            x: -tower.hgt * 0.07; y: -tower.hgt; width: tower.hgt * 0.14; height: tower.hgt
            color: P.col(P.mix([230, 232, 236], scene.sky.top, 0.35 + scene.night * 0.45))
        }
        Rectangle { x: -tower.hgt * 0.07; y: -tower.hgt * 0.62; width: tower.hgt * 0.14; height: tower.hgt * 0.1; color: P.col(P.mix([190, 60, 60], scene.sky.top, 0.3 + scene.night * 0.4)) }
        Rectangle { x: -tower.hgt * 0.07; y: -tower.hgt * 0.32; width: tower.hgt * 0.14; height: tower.hgt * 0.1; color: P.col(P.mix([190, 60, 60], scene.sky.top, 0.3 + scene.night * 0.4)) }
        Rectangle { x: -tower.hgt * 0.1; y: -tower.hgt * 1.12; width: tower.hgt * 0.2; height: tower.hgt * 0.14; radius: 2; color: Qt.rgba(1, 0.92, 0.7, 0.35 + scene.night * 0.65) }
        Item {                                                   // the lamp's glow (not part of the turning beam)
            y: -tower.hgt * 1.05
            visible: scene.night > 0.25
            opacity: (scene.night - 0.25) * 1.3
            Glow { r: tower.hgt * 0.6; tone: [255, 236, 190]; strength: 0.7 }
        }
        Item {                                                   // the beam: flat over the sea; a turning lamp seen from the side
            id: beam
            y: -tower.hgt * 1.05
            visible: scene.night > 0.25
            opacity: (scene.night - 0.25) * 1.3
            readonly property real phase: scene.t * 0.9
            readonly property real reach: Math.cos(phase)            // +1 right … −1 left, 0 = pointing at us / away
            transform: Scale { xScale: beam.reach; yScale: 1 }
            Shape {
                readonly property real len: scene.width * 0.6
                x: 0; y: -scene.vh * 0.012; width: len; height: scene.vh * 0.03
                opacity: 0.35 + 0.65 * Math.abs(beam.reach)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: scene.width * 0.6; y2: 0
                        GradientStop { position: 0; color: Qt.rgba(1, 0.95, 0.8, 0.4) }
                        GradientStop { position: 1; color: Qt.rgba(1, 0.95, 0.8, 0) }
                    }
                    PathPolyline { path: [Qt.point(0, scene.vh * 0.011), Qt.point(scene.width * 0.6, 0), Qt.point(scene.width * 0.6, scene.vh * 0.03), Qt.point(0, scene.vh * 0.014)] }
                }
            }

        }
    }

    // ---------------------------------------------------------------- the sea
    Rectangle {
        y: scene.horizon; width: parent.width; height: parent.height - scene.horizon
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.shallow, scene.sky.bot, 0.35)) }
            GradientStop { position: 0.35; color: P.col(scene.shallow) }
            GradientStop { position: 1; color: P.col(scene.deep) }
        }
    }
    Rectangle {                                                  // bioluminescence / glow from the GPU
        visible: scene.gpu > 0.03
        y: scene.horizon; width: parent.width; height: parent.height - scene.horizon
        opacity: scene.gpu * (0.4 + scene.night * 0.6)
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: P.col([40, 220, 200], 0.45) }
        }
    }
    // glittering path of light
    Repeater {
        model: scene.lightUp ? 30 : 0
        Rectangle {
            required property int index
            readonly property real d: index / 29
            readonly property real base: (14 + d * d * 180) * scene.k
            width: base * (0.45 + 0.55 * Math.abs(Math.sin(scene.t * 1.7 + index * 2.1)))
            height: Math.max(1, (1.5 + d * 3) * scene.k)
            radius: height / 2
            x: scene.lightX - width / 2 + Math.sin(scene.t * 0.8 + index * 1.3) * (6 + d * 40) * scene.k
            y: scene.horizon + 3 + Math.pow(d, 1.7) * (scene.height - scene.horizon) * 0.95
            color: P.col(scene.light, (0.55 - d * 0.25) * (0.55 + scene.golden * 0.45))
        }
    }
    // wave lines: many thin crests far away, larger swells closer – each a static path slid sideways
    Repeater {
        model: 12
        Shape {
            id: wv
            required property int index
            readonly property real d: index / 11                        // 0 = horizon … 1 = front
            readonly property real wl: scene.width / (26 - index * 1.6)
            readonly property real amp: (1.2 + d * d * 16) * scene.k * scene.swell
            width: scene.width + wl; height: amp * 2 + 6
            x: -((scene.t * wl / (7 - d * 3) + index * 97) % wl)
            y: scene.horizon + Math.pow((index + 0.6) / 12.6, 1.8) * (scene.height - scene.horizon) - amp
            opacity: 0.18 + d * 0.5
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: P.col(P.mix(P.mix(scene.sky.bot, [235, 245, 250], 0.55), scene.light, scene.golden * 0.3), 0.55)
                strokeWidth: (0.8 + wv.d * 2.2) * scene.k
                capStyle: ShapePath.RoundCap
                PathPolyline {
                    path: {
                        const pts = [], w = wv.width, a = wv.amp, l = wv.wl
                        if (l <= 1) return pts
                        // a sharper crest and a long, flat trough
                        for (let x = 0; x <= w; x += Math.max(4, l / 18)) {
                            const ph = (x / l) % 1
                            const y = ph < 0.35 ? -Math.sin(ph / 0.35 * Math.PI) : 0.25 * Math.sin((ph - 0.35) / 0.65 * Math.PI)
                            pts.push(Qt.point(x, a + y * a))
                        }
                        return pts
                    }
                }
            }
        }
    }
    // two large foreground swells with a lit crest
    Repeater {
        model: 2
        Shape {
            id: sw
            required property int index
            readonly property real wl: scene.width / (2.2 + index * 1.1)
            readonly property real amp: scene.vh * (0.02 + index * 0.012) * scene.swell
            readonly property real baseY: scene.height - scene.vh * (0.13 - index * 0.07)
            width: scene.width + wl; height: scene.height - baseY + amp * 2
            x: -((scene.t * wl / (14 - index * 4) + index * 311) % wl)
            y: baseY - amp
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: P.col(P.mix(scene.sky.bot, [240, 248, 252], 0.6), 0.35)
                strokeWidth: 2 * scene.k
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: sw.amp * 4
                    GradientStop { position: 0; color: P.col(P.mix(scene.shallow, [120, 170, 180], 0.25 * (1 - scene.night)), 0.95) }
                    GradientStop { position: 1; color: P.col(scene.deep, 0.98) }
                }
                PathPolyline {
                    path: {
                        const pts = [], w = sw.width, a = sw.amp, l = sw.wl
                        if (l <= 1) return pts
                        for (let x = 0; x <= w; x += Math.max(6, l / 40)) {
                            const ph = (x / l) % 1
                            pts.push(Qt.point(x, a - Math.pow(Math.sin(ph * Math.PI), 2.2) * a))
                        }
                        pts.push(Qt.point(w, sw.height + 4)); pts.push(Qt.point(0, sw.height + 4))
                        return pts
                    }
                }
            }
        }
    }

    Precip { id: rain }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { rain.start(20) } }
}
