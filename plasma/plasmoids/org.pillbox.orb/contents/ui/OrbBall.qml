/*
 * The glowing ball: rotating aura, breathing core, soft glow.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: ball

    property color accent: "#7f97a6"
    property int ballSize: 30
    property bool hot: false          // hovered / drop target: brighter, a bit larger
    property bool alert: false        // a window demands attention: amber pulse
    property string effect: "aura"    // aura | pulse | calm | plain
    property int speed: 100           // percent, 100 = normal
    readonly property real tempo: Math.max(0.25, speed / 100)
    readonly property color tone: alert ? "#d9a35b" : accent

    implicitWidth: ballSize * 2
    implicitHeight: ballSize * 2

    // rotating aura ring
    Shape {
        id: aura
        anchors.centerIn: parent
        width: ball.ballSize * 1.62; height: width
        visible: ball.effect === "aura" || ball.effect === "calm"
        opacity: ball.hot ? 1 : 0.75
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity { NumberAnimation { duration: 250 } }

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: aura.width / 2; centerY: aura.height / 2
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.18; color: Qt.rgba(ball.tone.r, ball.tone.g, ball.tone.b, 0.85) }
                GradientStop { position: 0.36; color: "transparent" }
                GradientStop { position: 0.58; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 0.72; color: "transparent" }
                GradientStop { position: 0.88; color: Qt.rgba(ball.tone.r, ball.tone.g, ball.tone.b, 0.55) }
                GradientStop { position: 1.00; color: "transparent" }
            }
            PathAngleArc { centerX: aura.width / 2; centerY: aura.height / 2; radiusX: aura.width / 2; radiusY: aura.width / 2; startAngle: 0; sweepAngle: 360 }
            PathAngleArc { moveToStart: true; centerX: aura.width / 2; centerY: aura.height / 2; radiusX: aura.width / 2 - 3; radiusY: aura.width / 2 - 3; startAngle: 0; sweepAngle: 360 }
        }
        RotationAnimator on rotation { from: 0; to: 360; duration: (ball.hot ? 2400 : 6500) / ball.tempo; loops: Animation.Infinite; running: ball.effect === "aura" }
    }

    // core with a light spot, rendered into a layer so it can glow
    Item {
        id: coreSrc
        anchors.centerIn: parent
        width: ball.ballSize; height: ball.ballSize
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: coreSrc.width * 0.5; centerY: coreSrc.height * 0.5; centerRadius: coreSrc.width * 0.5
                    focalX: coreSrc.width * 0.36; focalY: coreSrc.height * 0.3; focalRadius: 0
                    GradientStop { position: 0.0; color: "#ffffff" }
                    GradientStop { position: 0.32; color: Qt.lighter(ball.tone, 1.25) }
                    GradientStop { position: 0.75; color: ball.tone }
                    GradientStop { position: 1.0; color: Qt.darker(ball.tone, 1.6) }
                }
                PathAngleArc { centerX: coreSrc.width / 2; centerY: coreSrc.height / 2; radiusX: coreSrc.width / 2; radiusY: coreSrc.width / 2; startAngle: 0; sweepAngle: 360 }
            }
        }
    }
    MultiEffect {
        id: core
        source: coreSrc
        anchors.fill: coreSrc
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: ball.tone
        shadowBlur: 1.0
        shadowOpacity: ball.effect === "plain" ? 0.45 : (ball.hot ? 1.0 : 0.85)
        shadowScale: ball.effect === "pulse" ? 1.45 : 1.25
        shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        blurMax: 32
        brightness: ball.hot ? 0.12 : 0

        transformOrigin: Item.Center
        scale: ball.hot ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        // slow breathing; faster pulse when something needs attention
        // breathing: strong for "pulse", gentle for "aura", none for "calm"/"plain";
        // a window demanding attention always pulses
        readonly property bool breathes: ball.alert || ball.effect === "aura" || ball.effect === "pulse"
        readonly property real low: ball.alert ? 0.55 : ball.effect === "pulse" ? 0.45 : 0.88
        readonly property int half: ball.alert ? 450 : Math.round((ball.effect === "pulse" ? 1300 : 2100) / ball.tempo)
        SequentialAnimation on opacity {
            loops: Animation.Infinite; running: core.breathes
            NumberAnimation { to: core.low; duration: core.half; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: core.half; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) core.opacity = 1
        }
    }
}
