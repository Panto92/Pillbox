/*
 * The pointer on one dock icon, the same for every dock form:
 * click (left / middle / right), drag along the dock to reorder, mouse wheel to step
 * through the app's windows. Dragging moves only the icon's look (dragOffset);
 * the dock reorders once on release.
 * SPDX-License-Identifier: MIT
 */
import QtQuick

MouseArea {
    id: ma
    property var orb
    property int index: -1                 // -1: not an app (all applications, trash)
    property real step: 60                 // distance between two icons
    property Item frame                    // the unrotated row the icons sit in
    readonly property real dragOffset: dragging ? dx : 0
    property bool dragging: false
    property real dx: 0
    property real startX: 0
    property bool swallowClick: false
    property real wheelSum: 0
    signal tapped(var mouse)

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    preventStealing: true

    function along(m) { return (frame ? ma.mapToItem(frame, m.x, m.y) : Qt.point(m.x, m.y)).x }
    onPressed: m => { startX = along(m); dx = 0 }
    onPositionChanged: m => {
        if (index < 0 || !(pressedButtons & Qt.LeftButton)) return
        dx = along(m) - startX
        if (!dragging && Math.abs(dx) > step * 0.35) { dragging = true; orb.slotLeft() }
    }
    onReleased: m => {
        if (!dragging) return
        const to = Math.max(0, Math.min(orb.apps.count - 1, index + Math.round(dx / step)))
        dragging = false; dx = 0; swallowClick = true
        if (to !== index) orb.moveApp(index, to)
    }
    onCanceled: { dragging = false; dx = 0 }
    onClicked: m => { if (swallowClick) { swallowClick = false; return } tapped(m) }
    onWheel: w => {
        if (index < 0) return
        wheelSum += w.angleDelta.y || w.angleDelta.x
        if (Math.abs(wheelSum) >= 120) { orb.cycleWindows(index, wheelSum < 0); wheelSum = 0 }
    }
}
