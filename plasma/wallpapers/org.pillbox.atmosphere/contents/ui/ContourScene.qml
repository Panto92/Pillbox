/*
 * Contour – topographic lines, nothing else. Light by day, glowing lines at night.
 * CPU: the lines move more. GPU: the valleys glow warm. Unread: a wave runs through.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property real t: env ? env.time : 0
    readonly property real cpu: env ? env.cpu : 0
    readonly property real gpu: env ? env.gpu : 0
    readonly property var sky: P.sky(hour, [140, 150, 160], 0.1)
    readonly property real dayK: Math.max(0, Math.min(1, (sky.light - 0.3) / 0.6))
    readonly property var lineTone: P.mix([150, 205, 232], [44, 56, 68], dayK)
    property real wave: -5
    readonly property string dens: ((env && env.cfg && env.cfg.ContourDensity) || "normal")
    readonly property int lines: dens === "fine" ? 26 : dens === "wide" ? 12 : 18
    readonly property real gap: 0.96 / lines
    NumberAnimation { id: waveAnim; target: scene; property: "wave"; from: -3; to: scene.lines + 4; duration: 2600 }

    Rectangle { anchors.fill: parent; color: P.col(P.mix([10, 13, 19], [214, 220, 226], scene.dayK)) }
    Repeater {
        model: scene.lines
        Shape {
            id: ln
            required property int index
            readonly property real amp: scene.height * 0.035
            readonly property real hi: Math.max(0, 1 - Math.abs(index - scene.wave) / 1.5)
            readonly property real valley: Math.max(0, (index - scene.lines / 2) / (scene.lines / 2))
            width: scene.width * 2; height: amp * 2 + 8
            x: -((scene.t * scene.width / (120 + index * 7)) % scene.width)
            y: scene.height * (0.03 + index * scene.gap) - amp
            transform: Scale { origin.y: ln.amp; yScale: 1 + scene.cpu }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: P.col(P.mix(P.mix(scene.lineTone, [255, 150, 90], scene.gpu * ln.valley), [255, 255, 255], ln.hi * (1 - scene.dayK) * 0.5),
                                   0.22 + (1 - scene.dayK) * 0.14 + ln.hi * 0.5)
                strokeWidth: 1.2 + ln.hi * 1.2
                PathPolyline {
                    path: {
                        const W = scene.width, pts = [], ph = ln.index * 0.9
                        for (let x = 0; x <= 2 * W; x += 12) {
                            const u = x / W
                            pts.push(Qt.point(x, ln.amp + ln.amp * (Math.sin(2 * Math.PI * 2 * u + ph) * 0.55 + Math.sin(2 * Math.PI * 3 * u + ph * 1.7) * 0.3 + Math.sin(2 * Math.PI * 5 * u + ph * 0.6) * 0.15)))
                        }
                        return pts
                    }
                }
            }
        }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { waveAnim.restart() } }
}
