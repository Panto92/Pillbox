/*
 * Neon – a city at night. CPU: more windows light up. GPU: the signs glow.
 * Unread: rain on a wet street that mirrors the signs. Evening: a violet sky.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property real eve: hour >= 17 && hour < 23 ? Math.min(1, (hour - 17) / 1.5) * Math.min(1, (23 - hour) / 1.5) : 0
    readonly property var sky: P.sky(hour, [110, 60, 170], 0.18 + eve * 0.35)
    readonly property real night: sky.star
    readonly property real s: height / 1440
    readonly property real street: height * 0.9
    readonly property real lit: Math.min(0.95, 0.08 + night * 0.3 + cpu * 0.55)
    property real wet: 0
    Behavior on wet { NumberAnimation { duration: 4000 } }

    readonly property var blocks: {
        const out = []
        if (width < 50 || height < 50) return out          // not laid out yet
        for (let row = 0; row < 2; ++row) {
            let x = -20, i = 0
            while (x < width + 20) {
                const w = (70 + P.rnd(i, row * 7 + 1) * 130) * s
                const h = height * (row === 0 ? 0.3 + P.rnd(i, row * 7 + 2) * 0.38 : 0.16 + P.rnd(i, row * 7 + 3) * 0.3)
                out.push({ x: x, w: w, h: h, row: row })
                x += w + (row === 0 ? -10 : 4) * s; i++
            }
        }
        return out
    }
    readonly property var windowsList: {
        const out = [], dims = blocks.map(k => [Math.floor((k.w - 14 * s) / (16 * s)), Math.floor((k.h - 24 * s) / (24 * s))])
        const cells = dims.reduce((n, d) => n + Math.max(0, d[0]) * Math.max(0, d[1]), 0)
        const keep = Math.min(0.5, 900 / Math.max(1, cells))       // at most ~900 windows, spread over the whole city
        for (let b = 0; b < blocks.length; ++b) {
            const k = blocks[b], cols = dims[b][0], rows = dims[b][1]
            for (let r = 0; r < rows; ++r) for (let c = 0; c < cols; ++c) {
                const id = b * 1000 + r * 40 + c
                if (P.rnd(id, 5) < keep) out.push({ x: k.x + 9 * s + c * 16 * s, y: street - k.h + 14 * s + r * 24 * s, row: k.row, k: P.rnd(id, 6), cool: P.rnd(id, 7) < 0.15 })
            }
        }
        return out
    }
    readonly property var signs: {
        const mode = ((env && env.cfg && env.cfg.NeonSigns) || "mixed")
        const tones = mode === "pink" ? [[255, 80, 170], [255, 110, 200], [230, 90, 255]]
                    : mode === "cyan" ? [[70, 220, 255], [90, 255, 220], [110, 170, 255]]
                    : [[255, 80, 170], [70, 220, 255], [170, 110, 255], [255, 180, 70], [90, 255, 190]]
        const out = []
        let n = 0
        for (let b = 0; b < blocks.length && n < 6; ++b) {
            const k = blocks[b]
            if (k.row !== 1 || P.rnd(b, 9) > 0.45 || k.w < 90 * s) continue
            out.push({ x: k.x + k.w * 0.18, y: street - k.h - 30 * s, w: k.w * 0.64, tone: tones[n % tones.length], i: n }); n++
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: P.col(scene.sky.top) }
            GradientStop { position: 0.9; color: P.col(scene.sky.bot) }
        }
    }
    Stars { count: 60; band: 0.35; strength: scene.night * 0.6 }
    Repeater {
        model: scene.blocks
        Rectangle {
            required property var modelData
            x: modelData.x; y: scene.street - modelData.h; width: modelData.w; height: modelData.h
            color: modelData.row === 0 ? P.col(P.mix(scene.sky.bot, [14, 12, 24], 0.72)) : P.col(P.mix(scene.sky.top, [8, 8, 14], 0.85))
        }
    }
    Repeater {
        model: scene.windowsList
        Rectangle {
            required property var modelData
            visible: modelData.k < scene.lit
            x: modelData.x; y: modelData.y; width: 7 * scene.s; height: 10 * scene.s
            color: modelData.cool ? "#9fd8ff" : "#ffd28c"
            opacity: modelData.row === 0 ? 0.45 : 0.85
        }
    }
    Rectangle {
        y: scene.street; width: parent.width; height: parent.height - scene.street
        color: P.col(P.mix(scene.sky.top, [12, 11, 18], 0.8))
    }
    Repeater {
        model: scene.signs
        Item {
            id: sign
            required property var modelData
            readonly property real glow: (0.15 + scene.night * 0.35 + scene.gpu * 0.7) * (0.88 + 0.12 * Math.sin(scene.t * 5 + modelData.i * 2))
            x: modelData.x; y: modelData.y
            Item { x: sign.modelData.w / 2; y: 10 * scene.s; Glow { r: sign.modelData.w * 0.8; tone: sign.modelData.tone; strength: 0.3 * sign.glow } }
            Rectangle {
                width: sign.modelData.w; height: 20 * scene.s; radius: height / 2
                color: P.col(sign.modelData.tone, 0.18 * sign.glow)
                border.width: Math.max(1.5, 2 * scene.s); border.color: P.col(sign.modelData.tone, Math.min(1, sign.glow))
            }
            // its mirror image on the wet street
            Rectangle {
                visible: scene.wet > 0.02
                y: scene.street - sign.modelData.y + 4 * scene.s
                width: sign.modelData.w; height: (scene.height - scene.street) * 0.9
                opacity: scene.wet * sign.glow * 0.6
                gradient: Gradient {
                    GradientStop { position: 0; color: P.col(sign.modelData.tone, 0.5) }
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
