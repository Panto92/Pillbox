/*
 * Grid – a calm field of dots. The dots are holes in a single static layer, so
 * whatever moves underneath only lights the dots: a wave sweeps through (CPU),
 * the centre glows (GPU), a ping spreads out (unread). Background follows the day.
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
    readonly property var sky: P.sky(hour, [90, 110, 140], 0.15)
    readonly property var base: P.mix(sky.top, [8, 10, 14], 0.55)
    readonly property color baseColor: P.col(base)

    // what shows through the dots
    Rectangle { anchors.fill: parent; color: P.col(P.mix(scene.base, [255, 255, 255], 0.22)) }
    Rectangle {
        readonly property real span: scene.width * 1.5
        width: scene.width * 0.3; height: parent.height
        x: ((scene.t * span / 28) % span) - width
        opacity: 0.3 + scene.cpu * 0.7
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(0.8, 0.9, 0.96, 0.9) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Item {
        x: scene.width / 2; y: scene.height / 2
        visible: scene.gpu > 0.03
        Glow { r: scene.height * 0.5; tone: [255, 170, 110]; strength: scene.gpu }
    }
    Rectangle {
        id: ping
        anchors.centerIn: parent
        width: 10; height: width; radius: width / 2
        color: "transparent"; border.width: 60; border.color: Qt.rgba(0.85, 0.93, 1, 0.9); opacity: 0
        ParallelAnimation {
            id: pingAnim
            NumberAnimation { target: ping; property: "width"; from: 40; to: Math.max(scene.width, scene.height) * 1.3; duration: 3200; easing.type: Easing.OutCubic }
            NumberAnimation { target: ping; property: "opacity"; from: 1; to: 0; duration: 3200 }
        }
    }
    // the static mask: background colour with transparent dots, painted once per colour change
    Canvas {
        id: mask
        anchors.fill: parent
        readonly property color fill: scene.baseColor
        readonly property real factor: ({ wide: 1.5, normal: 1, fine: 0.7 })[((scene.env && scene.env.cfg && scene.env.cfg.GridGap) || "normal")] || 1
        onFactorChanged: requestPaint()
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = fill
            ctx.fillRect(0, 0, width, height)
            ctx.globalCompositeOperation = "destination-out"
            ctx.fillStyle = "#000000"
            ctx.beginPath()
            const gap = Math.max(18, Math.round(height / 42 * factor)), r = Math.max(1.3, Math.max(26, Math.round(height / 42)) / 22)
            for (let y = gap / 2; y < height; y += gap)
                for (let x = gap / 2; x < width; x += gap) { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, 2 * Math.PI) }
            ctx.fill()
        }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { pingAnim.restart() } }
}
