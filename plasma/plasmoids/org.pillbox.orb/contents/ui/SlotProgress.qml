/*
 * A thin progress line over the lower edge of a dock icon while the app has a job
 * running (download, copy …), from Plasma's job notifications.
 * SPDX-License-Identifier: MIT
 */
import QtQuick

Item {
    property real value: -1                // 0 … 100, below 0: nothing running
    property color tint: "white"
    visible: value >= 0
    height: 4
    Rectangle { anchors.fill: parent; radius: 2; color: Qt.rgba(0, 0, 0, 0.55) }
    Rectangle {
        height: parent.height; radius: 2
        width: Math.max(height, parent.width * Math.min(100, parent.value) / 100)
        color: parent.tint
        Behavior on width { NumberAnimation { duration: 300 } }
    }
}
