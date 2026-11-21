/*
 * Neon – a big city at night, in depth. A hazy far skyline under the glow of the
 * city, towers with lit windows and blinking aircraft lights, near buildings with
 * roof details, vertical neon signs and a wet street that mirrors them.
 * CPU: more windows light up. GPU: the signs glow brighter. Unread: rain
 * (or always, as an option).
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 22
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property real eve: hour >= 17 && hour < 23 ? Math.min(1, (hour - 17) / 1.5) * Math.min(1, (23 - hour) / 1.5) : 0
    readonly property var sky: P.sky(hour, [110, 60, 170], 0.2 + eve * 0.35)
    readonly property real night: sky.star
    readonly property real dark: Math.max(night, eve * 0.6)
    readonly property real k: Math.max(0.5, height / 1440)
    readonly property real street: height * 0.86
    readonly property real lit: Math.min(0.95, 0.06 + dark * 0.34 + cpu * 0.55)
    readonly property real signGlow: Math.min(1, 0.12 + dark * 0.55 + gpu * 0.6)
    readonly property string signMode: (env && env.cfg && env.cfg.NeonSigns) || "mixed"
    readonly property var signTones: signMode === "pink" ? [[255, 80, 170], [255, 120, 210], [230, 90, 255]]
                                   : signMode === "cyan" ? [[70, 220, 255], [90, 255, 220], [110, 170, 255]]
                                   : [[255, 70, 160], [60, 220, 255], [170, 100, 255], [255, 170, 60]]
    property real wet: 0
    Behavior on wet { NumberAnimation { duration: 4000 } }

    // ---------------------------------------------------------------- the city as data (built once per size)
    // three rows: 0 far (hazy silhouettes), 1 mid (towers with windows), 2 near (wider, roof details)
    readonly property var blocks: {
        const out = []
        if (width < 50 || height < 50) return out
        const rows = [{ h0: 0.28, h1: 0.5, w0: 50, w1: 140, gap: -6 }, { h0: 0.22, h1: 0.56, w0: 70, w1: 170, gap: 6 }, { h0: 0.18, h1: 0.4, w0: 140, w1: 280, gap: 12 }]
        for (let r = 0; r < 3; ++r) {
            let x = -30, i = 0
            const R = rows[r]
            while (x < width + 30) {
                const w = (R.w0 + P.rnd(i, r * 11 + 1) * (R.w1 - R.w0)) * k
                const h = height * (R.h0 + Math.pow(P.rnd(i, r * 11 + 2), 1.6) * (R.h1 - R.h0))
                out.push({ x: x, w: w, h: h, row: r, id: i, tall: h > height * (R.h1 - 0.06), roof: P.rnd(i, r * 11 + 3) })
                x += w + R.gap * k; i++
            }
        }
        return out
    }
    readonly property var windowsList: {
        const out = []
        const mids = blocks.filter(b => b.row >= 1)
        const cells = mids.reduce((n, b) => n + Math.floor(b.w / (15 * k)) * Math.floor(b.h / (22 * k)), 0)
        const keep = Math.min(0.55, 1000 / Math.max(1, cells))
        for (const b of mids) {
            const cols = Math.floor((b.w - 12 * k) / (15 * k)), rows = Math.floor((b.h - 26 * k) / (22 * k))
            for (let r = 0; r < rows; ++r) for (let c = 0; c < cols; ++c) {
                const id = b.row * 100000 + b.id * 400 + r * 20 + c
                if (P.rnd(id, 5) < keep) out.push({ x: b.x + 8 * k + c * 15 * k, y: street - b.h + 16 * k + r * 22 * k, near: b.row === 2, q: P.rnd(id, 6), cool: P.rnd(id, 7) < 0.18 })
            }
        }
        return out
    }
    readonly property var signs: {
        const out = []
        let n = 0
        for (const b of blocks) {
            if (b.row !== 2 || n >= 7 || P.rnd(b.id, 9) > 0.55) continue
            const vertical = P.rnd(b.id, 10) < 0.6
            out.push({ x: b.x + b.w * (vertical ? 0.12 : 0.15), y: street - b.h * (vertical ? 0.85 : 0.98) - (vertical ? 0 : 26 * k),
                       w: vertical ? 34 * k : b.w * 0.75, h: vertical ? b.h * 0.6 : 34 * k, i: n })
            n++
        }
        return out
    }

    // ---------------------------------------------------------------- sky with the city's glow
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.55; color: P.col(P.mix(scene.sky.bot, [120, 60, 150], scene.dark * 0.35)) }
            GradientStop { position: 0.8; color: P.col(P.mix(scene.sky.bot, [235, 120, 90], scene.dark * 0.35)) }
        }
    }
    Stars { count: 50; band: 0.3; strength: scene.night * 0.5 }
    Item {
        x: scene.width * 0.78; y: scene.height * 0.14
        visible: scene.night > 0.35
        Glow { r: scene.height * 0.12; tone: [230, 232, 250]; strength: 0.18 }
        Rectangle { x: -scene.height * 0.022; y: x; width: -x * 2; height: width; radius: width / 2; color: "#e8ecf6" }
    }

    // ---------------------------------------------------------------- buildings, far to near
    Repeater {
        model: scene.blocks
        Item {
            id: bld
            required property var modelData
            readonly property int row: modelData.row
            x: modelData.x; y: scene.street - modelData.h; width: modelData.w; height: modelData.h
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: bld.row === 0 ? P.col(P.mix(scene.sky.bot, [40, 28, 60], 0.55)) : bld.row === 1 ? P.col(P.mix(scene.sky.top, [16, 14, 26], 0.75)) : P.col(P.mix(scene.sky.top, [8, 8, 14], 0.88)) }
                    GradientStop { position: 1; color: bld.row === 0 ? P.col(P.mix(scene.sky.bot, [70, 40, 70], 0.45)) : bld.row === 1 ? P.col(P.mix(scene.sky.top, [10, 9, 18], 0.85)) : P.col(P.mix(scene.sky.top, [5, 5, 9], 0.93)) }
                }
            }
            // roof details on the near row: a water tower, an antenna or a stepped top
            Rectangle {
                visible: bld.row === 2 && bld.modelData.roof < 0.33
                x: parent.width * 0.6; y: -height; width: 22 * scene.k; height: 26 * scene.k; radius: 3
                color: P.col(P.mix(scene.sky.top, [8, 8, 14], 0.88))
            }
            Rectangle {
                visible: bld.row >= 1 && bld.modelData.roof >= 0.33 && bld.modelData.roof < 0.6
                x: parent.width * 0.5; y: -height; width: Math.max(1.5, 2 * scene.k); height: parent.height * 0.18
                color: P.col(P.mix(scene.sky.top, [8, 8, 14], 0.85))
            }
            Rectangle {
                visible: bld.row >= 1 && bld.modelData.roof >= 0.6
                x: parent.width * 0.2; y: -height; width: parent.width * 0.6; height: 18 * scene.k
                color: P.col(P.mix(scene.sky.top, bld.row === 2 ? [8, 8, 14] : [16, 14, 26], bld.row === 2 ? 0.88 : 0.75))
            }
            // aircraft warning light on the tallest towers
            Rectangle {
                visible: bld.modelData.tall && bld.row <= 1 && scene.dark > 0.2
                x: parent.width / 2 - width / 2; y: -height - (bld.modelData.roof >= 0.33 && bld.modelData.roof < 0.6 ? parent.height * 0.18 : 0)
                width: 5 * scene.k; height: width; radius: width / 2
                color: "#ff4040"
                opacity: (Math.sin(scene.t * 2.2 + bld.modelData.id) > 0.3 ? 1 : 0.15) * scene.dark
            }
        }
    }
    Repeater {
        model: scene.windowsList
        Rectangle {
            required property var modelData
            visible: modelData.q < scene.lit
            x: modelData.x; y: modelData.y; width: 7 * scene.k; height: 11 * scene.k
            color: modelData.cool ? "#a8dcff" : "#ffd08a"
            opacity: modelData.near ? 0.9 : 0.55
        }
    }
    // low haze in the street canyons
    Rectangle {
        y: scene.street - scene.height * 0.18; width: parent.width; height: scene.height * 0.2
        opacity: 0.35 + scene.dark * 0.25
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.bot, [200, 100, 140], scene.dark * 0.4), 0.5) }
        }
    }

    // the street
    Rectangle {
        y: scene.street; width: parent.width; height: parent.height - scene.street
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(P.mix(scene.sky.top, [14, 12, 20], 0.8)) }
            GradientStop { position: 1; color: P.col(P.mix(scene.sky.top, [6, 6, 10], 0.9)) }
        }
    }
    Rectangle {                                                  // kerb light line
        y: scene.street; width: parent.width; height: Math.max(1, 2 * scene.k)
        color: P.col(P.mix([255, 190, 140], scene.sky.bot, 0.5), 0.25 + scene.dark * 0.3)
    }

    // ---------------------------------------------------------------- neon signs and their reflections
    Repeater {
        model: scene.signs
        Item {
            id: sign
            required property var modelData
            readonly property var tone: scene.signTones[modelData.i % scene.signTones.length]
            readonly property real glow: scene.signGlow * (0.86 + 0.14 * Math.sin(scene.t * 6 + modelData.i * 2.3)) * (P.rnd(modelData.i, Math.floor(scene.t * 3)) > 0.04 ? 1 : 0.4)
            x: modelData.x; y: modelData.y
            Item { x: sign.modelData.w / 2; y: sign.modelData.h / 2; Glow { r: Math.max(sign.modelData.w, sign.modelData.h) * 1.1; tone: sign.tone; strength: 0.5 * sign.glow } }
            Rectangle {
                width: sign.modelData.w; height: sign.modelData.h; radius: Math.min(width, height) * 0.35
                color: P.col(sign.tone, 0.28 * sign.glow)
                border.width: Math.max(2, 4 * scene.k); border.color: P.col(sign.tone, Math.min(1, sign.glow))
            }
            // the sign's mirror on the wet street
            Rectangle {
                visible: scene.wet > 0.02
                y: (scene.street - sign.modelData.y) + (scene.street - sign.modelData.y - sign.modelData.h) * 0 + 4 * scene.k
                width: sign.modelData.w; height: (scene.height - scene.street) * 0.95
                opacity: scene.wet * sign.glow * 0.8
                gradient: Gradient {
                    GradientStop { position: 0; color: P.col(sign.tone, 0.55) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }
    Precip { id: rain }
    Timer { id: dry; interval: 60000; onTriggered: if (!scene.alwaysRain) scene.wet = 0 }
    readonly property bool alwaysRain: !!(env && env.cfg && env.cfg.NeonRain === "on")
    function applyRain() { if (alwaysRain) { rain.start(86400 * 20); wet = 1 } else { rain.active = false; dry.restart() } }
    onAlwaysRainChanged: applyRain()
    Component.onCompleted: if (alwaysRain) applyRain()
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { if (scene.alwaysRain) return; rain.start(25); scene.wet = 1; dry.restart() } }
}
