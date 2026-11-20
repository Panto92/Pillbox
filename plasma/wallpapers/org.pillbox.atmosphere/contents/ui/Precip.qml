/*
 * Rain or snow for a while after a notification. Only exists while it falls;
 * otherwise invisible and stopped.  SPDX-License-Identifier: MIT
 */
import QtQuick
import "palette.js" as P
Item {
    id: pr
    anchors.fill: parent
    property bool snow: false
    property bool active: false
    property real phase: 0
    opacity: active ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 2500 } }
    function start(seconds) { active = true; stopper.interval = seconds * 1000; stopper.restart() }
    Timer { id: stopper; onTriggered: pr.active = false }
    NumberAnimation on phase { from: 0; to: 1000; duration: 1000000; loops: Animation.Infinite; running: pr.visible }
    Repeater {
        model: pr.visible ? (pr.snow ? 90 : 110) : 0
        Rectangle {
            required property int index
            readonly property real sp: pr.snow ? 0.06 + P.rnd(index, 2) * 0.05 : 1.0 + P.rnd(index, 2) * 0.6
            readonly property real fy: (pr.phase * sp + P.rnd(index, 3)) % 1
            x: P.rnd(index, 1) * pr.width + (pr.snow ? Math.sin(pr.phase * 1.3 + index) * 18 : -fy * pr.height * 0.12)
            y: fy * (pr.height + 40) - 20
            width: pr.snow ? 2 + P.rnd(index, 4) * 3 : 1
            height: pr.snow ? width : 16 + P.rnd(index, 4) * 12
            radius: pr.snow ? width / 2 : 0
            rotation: pr.snow ? 0 : 7
            color: pr.snow ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0.8, 0.86, 0.95, 0.32)
        }
    }
}
