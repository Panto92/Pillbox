/*
 * One app in the ring: icon tile, window dots, hover/active state.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: slot

    property int slotIndex: 0
    property int slotCount: 1
    property real ringRadius: 100
    property point centre: Qt.point(0, 0)
    property bool open: false
    property color accent: "#7f97a6"
    property var iconSource
    property int windows: 0
    property bool pinned: true
    property bool running: false     // has at least one window
    property bool front: false       // was the active app when the ring opened
    property bool minimized: false   // all its windows are minimised
    property bool highlighted: false
    property bool addSlot: false
    property real angleOffset: 0          // degrees; the outer ring sits between the inner slots
    property int tile: 60
    property bool useAppColor: true
    property int badge: 0

    // glow colour: the icon's own dominant colour, unless it is greyish (then the orb colour)
    Kirigami.ImageColors { id: iconColors; source: slot.iconSource }
    onIconSourceChanged: iconColors.update()
    Component.onCompleted: iconColors.update()
    readonly property color tint: {
        const c = iconColors.dominant
        if (!slot.useAppColor || slot.addSlot || c.a === 0 || c.hslSaturation < 0.2) return slot.accent
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.55), 0.7), 1)
    }

    signal entered()
    signal exited()
    signal clicked(var mouse)

    readonly property real angle: (-90 + angleOffset + slotIndex * 360 / Math.max(1, slotCount)) * Math.PI / 180

    width: tile; height: tile
    x: centre.x - width / 2 + (open ? Math.cos(angle) * ringRadius : 0)
    y: centre.y - height / 2 + (open ? Math.sin(angle) * ringRadius : 0)
    scale: open ? (highlighted ? 1.18 : 1) : 0.3
    opacity: open ? 1 : 0
    Behavior on x { NumberAnimation { duration: 340 + slot.slotIndex * 18; easing.type: Easing.OutBack } }
    Behavior on y { NumberAnimation { duration: 340 + slot.slotIndex * 18; easing.type: Easing.OutBack } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 180 } }

    // soft glow behind running apps
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 12; height: width; radius: slot.tile * 0.36
        visible: slot.running && !slot.minimized
        color: "transparent"
        border.width: 6
        border.color: Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, slot.front ? 0.35 : 0.16)
    }

    Rectangle {
        anchors.fill: parent
        radius: slot.tile * 0.3
        color: slot.front ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.42)
             : slot.highlighted ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.28)
             : slot.running ? Qt.rgba(slot.tint.r * 0.25, slot.tint.g * 0.25, slot.tint.b * 0.25, 0.92)
             : Qt.rgba(0.08, 0.1, 0.12, 0.85)
        border.width: slot.running ? 1.5 : 1
        border.color: slot.addSlot ? Qt.rgba(1, 1, 1, 0.28)
                     : slot.running ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, slot.front ? 1 : 0.75)
                     : slot.highlighted ? Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, 0.6)
                     : Qt.rgba(1, 1, 1, 0.1)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(slot.tile * (slot.addSlot ? 0.4 : 0.64)); height: width
        source: slot.iconSource
        opacity: slot.addSlot ? 0.6 : slot.running ? 1 : 0.7
    }

    // one dot per window (max 3): accent = open, hollow = minimised, long = in front
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 4
        spacing: 3
        Repeater {
            model: Math.min(slot.windows, 3)
            Rectangle {
                width: slot.front ? 12 : 5; height: 5; radius: 2.5
                color: slot.minimized ? "transparent" : slot.tint
                border.width: slot.minimized ? 1 : 0
                border.color: "#e6ecf0"
            }
        }
    }

    Rectangle {
        visible: slot.badge > 0
        anchors { right: parent.right; top: parent.top; rightMargin: -5; topMargin: -5 }
        height: 18; width: Math.max(height, badgeLabel.implicitWidth + 8); radius: height / 2
        color: slot.tint
        border.width: 1.5; border.color: "#0d1013"
        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: slot.badge > 99 ? "99+" : slot.badge
            color: "#0d1013"; font.bold: true; font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onEntered: slot.entered()
        onExited: slot.exited()
        onClicked: mouse => slot.clicked(mouse)
    }
}
