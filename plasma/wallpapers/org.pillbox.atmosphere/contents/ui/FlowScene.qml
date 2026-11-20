/*
 * Flow – soft clouds of colour drifting into each other.
 * Six radial-gradient shapes, built once per colour change; they move with the
 * shared slow clock and stop when the screen is covered.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import "palette.js" as P

Item {
    id: scene
    property var env
    readonly property real hour: env ? env.hour : 15
    readonly property var sky: P.sky(hour, [120, 110, 170], 0.1)
    readonly property real dark: 1 - sky.light
    readonly property real warm: env ? env.gpu : 0
    // the hour picks a palette: night violet, morning peach, day blue, evening rose
    readonly property var pal: hour < 6 || hour > 21 ? [[60, 40, 120], [20, 70, 130], [110, 50, 140]]
                             : hour < 10 ? [[255, 160, 130], [140, 150, 220], [250, 200, 170]]
                             : hour < 17 ? [[80, 170, 220], [120, 210, 200], [150, 160, 240]]
                             : [[240, 120, 140], [250, 170, 110], [140, 100, 190]]

    Rectangle {
        anchors.fill: parent
        color: P.col(P.mix(scene.sky.top, [6, 8, 14], 0.55 + scene.dark * 0.3))
        Behavior on color { ColorAnimation { duration: 4000 } }
    }

    // positions follow the shared slow clock (main.qml): a few updates per second,
    // smooth enough for blurry clouds, cheap for the compositor
    readonly property real t: env ? env.time : 0

    Repeater {
        model: 6
        Shape {
            id: blob
            required property int index
            readonly property real r: Math.max(scene.width, scene.height) * (0.35 + (index % 4) * 0.08)
            readonly property color tone: P.col(P.mix(scene.pal[index % 3], [255, 140, 70], scene.warm * 0.45), 0.34 - scene.dark * 0.12)
            readonly property real sx: 0.07 + (index % 3) * 0.035
            readonly property real sy: 0.05 + (index % 2) * 0.04
            width: r * 2; height: r * 2
            x: scene.width * (0.5 + 0.42 * Math.sin(index * 1.37 + 0.4 + scene.t * sx)) - r
            y: scene.height * (0.5 + 0.38 * Math.cos(index * 2.11 + 1.1 + scene.t * sy)) - r
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: blob.r; centerY: blob.r; centerRadius: blob.r
                    focalX: blob.r; focalY: blob.r
                    GradientStop { position: 0; color: blob.tone }
                    GradientStop { position: 1; color: Qt.rgba(blob.tone.r, blob.tone.g, blob.tone.b, 0) }
                }
                PathAngleArc { centerX: blob.r; centerY: blob.r; radiusX: blob.r; radiusY: blob.r; startAngle: 0; sweepAngle: 360 }
            }
        }
    }

    // a soft ring for a new notification
    Rectangle {
        id: pulse
        anchors.centerIn: parent
        width: 10; height: width; radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.35)
        opacity: 0
        ParallelAnimation {
            id: pulseAnim
            NumberAnimation { target: pulse; property: "width"; from: 40; to: Math.max(scene.width, scene.height) * 1.1; duration: 2600; easing.type: Easing.OutCubic }
            NumberAnimation { target: pulse; property: "opacity"; from: 0.9; to: 0; duration: 2600 }
        }
    }
    Connections { target: scene.env; ignoreUnknownSignals: true; function onNewNotification() { pulseAnim.restart() } }
}
