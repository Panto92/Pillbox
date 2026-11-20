// A streak of light (shooting star, comet) – runs only for about a second.  SPDX-License-Identifier: MIT
import QtQuick
Rectangle {
    id: m
    property real fromX; property real fromY; property real toX; property real toY
    property int duration: 1100
    property color tone: "#f4f6ff"
    width: 140; height: 2; radius: 1; opacity: 0
    transformOrigin: Item.Right
    rotation: Math.atan2(toY - fromY, toX - fromX) * 180 / Math.PI
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: m.tone }
    }
    function fire(fx, fy, tx, ty) { fromX = fx; fromY = fy; toX = tx; toY = ty; anim.restart() }
    ParallelAnimation {
        id: anim
        NumberAnimation { target: m; property: "x"; from: m.fromX - m.width; to: m.toX - m.width; duration: m.duration; easing.type: Easing.InQuad }
        NumberAnimation { target: m; property: "y"; from: m.fromY; to: m.toY; duration: m.duration; easing.type: Easing.InQuad }
        SequentialAnimation {
            NumberAnimation { target: m; property: "opacity"; to: 1; duration: 180 }
            PauseAnimation { duration: Math.max(0, m.duration - 600) }
            NumberAnimation { target: m; property: "opacity"; to: 0; duration: 420 }
        }
    }
}
